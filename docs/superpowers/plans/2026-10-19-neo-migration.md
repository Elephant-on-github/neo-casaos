# Neo Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move stock CasaOS installs onto neo builds via the existing Update button — a one-shot `migrate.sh` flips the box, GitHub Releases carry all later updates.

**Architecture:** Backend's version check (`GetCasaosVersion`) is redirected from IceWhale's cloud API to a `version.json` on this repo's main branch. `build/update.sh` (trimmed fork of get.casaos.io/update) installs pinned neo release assets with upstream's sysroot-overlay mechanics. `build/migrate.sh` rewrites `UpdateUrl` in `/etc/casaos/casaos.conf` (flip-before-install) then delegates to `update.sh`.

**Tech Stack:** Go (backend), bash + shellcheck (scripts), GitHub Actions (release + lint), Vue/pnpm (UI release workflow, pre-existing).

**Spec:** `docs/superpowers/specs/2026-10-19-neo-migration-design.md`

## Global Constraints

- Version scheme: numeric `vX.Y.Z` ONLY (no `-neo` suffixes) — `pkg/utils/version` compares per-segment with `strconv.Atoi`.
- `common.VERSION` (`common/constants.go:5`) must always equal `version.json`'s `data.version`; bumped in the same commit as the script pins. Current value: `0.4.15`.
- Exact success string in `/var/log/casaos/upgrade.log`: `CasaOS upgrade successfully` (the UI greps for it).
- Script URLs are stable raw URLs on main:
  `https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/update.sh` and `.../build/migrate.sh`.
