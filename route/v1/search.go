/*
 * @Author: neo
 * @Description: Recursive file-name search for the file browser.
 */
package v1

import (
	"context"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/IceWhaleTech/CasaOS/model"
	"github.com/IceWhaleTech/CasaOS/pkg/utils/common_err"
	"github.com/labstack/echo/v4"
)

const (
	searchMaxResults = 500
	searchMaxDepth   = 12
	searchTimeout    = 15 * time.Second
)

// SearchResult is a single matched path.
type SearchResult struct {
	Path  string    `json:"path"`
	Name  string    `json:"name"`
	IsDir bool      `json:"is_dir"`
	Size  int64     `json:"size"`
	Date  time.Time `json:"date"` // mtime; renders in the file browser list
}

// SearchFiles matches file/directory names under `path` containing `keyword`
// (case-insensitive substring). Returns up to searchMaxResults entries.
//
// GET /v1/file/search?path=/DATA&keyword=photo
func SearchFiles(ctx echo.Context) error {
	root := ctx.QueryParam("path")
	keyword := strings.TrimSpace(ctx.QueryParam("keyword"))

	if root == "" || keyword == "" {
		return ctx.JSON(http.StatusBadRequest, model.Result{
			Success: common_err.INVALID_PARAMS,
			Message: "path and keyword are required",
		})
	}
	if fi, err := os.Stat(root); err != nil || !fi.IsDir() {
		return ctx.JSON(http.StatusBadRequest, model.Result{
			Success: common_err.INVALID_PARAMS,
			Message: "path is not a directory",
		})
	}

	lower := strings.ToLower(keyword)

	// Fast path: GNU find does C-speed traversal (and matches directory names,
	// which ripgrep --files cannot).
	if results, ok := findSearch(root, keyword); ok {
		return ctx.JSON(common_err.SUCCESS, model.Result{
			Success: common_err.SUCCESS,
			Message: common_err.GetMsg(common_err.SUCCESS),
			Data:    results,
		})
	}

	// Fallback: bounded recursive walk in pure Go.
	results := searchWalk(root, lower)

	return ctx.JSON(common_err.SUCCESS, model.Result{
		Success: common_err.SUCCESS,
		Message: common_err.GetMsg(common_err.SUCCESS),
		Data:    results,
	})
}

// searchWalk is the non-rg fallback: case-insensitive substring match on file
// names, bounded by searchMaxDepth and searchMaxResults, skipping expensive
// virtual/package trees.
func searchWalk(root, lower string) []SearchResult {
	results := make([]SearchResult, 0, 64)
	_ = filepath.Walk(root, func(p string, info os.FileInfo, err error) error {
		if err != nil {
			return nil // skip unreadable entries
		}
		if len(results) >= searchMaxResults {
			return filepath.SkipAll // stop walking entirely
		}
		depth := strings.Count(strings.TrimPrefix(p, root), string(os.PathSeparator))
		if info.IsDir() {
			if depth >= searchMaxDepth || shouldSkipDir(info.Name()) {
				return filepath.SkipDir
			}
		}
		if strings.Contains(strings.ToLower(info.Name()), lower) {
			results = append(results, SearchResult{
				Path:  p,
				Name:  info.Name(),
				IsDir: info.IsDir(),
				Size:  info.Size(),
				Date:  info.ModTime(),
			})
		}
		return nil
	})
	return results
}

// shouldSkipDir excludes expensive/virtual trees we never want to traverse.
func shouldSkipDir(name string) bool {
	switch name {
	case "node_modules", ".git", ".cache", "proc", "sys", "dev", "run":
		return true
	}
	return false
}

// findSearch shells out to GNU find (always present on Linux, C-speed
// traversal, matches directory names too — ripgrep's --files cannot). The
// pattern is an -iname glob with user input escaped so keyword characters
// like *, ?, [ stay literal. Returns ok=false if find is unavailable so the
// caller can fall back to searchWalk.
func findSearch(root, keyword string) ([]SearchResult, bool) {
	if _, err := exec.LookPath("find"); err != nil {
		return nil, false
	}
	glob := "*" + escapeGlob(keyword) + "*"
	// Prune expensive trees first, then print matches:
	//   \( skip-list \) -prune -o -iname GLOB -print0
	// parses as: (skip AND prune) OR (iname AND print0)
	args := []string{root, "-maxdepth", strconv.Itoa(searchMaxDepth),
		"("}
	for i, n := range []string{"node_modules", ".git", ".cache", "proc", "sys", "dev", "run"} {
		if i > 0 {
			args = append(args, "-o")
		}
		args = append(args, "-name", n)
	}
	args = append(args, ")", "-prune", "-o", "-iname", glob, "-print0")

	// Hard deadline: a slow HDD or network mount must not stall the request
	// or stack unbounded find processes; timeout falls back to searchWalk.
	ctx, cancel := context.WithTimeout(context.Background(), searchTimeout)
	defer cancel()
	out, err := exec.CommandContext(ctx, "find", args...).Output()
	if err != nil {
		// unreadable subdirs make find exit non-zero — fall back to searchWalk
		return nil, false
	}

	results := make([]SearchResult, 0, 64)
	for _, p := range strings.Split(string(out), "\x00") {
		if p == "" {
			continue
		}
		name := filepath.Base(p)
		isDir := false
		var size int64
		var mtime time.Time
		if fi, statErr := os.Lstat(p); statErr == nil {
			isDir = fi.IsDir()
			size = fi.Size()
			mtime = fi.ModTime()
		}
		results = append(results, SearchResult{Path: p, Name: name, IsDir: isDir, Size: size, Date: mtime})
		if len(results) >= searchMaxResults {
			break
		}
	}
	return results, true
}

// escapeGlob makes user input safe to embed in a find -iname glob.
func escapeGlob(s string) string {
	r := strings.NewReplacer(`\`, `\\`, `*`, `\*`, `?`, `\?`, `[`, `\[`)
	return r.Replace(s)
}
