//go:build !deepworks

// Package edition names this build: the default one is magpie. The deepworks
// tag switches every caller to the DeepWorks build's words without any of
// them knowing which they were built into.
package edition

const (
	Name      = "magpie"
	Short     = "magpie"
	ID        = "com.yetone.magpie"
	DeepWorks = false
)

// Version is the version this build reports.
func Version(base string) string { return base }
