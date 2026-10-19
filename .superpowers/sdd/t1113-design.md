# #1113 — SMB share authentication (security-critical)

## Current (insecure) state
- Per-share stanza (`service/shares.go` UpdateConfigFile):
  `public = Yes / guest ok = Yes / read only = No / force user = root / create+dir mask = 0777`
  -> every share is public, world-writable, served as root.
- Global (`InitSambaConfig`): `map to guest = bad user`, `include=/etc/samba/smb.casa.conf`.
  Samba's default `security = user` is in effect (not overridden).
- Create handler (`route/v1/samba.go` PostSambaSharesCreate) hardcodes `Anonymous = true`.
- helper.sh has `AddSmabaUser(user, pass)` (useradd + `smbpasswd -a`) and `EditSmabaUserPassword`.

## Goal
Enforce authentication on Samba shares (opt-in per share so existing public shares don't break).

## Design
### Per-share stanza (when auth required)
`public = No / guest ok = No / valid users = <shareuser> / read only = No /
 create mask = 0644 / directory mask = 0755`  (drop `force user = root`).

### Credential model — DECISION NEEDED
A. Single dedicated share account (RECOMMENDED, self-contained):
   Admin sets a "share password" once; backend creates samba user (e.g. `casaos-share`)
   via smbpasswd -a. All auth-required shares use `valid users = casaos-share`.
   Pros: only this repo + helper.sh. Cons: one shared credential, not per-user.
B. Reuse CasaOS admin login:
   Needs the plaintext password -> requires CasaOS-UserService (cross-repo) or re-entry.
   Pros: matches login. Cons: cross-repo, password-handling complexity.
C. Per-share credentials:
   Each share gets its own samba user/password. Most granular, most complex (UI + N accounts).

### Migration
Existing shares stay public (Anonymous=true) until re-created. New/edited shares can opt in
to auth. No forced breakage of current guest access.

## Pre-existing helper.sh note
`AddSmabaUser` heredoc feeds the password with leading spaces (`<<EOF`, not `<<-EOF`) — the
stored password would include indentation. Would need a clean non-interactive smbpasswd helper
if we go with option A/C.
