# Task brief — T5b: Fix verification findings (quic-go vuln + printf vet)

## Context
Verification (T5) on branch `chore/deps-license-maintenance` surfaced two actionable items that keep `go test`/CI from being green. Fix both here. `GOOS=linux CGO_ENABLED=0 go build ./...` currently passes; keep it passing.

## Requirements
1. Clear the NEW vuln GO-2026-5676 in `github.com/quic-go/quic-go` (currently v0.59.0, indirect via oapi-codegen). Fix is FORWARD: bump to the earliest quic-go patch >= v0.59.1 that resolves it (try `go get github.com/quic-go/quic-go@v0.59.1`; if that exact patch is absent, use the lowest v0.59.x patch > v0.59.0). Then `go mod tidy`. Do NOT pin backward.
2. Fix the 4 vet "non-constant format string in call to fmt.Errorf" errors by replacing `fmt.Errorf(e.Error)` with `errors.New(e.Error)`:
   - `drivers/dropbox/util.go:34`
   - `drivers/dropbox/util.go:55`
   - `drivers/google_drive/util.go:43`
   - `drivers/google_drive/util.go:65`
   Ensure the `errors` package is imported in both files (add `"errors"` to the import block; if `fmt` becomes unused in a file, leave imports correct — `goimports`/`go mod tidy` won't fix imports, so set them correctly by hand).
3. Verify after fixes:
   - `GOOS=linux CGO_ENABLED=0 go vet ./drivers/dropbox/... ./drivers/google_drive/...` → the 4 errors are gone.
   - `GOOS=linux CGO_ENABLED=0 go build ./...` → exit 0.
   - `go run golang.org/x/vuln/cmd/govulncheck@latest ./...` (GOOS=linux if needed) → GO-2026-5676 no longer reported.

## Constraints
- This is a sanctioned 4-line source fix (controller ruling) — change ONLY those 4 lines + imports + go.mod/go.sum for quic-go. Nothing else.
- Do not touch LICENSE. Commit with gitmoji `:bug:` (or `:package:` for the quic-go bump) — a single commit is fine, e.g. `:bug: Clear quic-go vuln and fix non-constant fmt.Errorf vet errors`.

## Report
Write the full report to `.superpowers/sdd/t5b-fix-report.md`. Return only: status, commit SHA(s), one-line verify results (vet clean / build exit / vuln cleared), and concerns.
