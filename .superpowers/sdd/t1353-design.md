# #1353 — File share via URL (backend)

## Goal
Let a logged-in user generate a shareable link for a single file that anyone can
download without authenticating (Google-Drive style), instead of re-uploading.

## Design
Token -> path mapping, persisted in SQLite. Only the resolve endpoint is public.

### Data (new table `o_file_share`)
`FileShareDBModel{ ID uint PK; Token string uniqueIndex; Path string; ExpireAt int64 (unix sec, 0=never); Created int64 }`

### Service `FileShareService` (service/file_share.go)
- `CreateShare(path, expireSeconds)` -> token (crypto/rand, 32 bytes, base64url)
- `GetShareByToken(token)`
- `ListShares()`, `DeleteShare(id)`

### Routes
- `POST   /v1/file/share`        -> `PostCreateFileShare`   (auth; in v1FileGroup/JWT)
      body {path, expire_seconds?}; validates path is an existing regular file;
      returns {token, url:"/v1/file/share/<token>"} (client prepends origin).
- `GET    /v1/file/share`        -> `ListFileShares`        (auth)
- `DELETE /v1/file/share/:id`    -> `DeleteFileShare`       (auth; revoke)
- `GET    /v1/file/share/:token` -> `GetPublicFileShare`    (PUBLIC; registered on
      echo root `e`, bypassing v1Group JWT — same as /v1/recover/:type). Looks up
      token, enforces expiry, serves the stored path via http.ServeFile.

### Wiring
- AutoMigrate += FileShareDBModel (pkg/sqlite/db.go:44)
- Repository/store/NewService += FileShare() (service/service.go)
- No gateway change: gateway prefix-matches `/v1/file`, which covers `/v1/file/share/*`
  (confirmed: gateway service/management.go GetProxy sorts by length, HasPrefix).

## Security
- Token: crypto/rand 32 bytes -> base64.RawURLEncoding (unguessable, URL-safe).
- Public route never takes a user-controlled path — only the token; the stored path was
  captured server-side at share time. No path traversal.
- Optional expiry enforced on resolve; revocable via DELETE.
- create/list/delete are JWT-authenticated; only resolve is public.
- Sharing a file is no broader than existing auth'd file access (user already can read
  any path via /v1/file), so no new exposure of unauthorized data.

## Verified
- Gateway `GetProxy` (service/management.go:86-97) prefix-matches, longest-first.
- Auth: `/v1` group JWT (route/v1.go:44); routes on `e` root bypass it (line 41 pattern).
