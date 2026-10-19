# T1 — License compliance scan report (PLAN.md step 2)

- **Repo**: `neo-casaos` fork of IceWhaleTech/CasaOS · scan date 2026-10-19 · host Windows, `go1.26.3`
- **Nature**: read-only. No source files touched, nothing committed. Working tree at end of scan = working tree at start (`?? .superpowers/`, `?? PLAN.md`, both pre-existing). Scratch artifacts written only to `%TEMP%\opencode\`.
- **Scope**: fork's *current* dependency set (`go.mod` has already diverged from upstream: 166 vs 117 direct requires, 57 modules added / 10 removed by the in-progress dependency maintenance).

---

## 1. Repo LICENSE — Apache-2.0, preserved

| Check | Result |
| --- | --- |
| `LICENSE` at repo root | present |
| Text | "Apache License, Version 2.0, January 2004" → **SPDX id: `Apache-2.0`** |
| Preserved from upstream? | **Yes — byte-identical**: `git diff --quiet upstream/main -- LICENSE` → exit 0 |
| Other license files tracked | none (`git ls-files` matches only `LICENSE`) |
| `package.json` `license` field | `Apache-2.0`, and `package.json` itself is unchanged vs `upstream/main` |

Files changed vs `upstream/main` in the fork: `.github/workflows/{casa,codecov,demo,publish_npm,push_test_server}.yml`, `go.mod`, `go.sum` only. **No licensing files were altered by the fork.**

## 2. NOTICE — absent upstream and in the fork → human decision (not a defect)

- **Fork**: no `NOTICE` anywhere (`git ls-files` case-insensitive search for `notice` → zero hits; recursive file search → zero hits).
- **Upstream**: `git ls-tree upstream/main --name-only` lists `LICENSE` but **no `NOTICE`** — upstream never shipped one.
- **Conclusion**: nothing was lost in the fork; this is not a regression.

**⚠ Flag for the human (decision, deliberately not "fixed" here):**

1. **Fork-level NOTICE**: Apache-2.0 *recommends* preserving NOTICE when one exists (§4(d) obligates you only if the Work *includes* a NOTICE file). Adding a NOTICE to the fork is a project-policy choice — e.g. useful for CasaOS trademark/attribution text and for consolidating dependency attributions.
2. **Dependency NOTICEs DO exist** — 11 of the fork's Go dependencies ship a `NOTICE` file, and Apache-2.0 §4(d) requires reproducing those attribution notices when you distribute a binary that includes them:
   `github.com/coreos/go-systemd` (v0 + v22), `github.com/go-openapi/jsonpointer`, `github.com/go-openapi/testify/v2` (+`internal/difflib`), `github.com/kataras/iris/v12`, `github.com/kataras/neffos`, `github.com/oasdiff/yaml3`, `go.yaml.in/yaml/v3`, `gopkg.in/yaml.v2`, `gopkg.in/yaml.v3`.
   (kataras/iris's NOTICE is a FOSSA-generated third-party list; yaml's are Canonical copyright + Apache grant notices.)

## 3. Go dependency licenses

**Method** (go-licenses was *not* installed as a binary; brief allows the fallback, but I did better than recall alone):

1. `go list -m -f '{{.Path}} {{.Version}}' all` → **295 modules** (+ main module).
2. Direct inspection of every license-ish file in the module cache (`GOFLAGS`/`GOMODCACHE`), 370 files at depth ≤3 across the 295 modules, classified by full text.
3. Cross-check with `go run github.com/google/go-licenses@latest report ./...` → 149 packages in the build graph, exit 0, only 2 `Unknown`.
4. Targeted regex sweep of all 370 license files for GPL / AGPL / LGPL / SSPL / BUSL / EPL / CDDL / EUPL / MPL / "non-commercial".
5. `go mod why -m <module>` + `go list -deps ./...` on **windows/amd64 and darwin/arm64** to separate *linked* deps from *test-only* deps.
6. npm registry queried per package (`npm view <pkg>@<version> license`).

**Distribution over all 295 modules** (all permissive except the 3 MPL rows below):

| License | Count |
| --- | --- |
| MIT | 141 |
| BSD-3-Clause | 73 (72 + `iris-contrib/schema`, text in README) |
| Apache-2.0 | 57 (54 + 3 `xeipuuv/*` with `LICENSE-APACHE-2.0.txt`) |
| BSD-2-Clause | 19 |
| ISC | 1 |
| Public-domain dedication | 2 (`github.com/xi2/xz`, + 1 CC0/unlicense text) |
| **MPL-2.0 (weak copyleft)** | **3** |
| GPL / AGPL / SSPL / Commercial / unknown | **0 / 0 / 0 / 0 / 0 after manual resolution** |

### 3a. Non-permissive findings (the only copyleft in the tree)

| Module | License | Permissive? | Reachability / notes |
| --- | --- | --- | --- |
| `github.com/shoenig/go-m1cpu` v0.1.6 | **MPL-2.0** | ❌ weak, file-level copyleft | **Linked into `darwin/arm64` builds** via `service → shirou/gopsutil/v3/cpu`. Required as `// indirect` in fork `go.mod`. **Not in upstream `go.mod` — introduced by the fork's dependency bumps.** |
| `github.com/shoenig/test` v0.6.4 | **MPL-2.0** | ❌ weak, file-level copyleft | Test-only dependency of `go-m1cpu`; not linked into any binary. |
| `github.com/hashicorp/golang-lru/v2` v2.0.7 | **MPL-2.0** | ❌ weak, file-level copyleft | Only reachable through `modernc.org/libc`'s *tests* (`go mod why`); absent from `go list -deps ./...` on windows/amd64 **and** darwin/arm64; `modernc.org/sqlite`'s own `LICENSE-3RD-PARTY.md` files it under "§2 components used only by the test suite". |

**Assessment of the MPL-2.0 rows**: MPL-2.0 is *file-level* copyleft, not the viral GPL/AGPL/SSPL kind the brief asked about. Obligation if you distribute: keep the covered *files* source-available (they are, upstream on GitHub) and retain the license/copyright notices. It does **not** force the CasaOS code itself to become MPL. Still, it is the one non-permissive license in the graph and is new in this fork → worth a human's explicit acknowledgement in the maintenance plan (and a reminder that macOS-arm64 builds are the affected artifact).

**False-positive trap documented** (so the next scanner doesn't re-panic): MPL-2.0 §1.12 defines "Secondary License" and therefore *literally contains* the strings "GNU General Public License", "GNU Lesser General Public License" and "GNU Affero General Public License". Four files matched those strings: the three MPL LICENSE files above, and `modernc.org/sqlite/LICENSE-3RD-PARTY.md` (which embeds the MPL text as its appendix L13). Each was read manually — **no actual GPL/AGPL/LGPL code, no SSPL, no BUSL/Commercial, no "non-commercial" restriction anywhere.**

### 3b. "Unknown" / needs-manual-check → all resolved permissive

| Module | Scanner verdict | Manual resolution |
| --- | --- | --- |
| `github.com/iris-contrib/schema` v0.0.6 | **no `LICENSE` file** in the module (go-licenses: `Unknown`; GitHub `/license` API: 404) | **BSD-3-Clause** — full license text is in `README.md` (fork of `gorilla/schema`). In the production build graph (`codegen → deepmap/oapi-codegen → kataras/iris → iris-contrib/schema`). Low risk, but any license *tooling* will report "no license" for it → consider a manual note or an `exclude`/attribution entry. |
| `github.com/xi2/xz` | go-licenses: `Unknown` | `LICENSE` = explicit public-domain dedication ("do whatever you want with these files") → permissive. |
| `modernc.org/mathutil` v1.7.1 | go-licenses: `Unknown` | `LICENSE` = BSD-3-Clause → permissive. |

### 3c. Cross-check with go-licenses

`go run github.com/google/go-licenses@latest report ./...` → 149 package rows: MIT 79, BSD-3 37, Apache-2.0 22, BSD-2 9, **Unknown 2** (both resolved above). Zero GPL/AGPL/MPL rows in its output because MPL modules sit outside its package graph (test-only or non-selected-platform) — which is exactly why the module-level scan in §3/§3a was also run. Its only errors were the 2 `E1019 Failed to find license` lines plus benign "non-Go code can't be inspected" warnings for `.s` assembly files.

**Structural checks**: no `vendor/` directory, no `replace` / `exclude` / `retract` directives in `go.mod`, so every conclusion above is about the modules actually used.

## 4. npm dependencies (root `package.json`)

`node_modules` is not installed → licenses taken from the npm registry for the declared ranges (`npm view <pkg>@<version> license`):

| Package | Declared | Registry license | Permissive? |
| --- | --- | --- | --- |
| `axios` | ^1.1.0 (dependency) | MIT | ✅ |
| `all-contributors-cli` | ^6.24.0 | MIT | ✅ |
| `@openapitools/openapi-generator-cli` | 2.5.2 (exact) | **Apache-2.0** | ✅ |
| `@types/node` | ^18.8.3 | MIT | ✅ |
| `openapi-typescript-codegen` | ^0.23.0 | MIT | ✅ |
| `typescript` | ^4.9.5 | Apache-2.0 | ✅ |

- **No non-permissive, no missing/`"license": "none"` entries.**
- **Correction to the brief**: it listed `@openapitools/openapi-generator-cli` as MIT; the registry (both `2.5.2` and `latest`) says **Apache-2.0**. Still permissive, still a devDependency used only for codegen, so no compliance impact — but the brief's assumption table should be fixed.
- The published npm package ships only `LICENSE`, `README.md`, `dist`, `generate` (`files` field), so no devDependency license propagates to consumers.

## 5. Summary & open decisions for the human

| # | Item | Type |
| --- | --- | --- |
| 1 | `LICENSE` = `Apache-2.0`, byte-identical to upstream, fork preserved it | ✅ clean |
| 2 | No `NOTICE` in fork **or** upstream → nothing lost; decide whether the fork should *add* one (Apache-2.0 recommends it) | ⚠ human decision |
| 3 | 11 dependencies ship `NOTICE` files → their attributions should accompany binary distributions (Apache-2.0 §4(d)) | ⚠ human decision |
| 4 | 3 × **MPL-2.0** modules (`shoenig/go-m1cpu` linked on darwin/arm64; `shoenig/test`, `hashicorp/golang-lru/v2` test-only) — weak file-level copyleft, newly introduced by the fork's dep bumps | ⚠ human acknowledgement |
| 5 | `iris-contrib/schema` has no `LICENSE` file (BSD-3 text in README) → tooling shows "unknown"; resolved manually, permissive | ℹ️ note for tooling |
| 6 | `@openapitools/openapi-generator-cli` is Apache-2.0, not MIT as the brief assumed (still permissive) | ℹ️ brief correction |
| 7 | **No GPL, AGPL, SSPL, BUSL/Commercial or restricted-license dependency found** | ✅ clean |

**Limitations of this scan**

- License *texts* were read at module level (depth ≤3, filenames matching `LICENSE*/LICENCE*/COPYING*/COPYRIGHT*/NOTICE*`); individual third-party files buried deeper inside a dependency are covered only where the dependency self-inventories (e.g. `modernc.org/sqlite/LICENSE-3RD-PARTY.md`, which lists every linked component as MIT/BSD-3/Apache-2.0/public-domain + one MPL test-only entry).
- npm scan covers the six direct deps only; transitive npm deps were not enumerated (`node_modules` absent). Those are codegen/CI devDependencies and are not part of the published package output.
- Platform graphs: build-graph checks were run for windows/amd64 and darwin/arm64; other GOOS/GOARCH combinations use the same dependency set with different build-tag selections.
- The `go.mod`/`go.sum` dependency maintenance work is **not yet committed**, so this report describes the *proposed* dep set; re-run cheaply (`go list -m all` + the marker sweep) after any future bump.
