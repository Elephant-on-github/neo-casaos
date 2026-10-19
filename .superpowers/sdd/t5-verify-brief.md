# Task brief — T5: Verification (PLAN.md step 6)

## Context
Go deps were updated on branch `chore/deps-license-maintenance` (commit 68190f5) including large behavioral bumps: CasaOS-Common 0.4.11-alpha4→0.4.21, kin-openapi 0.117→0.151, gorm 1.25→1.31, oapi-codegen 1.12→1.16. `GOOS=linux go build ./...` already passes (T2). This task is the correctness NET: run tests + a vuln scan and determine whether the bumps introduced regressions. READ-ONLY: change NO source, commit NOTHING.

## Platform caveat (important)
CasaOS is a Linux server app. Native win32 `go build ./...` fails on Linux-only code (`service/connections.go` uses `unix.Mount`, no build tags) — this is PRE-EXISTING, not caused by the dep updates. You cannot natively run Linux test binaries on Windows. Account for this.

## Requirements
1. Compile-check the real target: `GOOS=linux CGO_ENABLED=0 go vet ./...` — report pass/fail (vet compiles without linking; catches compile errors incl. any from dep API changes).
2. Run tests: attempt `go test ./...` on host. Any failure must be classified as PRE-EXISTING (platform: Linux-only code that can't build/run on win32) vs REGRESSION (caused by the dep bumps). Method to classify: for a failing package, check if it fails identically at upstream baseline. Cheap baseline: `git stash` is not needed (changes committed); instead reason from the error (a `unix.Mount`/build-constraint failure = pre-existing platform; an API/type error referencing a bumped dep = regression). If ambiguous, note it.
3. Targeted test run for compile-safe packages: run `go test ./...` and report the pass/skip/fail counts, distinguishing platform-compile failures from real test failures.
4. Vuln scan: `go run golang.org/x/vuln/cmd/govulncheck@latest ./...` (install-on-demand). If it needs a Linux target, set `GOOS=linux`. Report any findings (vuln id, module, severity) and whether they are introduced by our bumps vs pre-existing.

## Success criteria
- A clear verdict: did the dep updates introduce any REGRESSION (compile error or failing test attributable to a bumped dep) or any NEW vulnerability?
- If a regression is traced to a specific bumped dep, NAME that dep — the controller will pin it back (per T2's deferred-correctness ruling). Do NOT pin it yourself; report only.
- Everything READ-ONLY; nothing committed.

## Report
Write the full report to `.superpowers/sdd/t5-verify-report.md`. Return only: status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED), a one-line verdict (clean / regressions-found), any deps to pin back, and concerns.
