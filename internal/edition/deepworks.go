//go:build deepworks

// Package edition names this build. The deepworks tag makes a magpie that is
// about one thing: the models DeepWorks ships, with everything else left as
// it is. The default build says magpie, so nothing outside the tag changes.
package edition

const (
	// Name is what the window, the tray and the about line say.
	Name = "DeepWorks Bridge"
	// Short is the name where a sentence needs one word ("DeepWorks Bridge
	// is running" reads wrong in a menu).
	Short = "DeepWorks"
	// ID seeds the app's bundle id, so this build and magpie keep separate
	// settings, sign-ins and history.
	ID = "com.yetone.deepworks-bridge"
	// DeepWorks is true in this build: the parts that only make sense here
	// are compiled in, and the ones that don't can be left out.
	DeepWorks = true
)

// Version is the version this build reports, told apart from magpie's.
func Version(base string) string { return base + "-dw" }
