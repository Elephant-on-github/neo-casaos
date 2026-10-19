# Task brief — T1: License compliance scan (PLAN.md step 2)

## Context
neo-casaos is our fork of IceWhaleTech/CasaOS (Apache-2.0, Go backend + a TypeScript SDK package.json at repo root). This is a read-only compliance scan. Produce a report; change NO code, NO files except your own report.

## Requirements
1. Confirm LICENSE: it is Apache-2.0, present at repo root. State its exact SPDX id and that the fork preserved it.
2. NOTICE: confirm whether a NOTICE file exists in the fork and in upstream (`git ls-tree upstream/main --name-only`). It does NOT. Report this: upstream never shipped NOTICE, so nothing was lost in the fork — but note that Apache-2.0 redistribution *recommends* preserving NOTICE, so flag it as a decision for the human (not a defect you fix).
3. Scan Go dependency licenses for non-permissive terms (GPL/AGPL/SSPL/Commercial/unknown). Method: `go list -m -f '{{.Path}} {{.Version}}' all` then inspect licenses. Use `go-licenses` if installed (`go run github.com/google/go-licenses@latest report ./... 2>&1`), otherwise reason from known module licenses and flag anything unknown as "needs manual check". Produce a table: module, license, permissive? Focus on flagging non-permissive/unknown; do not enumerate all 200+.
4. Scan npm dependency licenses in package.json (root): axios (MIT), all-contributors-cli (MIT), @openapitools/openapi-generator-cli (MIT), @types/node (MIT), openapi-typescript-codegen (MIT), typescript (Apache-2.0). All permissive. Report any non-permissive/none found. (node_modules may not be installed; reason from package metadata / known licenses.)

## Success criteria
- A report listing: LICENSE id, NOTICE status (absent upstream + fork) flagged as a human decision, Go dep license findings (non-permissive/unknown only, with a "none found" or list), npm dep license findings.
- Nothing committed. No source files touched.

## Report
Write the full report to `.superpowers/sdd/t1-license-report.md`. Return only: status (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED), one-line summary, and any concerns.
