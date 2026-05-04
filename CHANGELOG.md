# CHANGELOG — WaTE Engine

All notable changes to this project are documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioned with [SemVer](https://semver.org/).

---

## [v3.19.5] — 2026-05-04

### Added — Documentation (EN/FR)
- `doc/module.md` / `doc/module.fr.md` — Module creation guide: `_WATE_API` interface, `init()`/`done()`, hooks, `--mod`/`--ejs` syntax, full examples.
- `doc/api.md` / `doc/api.fr.md` — Expanded `init()` options table. New sections: `serve()`, `modify()`, `_WATE_API`, module system.
- `doc/architecture.md` / `doc/architecture.fr.md` — Added `_modules.js` to core table. Cross-links to module docs.
- Web `/docs` page — 3 new subsections (7.5 Interface `_WATE_API`, 7.6 Creating a module, 7.7 Core functions `serve()`/`modify()`).
- Web `/docs` — HTML formatting: `<code>` (inline monospace), `<pre>` (dark blocks), `<ul>`/`<ol>` (bullets/numbers) across sections 4, 7, 11, 12, 13.

### Changed — Source documentation
- `engine.js init()` — JSDoc with all options, return value, example.
- `_data.js serve()` — Full JSDoc (pipeline, params, errors, changelog).
- `_data.js modify()` — Full JSDoc (validation chain, params, `-self` operations).
- `_modules.js _WATE_API` — `@typedef` with all 9 properties documented.
- `_modules.js load()` — Full JSDoc (params, validation, lifecycle, timeout).

### Added — CI/CD
- `.github/workflows/ci.yml` — Push/PR on main: Node 18/20/22 matrix, install, audit, test suite.
- `.github/workflows/release.yml` — Tag `v*` push: test suite, auto GitHub Release with CHANGELOG body.

### Changed — Versioning
- `package.json` version 3.19.5 (source of truth).
- `engine.js` header and footer aligned to `package.json` (v3.19.5).

### Fixed — Logs RUN
- `_data.js modify()` — LEAVE on all 10+ error paths (table invalid, session, access, DB errors, PK missing, no values).
- `_db.js _reduceImageSize()` — LEAVE in `.then()` and `.catch()`.
- `_audit.js init()` — LEAVE on DB error.
- `_search.js` — LEAVE on `/admin/api/search` and `/api/search` routes.
- `_data.js serve()` — LEAVE moved inside async callback (was synchronous before render).
- `_auth.js` — LEAVE in verify/resend callback.

### Fixed — Security
- `_auth.js signup` — Column whitelist prevents mass assignment (`profil_id`, `verified`).
- `_auth.js` — Password max length 1024 chars (anti-DoS PBKDF2).
- `_auth.js _mail()` — Returns inert `{isAvailable:false}` instead of `undefined` when mail not loaded.
- `_db.js` — `Object.prototype.hasOwnProperty.call()` on `req.body` and form route.
- `_db.js` — `_RE_TABLE` validation on form route (was missing, unlike API routes).
- `_data.js` — `__proto__`/`constructor` filtered in `result[q]` and `elements[item.key]`.
- `_data.js` — `hasOwnProperty.call` on `req.body[colName]` prevents Object.prototype read.
- `engine.js` — CookieParser with secret (anti-hijacking).
- `engine.js` — `_RE_ROOT = /^\/(?!\/)/` blocks protocol-relative open redirect (`//evil.com`).
- `engine.js` — Rate limit bypass returns 429 (was `return next()`).
- `engine.js` — Block `.md`/`.db` files from static serving.
- `_modules.js` — `.catch()` on `Promise.race` prevents `load()` from hanging.
- `engine.js` — `.catch()` on `_close()` `Promise.race` prevents hang on shutdown.
- `web/scripts/demo.js` — Random session IDs (was predictable). CSRF validation + secure cookie.
- `web/app.js` — DB moved to `data/site.db` (was in public static folder).
- `custom/custom.js` — `hasOwnProperty` + skip `__proto__` in `_restoreFormValues`.
- `web/scripts/site-menu.js` — `hasOwnProperty` on all `for...in` + `encodeURIComponent`.
- `custom/custom.js` — Escape `"` in CSS selector (`admin-list[name="..."]`).
- `views/*.ejs` — Nonce conditional everywhere (was `nonce="undefined"` on some pages).
- `views/common.ejs` — Template include validated (`/^[a-zA-Z0-9_-]+$/`).

### Fixed — Rate limiting
- `engine.js` — Bucket per IP+prefix isolates `/signin` from `/forgot`.
- `_auth.js` — Password length limit mitigates PBKDF2 DoS.

### Fixed — Promises & robustness
- `_data.js serve()` — Generic error message (no SQL leak to client).
- `_migration.js` — Triggers recreated with `return` (was fire-and-forget).
- `engine.js` — `clearInterval` in `server.on('error')` (was timer leak).
- `engine.js` — `!isNaN(argv.log)` prevents silent logging with `--log abc`.
- `engine.js` — `err.message || String(err)` for string errors.
- `_mail.js` — Close old transporter on double `init()`.
- `_search.js` — `r.contains(e.target)` on click (was preventing link navigation).
- `custom/custom.js` — `try-catch` global on `_connectedCallback`.
- `custom/admin-row/def.js` + `schema-table/def.js` — `JSON.parse` with `try-catch`.
- `custom/admin-row/def.js` — `window.wateModal` guard + `composed:true` on CustomEvent.
- `custom/modal-popup/def.js` — Focus restored after close. `setTimeout` cancelable.
- `scripts/admin-stats.js` — `AbortError` suppressed on double-click. AbortController.
- `scripts/search.js` + `views/search.ejs` — AbortController cancels previous fetch.
- `scripts/admin-db.js` — Content-Type check before `res.json()`.
- `web/scripts/demo.js` — Cookie sent AFTER DB callback confirms INSERT.
- `web/views/site-ai.ejs` + `demo-code-block/def.js` — `.catch()` on `clipboard.writeText()`.
- `web/migrations/004_demo_seed.sql` — `DELETE _audit` on reset (was accumulating).
- `web/app.js` — WAL/SHM cleaned with DB file.

### Fixed — CSS & layout
- `css/common.css` v2.5.3 — Uses `--wate-*` variables. `box-sizing: border-box`. `--wate-error`.
- `css/admin-auth.css` v1.5.2 — Dead comment removed. `p.error` → `var(--wate-error)`.
- `custom/admin-row/def.css` v1.5.1 — `p.error` → `var(--wate-error)`.
- `custom/modal-popup/def.css` v1.3.3 — `.icon` uses `background-image` via `--mp-icon-src`.
- `web/css/common.css` v1.5.2 — Duplicate `--wate-orange` removed. Modal about logo via `--mp-icon-src`.
- `web/css/admin-db.css` v1.2.1 — `10pt` → `0.833rem`. `max-height` → `80vh`.
- `web/css/docs.css` v1.4.1 — `scroll-margin-top` → `5em`.
- `web/custom/wate-mcd/def.css` v2.2.3 — Grid slot fix (equal columns). Stale comment fixed.
- `web/custom/wate-mcd/def.js` — Slot is grid container (slotted elements become grid items).
- `custom/modal-popup/def.css` — Dead `.body a` CSS removed.

### Fixed — Accessibility
- `custom/modal-popup/def.js` — Focus trapping Tab/Shift+Tab.
- `custom/show-image/def.js` — Arrows focusable (Enter/Space). `aria-label`. `alt=""`.
- `custom/icon-menu/def.js` — `aria-expanded`/`aria-haspopup`. Escape closes dropdown.
- `custom/schema-table/def.js` — Emoji `aria-hidden="true"`.
- `web/custom/wate-card/def.js` — SVG icons `aria-hidden="true"`.
- `web/views/common.ejs` — Search input `aria-label`.
- `web/views/site-examples.ejs` — HTML attributes quoted.

### Fixed — Performance
- `_log.js` — `isTTY` cached at module level.
- Regexes moved to module level in `engine.js`, `custom.js`, `icon-menu/def.js`, `search.js`, `admin-stats.js`, `views/search.ejs`.
- `scripts/admin-db.js` — `_fkCacheGlobal` shared across all row builds (was per-row).

### Added
- `test/test-content.sh` — 90+ structural/CSS/JS/i18n assertions + JS sanity checks.
- `CHANGELOG.md` (EN) + `CHANGELOG.fr.md` (FR) — Full project history.
- `DockerFile` — Healthcheck, non-root user, strict-ssl removed.
- `docker-compose.yml` — Volume directory (WAL safe), CSRF secret env var.

### Changed
- `package.json` — All dependencies use `^` (standard SemVer).
- `_data.js` — `unregisterPageLoadHook` added (cleanup between `init()` calls).
- `web/views/common.ejs` — About modal unified with admin (`about-version`, `about-copy`, `about-intro`).
- See also [v3.19.3] below.

---

## [v3.19.3] — 2026-05-03

### Fixed
- Admin layout restored: background `#001633`, font family, vertical centering (lost when `@import error.css` removed).
- Scrollbar on admin pages (`margin: 0` on body).
- Signout button gap (`.nav-info` selector fixed, added `margin-top`).
- Vitrine about modal: logo now uses `--mp-icon-src` CSS variable (dark logo on light background, white logo on dark).
- Escaped `<strong>` tags in about modal (`<%=` → `<%-` for `site-about-product`).

### Changed
- `css/common.css` v2.5.3: uses its own `--wate-*` variables throughout, added `box-sizing: border-box`, new `--wate-error`.
- `css/admin-auth.css` v1.5.2: dead comment removed, `p.error` uses `var(--wate-error)`.
- `custom/admin-row/def.css` v1.5.1: `p.error` uses `var(--wate-error)`.
- `custom/modal-popup/def.css` v1.3.3: `.icon` uses `background-image` via `--mp-icon-src`, removed `<img>` from shadow DOM.
- `web/css/common.css` v1.5.2: duplicate `--wate-orange`/`--wate-orange-dk` removed.
- `web/css/admin-db.css` v1.2.1: `10pt` → `0.833rem`, `max-height: 680px` → `80vh`.
- `web/css/docs.css` v1.4.1: `scroll-margin-top: 80px` → `5em`.
- `web/custom/wate-mcd/def.css` v2.2.3: stale grid comment fixed.
- CSS conventions documented (`rem`/`em`/`px` usage).

### Added
- `CHANGELOG.md` (EN) + `CHANGELOG.fr.md` (FR): full project history (v1.5.0 → v3.19.3).
- `test/test-content.sh`: 68 structural/i18n/CSS/JS assertions for admin + vitrine pages.

---

## [v3.19.2] — 2026-05-03

### Fixed
- `_core.js` — `LEAVE dbRequest()` moved inside the async callback (was synchronous before SQL execution).
- `_data.js` — Cache key `substring(0,50)` on `req.query.table` (LRU pollution prevention).
- `_log.js` — `isTTY` cached at module level (avoids property access on every `print()`).
- `css/admin-auth.css` — Header version synced with footer (1.5.0 → 1.5.1).
- `custom/icon-menu/def.js` — `margin:20px` → `1.25rem` (responsive). `alt` added to `<img>` (accessibility).
- `scripts/admin-db.js` — Remaining `function()` callbacks → arrow functions.

### Accepted (documented limitations)
- `_audit.js` — TOCTOU in audit capture (mitigated by SQLite single-writer).
- `engine.js` — `donePromises` ignored after 5s timeout (intentional, prevents hanging shutdown).
- `_auth.js` — Account created even if `_sendTokenMail` fails (design: user can request resend).
- `_mail.js` — Module-level variables prevent multi-instance (rare case).
- `custom/modal-popup/def.js` — `innerHTML` without validation (trusted callers API only).
- `_db.js` — Filter parsing broken if value contains `,` or `:` (admin-only, edge case).
- `_utils.js` — `require('./_core')` in `glossaryItem()` on every call (circular dependency avoided).

---

## [v3.19.1] — 2026-05-02

### Fixed
- **#6** `scripts/search.js` + `views/search.ejs` — XSS via `javascript:` protocol blocked by `safeUrl()`.
- **#7** `engine.js` — `NaN` no longer passes port validation (`isNaN` check).
- **#8** `_utils.js` — `String()` protects `req.query.lang` against Express/qs arrays.
- **#9** `_modules.js` — Path traversal `..` blocked in module names.
- **#10** `_modules.js` — `Object.prototype.hasOwnProperty.call()` secures property access.
- **#11** `_migration.js` — Trigger failure → FATAL log, no longer rejects migration.
- **#12-13** `scripts/admin-stats.js` — Null-checks added for `getElementById` in catch block and `btn-refresh`.
- **#14** `scripts/admin-db.js` — `{once:true}` on `admin-row:done` listener (prevents stacking).
- **#15** `custom/admin-row/def.js` — `textarea` rendered correctly (dedicated type).
- **#16** `_db.js` — Mass assignment `file.fieldname` guarded.
- **#17** `_search.js` — Public `/api/search` route with default `scopeSQL` (public content only).
- **#18** `scripts/admin-auth.js` — `X-CSRF-Token` added to `adminSignout()` API.

### Changed
- Docs: `_data.js`, `architecture.md`, `architecture.fr.md`, `site-docs.ejs`.
- Harmonization: "Web as Table Engine" everywhere, CLI `node engine.js`.

---

## [v3.19.0] — 2026-05-02

### Fixed
- **#1** `_data.js` — SQL injection via `${...}` in JSON queries (JSON-escaped values, objects/functions rejected).
- **#2** `views/common.ejs` — XSS `</script>` in `JSON.stringify` (`.replace(/\//g, '\\/')`).
- **#3** `engine.js` — Rate limiter: inline eviction >10000 IPs instead of bypass. `_postRateCount` counter.
- **#4** `engine.js` — `PRAGMA foreign_keys`: `reject()` instead of FATAL log only (startup blocked if FK inactive).
- **#5** `_data.js` — VM sandbox: `resolveParams` rejects objects and functions (anti-sandbox-escape barrier Node < 10).

---

## [v3.18.0] — 2026-05-01

### Fixed
- Engine: `_close()` try-catch, `argv.name` sanitized.
- XSS: snippet escaped in `search.js` + `search.ejs`, `</script>` neutralized in `admin-db.ejs`, `esc()` unified.
- `_data.js`: `req.body` mutation eliminated, `urls.find()` deduplicated.
- `_log.js`: ANSI conditioned on `process.stdout.isTTY`.
- `_apikey.js`: prefix SELECT, `req.cookies` guard.
- `_auth.js`: verify-invalid, adaptive dummy hash, var→const, callback arrow, LEAVE in callback.
- `_modules.js`: regex backtracking fix.
- `_cron.js`: constant `PURGE_TOKENS_S`.
- `custom/admin-row`: `_collectBody` textarea/checkbox/radio, column width resize.
- `custom/show-image`: `isConnected`.
- `admin-auth.ejs`: `_RE_MSG` uppercase.
- `scripts/admin-stats`: null-check `getElementById`.

---

## [v3.17.2] — 2026-04-30

### Fixed
- `_core.js`: `\p{L}` → `\w` (Node 4.6.1 compatibility).
- `custom.js`: `const`→`let` reassigned attr.
- `show-image/def.js`: 2 missing `const`→`let`.
- `engine.js`: `--root` validated, `argv.path` null guard.
- `csrf.js`: Safari-compatible selector.
- `_data.js`: PK falsy (0, "", false), `resolveParams` JSON.stringify, `done()` try-catch.
- `_auth.js`: `verified` NULL-safe, named INSERT columns, signin rate limit 10/min/IP.
- `_apikey.js`: session ORDER BY, named INSERT columns.
- `_audit.js`: PK "" → null fix.
- `_migration.js`: triggers after failure, async init.
- `_modules.js`: `init()` async support + timeout.
- Shutdown/close: 5s timeout, try-catch `done()`.

### Added
- `POST /admin/api/auth/verify/resend` + form.
- `verify-resend*` glossary entries.
- Express error middleware (catches exceptions without leaking stack trace).
- `DELETE`/`UPDATE` without PK → blocks with 400.
- `_migration.js` — `_core.log.WARN` → `WARNING`.

---

## [v3.16.1] — 2026-04-29

### Fixed
- `_apikey.js` — `key.length < 70` → `!== 69`. LIKE injection prefix DELETE. Regex validation.
- `common.ejs` + `engine.js` — `for...in` → `Object.keys().forEach()`. `encodeURIComponent()` on query params.
- `icon-menu/def.js` — `innerHTML` → `textContent` (anti-XSS).
- `error.ejs` — `<%-` → `<%=` glossaryItem.
- `_db.js` — `csvEscape` `'` prefix for CSV formula injection prevention.
- `_audit.js` — SQL first, audit after (prevents orphan `_audit` entries).
- `_data.js` — `unregisterTableWriteHook` + cleanup in `_audit.done()`.
- `_cron.js` — Double `init()` safe (`done()` before creating new timers).
- `_stats.js` — `for...in` → `Object.keys`.
- `session.id` type consistency (string `'0'` everywhere).
- `_shutdown`/`_close` handle async `done()` (Promise collection, `Promise.all()`).
- `_migration.js` — DROP TRIGGER errors logged.
- `_core.js` — `dbRequest` callback wrapped in try-catch.

### Changed
- Code cleanup: `_RE_TABLE` unified, `boundedCache.get()` single lookup, `_SQLS` module-level, `_search.js` scope/minList, `_postRateBuckets` >10000 IPs guard, FTS5 `-` filtered, `_modules.js` restricted API for `--ejs`.

---

## [v3.16.0] — 2026-04-28

### Added
- **Undo** — `POST /admin/api/db/:table/undo` reverts the last write. Owner can revert any write with `?all=true`.

---

## [v3.15.1] — 2026-04-27

### Added
- Sort/search/filter on CRUD API (`?sort=`, `?search=`, `?filter=`).
- CSV/JSON export (`?format=csv`).
- Modules: `audit` (write journal), `search` (FTS5), `apikey` (Bearer tokens), `cron` (periodic purges).
- Health check `GET /health`.
- `getTableWriteHook` exposed.
- `executeAction` whitelist.

### Fixed
- Comments and async LEAVE.

---

## [v3.12.2] — 2026-04-26

### Added
- **Hardened CSRF** — Token = `SHA256(sessionId + secret)`. Random secret on every restart (auto-rotation). Overridable via `WATE_CSRF_SECRET`.

---

## [v3.12.1] — 2026-04-25

### Added
- `_user.verified` + `_user_token` (verify/forgot/reset flows).
- Custom element `modal-popup` (replaces native `alert()`/`confirm()`).

### Changed
- Migration `var` → `const`/`let`.

---

## [v3.12.0] — 2026-04-24

### Added
- Mail module (`_mail.js`, graceful degradation via optional nodemailer ≥2.3.2).
- Migration `004_mail.sql`.

### Changed
- `engine.js` version aligned with `package.json` (public source of truth).

---

## [v3.11.0] — 2026-04-23

### Changed
- `dbRequest` defined in `_core.js`, setter for private `_core_db` injection.

---

## [v3.10.1] — 2026-04-22

### Fixed
- `_config` read after migration — hydrates `_core.config` and resizes LRU caches.

---

## [v3.10.0] — 2026-04-21

### Changed
- **Architectural restructuring** — Single Responsibility.
- Migration engine extracted to `_migration.js`.
- Module loader extracted to `_modules.js` (Promise `load`).
- 100% async initialization flow via Promises.
- Deferred CSP variable hydration (Closure pattern).

---

## [v3.9.0] — 2026-04-20

### Added
- **SQL migration engine** — sequential execution of unapplied `.sql` files.

---

## [v3.8.0] — 2026-04-19

### Added
- **CSRF middleware** — token required on all mutating requests (POST/PUT/DELETE).

---

## [v3.7.1] — 2026-04-18

### Fixed
- Static regexes evaluated once (`test()` instead of `match()`).
- IP rate-limit: only remove IPs inactive for 60s.

---

## [v3.7.0] — 2026-04-17

### Changed
- `serve()` (ex-`pageData`) + `buildSelectSQL` + `_queriesCache` + `vm` migrated to `_data.js`.
- `jsHandlers` moved to `app.locals` (per-instance).
- `views/common.ejs`: master template — unified layout.

---

## [v3.6.0] — 2026-04-16

### Changed
- `adminSession`, `tableHooks`, `SESSION_TTL_S` initialized in `app.locals` (per-instance state isolated from `_core` singleton).

---

## [v3.4.0] — 2026-04-15

### Changed
- `loadModules` — unified syntax `name[:alias][=param]` for `--mod` and `--ejs`.
- Automatic `module.init(param)` and `module.done()` calls.
- Engine modules renamed `_auth.js`/`_db.js`.
- `_core.EJSs` added.

---

## [v3.3.0] — 2026-04-14

### Changed
- `modifyTable`, `reduceImageSize`, `upload`, `_tableInfoCache` moved to `_db.js`.
- `multer` and `jimp` removed from `engine.js`.

---

## [v3.2.0] — 2026-04-13

### Added
- **Optional engine modules** — auth and db extracted to `scripts/`.
- Loading via `init({ mod: [...] })` or `--mod name=param,...`.

---

## [v3.1.2] — 2026-04-12

### Fixed
- `pageData` — UNION Part 2 redesigned, expired session correctly detected.

---

## [v3.1.1] — 2026-04-11

### Added
- Option `init({ sessionTTL })` — takes priority over `--mod`, useful for tests.

---

## [v3.1.0] — 2026-04-10

### Added
- **Integrated administration** — JSON API + overridable EJS UI.
- UNIX profile convention: owner=0 (root), anonymous=9999.
- `_adminSession(req, res, cb)` — session verification middleware.
- JSON API routes: `POST /admin/api/auth/signin|signout`, `GET|PUT|DELETE /admin/api/auth/me`, `GET /admin/api/db/schema`, `GET|POST|PUT|DELETE /admin/api/db/:table`.
- EJS UI routes: `GET /admin/auth|me|db|db/:table`.
- `_adminHashPassword` — shared PBKDF2.

---

## [v3.0.0] — 2026-04-09

### Added
- **Library mode** — `module.exports = { init }`.
- `init(options)` returns `Promise<{app, db, server?, close}>`.
- `':memory:'` accepted as DB (tests).
- `_parseArgv()` extracted.

### Changed
- `process.exit()` replaced by `throw`/`reject()` in `init()`.
- `SIGTERM`/`SIGINT` only registered in CLI mode.

---

## [v2.15.2] — 2026-04-08

### Fixed
- Double `_glossaryCache.get(lang)` call avoided.
- DoS limit: 10 MB max, 5 files max for uploads.

---

## [v2.15.0] — 2026-04-07

### Changed
- LRU cache: `Map` ES6 implementation (O(1) eviction).

---

## [v2.14.0] — 2026-04-06

### Fixed
- `pageData`: UNION logic fixed (404/401 correctly discriminated).
- `_cspScriptSrcBase` actually used in `setSecurityHeaders`.
- `_core.app.listen`: startup errors caught via `server.on('error')`.
- Dead code removed after `return` in `reduceImageSize`.
- `sessionId` harmonized as string `'0'`.
- `delete req.body.email` moved after PK loop.

### Added
- `_boundedCache`: bounded LRU factory for `_glossaryCache`, `_queriesCache`, `_tableInfoCache`.
- Rate limiter: token bucket replaces fixed window.
- HSTS: `Strict-Transport-Security` in `setSecurityHeaders`.
- Doxygen: comments on all functions, variables and routes.

---

## [v2.13.4] — 2026-04-05

### Fixed
- Removed `_core.app.use(upload.array())` which was intercepting forms before the POST route.

---

## [v2.13.0] — 2026-04-04

### Changed
- UNION query to determine if a page exists AND if it exists for the user's profile.

### Fixed
- `request` column in `_access` renamed to `request_name`.
- Access right via `IN(request, baseRight)` instead of `LIKE`.

---

## [v2.12.2] — 2026-04-03

### Fixed
- Session validation via cookie presence + session object + ID.
- `eval()` and `Function()` neutralized in VM sandbox.
- Preventive table name parsing in `modifyTable`.

---

## [v2.12.0] — 2026-04-02

### Changed
- `reduceImageSize`: `image-size` removed, `image.bitmap` used directly.
- CSP: static part pre-computed at startup (`_cspStatic`).

### Fixed
- `pageData`: 401 if session expired, 404 if page missing.

---

## [v2.11.2] — 2026-04-01

### Fixed
- `A.request` → `A.request_name` in `modifyTable`.
- `lang` sanitization in `httpError`.
- Favicon path relative → absolute.
- SQLite triggers without callback → silent errors.
- Views directory order inverted.

---

## [v2.11.0] — 2026-03-31

### Added
- `res.headersSent` guard in `httpError`.
- Clean `SIGTERM`/`SIGINT` shutdown.
- 429 status code (POST rate limiting).
- Glossary cache per language.
- Integrated POST rate limiting (30 req/min/IP).

---

## Earlier versions (v1.5.0 — v2.10.3)

### Added
- PRAGMA `foreign_keys`, `journal_mode=WAL`, `busyTimeout`.
- Centralized `SESSION_TTL_S`.
- Static routes `engine/custom/`, `engine/images/`, `engine/css/`.
- `minimist` for CLI parsing.
- TCP port validation (1-65535).
- `trust proxy` for HTTPS reverse proxy.

### Fixed
- `httpError` 401 → `next='signin'`.
- Render errors intercepted.
- Debug `console.log` removed.
- `buildSelectSQL()` extracted.

### Changed
- `modifyTable` and `pageData` in `engine.js` (before migration to `_data.js`/`_db.js`).
- Express `views` accepts an array (engine + app).
---
