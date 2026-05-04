# Deployment & Security

## Configuration

### `_config` Table

| Key | Default | Description |
|-----|---------|-------------|
| `session.ttl` | — | Session lifetime (seconds) |
| `cache.tableInfo` | 100 | PRAGMA table_info LRU cache |
| `cache.fkList` | 100 | PRAGMA foreign_key_list LRU cache |
| `cache.queries` | 200 | JSON queries LRU cache |
| `upload.maxFileSize` | 10 MB | Max upload size |
| `upload.maxFiles` | 5 | Max files per request |
| `db.defaultLimit` | 50 | Default SELECT LIMIT |
| `db.maxLimit` | 200 | Maximum SELECT LIMIT |
| `db.maxExport` | 10000 | Maximum export rows |
| `cron.purgeInterval` | 300 | Cron purge interval (seconds) |
| `cron.auditRetention` | 90 days | Audit retention period |

### Environment Variables

| Variable | Role |
|----------|------|
| `WATE_CSRF_SECRET` | CSRF secret (random at startup if absent) |
| `NODE_ENV=production` | Express optimizations |

## Security

### CSRF
Token = `SHA256(sessionId + secret)`. Sent via `X-CSRF-Token` header or `_csrf` body field. Timing-safe comparison. Skipped for GET/HEAD/OPTIONS and signin.

### CSP
Nonce per request. Base: `default-src 'self'; script-src 'nonce-...' 'self'; style-src 'self' 'unsafe-inline'`. Modules extend via `module.csp`.

### Headers
`X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Strict-Transport-Security` (HTTPS only).

### Rate Limiting
Token bucket: 30 POST/min/IP, refill 0.5 tokens/s. Purge after 60s inactivity.

### Password Hashing
PBKDF2-SHA512, 100k iterations, salt = `SHA256(email)`. Timing-safe comparison.

### VM Sandbox
Query expressions (`${expr}`) run in isolated `vm.createContext`: `eval`/`Function` disabled, 50ms timeout, 500 char max. Strict types: `${expr:number}`, `${expr:identifier}`, `${expr:text}`.

### Input Validation
Table names: `/^[a-zA-Z0-9_]+$/`. Error messages filtered and truncated to 120 chars. Body limited to 100 KB.

## Health Check

`GET /health` → `{ status: 'ok', uptime: <seconds> }`. No auth. Registered before CSRF middleware.

## Reverse Proxy

WaTE runs on local HTTP. HTTPS delegated to Nginx/Caddy:

```nginx
location / {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

`trust proxy: 1` already enabled in Express.

## Deployment

### PM2
```bash
pm2 start engine.js --name wate -- --port 8080 --db app.db --mod auth=3600,db
```

### Docker
`DockerFile` and `docker-compose.yml` provided. `.dockerignore` excludes `node_modules/`, `test/`, `.git/`, `*.db`.

### Backup
```bash
sqlite3 app.db ".backup app-backup.db"
```
Never copy the file during a write. SQLite WAL mode enabled.

## Testing

`test/app.js` starts 5 Express instances on ports 3001-3005. `test-wate.sh` runs ~290 curl-based HTTP tests. CSRF tokens pre-computed via `test-secret`.

```bash
node test/app.js        # terminal 1
bash test/test-wate.sh  # terminal 2
```

## Migrations

Naming: `NNN_<scope>_<desc>.sql`. Scope `engine` always runs. `auth`, `db`, `stats`, `mail`, `audit`, `search`, `apikey`, `cron` run when corresponding `--mod` is active.

| Migration | Scope | Creates |
|-----------|-------|---------|
| `001_engine.sql` | (always) | Core schema + defaults |
| `002_config.sql` | (always) | `_config` table |
| `003_stats.sql` | `stats` | `_stats_*` tables + admin page |
| `004_auth_token.sql` | `auth` | `_user_token` table + verify/reset |
| `005_audit_audit.sql` | `audit` | `_audit` table |
| `006_search_search.sql` | `search` | `_fts` FTS5 virtual table + triggers |

---

## Links

- [README](../README.md) — Project overview
- [Architecture](architecture.md) — Engine internals
- [API Reference](api.md) — Routes & modules
- [CHANGELOG](../CHANGELOG.md) — Version history
| `007_apikey_apikey.sql` | `apikey` | `_api_key` table |
