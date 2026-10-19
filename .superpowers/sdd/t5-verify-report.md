# T5 Verification report — Go dep updates on `chore/deps-license-maintenance`

Date: 2026-10-19
Subject: commit `68190f5` (Go dep bumps) vs baseline `0d3b2f4` (upstream README HEAD)
Mode: READ-ONLY — no source changed, nothing committed. Working tree at end identical to start
(`git status`: only pre-existing untracked `.superpowers/` and `PLAN.md`).

Toolchain: `go1.26.3 windows/amd64`, host = win32. Baseline comparison done in an **ephemeral clone**
at `%TEMP%\opencode\t5-baseline` (checked out at `0d3b2f4`, `codegen/` copied in since it is
gitignored generated output) — the real repo was never modified.

---

## 1. Verdict

**No behavioral regressions from the dependency bumps.** Every test that can execute passes, and
`GOOS=linux` compilation (build + vet, incl. test files) is clean of API/compile errors — including
for the large bumps (CasaOS-Common 0.4.21, kin-openapi 0.151, gorm 1.31.2, oapi-codegen 1.16.3).

Two items were **introduced by commit 68190f5** (neither is a code-behavior break):

1. **NEW vulnerability GO-2026-5676** in `github.com/quic-go/quic-go@v0.59.0` (fixed `v0.59.1`) —
   introduced transitively by the **oapi-codegen 1.12.4 → 1.16.3** bump. Traced, not pinned.
