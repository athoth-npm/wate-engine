# WaTE Architecture

WaTE (Web as Table Engine) is a Node.js/Express/SQLite CMS engine built on a **Data-First** paradigm: the SQL schema drives UI, routing, ACL, and i18n. The code stays generic — all business logic lives in the database.

## Engine Core

| File | Role | Loading |
|------|------|---------|
| `engine.js` | Entry point, Express init, orchestration | `require('wate-engine')` |
| `_core.js` | Central registry (state manager) | Singleton via `require()` |
| `_data.js` | Data access — `serve()` (read) + `modify()` (write) | Internal |
| `_modules.js` | Module loader — unified syntax, `_WATE_API` facade | Internal |
| `_auth.js` | Sessions, signin/signup/me, verify/forgot/reset | `--mod auth=TTL` |
| `_db.js` | CRUD API + UI, sort/filter/export | `--mod db` |
| `_stats.js` | Access statistics (LRU cache) | `--mod stats` |
| `_mail.js` | Verification/recovery emails (nodemailer) | `--mod mail` |
| `_audit.js` | Write audit log + undo | `--mod audit` |
| `_search.js` | FTS5 full-text search | `--mod search` |
| `_apikey.js` | Bearer API keys for M2M access | `--mod apikey` |
| `_cron.js` | Periodic maintenance tasks | `--mod cron` |
| `_migration.js` | SQL migration engine (001 → N) | Internal |
| `_modules.js` | Application and WaTE module loader | Internal |
| `_utils.js` | Shared pure functions (crypto, CSRF, cookies, LRU) | Internal |
| `_log.js` | Internal logger | Internal |

## System Tables

```
_list ───┐                    _lang
 │        │                      │
 │    ┌───┴──────────────┐       ├──────────────┐
 │    │                  │       │              │
 ▼    ▼                  ▼       ▼              ▼
_item  _page           _glossary  _user ─── _session
                            │       │
                            │       ├── _profil
                            │       │
                            ▼       ▼
                          _access ──┤
                                    │
                              _request

Optional module tables:
  _audit    (module audit) — write log
  _fts      (module search) — FTS5 index
  _stats_*  (module stats) — access statistics
```

### Core tables (12)

| Table | Role |
|-------|------|
| `_list` | Item group identifier |
| `_item` | Key/value configuration (template, CSS, queries, title…) |
| `_page` | URL × profile → list_id routing |
| `_lang` | Available languages (fr, en) |
| `_profil` | User profiles (0=owner, 9999=anonymous) |
| `_user` | User accounts (email, PBKDF2 password, profile) |
| `_session` | Login sessions + ghost session id='0' |
| `_request` | Allowed operations (select, insert, update, update-self, delete, delete-self) |
| `_access` | ACL matrix: profile × table × operation |
| `_glossary` | i18n texts scoped by list_id |
| `_config` | Key/value runtime settings |
| `_user_token` | Verify/reset tokens (module auth) |

### Optional module tables

| Table | Module | Content |
|-------|--------|---------|
| `_audit` | audit | INSERT/UPDATE/DELETE log with old_values/new_values JSON |
| `_fts` | search | FTS5 virtual table indexing glossary + items |
| `_stats_*` | stats | Page view counters |
| `_api_key` | apikey | Bearer tokens for M2M access |

## The Ghost Session

Session `id='0'` is permanent: `INSERT INTO _session VALUES ('0', 'anonymous', 9999999999)`.
- No cookie → `getSession()` returns `{id: 0}` → anonymous profile 9999
- `issued=9999999999` (year 2286) → never filtered by TTL

## Dynamic Queries — `_item.queries`

Pages can define parameterized SQL queries in `_item` (key = `queries`). The value is a **JSON template** with `${expr}` or `${expr:type}` placeholders, resolved at request time via a sandboxed VM.

### Template Format

```json
{"QueryName": {
  "request": "SELECT * FROM t WHERE col IN (${req.query.filter:text})",
  "values":  ["${lang}", ${req.query.limit:number}]
}}
```

Each key becomes a query executed via `db.all(request, values, callback)`.

### Substitution Syntax

| Syntax | Behavior |
|--------|----------|
| `${expr}` | Evaluates `expr` in VM sandbox, injects result |
| `${expr:number}` | Forces `parseFloat()`, rejects NaN |
| `${expr:identifier}` | Validates against `/^[a-zA-Z0-9_]+$/` (table/column names) |
| `${expr:text}` | Forces `String()`, escapes `"` and `\` for JSON safety |

### Two Injection Contexts

1. **JSON context**: values are injected into a JSON string before `JSON.parse()`. Characters `"` and `\` are escaped. Objects and functions are rejected (security barrier).
2. **SQL context**: after `JSON.parse()`, `request` is executed by `db.all()`. `values` are passed as bound parameters (`?`) — immune to classical SQL injection.

### Developer Rules

- **Always use a type** (`:number`, `:identifier`, `:text`) for values coming from `req.query` or `req.body`. The type enforces strict conversion before injection.
- **Never** concatenate a `${...}` directly into `request` without `:identifier` if it's a table or column name. `:identifier` validates the value.
- **Values are bound** (`?`): a string containing `'; DROP--` is harmless. Do NOT bypass this by concatenating user values directly into `request`.
- An untyped expression returning an object or function is **rejected** (logged as ERROR, replaced with `null`).
- Maximum expression length: **500 characters** (anti-DoS on the VM sandbox).

### Valid Expressions

```
${req.query.id:number}      → forces a number (NaN → error)
${req.query.table:identifier} → validates table name (regex)
${req.query.name:text}      → forces String, escapes " and \
${lang}                     → internal value (current language), safe
```

### Invalid Expression (rejected)

```
${req.query.raw}            → no type, object/function rejected
```


## ACL System

`_data.modify()` checks rights in two steps:
1. Session verification → 401 if absent/expired
2. `_access(profil, table, operation)` → 403 if denied

`-self` operations require an `email` column and filter automatically on the session email.

## Request Lifecycle

```
HTTP Request → cookieParser → json/urlencoded → static files → favicon
→ disablePageCache → setSecurityHeaders (CSP+nonce) → CSRFProtection
→ postRateLimit → Routes → serve()/modify() → Response
```

---

## Links

- [README](../README.md) — Project overview & quick start
- [API Reference](api.md) — Routes & modules
- [Modules](module.md) — Module creation guide
- [Deployment](deploiement.md) — Docker, PM2, reverse proxy
- [CHANGELOG](../CHANGELOG.md) — Full version history
- [WaTE Website](https://www.wate.fr) — Online demo & docs
