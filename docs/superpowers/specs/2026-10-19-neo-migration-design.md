# Neo migration — design

Date: 2026-10-19
Status: awaiting user approval

## Intent

Stock CasaOS users need a supported way to move a running install onto neo
builds and keep receiving updates afterwards. CasaOS already ships the
proven channel: the UI "Upgrade Now" button
(`CasaOS-UI/src/components/settings/UpdateModal.vue`) triggers
`UpdateSystemVersion()` in the backend, which runs
`curl -fsSL <UpdateUrl> | bash` — `UpdateUrl` being a plain config value in
`/etc/casaos/casaos.conf`. The script tees output to
`/var/log/casaos/upgrade.log` and the UI waits for the exact string
`CasaOS upgrade successfully`.

We reuse this machinery unchanged: a one-shot `migrate.sh` flips a stock
box to neo (installs neo components + rewrites `UpdateUrl` to point at our
`update.sh`), and every later update is the stock button pulling our
`update.sh`, which installs pinned neo release assets from GitHub Releases.

## Goals

- `migrate.sh`, hosted on this repo and fetched via
  `raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/...`,
  converts stock CasaOS (v0.4.x, installed via get.casaos.io) to neo in
  place: data, databases, users, and app containers untouched.
- After migration the existing Update button pulls neo releases with no UI
  changes required for the flow to work.
- Ongoing updates via `update.sh` (also on this repo): upstream-style
  version pins per component, one bump commit per release.
- The asset list covers the three forked components only: `casaos`
  (backend), `casaos-gateway`, `casaos-ui`. Upstream-only services
  (message-bus, user-service, local-storage, app-management, CLI,
  app-store) are never touched by our scripts; they stay at whatever
  version stock installed. When those repos get forked later, they are
  added to the same asset list.
- Release assets follow upstream conventions
  (`linux-<arch>-<name>-<version>.tar.gz` containing `build/sysroot/`,
  UI as `linux-all-casaos-vX.tar.gz`) so the update script can mirror
  upstream install mechanics.

## Non-goals

- Fresh-install path (a neo equivalent of get.casaos.io/get.sh).
- China CDN mirror (upstream falls back to
  casaos.oss-cn-shanghai.aliyuncs.com). Noted as future work.
- Updating or forking upstream-only services.
- Rollback automation. Property that covers it: running the official
  `get.casaos.io/update` after migrating reinstalls the stock backend,
  gateway, and UI on top of untouched data — that is the documented
  way back.
- Changing the uninstall script (`/usr/bin/casaos-uninstall` stays
  upstream's).

## Constraints

- Follow upstream's proven mechanics: sysroot tarballs overlaid onto `/`,
  `/var/log/casaos/upgrade.log` written by the script itself, the exact
  success string `CasaOS upgrade successfully`, services restarted with
  `casaos.service` last so the UI update flow keeps working mid-restart.
- `UpdateUrl` is read by the backend at startup, so the config flip in
  `migrate.sh` must be followed by a `casaos.service` restart.
- Scripts are fetched from the `main` branch by raw URL; paths must stay
  stable, and every edit to `update.sh` on main changes what all migrated
  boxes run next — keep edits release-driven.
- Architectures: amd64, arm64, arm-7 for Go binaries; UI is
  arch-independent.
- No local Linux test environment on the maintainer machine — CI and a
  manual run on real hardware are the verification gates.

## Decided with the user

1. The existing update button pulls neo; the button experience stays
   unchanged.
2. `migrate.sh` performs the one-time stock→neo flip and is hosted on the
   main neo-casaos repo.
3. GitHub Releases (Elephant-on-github org) are the update channel for all
   subsequent updates.
4. Versioned assets with pins inside `update.sh`, bump-commit per release
   (upstream's maintenance model) — chosen over "latest" resolution.
5. Only the three forked components are in the asset list for now.

## How — calls made here (flagged for review)

- `build/migrate.sh` and `build/update.sh` live in this repo at stable
  raw URLs. `update.sh` is a trimmed fork of upstream's update script:
  arch check, dependency check (no dependency install — stock already has
  them), download the pinned assets, run `scripts/migration/script.d`
  from the backend tarball, overlay `build/sysroot/*` onto `/` (after
  clearing `/var/lib/casaos/www/*`), restart gateway + backend, log and
  success string as upstream. Drop upstream's rclone install, addon
  configuration, and uninstall-script refresh — out of scope for
  component swapping.
- `migrate.sh` = same install core, plus: verify we are migrating an
  existing stock install (`/etc/casaos/casaos.conf` present), rewrite
  `UpdateUrl` in `/etc/casaos/casaos.conf` to the raw `update.sh` URL,
  restart `casaos.service`, and print a clear migrated/failed summary.
- Manifest handling: upstream regenerates
  `/var/lib/casaos/manifest` from every package's sysroot. If we
  overwrite it with only our three components, uninstall would leave
  upstream services' files untracked. Call: merge (append, de-duplicated)
  our file list into the existing manifest instead of truncating it.
- Version pins: `migrate.sh` and `update.sh` share the same pin block
  (component version + asset URL); each neo release = tag the component
  repos, then one commit bumping the pins in this repo.
- Release prerequisites: backend and gateway already release on tag via
  the IceWhaleTech reusable goreleaser workflow (assets named as
  upstream). `neo-casaos-ui` has no release workflow — one must be added
  that builds the Vue app and packages `dist/` as
  `linux-all-casaos-vX.tar.gz` in upstream's shape.
- The UI's "A new version is available!" banner source is not a direct
  GitHub call from the UI; where the signal comes from must be
  investigated, and if it consults upstream release metadata it gets
  pointed at the fork's releases.

## Risks

- Both release workflows call
  `IceWhaleTech/github/.github/workflows/go_release.yml@main` — a shared
  workflow outside our control. If it changes or breaks, releases stop;
  vendoring it into the org is the mitigation when that happens.
- Release workflow secrets (GoogleID/Secret, Dropbox, OneDrive, OSS) are
  configured for upstream; if any step requires them and they are absent
  in the fork, tagged releases may fail. Needs one tagged test release
  per repo to confirm.
- Migration untested on real hardware until the first manual run; script
  is one command and failures leave the box on stock (install core runs
  before the config flip, so a failed flip still leaves stock binaries —
  the flip and the binary swap are the two failure points to test).
- Stock versions older than the v0.4.x line are unverified as migration
  sources.

## What's left to the builder

- Exact internals of upstream release tarballs (verify by downloading one
  upstream asset; mirror its layout).
- Exact service restart set for the update path (gateway + casaos expected;
  confirm UI needs no restart beyond file replacement).
- Where the UI version banner gets its signal; redirect if upstream.
- Manifest merge implementation detail (append + sort -u is fine).
