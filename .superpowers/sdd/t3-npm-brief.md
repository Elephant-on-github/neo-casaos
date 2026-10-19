# Task brief — T3: npm dependency updates (PLAN.md step 4)

## Context
The only npm package is the root `@icewhale/casaos-openapi` SDK (a generated OpenAPI TypeScript client). No lockfile is currently present (checked). Scope: update deps WITHIN their existing semver ranges — not major jumps.

Deps (verbatim from package.json):
- dependencies: `axios: ^1.1.0`
- devDependencies: `all-contributors-cli: ^6.24.0`, `@openapitools/openapi-generator-cli: 2.5.2` (EXACT pin, no caret → leave at 2.5.2), `@types/node: ^18.8.3`, `openapi-typescript-codegen: ^0.23.0`, `typescript: ^4.9.5`

## Requirements
1. Check tooling: report whether `node` and `npm` are available (`node --version`, `npm --version`). If npm is NOT available, STOP and report BLOCKED with that fact — do not fake it.
2. Check lockfiles: none present (confirmed). 
3. Run `npm update` at the repo root. This resolves deps to the newest versions WITHIN the existing ranges and generates `package-lock.json`. It should NOT change the version ranges in package.json (those stay as-is); the exact-pinned `@openapitools/openapi-generator-cli@2.5.2` stays pinned.
4. Verify: attempt `npx tsc --noEmit` (or `npm run build` if tsc alone is insufficient). IMPORTANT: this package compiles a GENERATED `generate/` directory (from openapi.yaml) that may be absent in the repo. If tsc fails because the generated input is missing (not because of a dependency version), classify that as a PRE-EXISTING condition, NOT a regression from the update — note it and do not try to generate the SDK (out of scope). Distinguish clearly: did any failure come from a dependency version change, or from missing generated input / tooling?
5. Do NOT bump majors. Do NOT change the version ranges in package.json by hand.

## Success criteria
- Either: deps updated within range + tsc verification result clearly classified (pass / pre-existing-input-failure / dependency-regression), OR npm-absent → BLOCKED.
- If a NEW package-lock.json is produced and no dependency regression occurred, commit it on branch `chore/deps-license-maintenance` with gitmoji `:package: Update npm deps within semver ranges`. If package.json changed at all, include it and explain.
- Nothing else touched.

## Report
Write the full report to `.superpowers/sdd/t3-npm-report.md`. Return only: status, commit SHA(s) or "none", one-line tsc/verify classification, and concerns.
