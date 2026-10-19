# X1 Fix Report — codecov Go version floor

**Branch:** `chore/deps-license-maintenance` (BASE `7c9a981`)
**Status:** DONE
**Commit:** `ce20dc6` — `:arrow_up: Bump codecov Go version to match go 1.26 floor`

## Issue addressed

The branch raised the module go floor to `go 1.26.0` in `go.mod`, but
`.github/workflows/codecov.yml` (the only workflow running `go test ./...`)
pinned `go-version: "1.20"`, so that CI job could no longer build the module.

## Change

Exactly one value on one line in `.github/workflows/codecov.yml`:

```diff
-          go-version: "1.20"
+          go-version: "1.26.3"
```

No other workflow, file, or line touched.

## Verification

- `git diff 7c9a981..HEAD --stat` / `git show --stat ce20dc6`:
  `1 file changed, 1 insertion(+), 1 deletion(-)` — only `.github/workflows/codecov.yml`.
- Working tree: clean except pre-existing untracked `.superpowers/` and `PLAN.md`
  (not part of this fix; left untracked).
- YAML parse: `npx --yes js-yaml .github/workflows/codecov.yml` → exit 0 (`YAML OK`).

## Concerns

- None blocking. `1.26.3` was specified by the controller and exists as a Go
  release; `setup-go@v5` resolves it fine.
- Note (out of scope): the workflow still uses `codecov/codecov-action@v3`,
  which is old; left untouched per instructions.
