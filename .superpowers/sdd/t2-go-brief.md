# Task brief — T2: Fix + finalize Go dependency updates (PLAN.md step 3)

## Context
`go get -u ./...` was already run; go.mod/go.sum are modified (uncommitted) on branch `chore/deps-license-maintenance`. But `go build ./...` currently FAILS. Root cause identified: the update pulled `github.com/google/safetext v0.0.0-20260929084330-d0e6ffa9feb4` (a future-dated pseudo-version) which declares `go 1.21` in its own go.mod but uses Go 1.22 range-over-int syntax, so the toolchain rejects it. Upstream `main` pins `safetext v0.0.0-20240104143208-7a7d9b3d812f`. `go mod why github.com/google/safetext` shows it is only an indirect dependency.

## Requirements
1. Pin safetext back to upstream's working version: `go get github.com/google/safetext@v0.0.0-20240104143208-7a7d9b3d812f`.
2. Run `go mod tidy`.
3. Verify `go build ./...` passes (exit 0, no compile errors).
4. Sanity: confirm no OTHER newly-updated dep breaks the build. If another dep fails to compile, prefer pinning THAT dep back to the version upstream `main` uses (`git show upstream/main:go.mod`) rather than editing source — the plan scope is "safe minor/patch updates, skip changes needing code edits". If a dep can only be fixed by code changes, pin it back and note it.
5. Do NOT bump the module `go` directive beyond what upstream uses unless a pinned-back version still fails; note if you do.

## Global constraints
- Scope: safe minor/patch dependency updates only. Never edit application source code to satisfy a dependency. Pinning back a broken transitive dep is the expected remedy.
- Preserve LICENSE (Apache-2.0). Do not touch LICENSE.
- Commits use gitmoji convention: `:package:` or `:arrow_up:` for dep bumps. Commit message e.g. `:package: Pin safetext back, finalize Go dep updates`.

## Success criteria
- `go build ./...` exits 0.
- go.mod/go.sum committed on this branch with a gitmoji message.
- Report the final safetext version and whether any other dep had to be pinned back.

## Report
Write the full report to `.superpowers/sdd/t2-go-report.md`. Return only: status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED), commit SHA(s), one-line build-verify result, and any concerns.
