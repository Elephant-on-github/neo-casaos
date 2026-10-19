package route

import "testing"

// TestInitV1RouterDoesNotPanic guards against echo panicking at startup due to
// conflicting or overlapping route registrations (e.g. the public file-share
// resolve route vs the authenticated share management routes).
func TestInitV1RouterDoesNotPanic(t *testing.T) {
	handler := InitV1Router()
	if handler == nil {
		t.Fatal("expected a non-nil handler from InitV1Router")
	}
}
