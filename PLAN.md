# neo-casaos kickoff plan

Fork: https://github.com/Elephant-on-github/neo-casaos (of IceWhaleTech/CasaOS, Apache-2.0, Go + Vue submodule)

Scope agreed with user: all safe minor/patch dependency updates (skip major migrations needing code changes) + license compliance.

1. Fork + clone → done: origin=neo-casaos, upstream=CasaOS, cloned to `.ai/temp/neo-casaos`
2. License compliance
   - verify LICENSE/NOTICE preserved in fork → verify: LICENSE present, Apache-2.0
   - scan Go deps for non-permissive licenses (GPL/AGPL/SSPL/Commercial) → report
   - scan npm deps licenses → report
3. Go dependency updates (minor/patch only): `go get -u ./... && go mod tidy` → verify: `go build ./...`
4. npm dependency updates within semver ranges: `npm update` (check lockfiles first) → verify: `npx tsc` build if applicable
5. GitHub Actions workflow version bumps (safe ones only) → verify: workflows parse (actionlint if available)
6. Verification: `go test ./...`, `govulncheck` scan
7. Push changes on gitmoji-convention branches, open PRs on our fork
8. Triage upstream CasaOS issues + PRs → pick addressable items for follow-up PRs