- Asset list contains ONLY the three forked components (backend, gateway, UI); upstream-only services are never touched.
- First neo release versions: backend `v0.4.16`, gateway `v0.4.10`, UI `v0.4.26` (all numeric, continuing each repo's upstream numbering).
- `build/update.sh` and `build/migrate.sh` must NOT be merged to main before the pinned release assets exist.
- Local machine is Windows without bash/WSL: Go gate = `GOOS=linux go build ./...` + `GOOS=linux go vet` (the `service` package is Linux-only); shell verification = CI (Task 2) + review; Go tests execute in CI (`codecov.yml` runs `go test ./...` on push/PR).
- All public actions (push to fork, PRs, tags, releases, merges to main) require explicit user confirmation.
- Gitmoji commit convention.

## Review Focus

1. `version.json` unreachable at runtime → expected: empty version, no panic, Update button simply no-ops. Pinned by `TestGetCasaosVersionUnreachable` in Task 1.
2. Stock `/etc/casaos/casaos.conf` has NO `UpdateUrl` key (verified against upstream `casaos.conf.sample`) → expected: migrate.sh inserts the key into `[server]`, not just sed-replaces. Pinned by the exact grep/insert logic in Task 4 and validation (b) in Task 7.
3. A suffixed tag (e.g. `v0.4.16-neo`) corrupts the naive comparator into a permanent "update available" → expected: every release tag numeric. Pinned by the regexp assertion in Task 1's drift test and Task 5's checklist.
4. arm asset naming is `arm-7` (not `armv7`/`armhf`) and must match release assets byte-for-byte or the download 404s → expected: exact URLs. Pinned by the verbatim pin block in Task 3 and asset verification in Task 7.
5. `/var/log/casaos/` may not exist on odd installs → expected: scripts create the directory before teeing. Pinned by the `mkdir -p` step in Task 3.

---

### Task 1: Backend version signal (`version.json` fetch)

**Repo:** neo-casaos, branch `feat/version-signal`

**Files:**
- Create: `version.json` (repo root)
- Modify: `service/casa.go:23-45` (`GetCasaosVersion`)
- Test: `service/casa_test.go` (new, package `service`)

**Interfaces:**
- Consumes: `httper.Get(url string, head map[string]string) (response string)` (`pkg/utils/httper/httper.go:18`); package-level `Cache` (ecache, has `Get/Set/Delete`); `model.Version{Version string json:"version"; ChangeLog string json:"change_log"}`.
- Produces: package var `versionJSONURL string` (test override point); `version.json` shape `{"data":{"version":"X.Y.Z","change_log":"https://github.com/Elephant-on-github/neo-casaos/releases"}}`; `GetCasaosVersion() model.Version` signature unchanged (callers in `route/v1/system.go:39,65,89` untouched).

- [ ] **Step 1: Create `version.json` and write the failing tests**

`version.json` (repo root), initial content pinned to the current `common.VERSION`:

```json
{"data":{"version":"0.4.15","change_log":"https://github.com/Elephant-on-github/neo-casaos/releases"}}
```

`service/casa_test.go` — three tests:

```go
func TestGetCasaosVersionFromVersionJSON(t *testing.T) {
	// httptest server serving {"data":{"version":"9.9.9","change_log":"notes"}}
	// override versionJSONURL, defer-restore; Cache.Delete("casa_version")
	// assert NewCasaService().GetCasaosVersion() -> Version=="9.9.9", ChangeLog=="notes"
}

func TestGetCasaosVersionUnreachable(t *testing.T) {
	// versionJSONURL = "http://127.0.0.1:1" (closed port); Cache.Delete("casa_version")
	// assert GetCasaosVersion() returns Version=="" and does not panic
}

func TestVersionJSONMatchesCommonVERSION(t *testing.T) {
	// os.ReadFile("../../version.json")
	// v := gjson.GetBytes(b, "data.version").String()
	// assert v == common.VERSION
	// assert regexp.MustCompile(`^\d+\.\d+\.\d+$`).MatchString(v)
	//   (numeric-only guard: comparator parses segments with Atoi)
}
```

- [ ] **Step 2: Compile gate**

Run: `go vet ./service/...` (no GOOS — this fails if test files don't compile) and `GOOS=linux go build ./...`
Expected: vet fails only on the not-yet-implemented `versionJSONURL` (undefined); build passes on main's code.

- [ ] **Step 3: Implement the fetch in `service/casa.go`**

Add near the top of the file:

```go
// versionJSONURL is neo's release channel: version.json on main, bumped with every release.
var versionJSONURL = "https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/version.json"
```

In `GetCasaosVersion`, replace the single line
`v := httper.OasisGet(config.ServerInfo.ServerApi + "/v1/sys/version")`
with
`v := httper.Get(versionJSONURL, nil)`.
Keep everything else (cache check, `gjson.Get(v, "data")`, unmarshal, 20-minute cache) verbatim. Remove the now-unused `config` import if nothing else in the file uses it.

- [ ] **Step 4: Compile gate again**

Run: `GOOS=linux go build ./...` and `GOOS=linux go vet ./service/...`
Expected: exit 0 (vet only shows the 2 pre-existing `service/notify.go` warnings). Runtime test proof is CI: `codecov.yml` runs the three tests on push.

- [ ] **Step 5: Commit**

```bash
git add version.json service/casa.go service/casa_test.go
git commit -m ":sparkles: Read update availability from in-repo version.json"
```

---

### Task 2: Shell lint workflow

**Repo:** neo-casaos, branch `feat/migration-scripts` (shared with Tasks 3-4)

**Files:**
- Create: `.github/workflows/scripts-lint.yml`

**Interfaces:**
- Produces: CI gate for Tasks 3-4 (runs `bash -n` + `shellcheck` on every push/PR touching `build/*.sh`).

- [ ] **Step 1: Create the workflow**

```yaml
name: shell-lint
on:
  push:
    paths: ['build/**.sh', '.github/workflows/scripts-lint.yml']
  pull_request:
    paths: ['build/**.sh', '.github/workflows/scripts-lint.yml']
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash -n build/*.sh
      - run: shellcheck -S warning build/*.sh
```

(`-S warning` to start; upstream scripts carry `# shellcheck disable=` comments for known-noisy cases — use the same idiom.)

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/scripts-lint.yml
git commit -m ":wrench: Add shellcheck CI for migration scripts"
```

---

### Task 3: `build/update.sh`

**Repo:** neo-casaos, branch `feat/migration-scripts`

**Files:**
- Create: `build/update.sh`

**Interfaces:**
- Produces: the update script that `migrate.sh` (Task 4) delegates to and that migrated boxes curl on every Update-button press.
- Source material: webfetch `https://get.casaos.io/update` and trim it — do not rewrite from scratch.

- [ ] **Step 1: Write `build/update.sh`**

Spec (what to copy verbatim from upstream, what to drop, what to change):

- Copy verbatim: `#!/usr/bin/bash`, `set -e`, `export PATH=/usr/sbin:$PATH`, sudo detection (`((EUID)) && sudo_cmd="sudo"`), log setup (`upgradePath=/var/log/casaos`, `upgradeFile=/var/log/casaos/upgrade.log`, `mkdir -p`, remove+touch — **this is the mkdir that satisfies Review Focus 5**), the whole `Show()` function (all four branches, `tee -a /var/log/casaos/upgrade.log`), and `Check_Arch()` (case order matters: `*aarch64*`→arm64 before `*64*`→amd64, `*armv7*`→arm-7).
- Header comment: neo fork URLs, issues link to `https://github.com/Elephant-on-github/neo-casaos/issues`, usage line `curl -fsSL https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/update.sh | bash`.
- New pin block (**Review Focus 4** — exact URLs, `arm-7` spelling):

```bash
readonly CASA_PACKAGES=(
    "https://github.com/Elephant-on-github/neo-casaos-gateway/releases/download/v0.4.10/linux-${TARGET_ARCH}-casaos-gateway-v0.4.10.tar.gz"
    "https://github.com/Elephant-on-github/neo-casaos/releases/download/v0.4.16/linux-${TARGET_ARCH}-casaos-v0.4.16.tar.gz"
    "https://github.com/Elephant-on-github/neo-casaos-ui/releases/download/v0.4.26/linux-all-casaos-v0.4.26.tar.gz"
)
```

- Trimmed `DownloadAndInstallCasaOS`, keeping upstream's flow: `TMP_ROOT=/tmp/casaos-installer`, `mkdir -p`, `mktemp -d`, `pushd`, `wget -t 3 -q --show-progress -c` each package, `tar zxf linux-*.tar.gz`, `BUILD_DIR=$(realpath -e "${TMP_DIR}"/build)`, `popd`, run `build/scripts/migration/script.d/*.sh`, install: manifest **merge** (upstream truncates with `find ... | cut -c ${#SYSROOT_DIR}- | cut -c 2-`; we merge instead: write to a temp file, then `sort -u` temp + existing manifest over it, so uninstall keeps tracking upstream components), `rm -rf /var/lib/casaos/www/*`, `cp -rf "${SYSROOT_DIR}"/* /`, run `build/scripts/setup/script.d/*.sh`, `chmod +x /etc/casaos/start.d/register-ui-events.sh` if present, `Show 0 "CasaOS upgrade successfully"`, restart exactly two services in order: `casaos-gateway.service`, then `casaos.service`.
- Drop entirely: `Get_Download_Url_Domain`, `Check_Distribution`, `Check_Port`, `Update_Package_Resource`, `Install_Depends`, `Check_Dependency_Installation`, rclone install, `Configuration_Addons`, uninstall-script download, `-p BUILD_DIR` getopts.
- Add a minimal preflight instead of the dependency machinery: abort via `Show 1` unless `wget`, `tar`, `systemctl` are on PATH.
- Main sequence: preflight → `Check_Arch` → `DownloadAndInstallCasaOS`. Nothing interactive.

- [ ] **Step 2: Self-check against the keep/drop list, then commit**

```bash
git add build/update.sh
git commit -m ":sparkles: Add neo update script (pinned GitHub Releases)"
```

- [ ] **Step 3: Verify via CI**

Push the branch (confirmation-gated). Expect `shell-lint` workflow green (`bash -n` + shellcheck). There is no local bash — CI is the syntax gate; Task 7's box run is the behavioral gate.

---

### Task 4: `build/migrate.sh`

**Repo:** neo-casaos, branch `feat/migration-scripts`

**Files:**
- Create: `build/migrate.sh`

**Interfaces:**
- Consumes: Task 3's raw URL (`UPDATE_URL` constant below must match Task 3's URL byte-for-byte).
- Produces: the one-liner users run once on a stock box.

- [ ] **Step 1: Write `build/migrate.sh`**

Spec:

- `#!/usr/bin/bash`, `set -e`, sudo detection, header with usage line
  `curl -fsSL https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/migrate.sh | bash`
  and a short rollback note (spec: rollback = run official `get.casaos.io/update`,
  then revert the `UpdateUrl` line in `/etc/casaos/casaos.conf`).
- Constants:

```bash
readonly UPDATE_URL="https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/update.sh"
readonly FORK_BASE="0.4.15"
```

- Preflight (abort with a clear message): `/etc/casaos/casaos.conf` must exist (else "this does not look like an existing CasaOS install") and `casaos` must be on PATH.
- Version guard (warn only, never block): extract `STOCK=$(casaos -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)`; if `printf '%s\n%s' "$FORK_BASE" "$STOCK" | sort -V | tail -n1` is not `FORK_BASE`, print a warning that stock is newer than the neo base and issues should go to the fork.
- Config flip (**Review Focus 2** — stock conf has no `UpdateUrl` key):

```bash
if grep -qE '^\s*UpdateUrl\s*=' /etc/casaos/casaos.conf; then
  ${sudo_cmd} sed -i -E "s|^\s*UpdateUrl\s*=.*|UpdateUrl = ${UPDATE_URL}|" /etc/casaos/casaos.conf
else
  ${sudo_cmd} sed -i "/^\[server\]/a UpdateUrl = ${UPDATE_URL}" /etc/casaos/casaos.conf
fi
```

- Then install (flip-before-install ordering — a failure here self-heals on the next Update press): `curl -fsSL "${UPDATE_URL}" | bash`.
- Final summary to stdout: migrated (or failed, with pointer to `/var/log/casaos/upgrade.log`); note that future updates come from the UI's Update button.
- Nothing interactive.

- [ ] **Step 2: Commit**

```bash
git add build/migrate.sh
git commit -m ":sparkles: Add migrate.sh (stock CasaOS to neo, one-liner)"
```

- [ ] **Step 3: Verify via CI**

Push (confirmation-gated). Expect `shell-lint` green on both scripts.

---

### Task 5: Release process doc

**Repo:** neo-casaos, branch `feat/migration-scripts`

**Files:**
- Create: `docs/releasing.md`

- [ ] **Step 1: Write the checklist**

Content (concise checklist, no prose padding):

1. Rule: tags are numeric `vX.Y.Z` only — suffixed tags break `pkg/utils/version`'s Atoi comparator (permanent update banner).
2. Pre-tag commit must bump together: `common/constants.go` `VERSION`, `version.json` `data.version`, and the pin block in `build/update.sh` (pins move to the versions about to be tagged).
3. Per repo: tag `vX.Y.Z`, push tag — backend and gateway release via the IceWhaleTech reusable goreleaser workflow; UI via `node-prerelease.js.yml` (tag `v*`).
4. After release: verify assets exist with exact names (`linux-<arch>-casaos-vX.tar.gz` for amd64/arm64/arm-7, `linux-<arch>-casaos-gateway-vX.tar.gz`, `linux-all-casaos-vX.tar.gz`) — a missing arch asset makes that arch's update 404.
5. Never merge `build/*.sh` changes to main before the pinned assets exist (main is what the raw URLs serve).
6. Known prerequisites: backend/gateway release workflows call `IceWhaleTech/github` reusable workflow — if a tag run fails on missing fork secrets (GoogleID, OSS, etc.), vendor the workflow; UI build needs `@icewhale/*` npm packages resolvable in CI (`NPM_TOKEN` secret or public availability).

- [ ] **Step 2: Commit**

```bash
git add docs/releasing.md
git commit -m ":memo: Add neo release checklist"
```

---

### Task 6: UI release workflow fix

**Repo:** neo-casaos-ui, branch `feat/release-workflow-fix`

**Files:**
- Modify: `.github/workflows/node-prerelease.js.yml:91-100` (remove the `Upload to oss` step — it pushes to IceWhale's `casaos` OSS bucket with secrets the fork doesn't have; the `git-release-private` release step above it stays)

**Interfaces:**
- Produces: a UI tag (`v0.4.26`) that publishes `linux-all-casaos-v0.4.26.tar.gz` containing `build/sysroot/var/lib/casaos/www/*` (already produced by `pnpm build` → `vue-cli-service build --dest ./build/sysroot/var/lib/casaos/www/`, plus `register-ui-events.sh` copied by `message_bus.build.js`).

- [ ] **Step 1: Remove the OSS upload step** (lines 91-100: `id: upload_to_oss` through the `assets:` block)
- [ ] **Step 2: Commit**

```bash
git add .github/workflows/node-prerelease.js.yml
git commit -m ":wrench: Drop IceWhale OSS upload from release workflow"
```

---

### Task 7: Releases, merge gating, validation (all public actions confirmation-gated)

**Repos:** all three.

- [ ] **Step 1: Ship the backend signal first**
  - Merge Task 1 branch (`feat/version-signal`) to main → PR against the fork (confirmation-gated).
  - Bump commit on main: `VERSION` → `0.4.16`, `version.json` → `0.4.16` (drift test enforces they match).
  - Tag `v0.4.16`, push tag (confirmation-gated); watch the goreleaser run; if it fails on secrets, stop and report.
- [ ] **Step 2: First gateway + UI releases**
  - Tag gateway `v0.4.10` (no code change needed), push (confirmation-gated).
  - Merge Task 6 branch to UI main, tag UI `v0.4.26`, push (confirmation-gated).
  - Verify all three releases' assets: exact names, all three arches for Go components + `linux-all` for UI (Review Focus 4).
- [ ] **Step 3: Publish the scripts**
  - Merge `feat/migration-scripts` (Tasks 2-5) to main (confirmation-gated) — now the raw URLs serve working scripts. Merge the UI #1848 branch separately if desired.
- [ ] **Step 4: Manual validation on the amd64 box** (user runs; non-breaking checks)
  - (a) stock box → run the `migrate.sh` one-liner → `casaos -v` reports `0.4.16`;
  - (b) `grep UpdateUrl /etc/casaos/casaos.conf` shows the neo URL (inserted into `[server]`);
  - (c) `/var/log/casaos/upgrade.log` ends with `CasaOS upgrade successfully`; UI loads, existing data (apps, shares, files) intact;
  - (d) end-to-end button test: temporarily bump `version.json` on main to `0.4.17` → banner appears in UI → press Upgrade Now → log shows success (binaries remain 0.4.16) → revert `version.json` to `0.4.16`;
  - (e) failure drill (optional but recommended): on a scratch install, kill the network mid-migrate and confirm the box recovers by pressing Update again (flip-before-install self-heal).