2. **4 `go vet` printf failures** (`non-constant format string`) on `drivers/dropbox` and
   `drivers/google_drive` that make `go vet ./...` and `go test ./...` exit non-zero — caused by the
   **`go` directive bump 1.21 → 1.26.0** in go.mod (which per the commit message is forced by the
   updated deps' own `go 1.26.0` declarations), **not** by any library API. Proven by experiment
   (§3.3).

**Deps to pin back: NONE.** (Details in §6 — forward fixes recommended instead.)

---

## 2. Requirement 1 — `GOOS=linux CGO_ENABLED=0 go vet ./...` (HEAD)

Result: **exit 1, 6 diagnostics, ZERO compile errors.**

```
drivers\dropbox\util.go:34:21:    non-constant format string in call to fmt.Errorf
drivers\dropbox\util.go:55:21:    non-constant format string in call to fmt.Errorf
drivers\google_drive\util.go:43:21: non-constant format string in call to fmt.Errorf
drivers\google_drive\util.go:65:21: non-constant format string in call to fmt.Errorf
service\notify.go:244:9:  GetList passes lock by value: ... notifyServer contains
                          golang.org/x/sync/syncmap.Map contains sync.noCopy
service\notify.go:346:9:  return copies lock value: ... syncmap.Map contains sync.noCopy
```

Important: **no dep-API compile errors** — vet compiled every package (incl. test files) for the
real Linux target. Both diagnostics classes are analyzed against baseline in §3.

## 3. Requirement 2/3 — test runs and classification

### 3.1 Native win32 `go test ./...` (tests actually execute)

| Result | Count | Packages |
|---|---|---|
| **ok** | 4 | `pkg/sqlite` 1.88s, `pkg/utils` 1.32s, `pkg/utils/file` 1.38s, `pkg/utils/ip_helper` 6.67s |
| FAIL — pre-existing platform (unix.Mount etc.) | 6 | root `CasaOS`, `cmd/migration-tool`, `route`, `route/v1`, `route/v2`, `service` |
| FAIL — vet printf (go-directive-caused) | 2 | `drivers/dropbox`, `drivers/google_drive` (**both have NO test files**) |
| no test files | ~41 | rest |
| skipped | 0 | — |
| **test assertion failures** | **0** | — |

- The 6 platform failures are `service\connections.go: undefined: unix.Mount / mount.Unmount …` —
  exactly the pre-existing Linux-only code the brief calls out. Classification proof: `git diff
  0d3b2f4..HEAD --stat` shows **only** `go.mod`, `go.sum` and `.github/workflows/*` changed — no Go
  source changed, so these compile failures are byte-identical at baseline.
- Re-run with `go test -vet=off ./...`: drivers packages show `[no test files]`, everything else
  identical → **the printf issue loses zero test coverage**.

### 3.2 `GOOS=linux CGO_ENABLED=0 go test ./...` (real target, cannot exec on win32)

- All 6 test-bearing packages **compiled** test binaries: `pkg/sqlite`, `pkg/utils`,
  `pkg/utils/file`, `pkg/utils/ip_helper`, `route/v1`, `service`.
- 6 × `fork/exec …: %1 is not a valid Win32 application` = ELF binaries built but not executable on
  Windows → **platform limitation, not test failures** (0 `--- FAIL` marks in output).
- `drivers/dropbox` + `drivers/google_drive` `[build failed]` = the printf vet diagnostics from §2
  (test-time vet subset); again, no test files in those packages.
- ⇒ Compile-level correctness verified for the real target including test code; **runtime tests for
  `route/v1` and `service` could not be executed on this host** (no Linux runner; WSL present but
  has no distributions installed). This is the main verification gap — see §7.

### 3.3 Baseline classification (ephemeral clone at `0d3b2f4`, same toolchain, `GOOS=linux`)

| Diagnostic | HEAD (68190f5) | Baseline (0d3b2f4) | Classification |
|---|---|---|---|
| 2 × copylocks `service/notify.go` | present | **present, identical** | **PRE-EXISTING** (source + `syncmap.Map = sync.Map` alias also in x/sync v0.3.0's `go19.go`; go1.26 `sync.Map` contains `_ noCopy`). NOT caused by x/sync 0.3.0→0.24.0. |
| 4 × printf non-constant format | present | **absent** | **INTRODUCED by the commit — via the `go` directive, not a library.** |

**Causality experiment** (temp clone only, then `git checkout -- go.mod` restored): editing *only*
baseline `go.mod` line `go 1.21` → `go 1.26.0` (source and deps untouched) makes all 4 printf
diagnostics appear under `go vet ./drivers/dropbox ./drivers/google_drive`; restoring `go 1.21`
removes them. So vet's non-constant-format check is gated on the module language version, and the
directive was raised by the dep set (`x/sys v0.49.0`, `modernc.org/sqlite v1.60.1`,
`mvdan.cc/sh/v3 v3.14.1` declare `go 1.26.0`; per commit message `go mod tidy` rejects reverting to
1.21). **No single dep pin fixes this**; the fix is a 4-line source change (`fmt.Errorf("%s", msg)`
or constant formats) — out of scope for this read-only task.

### 3.4 Behavioral coverage of the big bumps (what actually got exercised)

- **gorm 1.25 → 1.31.2 + glebarez/sqlite**: `pkg/sqlite/db_test.go` → **PASSED** (opens a real
  gorm DB, exercises migrations/queries).
- **CasaOS-Common / echo / oapi-codegen runtime**: exercised mainly via `service` + `route/v1`
  tests → **compiled (linux) but NOT executed on this host** (§3.2).
- **kin-openapi 0.117 → 0.151**: imported only through `codegen` (openapi3); `codegen` has no test
  files; its runtime consumers (`route/*` validation) are in the un-executed set → compile-verified
  only.

## 4. Requirement 4 — govulncheck (`golang.org/x/vuln/cmd/govulncheck@latest`, `GOOS=linux`)

Method note: `go run govulncheck@latest` with `GOOS=linux` fails on Windows (`go run` builds a linux
exe it cannot spawn), and without `GOOS=linux` package loading fails on `unix.Mount`. Working
recipe: `go install …@latest` (host exe) then run the installed exe with `GOOS=linux` in env.

### Current (68190f5): **25 vulnerabilities affecting code** (5 modules + Go stdlib)
plus 11 in imported-but-not-called packages, 1 in required-but-uncalled modules (exit 3).

- **19 stdlib** (go1.26.3 toolchain): GO-2026-6617/6613/6612/6611/6610/6609/6608/6607/6605/6603,
  -6218, -6090, -6089, -6088, -5972, -5856, -5039, -5037, -5026 — fixed in go1.26.4…1.26.9.
  **Pre-existing**: baseline ran the identical toolchain (module `go 1.21` also uses local 1.26.3),
  and baseline scan shows the same stdlib entries. Remedy = upgrade toolchain, not a dep pin.
- **Module vulns (6)**:
  | ID | Module | Status |
  |---|---|---|
  | GO-2026-5676 (CVE-2026-40898) | quic-go v0.59.0, fixed **v0.59.1** | **NEW — introduced by this commit** (§5) |
  | GO-2026-5932 | x/crypto v0.58.0, Fixed N/A | pre-existing (baseline v0.23.0 affected too, Fixed N/A ⇒ all versions) |
  | GO-2025-4020 | rardecode v1.1.3, Fixed N/A | pre-existing (version unchanged) |
  | GO-2025-3605, GO-2024-2698 | mholt/archiver/v3 v3.5.1, Fixed N/A | pre-existing (version unchanged) |
  | GO-2025-3553 | golang-jwt/jwt v3.2.2, Fixed N/A | pre-existing (version unchanged) |

### Baseline (0d3b2f4): **47 vulnerabilities** (11 modules + stdlib), 18 imported / 24 uncalled.

ID-set diff (current vs baseline): exactly **one** ID added — `GO-2026-5676`; **22 IDs removed**
(x/net ×7, x/crypto ×8, x/image ×8, gorilla/websocket GO-2026-6278, kin-openapi GO-2026-6112 &
GO-2025-3533, x/text GO-2026-5970, ulikunitz/xz GO-2025-3922, golang-jwt/v4 GO-2024-3250, jwt/v5
via GO-2025-3553). **Net security posture improved 47 → 25.**

## 5. The one introduced vulnerability — traceability

- `GO-2026-5676` — HTTP/3 QPACK trailer memory exhaustion, `github.com/quic-go/quic-go`
  `< v0.59.1`, reachable traces reported (e.g. `main.go:225 http.Server.Serve →
  http3.ConfigureTLSConfig`, `pkg/utils/file/file.go:726 → http3.countingByteReader.Read`).
- Baseline module graph contains **neither gin nor quic-go** (`git show 0d3b2f4:go.mod` has no such
  lines; baseline scan reports no quic-go/gin vulns).
- Chain (`go mod why` / `go mod graph`): `codegen → deepmap/oapi-codegen/pkg/runtime →
  github.com/gin-gonic/gin@v1.12.0 → github.com/quic-go/quic-go/http3`.
  Parents: `oapi-codegen@v1.16.3 requires gin@v1.9.1`; MVS selects gin **v1.12.0** (new indirect
  require in go.mod), which requires quic-go **v0.59.0** (new indirect require in go.mod).
- ⇒ **Attributed to the oapi-codegen 1.12.4 → 1.16.3 bump** (the gin/quic-go subgraph did not exist
  before it). Named per brief; **not pinned here**.

## 6. Deps to pin back

**None.** Rationale:
- No compile/API regression anywhere → nothing needs reverting for correctness.
- The new quic-go vuln is fixed *forward* by `quic-go ≥ v0.59.1`; reverting oapi-codegen to 1.12.4
  would cost the 22 fixed vulns and is not warranted. Controller's call (see §7).
- The printf vet failures cannot be fixed by pinning any single dep — they follow from the module
  `go` directive that `go mod tidy` pins to ≥1.26.0 as long as the updated deps remain.

## 7. Concerns / limitations (for the controller)

1. **quic-go GO-2026-5676 (introduced).** Recommended forward fix (controller's decision, not done
   here): bump `github.com/quic-go/quic-go` to ≥ v0.59.1, or re-tidy after a newer
   oapi-codegen/gin release. Oapi-codegen is the dep that brought it in.
2. **`go vet ./...` / `go test ./...` now exit 1** on HEAD (4 printf diagnostics), also on the real
   Linux target. No test coverage is lost (packages have no test files), but any CI gate running
   vet/test will go red. Needs a 4-line source fix (`fmt.Errorf` → constant format) — source edits
   are out of scope for T5.
3. **Unexecuted tests on this host:** `route/v1` (`samba_test.go`) and `service`
   (`file_test.go`, `health_test.go`, `other_test.go`) compile for `GOOS=linux` but could not be
   run (win32 host, WSL has no distro). These are the tests most likely to cover CasaOS-Common,
   echo middleware and kin-openapi behavior → recommend one Linux CI/local run before merge.
4. **19 stdlib vulns at go1.26.3** — pre-existing/toolchain; upgrade Go to ≥ 1.26.9 (fixes 15 of
   them; 1.26.6 covers more) in dev + CI.
5. **Stale CI Go pin:** `.github/workflows/codecov.yml` pins `go-version: "1.20"`, which cannot load
   a module requiring `go 1.26.0`. Pre-existing in kind (baseline required 1.21 > 1.20 already),
   but the gap is now wider; unrelated to the dep bumps themselves.
6. Pre-existing, unchanged by this work: win32 build fails on `service/connections.go`
   (`unix.Mount`, no build tags); `go vet` copylocks warnings at `service/notify.go:244,346` fail
   `go vet` at baseline too.

## 8. Reproduction

```
GOOS=linux CGO_ENABLED=0 go vet ./...                 # 6 diags (4 printf new, 2 copylocks pre-existing)
go test ./...                                          # 4 ok, 8 build-fail (6 unix-platform, 2 vet-printf), 0 assert fails
go test -vet=off ./...                                 # same; drivers = no test files
GOOS=linux CGO_ENABLED=0 go test ./...                 # builds all 6 test pkgs; fork/exec on win32 (platform)
go install golang.org/x/vuln/cmd/govulncheck@latest
$env:GOOS='linux'; $env:CGO_ENABLED='0'; & "$(go env GOPATH)\bin\govulncheck.exe" ./...   # 25 vulns, exit 3
# baseline: ephemeral clone @ 0d3b2f4 (+ gitignored codegen/ copied in) → vet: 2 diags; govulncheck: 47 vulns
```
