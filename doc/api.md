# API Reference

## `init(options)`

Initializes and starts the WaTE engine. In CLI mode, port and DB are read from `process.argv`. In library mode, all options are passed via the `options` object. Modules are loaded in the order declared in `mod`.

```javascript
const wate = require('wate-engine')
wate.init({
  db: './data/app.db',      // required — DB path or ':memory:'
  port: 8080,               // required — TCP port (1-65535)
  path: './',               // optional — app root directory
  root: '/home',            // optional — redirects '/' to this URL
  mod: ['auth=3600', 'db', 'audit'],
  ejs: ['fs-tools'],        // optional — EJS helper modules
  log: 7,                   // optional — log level bitmask (1=ERROR 2=WARN 4=INFO)
  listen: true,             // optional — false = init without starting HTTP server
  name: 'My App',           // optional — display name in logs and admin UI
  sessionTTL: 3600          // optional — session TTL in seconds (overrides --mod auth=TTL)
}).then(({ app, db, server, close }) => {
  // Register business hooks
  // app.locals.tableHooks, app.locals.jsHandlers available
}).catch(err => console.error('Startup error:', err))
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `db` | `string` | **required** | SQLite database path or `':memory:'` |
| `port` | `number` | **required** | TCP port (1-65535) |
| `path` | `string` | `'./'` | Application root directory |
| `root` | `string` | — | Redirect `'/'` to this URL |
| `mod` | `string[]\|string` | — | Modules to load. Syntax: `name[:alias][=param]` |
| `ejs` | `string[]\|string` | — | EJS helper modules (restricted API) |
| `log` | `number` | `7` | Log level bitmask: 1=ERROR, 2=WARN, 4=INFO |
| `listen` | `boolean` | `true` | Set `false` to skip HTTP server start |
| `name` | `string` | — | Display name for logs and admin UI |
| `sessionTTL` | `number` | — | Session TTL in seconds (overrides `--mod auth=TTL`) |

Returns `Promise<{app, db, server?, close}>`:
- `app` — configured Express instance
- `db` — connected sqlite3 instance
- `server` — http.Server (absent if `listen: false`)
- `close()` — clean shutdown function → Promise (waits for module `done()` calls)

## JSON API Routes

### Authentication — `/admin/api/auth/*`

| Method | Route | Description |
|--------|-------|-------------|
| `POST` | `/admin/api/auth/signin` | Login. Body: `{email, password}` → `{ok, lang, csrf}` |
| `POST` | `/admin/api/auth/signout` | Logout → `{ok: true}` |
| `GET` | `/admin/api/auth/me` | Current profile → `{email, profil_id, lang, csrf}` |
| `PUT` | `/admin/api/auth/me` | Update profile (update-self on `_user`) |
| `DELETE` | `/admin/api/auth/me` | Delete account (delete-self) |
| `POST` | `/admin/api/auth/signup` | Register. `{email, password}` |
| `POST` | `/admin/api/auth/forgot` | Password reset request (mail module required) |
| `POST` | `/admin/api/auth/reset` | Apply new password. `{token, password}` |

### API Keys — `/admin/api/auth/apikey`

| Method | Route | Description |
|--------|-------|-------------|
| `GET` | `/admin/api/auth/apikey` | List keys (masked) |
| `POST` | `/admin/api/auth/apikey` | Create key → `{ok, key, prefix, label}` |
| `DELETE` | `/admin/api/auth/apikey` | Revoke by prefix |

Use: `Authorization: Bearer wate_xxx` header. Module `--mod apikey`.

### Database — `/admin/api/db/*`

**`GET /admin/api/db/schema`** — List accessible tables with columns.

**`GET /admin/api/db/:table?sort=col&dir=asc|desc&search=term&filter=col:val,col2:val2&offset=0&limit=50`** — Paginated SELECT. All params validated against PRAGMA.

**`POST /admin/api/db/:table`** — INSERT. Checks `insert` right.

**`PUT /admin/api/db/:table`** — UPDATE. Checks `update`/`update-self` right. PK columns mandatory.

**`DELETE /admin/api/db/:table`** — DELETE. Checks `delete`/`delete-self` right.

**`GET /admin/api/db/:table/export?format=csv|json[&sort=&filter=&search=]`** — Export with filters. CSV follows RFC 4180 with UTF-8 BOM. Limited by `db.maxExport` (default 10000).

**`POST /admin/api/db/:table/undo`** — Undo last write. Reverses insert/update/delete using audit data. Module `--mod audit` required. Owner can pass `?all=true` to undo any user's last write. Returns `{ok: true}` or 404 `{error: "Nothing to undo"}`.

### Search — `/admin/api/search`

**`GET /admin/api/search?q=term&lang=fr[&scope=demo]`** — FTS5 search. Session required.

**`GET /api/search?q=term&lang=fr[&scope=demo]`** — Public endpoint (list_id ≥ 200 only).

Response: `{ results: [{ source, tag, text, snippet, urls }] }`. Module `--mod search`.

### Statistics — `/admin/api/stats`

`GET /admin/api/stats` — LRU cache statistics. Module `--mod stats`.

### Health — `/health`

`GET /health` — `{ status: 'ok', uptime: <seconds> }`. No auth required.

## HTTP Error Codes

| Code | Meaning |
|------|---------|
| 400 | Bad Request — missing params, invalid table name |
| 401 | Unauthorized — missing/expired session |
| 403 | Forbidden — insufficient `_access` rights, invalid CSRF |
| 404 | Not Found — page/table doesn't exist |
| 429 | Rate limit exceeded (30 POST/min/IP) |
| 500 | Internal Server Error |

## Engine Modules

| Module | CLI | Description |
|--------|-----|-------------|
| `auth` | `--mod auth=3600` | Sessions, PBKDF2, CSRF. TTL in seconds. |
| `db` | `--mod db` | CRUD API + admin UI, sort/filter/export. |
| `stats` | `--mod stats` | LRU cache statistics. |
| `mail` | `--mod mail` | Verification/reset emails (nodemailer). |
| `audit` | `--mod audit` | Write audit log (`_audit` table). |
| `search` | `--mod search` | FTS5 full-text search (`_fts` table). |
| `apikey` | `--mod apikey` | Bearer API keys for M2M access. |
| `cron` | `--mod cron` | Periodic purge of sessions/tokens/audit. |

## Hooks

**`tableHooks`** — Intercept INSERT/UPDATE/DELETE:
```javascript
_data.registerTableWriteHook('tableName', 'insert', function(req, next) {
  // modify req.body, then call next() or next(err)
})
```

**`getTableWriteHook(table, action)`** — Retrieve existing hook (for wrapping, used by audit).

**`pageLoadHooks`** — Inject data before EJS render via `_item` key `HOOK`.

## Core Functions

### `serve(req, res, data?, urlOverride?)`

Resolves and returns page data to the client. This is the core GET rendering pipeline.

1. Validates the session from `req.cookies.sid`
2. Loads `_item` entries for the page URL via `_page` / `_item` UNION query
3. Executes SQL queries defined in `_item.queries` via a VM sandbox
4. Merges results, loads scoped glossary, runs page load hooks
5. Renders the EJS template (`common.ejs`) or delegates to a JS handler

```
serve(req, res)           // standard page render
serve(req, res, extraData) // with extra data injected
serve(req, res, extraData, '/custom/url') // URL override for dynamic routes
```

- `req` — Express Request (must have `req.cookies.sid`, `req.query.lang`, `req.path`)
- `res` — Express Response
- `data` — Optional `{ key, value }` injected into the render result
- `urlOverride` — Optional URL to look up in `_page` instead of `req.path`

Error responses: 401 (expired/missing session), 403 (forbidden), 404 (page not found), 500 (query/config error).

### `modify(req, res, responder?)`

Executes a write operation (INSERT, UPDATE, DELETE) against a database table.

Validation order:
1. Table name validated against `/^[a-zA-Z0-9_]+$/`
2. Active session required (401 if missing)
3. ACL check via `_access` for the current profile (403 if denied)
4. PK columns present for UPDATE/DELETE (400 if missing)
5. Registered `tableWriteHook` executed (if any)
6. SQL write executed (INSERT/UPDATE/DELETE)

`-self` operations (`update-self`, `delete-self`) automatically filter on the `email` column of the current session.

- `req` — Express Request (`req.body` = column values, `req.params.table` = target table, `req.params.request` = action)
- `res` — Express Response
- `responder` — Optional custom responder with `{ success(), error(code, msg) }`. Default: redirects to `../data-<table>?lang=<lang>`

## Module API (`_WATE_API`)

The `_WATE_API` object is passed to every module's `init(api)` function. It provides access to engine primitives without exposing internals.

| Property | Type | Description |
|----------|------|-------------|
| `api.app` | `Express.Application` | Shared Express instance. `app.locals` holds `tableHooks`, `jsHandlers`, `SESSION_TTL_S` |
| `api.log` | `Logger` | Logger with `.INFO(msg)`, `.WARN(msg)`, `.ERROR(msg)` methods |
| `api.db.run()` | `Function` | `db.run(sql, params, callback)` — write queries |
| `api.db.all()` | `Function` | `db.all(sql, params, callback)` — SELECT returning all rows |
| `api.db.get()` | `Function` | `db.get(sql, params, callback)` — SELECT returning first row |
| `api.renderPage(req, res, targetUrl?, extraData?)` | `Function` | Forces a DB page render. Uses `serve()` internally |
| `api.renderError(req, res, code, msg, nextUrl?)` | `Function` | Renders an error page |
| `api.hooks.onPageLoad(name, callback)` | `Function` | Registers a page load hook |
| `api.hooks.onTableWrite(table, action, callback)` | `Function` | Registers a table write hook |

### `api.executeAction(action, params)`

Executes a whitelisted action on the engine. Returns `Promise`.

### `api.getTableWriteHook(table, action)`

Returns the existing hook for `(table, action)`. Useful for chaining without overwriting (pattern used by the audit module).

## Module System

Modules are loaded via `_modules.load(flag, rawInput, appPath)`. The unified syntax for both `--mod` and `--ejs` is:

```
name[:alias][=param]
```

Examples: `auth=3600`, `db`, `audit`, `mail:smtp={"host":"..."}`

**Engine modules** (names in the built-in list) are resolved from `__dirname/_name`. **Application modules** are resolved from `<appPath>/scripts/<name>`.

Module names are validated against `/^[a-zA-Z0-9_-]+$/` (anti path-traversal). Path separators (`/`, `\`, `..`) are rejected.

Each module can export:
- `init(param, api)` — called at load time (can be async → Promise). For `--ejs` modules, `api` is restricted to `{ log, app }`
- `done()` — called during shutdown

Async init has a 10-second timeout. If any module's init rejects, the engine startup fails.

## Web Components

| Element | Purpose |
|---------|---------|
| `<admin-row>` | CRUD form row (adapts to column type) |
| `<schema-table>` | Merise-style schema diagram |
| `<icon-menu>` | Responsive hamburger menu |
| `<show-image>` | Zoomable image display |
| `<admin-list>` | FK dropdown |
| `<modal-popup>` | Replaces native alert/confirm |

---

## Links

- [README](../README.md) — Project overview
- [Modules](module.md) — Module creation and API
- [Architecture](architecture.md) — Engine internals
- [Deployment](deploiement.md) — Docker, PM2, reverse proxy
- [CHANGELOG](../CHANGELOG.md) — Version history
