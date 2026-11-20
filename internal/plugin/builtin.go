package plugin

import (
	"bytes"
	"embed"
	"encoding/json"
	"os"
	"path/filepath"

	"github.com/yetone/magpie/internal/edit"
)

// DeepWorks ships as a plugin of magpie's own: the package is embedded in
// the binary and written into the plugins folder on start, so it is there
// on a fresh install with nothing to fetch. The provider it declares is
// DeepFoundry's, and its key is read off DeepWorks's runtime folder per
// request — see builtin/deepworks/index.mjs.
//
//go:embed builtin/deepworks/package.json builtin/deepworks/index.mjs
var builtinDeepworks embed.FS

// BuiltinDeepworksID is the provider the embedded plugin signs in to.
const BuiltinDeepworksID = "deepworks"

// EnsureBuiltinDeepworks writes the embedded plugin where the host looks
// for it and puts it on the list, once: a plugin the user turned off stays
// off, and one already on the list is left as it is.
func EnsureBuiltinDeepworks() error {
	dir := filepath.Join(Dir(), "builtin", BuiltinDeepworksID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return err
	}
	for _, name := range []string{"package.json", "index.mjs"} {
		want, err := builtinDeepworks.ReadFile("builtin/" + BuiltinDeepworksID + "/" + name)
		if err != nil {
			return err
		}
		path := filepath.Join(dir, name)
		if have, err := os.ReadFile(path); err == nil && bytes.Equal(have, want) {
			continue
		}
		if err := edit.WriteAtomic(path, want); err != nil {
			return err
		}
	}

	l := Load()
	for _, e := range l.Plugins {
		if e.Spec == dir {
			return ensureBuiltinDeepworksAuth()
		}
	}
	l.Plugins = append(l.Plugins, Entry{Spec: dir})
	if err := save(l); err != nil {
		return err
	}
	return ensureBuiltinDeepworksAuth()
}

// ensureBuiltinDeepworksAuth marks the provider signed in when it is not:
// there is no sign-in to perform, only a key DeepWorks already wrote, and
// a provider with no account is one no agent is offered. The key kept here
// is a marker; every request is signed with the one on disk at that moment
// (the plugin's chat.headers), so a re-sign-in needs nothing done here.
func ensureBuiltinDeepworksAuth() error {
	path := AuthPath()
	all := map[string]json.RawMessage{}
	if b, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(b, &all)
	}
	if _, ok := all[BuiltinDeepworksID]; ok {
		return nil
	}
	key := "deepworks"
	if k := deepworksKeyOnDisk(); k != "" {
		key = k
	}
	b, err := json.Marshal(map[string]any{
		"type": "api",
		"key":  key,
	})
	if err != nil {
		return err
	}
	all[BuiltinDeepworksID] = b
	out, err := json.MarshalIndent(all, "", "  ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	return edit.WriteAtomic(path, append(out, '\n'))
}

// deepworksKeyOnDisk is DeepWorks's key, when the app is here and signed in.
// The plugin reads the same file; this only seeds the account marker.
func deepworksKeyOnDisk() string {
	dir := os.Getenv("DEEPWORKS_RUNTIME_DIR")
	if dir == "" {
		return ""
	}
	b, err := os.ReadFile(filepath.Join(dir, "dth-auth.json"))
	if err != nil {
		return ""
	}
	var a struct {
		DTH struct {
			Key string `json:"key"`
		} `json:"dth"`
	}
	if json.Unmarshal(b, &a) != nil {
		return ""
	}
	return a.DTH.Key
}
