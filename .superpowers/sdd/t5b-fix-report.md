# T5b fix report — quic-go vuln + printf vet errors

**Status:** DONE
**Commit:** `cfabccca26c475ce18d80eb301612be264406c88` — `:bug: Clear quic-go vuln and fix non-constant fmt.Errorf vet errors` (single commit, branch `chore/deps-license-maintenance`, base fee0b50)

## What was changed

### 1. quic-go vulnerability GO-2026-5676 (go.mod / go.sum)
- `go get github.com/quic-go/quic-go@v0.59.1` → `upgraded github.com/quic-go/quic-go v0.59.0 => v0.59.1` (v0.59.1 exists; used as-is per brief, no need for a later patch)
- `go mod tidy` run afterward. Only quic-go (and its go.sum entries) changed; `qpack v0.6.0` unchanged.

### 2. Vet printf errors (4 lines, per controller sanction)
- `drivers/dropbox/util.go:34` and `:55` — `return fmt.Errorf(e.Error)` → `return errors.New(e.Error)`; added `"errors"` to the import block (before `"fmt"`).
- `drivers/google_drive/util.go:43` and `:65` — same replacement; added `"errors"` to the import block (after `"context"`, before `"fmt"`).
- `fmt` is still used in both files (`fmt.Errorf`/`fmt.Sprintf` at dropbox/util.go:85 and google_drive/util.go:96,117,148), so the `fmt` import was kept — imports verified correct by hand and confirmed by the vet/build results.

**Diff scope:** exactly 4 source lines + 2 import lines + go.mod + go.sum (4 files changed, 9 insertions, 7 deletions). LICENSE untouched. Nothing else modified. Untracked `.superpowers/` and `PLAN.md` were deliberately NOT committed.

## Verification results (all run post-change, pre-commit)

| Check | Command | Result |
|---|---|---|
| Vet | `GOOS=linux CGO_ENABLED=0 go vet ./drivers/dropbox/... ./drivers/google_drive/...` | exit 0 — the 4 non-constant-format-string errors are gone, no new diagnostics |
| Build | `GOOS=linux CGO_ENABLED=0 go build ./...` | exit 0 |
| Vuln | `GOOS=linux govulncheck ./...` (govulncheck@latest installed to host, GOOS=linux set for the scan) | exit 3 overall (pre-existing unrelated vulns, see concerns), but grep of full output for `GO-2026-5676` and `quic-go` returns **zero matches** — the finding is cleared |

Notes on process:
- `go run golang.org/x/vuln/cmd/govulncheck@latest` with `GOOS=linux` fails on this Windows host (cross-compiled binary can't execute). Worked around by `go install`ing govulncheck for the host platform first, then running it with `GOOS=linux` env set — this scans the same Linux target CI uses.

## Concerns / notes for the controller

1. **govulncheck exit code is still non-zero (3):** the scan reports 24 vulnerabilities from 4 modules plus the Go stdlib (archiver/deps chain, etc.). These are PRE-EXISTING and unrelated to this finding — they do not appear in the verification brief and were out of sanctioned scope. If CI gates on govulncheck exit code rather than on the specific GO-2026-5676 finding, those older vulns will need a separate decision.
2. **Did not run `go test ./...`:** tests can't execute cross-OS on this Windows host (GOOS=linux). Both the target packages and the full module compile (`go build ./...`) and vet cleanly; CI (linux) is the environment that can actually run the test binaries.
3. quic-go v0.59.1 was available on the proxy — the brief's preferred exact patch resolved cleanly, no fallback to a higher v0.59.x patch was needed.
