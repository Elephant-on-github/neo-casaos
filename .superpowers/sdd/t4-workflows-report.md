# T4 report — GitHub Actions workflow version bumps

- **Status:** DONE
- **Branch:** `chore/deps-license-maintenance`
- **Commit:** `fee0b50` — `:arrow_up: Bump GitHub Actions to current majors`
- **Scope:** `.github/workflows/` (10 files), 9 pure tag changes in 5 files; 5 files untouched.

## Bumped

| File | Action | Old tag | New tag |
|---|---|---|---|
| casa.yml | actions/checkout | v3 | v4 |
| casa.yml | actions/setup-node | v3 | v4 |
| codecov.yml | actions/checkout | v3 | v4 |
| codecov.yml | actions/setup-go | v4 | v5 |
| demo.yml | actions/checkout | v3 | v4 |
| publish_npm.yaml | actions/checkout | v3 | v4 |
| publish_npm.yaml | actions/setup-node | v3 | v4 |
| push_test_server.yml | actions/checkout | v3 | v4 |
| push_test_server.yml | actions/setup-go | v4 | v5 |

All 9 are on the brief's known-safe list (checkout@v4, setup-node@v4, setup-go@v5) and are runtime-only major bumps (node16→node20) with no input/behavior change.

## Skipped

| File | Action | Tag | Reason |
|---|---|---|---|
| casa.yml | crazy-max/ghaction-xgo | v1 | Not on safe list; cannot verify drop-in → prefer skip |
| casa.yml | meeDamian/github-release | 2.0 | Not on safe list; non-vN tag → prefer skip |
| casa.yml (×3, lines 39/138/145) | commented-out `uses:` | — | Comments, untouched |
| codecov.yml | codecov/codecov-action | v3 | v4/v5 changed upload/token behavior (token requirements, CLI rewrite) → risky |
| demo.yml | aws-actions/configure-aws-credentials | v1 | v2+ input/output changes (region handling) → not drop-in |
| add_issues_to_projects.yml (×2) | actions/add-to-project | v0.3.0 | Not on safe list → prefer skip |
| move_alpha_bug_to_project.yml | actions/add-to-project | v0.1.0 | Not on safe list → prefer skip |
| push_events_to_discord.yml (×3) | joseph-montanez/forward-event-action | v3.0.0 | Not on safe list → prefer skip |
| push_test_server.yml | goreleaser/goreleaser-action | v4 | Not on safe list (v5/v6 changes unverified) → prefer skip |
| push_test_server.yml | zerotier/github-action | v1.0.1 | Not on safe list → prefer skip |

## Left as-is (rule 4 — pinning/refs)

| File | Reference | Note |
|---|---|---|
| add_issues_to_projects.yml | tibdex/github-app-token@36464acb844fc53b9b8b2401da68844f6b05ebb0 | SHA-pinned, untouched |
| move_alpha_bug_to_project.yml | tibdex/github-app-token@36464acb844fc53b9b8b2401da68844f6b05ebb0 | SHA-pinned, untouched |
| release.yml | IceWhaleTech/github/.github/workflows/go_release.yml@main | Reusable workflow pinned to `main` branch, not a version tag; changing ref risky → untouched |
| sync_openapi.yml | IceWhaleTech/github/.github/workflows/sync_openapi.yml@main | Same as above → untouched |

Not present in this repo at all: upload-artifact, download-artifact, cache, github-script, setup-python, docker/* — nothing to bump there.

## Verification

1. **Diff purity:** `git diff -U0` shows exactly 9 changed lines, every one a `uses:` line differing only in the version tag (no triggers/logic/secrets/filenames altered). `git diff --stat`: 5 files changed, 9 insertions(+), 9 deletions(-).
2. **Workflow parse:** `actionlint` is **not installed** (`actionlint: term not recognized`). Fell back to **YAML-parse validation** with `npx --yes js-yaml` (PyYAML and yq also absent): **all 10 workflow files parse OK** — result: `RESULT: all 10 workflows parse`.
3. **Commit:** made on `chore/deps-license-maintenance` as `fee0b50`; only `.github/workflows` staged (repo's untracked `.superpowers/` and `PLAN.md` left untracked).

## Concerns

- Verification used js-yaml parse, not actionlint — semantic GitHub Actions schema issues (as opposed to YAML errors) were not machine-checked; low risk since only version tags changed.
- Skipped actions (esp. `codecov-action@v3`, `goreleaser-action@v4`, `aws-actions/configure-aws-credentials@v1`, `add-to-project@v0.x`) still carry old majors and may hit runner deprecations (node16); out of scope per "prefer skipping over risky".
