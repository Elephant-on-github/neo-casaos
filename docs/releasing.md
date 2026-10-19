# Releasing neo

Checklist for cutting neo releases. The migration/update scripts pin
versions explicitly (upstream-style), so every release ends with a bump
commit on this repo.

## Rules

- Tags are numeric `vX.Y.Z` ONLY — no suffixes. `pkg/utils/version`
  compares version segments with `strconv.Atoi`; a suffixed tag like
  `v0.4.16-neo` parses a segment to 0 and corrupts the update check
  (permanent "update available" banner).
- Every release-tag commit bumps together, in one commit:
  - `common/constants.go` `VERSION`
  - `version.json` `data.version` (repo root; a CI test enforces it
    matches `common.VERSION`)
  - the pin block in `build/update.sh`
- Never merge `build/*.sh` changes to main before the pinned release
  assets exist — main is what the raw URLs serve to every migrated box.

## Per-release steps

1. Pre-tag commit: bump `VERSION`, `version.json`, and the `build/update.sh`
   pins to the versions about to be tagged.
2. Per repo, tag `vX.Y.Z` and push the tag:
   - `neo-casaos` (backend) — releases via the IceWhaleTech reusable
     goreleaser workflow (`.github/workflows/release.yml`)
   - `neo-casaos-gateway` — same reusable workflow
   - `neo-casaos-ui` — releases via `node-prerelease.js.yml` (tag `v*`,
     builds the Vue app, packages the sysroot tarball)
3. Verify the release assets exist with exact names, for every arch:
   - `linux-amd64-casaos-vX.Y.Z.tar.gz`, `linux-arm64-casaos-vX.Y.Z.tar.gz`,
     `linux-arm-7-casaos-vX.Y.Z.tar.gz` (note: `arm-7`, not `armv7`)
   - `linux-<arch>-casaos-gateway-vX.Y.Z.tar.gz` (same three arches)
   - `linux-all-casaos-vX.Y.Z.tar.gz` (UI, arch-independent)
   A missing arch asset makes that arch's update fail with a 404.
4. Merge the bump commit to main (raw URLs now serve the new pins, and
   `version.json` — fetched live from main — arms the update banner in
   already-migrated UIs).

## Known prerequisites / failure modes

- Backend and gateway release workflows call
  `IceWhaleTech/github/.github/workflows/go_release.yml@main` — a shared
  workflow outside this org's control, and it may require fork secrets
  (GoogleID/Secret, Dropbox, OneDrive, OSS). If a tag run fails on missing
  secrets, vendor the workflow into this org and strip what we do not use.
- The UI release build needs the `@icewhale/*` npm packages to resolve in
  CI (`NPM_TOKEN` secret or public availability on the registry).

## First releases

Backend `v0.4.16`, gateway `v0.4.10`, UI `v0.4.26` — these are the
versions pinned in `build/update.sh` as shipped.
