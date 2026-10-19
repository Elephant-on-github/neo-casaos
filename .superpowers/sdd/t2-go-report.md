# T2 report — Fix + finalize Go dependency updates

**Status:** DONE_WITH_CONCERNS
**Branch:** `chore/deps-license-maintenance`
**Commit:** `68190f5` — `:package: Pin safetext and echo/v4 back, finalize Go dep updates` (files: `go.mod`, `go.sum` only)

## What was done

1. **Pinned safetext back (per brief req. 1)**
   `go get github.com/google/safetext@v0.0.0-20240104143208-7a7d9b3d812f`
   → downgraded `v0.0.0-20260929084330-d0e6ffa9feb4` → `v0.0.0-20240104143208-7a7d9b3d812f` (matches upstream `main`).
   This removed the reported failure (`common/common.go:126:18: cannot range over value.Len() … requires go1.22 or later; -lang was set to go1.21`).

2. **`go mod tidy`** — exit 0 (run twice, idempotent; final run exit 0).

3. **Second breakage found and fixed (brief req. 4): `github.com/labstack/echo/v4` v4.12.0 → v4.16.0**
   `go get -u ./...` had bumped echo to v4.16.0, which **removed the deprecated
   `middleware.JWTWithConfig` / `middleware.JWTConfig` shims** still used by
   `route/v1.go:44` and `route/v2.go:71`:
   ```
   route\v1.go:44:30: undefined: echo_middleware.JWTWithConfig
   route\v1.go:44:60: undefined: echo_middleware.JWTConfig
   route\v2.go:71:24: undefined: echo_middleware.JWTWithConfig
   route\v2.go:71:60: undefined: echo_middleware.JWTConfig
   ```
   Remedy: **pinned back, no source edits** — `go get github.com/labstack/echo/v4@v4.12.0`
   (upstream `main` uses `v4.12.0`). `echo-jwt/v4` followed down to `v4.2.1`
   (upstream `v4.2.0`; patch-level, left as-is). This was the only other dep that had to be pinned back.

4. **`go` directive (brief req. 5)** — the earlier `go get -u ./...` had raised it from upstream's
   `go 1.21` to `go 1.26.0`. I attempted to revert it: `go mod edit -go 1.21.0` succeeded, but
   `go mod tidy` immediately re-raised it to `go 1.26.0`. Confirmed cause: many updated deps now
   declare `go 1.26.0` themselves, e.g. `golang.org/x/sys v0.49.0`, `golang.org/x/net v0.61.0`,
   `modernc.org/sqlite v1.60.1`, `modernc.org/libc v1.79.0`, `mvdan.cc/sh/v3 v3.14.1`,
   `golang.org/x/tools v0.52.0`. So the bump is **required**, not gratuitous — noted as instructed.
   (Also observed: `go mod edit -go=1.21.0` with `=` form is rejected by go1.26.3
   `invalid -go option`; the space form `-go 1.21.0` works. Tooling quirk, not a repo issue.)

## Verification (evidence)

| Check | Command | Result |
|---|---|---|
| tidy | `go mod tidy` | exit **0** |
| build (target platform) | `GOOS=linux CGO_ENABLED=0 go build ./...` | exit **0** |
| build (native host) | `go build ./...` (win32) | exit **1** — pre-existing, see Concern 1 |
| baseline (pre-change) | stash `go.mod`/`go.sum`, `go build ./...` at HEAD | exit **1**, identical `service/connections.go` errors |
| safetext version | `go.mod` | `github.com/google/safetext v0.0.0-20240104143208-7a7d9b3d812f // indirect` |
| no source edits | `git show --stat 68190f5` | 2 files: `go.mod`, `go.sum` |
| LICENSE | untouched | not in diff |

## Concerns

1. **Native `go build ./...` on this Windows host still exits 1**, on
   `service/connections.go` (`undefined: unix.Mount`, `unix.MS_NOATIME/MS_NODEV/MS_NOSUID`,
   `mount.Unmount`). **Verified pre-existing:** I stashed the modified `go.mod`/`go.sum` and
   built the untouched HEAD — it fails with the exact same 5 errors. This is Linux-only code
   (`golang.org/x/sys/unix`, `moby/sys/mount`) with no build tags, so it cannot compile for
   GOOS=windows regardless of dependency versions; fixing it would mean editing source, which is
   forbidden. Build was therefore verified with **`GOOS=linux CGO_ENABLED=0 go build ./...` → exit 0**,
   which is CasaOS's actual target platform. If the controller's success criterion is literally
   "`go build ./...` exits 0 on this machine", that criterion was already unmet before this task
   started and cannot be met without a source change or a Linux build environment.
2. **Breadth of the already-applied `go get -u ./...` update exceeds "safe minor/patch"** in
   places: `getkin/kin-openapi` 0.117→0.151, `deepmap/oapi-codegen` 1.12.4→1.16.3,
   `gorm.io/gorm` 1.25→1.31, `CasaOS-Common` 0.4.11-alpha4→0.4.21, plus the `go 1.21`→`1.26.0`
   directive (now mandatory). Compile-wise everything passes for linux; the controller may want
   to decide whether this breadth fits the plan's scope.
3. **No tests were run** — `go test ./...` is outside this task's contract; only `go mod tidy`
   and `go build` were verified. API-removal risk (as with echo) can also surface at test/runtime.
4. `echo-jwt/v4` is at `v4.2.1` vs upstream's `v4.2.0` (patch difference introduced by the
   echo downgrade); harmless, left alone to avoid churn.
5. Git reports LF→CRLF warnings for `go.mod`/`go.sum` (pre-existing repo/line-ending state,
   unchanged by me).

## Final pinned versions of interest

- `github.com/google/safetext v0.0.0-20240104143208-7a7d9b3d812f` (upstream's)
- `github.com/labstack/echo/v4 v4.12.0` (upstream's)
- `github.com/labstack/echo-jwt/v4 v4.2.1` (indirect, follows echo)
- `go 1.26.0` (required by updated deps; upstream uses `go 1.21`)
