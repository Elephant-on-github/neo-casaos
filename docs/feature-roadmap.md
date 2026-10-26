# neo-casaos feature roadmap

Ranked by **(quality-of-life impact) ÷ (implementation effort)**. Effort is
calendar days for one developer familiar with this codebase; impact is how
much daily friction the feature removes for a home-server user.

Legend: **B** = backend (neo-casaos), **U** = UI (neo-casaos-ui), **G** = gateway,
**O** = OS-level / needs new service. ✅ = already shipped in neo.

## Already shipped (neo)

- Revocable file share links (B+U) ✅
- Opt-in SMB authentication (B) ✅
- Show hidden files toggle (U) ✅
- Self-hosted update channel + migrate/install/uninstall scripts (B) ✅
- Version check redirected to in-repo `version.json` (B) ✅
- README rebrand + structure diagram (docs) ✅

## Tier S — trivial effort, high QoL (do next)

| # | Feature | Effort | Impact | Where | Notes |
|---|---|---|---|---|---|
| 1 | CPU + drive temperature widgets on dashboard | 1d | 4 | B+U | `GetCPUTemperature()` and `GetDiskInfo()` already exist; just render |
| 2 | System log viewer in settings | 1d | 3 | U | `GET /v1/sys/logs` exists; UI has UpdateModal polling logs already |
| 3 | Hide apps not imported to CasaOS | 1d | 3 | U | Filter in app list (issue #133) |
| 4 | Public roadmap | 1d | 2 | docs | GitHub project board (issue #1240) |
| 5 | Dark/light theme polish | 1-2d | 2 | U | CSS variables; UI already has theme scaffolding |
| 6 | App store search & filter | 1-2d | 2 | U | Client-side filter on app list |
| 7 | Notification center surface | 1-2d | 3 | U | `Notify` service exists in backend; check UI wiring |
| 8 | Terminal in browser | 1-2d | 3 | U | `ssh.go` + websocket upgrader exist; check wiring |

## Tier A — easy, good QoL (2–5 days each)

| # | Feature | Effort | Impact | Where | Notes |
|---|---|---|---|---|---|
| 9 | File search (recursive by name) | 2-3d | 4 | B+U | New backend endpoint + search bar in file browser |
| 10 | Edit docker container from UI | 2-3d | 3 | U | Reuse existing container update API; three-dots menu (issue #133) |
| 11 | Drive temp + SMART status widget | 2-3d | 3 | B+U | `smartmontools` is already a dep; parse `smartctl`, add route + widget |
| 12 | Folder size in file browser | 2d | 3 | B+U | `GET /v1/folder/size` exists; wire into UI |
| 13 | File preview improvements (image/video/PDF) | 2d | 3 | U | Viewer components exist; extend supported types |
| 14 | Manual network config (IPv4/IPv6, DNS, gateway, proxy) | 3-5d | 3 | B+U | Backend has `GetNet`/`GetNetInfo`; needs set route + form. (Dropped from earlier triage as env issue, but valuable as a feature.) |
| 15 | WebDAV / SFTP access | 3-5d | 3 | B | New routes; standard protocol surface |
| 16 | UPS monitoring | 3-5d | 3 | B+U | `nut` integration; widget |

## Tier B — medium effort, high QoL (1–2 weeks)

| # | Feature | Effort | Impact | Where | Notes |
|---|---|---|---|---|---|
| 17 | Backup / restore (system + apps) | 1-2w | 4 | B+U | Backup service + UI wizard |
| 18 | Remote access / HTTPS / tunneling | 1w | 4 | B+G | Cloudflare tunnel or Tailscale integration |
| 19 | Encrypted folders | 2w+ | 4 | O+B+U | fscrypt/LUKS; ZimaOS has this. High value, OS-level |
| 20 | 2FA for login | 1-2w | 4 | B (fork user-service) | Auth lives in CasaOS-UserService (upstream, not forked). Requires forking it. |
| 21 | File streaming (DLNA / media) | 1w | 3 | B+U | ZimaOS review flags this as missing |
| 22 | Photo gallery | 1-2w | 3 | U+B | ZimaOS photos (Live Photos, RAW, 360°) |
| 23 | Disk health (SMART) deep dive | 1w | 3 | B+U | Beyond the widget — full SMART attribute view |
| 24 | Encrypted remote access | 2w+ | 3 | O+B+G | Ties into remote access + encrypted folders |

## Tier C — hard (ZimaOS parity, weeks–months)

| # | Feature | Effort | Impact | Where | Notes |
|---|---|---|---|---|---|
| 25 | RAID management (0/1/5/6) | 3w+ | 3 | O+B+U | mdadm; ZimaOS has this |
| 26 | ZFS support | 3w+ | 3 | O+B+U | ZimaOS review flags as missing even there |
| 27 | Cloud sync (Nextcloud-like) | 2w+ | 3 | B+U | Heavy backend work |
| 28 | AI / local LLM (LocalAI) | 2w+ | 2 | B+U+O | ZimaOS has LocalAI integration |
| 29 | VM support (ZVM) | 3w+ | 2 | O+B+U | Full OS virtualization |
| 30 | Mobile app improvements | 2w+ | 2 | U | Separate mobile codebase (not in this repo) |

## Out of scope / not worth it

- **IPv4/IPv6 dual-stack binding** — already binds `:port` (dual-stack); the reported issue is environmental (port conflicts). Dropped earlier.
- **TLS in the backend** — no cert infrastructure in any repo. Dropped earlier.
- **Forking upstream-only services** (message-bus, user-service, local-storage, app-management, CLI, app-store) — needed eventually for 2FA and full control, but not yet. Tracked as a prerequisite for Tier B items 17/20.
- **China CDN mirror** — upstream's fallback to casaos.oss-cn-shanghai.aliyuncs.com. Non-goal for now.

## Recommended next batch (highest (impact/effort) ratio)

1. **Tier S #1** — CPU/drive temp widgets (backend exists, just UI) — 1 day, daily friction gone
2. **Tier S #5** — system log viewer (route exists, generalize UpdateModal) — 1 day
3. **Tier S #3** — hide apps not imported (issue #133) — 1 day
4. **Tier A #9** — file search — 2-3 days, high daily value
5. **Tier A #10** — edit docker container (issue #133, "return of features") — 2-3 days
6. **Tier A #12** — SMART/drive health widget — 2-3 days
7. **Tier B #17** — backup/restore — 1-2 weeks, high value for home users

## Notes on effort estimates

- Effort assumes familiarity with the codebase (Vue 3 Composition API for UI, Go/echo for backend).
- "Where" column: B = backend (neo-casaos), U = UI (neo-casaos-ui), G = gateway, O = OS-level or new service.
- Items requiring forking upstream services (user-service for 2FA) are flagged; those can't be done without forking first.
- ZimaOS has ~800 apps in its store; CasaOS has ~100. App store growth is content work, not code — tracked separately.
