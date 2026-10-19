# QoL + Modernity Batch — Todo

Repos (all inside `.ai/`, separate git, `upstream` = IceWhaleTech):
- `neo-casaos`        — Go backend (fork: Elephant-on-github/neo-casaos)
- `neo-casaos-ui`     — CasaOS-UI frontend (clone)
- `neo-casaos-gateway`— CasaOS-Gateway (clone)

Dropped:
- #1074 TLS — no cert/ACME/`:443` infra in any of these repos.
- #1766 IPv4/IPv6 — gateway binds dual-stack (`main.go:322` `:port`); issue is environmental
  (slow-over-IPv4 / port conflict). Not a code fix.

## 1. #1353 — File share via URL (backend) — DONE (backend) ✓
- [x] Explore backend patterns: DB init, service wiring, route registration, auth model.
- [x] Design: share-token model + public serving route (see t1353-design.md).
- [x] Implement: model (o_file_share) + service (FileShareService) + handlers
      (route/v1/file_share.go) + wiring (service.go, sqlite/db.go) + routes (v1.go).
      - POST/GET/DELETE /v1/file/share (auth) ; GET /v1/file/share/:token (PUBLIC).
      - Revoke uses ?id= (query param) to avoid echo route-param conflict with :token.
- [x] Verify: GOOS=linux go build ./... exit 0; vet clean for my code (notify.go warnings pre-existing).
- [x] Tests: service/file_share_test.go + route/router_test.go (compile; run in CI).
- [ ] PR + user confirmation before merge.
- Note: UI "Share URL" button is a companion change in neo-casaos-ui (deferred; backend is core).

## 2. #1848 — View hidden dotfiles (UI toggle) — neo-casaos-ui — IMPLEMENTED
- [x] Locate filebrowser/FilePanel.vue:582 dotfile filter (`!item.name.startsWith(".")`).
- [x] Design: `showHidden` flag (localStorage `casaos_show_hidden`, default off=hidden).
- [x] Implement: gate filter on showHidden; `toggleShowHidden()` re-lists; toolbar eye/eye-off
      toggle beside Change View; i18n key added to en_US.json.
- [x] Verify: en_US.json valid JSON; template/filter/method/data re-read + correct.
- [ ] Full UI lint/build — gated by UI repo CI (background `pnpm install` started for local lint).
- [ ] PR + user confirmation before merge.

## 3. #1113 — SMB share authentication (backend, security-critical) — DONE ✓
- [x] KISS design: honor the existing `Anonymous` wire flag (UI already sends `anonymous:true`,
      so backward compatible); single dedicated account `casaos-share` for all auth'd shares.
- [x] Implement:
      - model/share.go: optional `Password` (used at create time, never stored).
      - route/v1/samba.go: honor v.Anonymous; password required when auth'd; chmod 0777
        only for anonymous shares; EnsureShareUser via helper.
      - service/shares.go: buildShareConfig() pure fn — auth'd stanza = public=No /
        guest ok=No / valid users=casaos-share / masks 0664+0775 (still force user=root).
      - helper.sh: fixed AddSmabaUser (base64 stdin, smbpasswd -a -s, no leading-space bug,
        useradd tolerant of existing user).
- [x] Verify: GOOS=linux go build ./... exit 0; vet clean (minus pre-existing notify.go).
- [x] Test: service/shares_test.go covers both stanza branches (compiles; runs in CI).
- [ ] PR + user confirmation before merge.
- Migration: existing shares keep anonymous=true from DB → unchanged behavior.
