# T3 report — npm dependency updates (within semver ranges)

Branch: `chore/deps-license-maintenance` (base cfabccca)
Status: **DONE**

## Tooling
- `node --version` → **v22.22.3**
- `npm --version` → **11.5.2**
- npm available → proceeded.

## Lockfile state before
- No `package-lock.json` present (confirmed). Only npm package in repo is root `@icewhale/casaos-openapi`.

## Action taken
- Ran `npm update` at the repo root (177 packages installed, 178 audited).
- `package.json` was **NOT modified** (`git diff -- package.json` empty) — version ranges untouched, exact pin preserved.

## Resolved versions (top-level, post-update)
| Package | Range | Before | After |
|---|---|---|---|
| axios | ^1.1.0 | — | **1.20.0** |
| all-contributors-cli | ^6.24.0 | — | **6.26.1** |
| @openapitools/openapi-generator-cli | 2.5.2 (exact) | 2.5.2 | **2.5.2** (unchanged, as required) |
| @types/node | ^18.8.3 | — | **18.19.130** |
| openapi-typescript-codegen | ^0.23.0 | — | **0.23.0** (no newer in-range) |
| typescript | ^4.9.5 | — | **4.9.5** (no newer in-range v4) |

`npm ls --depth=0` clean — no invalid/unmet peer deps reported.

## Verification (`npx tsc --noEmit`)
- Output: `error TS18003: No inputs were found in config file ... Specified 'include' paths were '["**/*"]' ... 'exclude' paths were '["node_modules"]'` — exit code 2.
- Classification: **PRE-EXISTING (missing generated input), NOT a dependency regression.**
  - Confirmed zero `.ts` files exist anywhere in the repo outside `node_modules`; the only TS input the tsconfig would ever see is the generated `generate/` dir (`main: generate/index`), which is absent from the repo by design (generated from `api/casaos/openapi.yaml`; generating it is out of scope per brief).
  - Toolchain sanity check: compiled a trivial strict `.ts` file with the freshly installed `node_modules/.bin/tsc` (typescript 4.9.5) → **exit 0**. So the compiler and deps are functional; the failure is purely absence of generated source, not a version problem.
- Note: `npm audit` reports 11 vulnerabilities (3 low / 2 moderate / 6 high) — these live in the pinned/legacy generator toolchain (`openapi-typescript-codegen@0.23.0`, `openapi-generator-cli@2.5.2` transitive deps: glob@7, uuid@8, json-schema-ref-parser@9, inflight). Fixing them would require major bumps or changing the exact pin → out of scope for this task.

## Commit
- `60f436f` — `:package: Update npm deps within semver ranges`
- Contains only the new `package-lock.json` (2222 insertions). Nothing else touched.

## Concerns
1. `node_modules/` is currently untracked and **not gitignored** by the repo's `.gitignore` (which is Go-oriented). It was NOT committed here, but a follow-up may want to add `node_modules/` to `.gitignore` to prevent accidental commits.
2. The 11 `npm audit` findings are inherent to the in-range/pinned legacy SDK-generation toolchain; they cannot be cleared without major bumps or breaking the exact pin on `@openapitools/openapi-generator-cli@2.5.2`.
3. Since there was no prior lockfile, "before" versions are not recorded anywhere; the new lockfile establishes the baseline going forward.
