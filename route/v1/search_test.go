package v1

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/labstack/echo/v4"
)

func TestShouldSkipDir(t *testing.T) {
	for _, name := range []string{"node_modules", ".git", ".cache", "proc", "sys", "dev", "run"} {
		if !shouldSkipDir(name) {
			t.Errorf("shouldSkipDir(%q) = false, want true", name)
		}
	}
	for _, name := range []string{"Documents", "photos", "DATA", "sda1"} {
		if shouldSkipDir(name) {
			t.Errorf("shouldSkipDir(%q) = true, want false", name)
		}
	}
}

func TestSearchWalk(t *testing.T) {
	root := t.TempDir()
	// layout:
	//   root/Photo.jpg
	//   root/docs/notes.md
	//   root/docs/photos/holiday/photo2.jpg
	//   root/node_modules/photos/should_skip.jpg
	for _, rel := range []string{
		"Photo.jpg",
		"docs/notes.md",
		"docs/photos/holiday/photo2.jpg",
		"node_modules/photos/should_skip.jpg",
	} {
		p := filepath.Join(root, rel)
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(p, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	results := searchWalk(root, "photo")

	names := map[string]bool{}
	for _, r := range results {
		names[r.Name] = true
	}
	if !names["Photo.jpg"] {
		t.Errorf("expected case-insensitive match Photo.jpg, got %v", names)
	}
	if !names["photo2.jpg"] {
		t.Errorf("expected nested match photo2.jpg, got %v", names)
	}
	if names["should_skip.jpg"] {
		t.Errorf("node_modules contents must be skipped, got %v", names)
	}
	if names["notes.md"] {
		t.Errorf("non-matching file must not appear, got %v", names)
	}
}

func TestSearchWalkNoMatches(t *testing.T) {
	root := t.TempDir()
	if err := os.WriteFile(filepath.Join(root, "a.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := searchWalk(root, "zzz"); len(got) != 0 {
		t.Errorf("expected no results, got %v", got)
	}
}

func TestSearchWalkDepthCap(t *testing.T) {
	root := t.TempDir()
	// build a chain deeper than searchMaxDepth containing a matching leaf
	deep := root
	for i := 0; i <= searchMaxDepth+2; i++ {
		deep = filepath.Join(deep, "d")
	}
	if err := os.MkdirAll(deep, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(deep, "match_here.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	// also put a shallow match so the walk isn't trivially empty
	if err := os.WriteFile(filepath.Join(root, "match_root.txt"), []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}

	results := searchWalk(root, "match")
	for _, r := range results {
		rel := strings.TrimPrefix(r.Path, root)
		if strings.Count(rel, string(os.PathSeparator)) > searchMaxDepth {
			t.Errorf("result %q deeper than max depth %d", rel, searchMaxDepth)
		}
	}
	if len(results) == 0 {
		t.Error("expected shallow match to be found")
	}
}

func TestSearchWalkResultCap(t *testing.T) {
	root := t.TempDir()
	for i := 0; i < searchMaxResults+50; i++ {
		name := filepath.Join(root, fmt.Sprintf("file_match_%04d.txt", i))
		if err := os.WriteFile(name, []byte("x"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	results := searchWalk(root, "match")
	if len(results) > searchMaxResults {
		t.Errorf("results %d exceed cap %d", len(results), searchMaxResults)
	}
	if len(results) == 0 {
		t.Error("expected some matches")
	}
}

func TestEscapeGlob(t *testing.T) {
	// escapeGlob is the only barrier between user input and find's expression
	// parser — these cases pin the escaping.
	for in, want := range map[string]string{
		"photo":   "photo",
		"a*b":     `a\*b`, // glob repeat must stay literal
		"a?b":     `a\?b`, // glob single-char must stay literal
		"a[b":     `a\[b`, // opening bracket must not start a character class
		`a\b`:     `a\\b`, // backslash must not escape the next character
		"a]b":     "a]b",  // bare ] is literal in glob — must NOT be escaped
		`*\[]?`:   `\*\\\[]\?`,
		"hello..": "hello..",
	} {
		if got := escapeGlob(in); got != want {
			t.Errorf("escapeGlob(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestSearchFilesRejectsRelativePath(t *testing.T) {
	// a leading-`-` path would be parsed by find as an expression; the handler
	// must 400 on all relative paths before any subprocess is spawned.
	for _, p := range []string{"-delete", "relative/dir", "./x", "../x"} {
		e := echo.New()
		req := httptest.NewRequest(echo.GET,
			"/v1/file/search?path="+url.QueryEscape(p)+"&keyword=x", nil)
		rec := httptest.NewRecorder()
		ctx := e.NewContext(req, rec)

		if err := SearchFiles(ctx); err != nil {
			t.Fatalf("SearchFiles(%q): %v", p, err)
		}
		if rec.Code != http.StatusBadRequest {
			t.Errorf("path %q: status %d, want 400", p, rec.Code)
		}
	}
}
