# T7 report — Upstream CasaOS issue/PR triage (neo-casaos)

Date: 2026-10-19. Source: `gh` CLI, authenticated (account: Elephant-on-github). READ-ONLY — nothing committed, no source touched.

## Data pulled
- **823 open issues** (all pages, `gh api .../issues?state=open&per_page=100 --paginate`, PRs filtered out).
- **15 open PRs** (`gh api .../pulls?state=open`), with diff stats/files fetched per PR.

## Fork divergence (conflict surface)
Our branch is 3 commits ahead of `upstream/main`:
- `cfabccc` — quic-go vuln clear + `fmt.Errorf`→`errors.New` vet fixes in `drivers/dropbox/util.go` and `drivers/google_drive/util.go` (the 4-line printf fix).
- `fee0b50` — GitHub Actions major bumps in 5 workflows (`casa.yml`, `codecov.yml`, `demo.yml`, `publish_npm.yaml`, `push_test_server.yml`).
- `68190f5` — Go dep updates in `go.mod`/`go.sum` (incl. go-directive `1.21` → `1.26.0`).

Conflict surface = `go.mod`, `go.sum`, 5 workflow files, `drivers/dropbox/util.go`, `drivers/google_drive/util.go`.

## Bucket counts
| Bucket | Count |
|---|---|
| Bugs small/addressable, dep or build health (our lane) | ~6 issue clusters (see below) |
| Dependency/security-related open items | ~7 issues + 4 PRs (#2462, #2566, #2546, #2585) |
| NOT relevant to a dep-maintenance fork (UI/features/app requests/translations/feedback spam) | ~810 issues + 11 PRs — count only |

Notes on bucket 1/2 items not shortlisted:
- The massive **"Failed to load apps" / Docker 29 API incompatibility** cluster (#2404, #2399, #2390, #2396, #2407, ~40 duplicate feedback issues) is upstream's biggest active pain, but **not fixable in this repo**: `go.mod` contains no Docker client dependency at all — the breakage lives in the app-management/installer side. Out of scope for small candidates.
- #2358 (OneDrive login fails, expired app credentials), #2452 (apt pin `24.0.7` not found), #2251 (Arch udevil compile fail) — installer/credential issues in sibling repos.
- #2362/#2357 (expired SSL cert on casaos.zimaspace.com) — upstream infra, not code.

## TOP 5 follow-up candidates

1. **PR #2530 — fix: fallback to displayName when OneDrive email is empty in GetInfo**
   https://github.com/IceWhaleTech/CasaOS/pulls/2530 — +9/−1, 1 file (`drivers/onedrive/drive.go`), mergeable=clean, 1 commit.
   Why: trivially small, single-file, zero overlap with our divergence surface, hardens a cloud driver against empty-identity crashes. Effort: **trivial** (cherry-pick + build).

2. **PR #2582 — fix: copy the network counters instead of reinterpreting them**
   https://github.com/IceWhaleTech/CasaOS/pulls/2582 — +71/−5, 4 files (`model/net.go`, `model/net_test.go`, `route/periodical.go`, `route/v1/system.go`), includes a test, actively maintained (updated 2026-10-17).
   Why: fixes an unsafe reinterpret of gopsutil counters (classic panic/data-corruption shape), in our build-health lane, no overlap with our files. Effort: **small**; caveat: upstream CI state=unstable — verify the test locally.

3. **PR #2359 — Fix broken Samba user management functions in helper.sh**
   https://github.com/IceWhaleTech/CasaOS/pulls/2359 — +3/−3, 1 file (`build/sysroot/usr/share/casaos/shell/helper.sh`), mergeable=clean, stale since 2025-09.
   Why: one-liner, stale (preferring stale is our brief), touches Samba user mgmt tied to the long-running #692/#1113 Samba-auth issue family. Effort: **trivial**.

4. **PR #2296 — Fix coding bugs: Replace panic with proper error handling**
   https://github.com/IceWhaleTech/CasaOS/pulls/2296 — +10/−8, 2 files (`main.go`, `pkg/utils/httper/httper.go`), stale since 2025-07.
   Why: tiny robustness fix, no overlap with our changed files. Effort: **small**; caveat: upstream CI state=blocked — build/test locally before adopting.

5. **Issue #2588 — [Bug] Release binaries packed with UPX 3.96 --lzma randomly fail to start (exit 127)**
   https://github.com/IceWhaleTech/CasaOS/issues/2588 — open, 0 comments, filed 2026-10-16.
   Why: pure build/release-health bug squarely in our lane; probable fix is dropping/upgrading UPX compression. Effort: **small–medium** (investigate first: our workflows have no direct `upx` reference — the packing likely happens in upstream's packaging step, so confirm where before estimating).

Honorable mention: **PR #2555** (dedupe `CopyFile`/`CopySingleFile`, +164/−239, `pkg/utils/file/file.go`, clean) — safe vs our fork but larger and it conflicts with PR #2546 (same file); pick at most one if either is ever taken.

## Conflict warnings vs our branch
- **PR #2462** ("deps: Upgrade 9 packages to remove 21 vulnerabilities", go.mod+go.sum only) — **WILL CONFLICT** with our dep updates/go-directive bump. Likely superseded by our newer pins; action item is to re-run `govulncheck` against our HEAD and confirm the 21 vulns are already covered, rather than merging.
- **PR #2566** ("Security: patch critical vulnerabilities and remove hardcoded secrets", 32 files, +1244/−520) — **WILL CONFLICT** on `go.mod`, `go.sum`, `drivers/dropbox/util.go`, `drivers/google_drive/util.go` (our `errors.New` fix overlaps files they also modify). Too large to be a "small candidate" anyway; if ever wanted, cherry-pick selectively.
- **PRs #2555 and #2546 conflict with each other** (both rewrite `pkg/utils/file/file.go`).
- **No conflicts expected** for shortlisted #2530, #2582, #2359, #2296 (none touch our divergence surface).

## Concerns
- Upstream CI is red/unstable on #2582 (unstable) and #2296 (blocked); local build+test required before adopting either.
- The Docker-29 "Failed to load apps" mega-cluster dominates upstream pain but is out of reach for this repo (no docker dep in go.mod) — don't let its visibility distort fork priorities.
- Issue #2588's exact fix location (release packaging) is unverified.
- Only the newest 100-issue page window was read in full detail; older issues (2022–2024, mostly stale feedback) were bucketed by title/labels only — a small dependency-related item could hide there, though recent items dominate relevance.
