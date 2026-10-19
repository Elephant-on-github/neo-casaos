# Task brief — T4: GitHub Actions workflow version bumps (PLAN.md step 5)

## Context
Repo `.github/workflows/` has 10 workflow files: add_issues_to_projects.yml, casa.yml, codecov.yml, demo.yml, move_alpha_bug_to_project.yml, publish_npm.yaml, push_events_to_discord.yml, push_test_server.yml, release.yml, sync_openapi.yml.

Bump third-party actions to their current stable MAJOR versions — SAFE bumps only.

## Requirements
1. For each `uses:` reference (e.g. `actions/checkout@v3`, `actions/setup-go@v4`, `actions/setup-node@v3`, `actions/upload-artifact@v3`, `docker/...`, `codecov/...`, `github/...`), bump only the MAJOR tag to the latest stable major IF it is a drop-in upgrade (no input/rename/behavior change required). Known-safe current majors: actions/checkout@v4, actions/setup-go@v5, actions/setup-node@v4, actions/upload-artifact@v4, actions/download-artifact@v4, actions/cache@v4, actions/github-script@v7, actions/setup-python@v5, docker/setup-buildx-action@v3, docker/build-push-action@v6, docker/login-action@v3.
2. SKIP anything that would require editing workflow logic, renaming inputs, changing secrets, or restructuring (e.g. upload-artifact/download-artifact v3->v4 has breaking behavior only if used together with cross-workflow artifacts — if a workflow uses v3 artifacts in a way that breaks at v4, SKIP it and note why). Prefer leaving a workflow untouched over a risky bump.
3. Do not change workflow triggers, job logic, secrets, or file names. Only the version tag after `uses: owner/repo@`.
4. Local-pinned actions or SHA-pinned actions: leave as-is (note them).

## Success criteria
- Every bumped action is a pure tag change `@vN -> @vN+1` (or to listed safe major), no other line altered.
- Workflows still parse. Verify: `actionlint` if available (`actionlint --version`); else validate YAML parses (e.g. `python -c "import yaml,sys,glob;[yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*')]` or a pwsh/yq YAML parse). Report the method used.
- Changes committed on branch `chore/deps-license-maintenance` with gitmoji message `:arrow_up: Bump GitHub Actions to current majors`.

## Report
Write the full report (table: file, action, old tag, new tag / skipped+reason, verify method+result) to `.superpowers/sdd/t4-workflows-report.md`. Return only: status, commit SHA(s), one-line verify result, concerns.
