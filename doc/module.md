# WaTE Modules

## What is WaTE

WaTE (Web application Template Engine) is a lightweight web framework built on Express and SQLite. It provides:

- **Database-driven pages** — page structure, queries, and access control are defined in SQLite tables (`_page`, `_item`, `_access`)
- **Module system** — extensible via `--mod` (full API) and `--ejs` (restricted API) flags
- **Built-in admin** — CRUD UI, authentication, search, audit, and more via engine modules
- **VM sandbox** — dynamic SQL queries with `${expr:type}` syntax, evaluated in a secure context

## Getting Started

### CLI mode

```bash
node engine.js --db ./data/app.db --port 8080 --mod auth=3600,db,audit --name "My App"
```

### Library mode

```javascript
const wate = require('wate-engine')
wate.init({
  db: './data/app.db',
  port: 8080,
  mod: ['auth=3600', 'db', 'audit'],
  name: 'My App'
}).then(({ app, db, server, close }) => {
  console.log('WaTE started')
})
```

## Module System

### Syntax

Both `--mod` and `--ejs` use the same unified syntax:

```
name[:alias][=param]
```

| Example | Meaning |
|---------|---------|
| `auth=3600` | Load `auth`, pass param `3600` (TTL in seconds) |
| `db` | Load `db`, no alias, no param |
| `mail:smtp={"host":"smtp.example.com"}` | Load `mail` as alias `smtp`, pass JSON param |

Multiple modules are comma-separated:
```
--mod auth=3600,db,audit,mail:smtp={"host":"smtp.example.com"}
```

### Engine modules vs. Application modules

**Engine modules** (built-in names: `auth`, `db`, `stats`, `log`, `utils`, `mail`, `audit`, `search`, `apikey`, `cron`) are resolved from `__dirname/_name` (i.e., `_auth.js`, `_db.js`, etc. inside the engine directory).

**Application modules** are resolved from `<appPath>/scripts/<name>`. For example, `--mod mymodule` looks for `<app-root>/scripts/mymodule.js`.

Module names are validated against `/^[a-zA-Z0-9_-]+$/`. Path traversal (`/`, `\`, `..`) is rejected.

### `--mod` vs `--ejs`

| Flag | API scope | Purpose |
|------|-----------|---------|
| `--mod` | Full `_WATE_API` | Application modules with DB access, hooks, rendering |
| `--ejs` | Restricted `{ log, app }` | EJS helper modules (template functions, read-only utilities) |

### Module lifecycle

1. **Loading** — `_modules.load()` parses the input string, resolves each module path, and `require()`s it
2. **Initialization** — If the module exports `init(param, api)`, it's called. Async init (returns Promise) is supported with a 10-second timeout
3. **Runtime** — The module has access to `api` and can register routes, hooks, middleware
4. **Shutdown** — On `close()`, `module.done()` is called for each loaded module if exported

## The `_WATE_API` Interface

Passed as the second argument to `module.init(param, api)`. For `--ejs` modules, only `{ log, app }` is exposed.

### `api.app`

The shared Express application instance. Key properties:

```javascript
api.app.locals.tableHooks    // table write hook registry
api.app.locals.jsHandlers    // client-side JS handlers
api.app.locals.SESSION_TTL_S // session TTL in seconds
```

Use `api.app` to register custom routes, middleware, or static file handlers.

### `api.log`

Structured logger:

```javascript
api.log.INFO('Server started')
api.log.WARN('Rate limit approaching')
api.log.ERROR('Database connection failed')
```

### `api.db`

Parameterized database access (wraps `sqlite3`):

```javascript
// Write
api.db.run('INSERT INTO users (email, name) VALUES (?, ?)', [email, name], (err) => { ... })

// Read all rows
api.db.all('SELECT * FROM users WHERE active = ?', [1], (err, rows) => { ... })

// Read single row
api.db.get('SELECT * FROM users WHERE email = ?', [email], (err, row) => { ... })
```

All values are parameterized via `?` placeholders — safe from SQL injection.

### `api.renderPage(req, res, targetUrl?, extraData?)`

Forces a database-driven page render using the standard `serve()` pipeline.

```javascript
api.app.get('/custom-page', (req, res) => {
  api.renderPage(req, res)                                    // uses req.path
  api.renderPage(req, res, '/admin/dashboard')                // explicit URL
  api.renderPage(req, res, '/admin/dashboard', { key: 'extra', value: { ... } })
})
```

### `api.renderError(req, res, code, msg, nextUrl?)`

Renders a standard error page:

```javascript
api.renderError(req, res, 404, 'Item not found')
api.renderError(req, res, 403, 'Access denied', '/signin')
```

### `api.hooks`

#### `api.hooks.onPageLoad(name, callback)`

Injects data before EJS render. The `name` must match `elements.HOOK` from the `_item` definition.

```javascript
api.hooks.onPageLoad('MY_PROVIDER', (req, elements) => {
  // Fetch external data and return { key, value }
  return fetchExternalData(req).then(data => ({ key: 'external', value: data }))
})
```

#### `api.hooks.onTableWrite(tableName, action, callback)`

Intercepts database writes. `action` is one of `'insert'`, `'update'`, `'delete'`, `'update-self'`, `'delete-self'`.

```javascript
api.hooks.onTableWrite('orders', 'insert', (req, next) => {
  // Add computed fields
  req.body.created_at = new Date().toISOString()
  req.body.created_by = req.session?.email

  // Call next() to proceed, or next(err) to abort
  next()
})
```

The callback receives `(req, next)`:
- Modify `req.body` before calling `next()` — changes are applied to the SQL write
- Call `next(err)` to abort the write with an error

### `api.executeAction(action, params)`

Executes a whitelisted action. Returns `Promise`.

### `api.getTableWriteHook(table, action)`

Returns the currently registered hook, if any. Used for chaining:

```javascript
const existing = api.getTableWriteHook('orders', 'insert')
api.hooks.onTableWrite('orders', 'insert', (req, next) => {
  // Custom logic first
  req.body.audited = true
  // Chain to the existing hook
  if (existing) {
    existing(req, (err, onSuccess) => next(err, onSuccess))
  } else {
    next()
  }
})
```

## Creating an Application Module

### Minimal module

```javascript
// scripts/my-module.js
module.exports = {
  init(param, api) {
    api.log.INFO('my-module initialized with param: ' + param)

    // Register a custom route
    api.app.get('/api/custom', (req, res) => {
      res.json({ ok: true, module: 'my-module' })
    })
  },

  done() {
    // Cleanup: close connections, clear intervals, etc.
  }
}
```

### Module with async init

```javascript
// scripts/data-sync.js
module.exports = {
  async init(config, api) {
    api.log.INFO('data-sync: connecting to external API...')

    // Async setup (must complete within 10 seconds)
    const client = await createExternalClient(config)

    // Register a route that uses the client
    api.app.get('/api/sync-status', async (req, res) => {
      const status = await client.getStatus()
      res.json(status)
    })

    // Store cleanup reference
    this._client = client
  },

  async done() {
    if (this._client) {
      await this._client.disconnect()
    }
  }
}
```

### Module with table hooks

```javascript
// scripts/order-audit.js
module.exports = {
  init(param, api) {
    // Log every order creation
    api.hooks.onTableWrite('orders', 'insert', (req, next) => {
      api.log.INFO('New order being created by: ' + req.session?.email)
      req.body.audit_trail = JSON.stringify({
        created: new Date().toISOString(),
        ip: req.ip
      })
      next()
    })

    // Validate before update
    api.hooks.onTableWrite('orders', 'update', (req, next) => {
      if (req.body.status === 'cancelled' && !req.body.cancel_reason) {
        return next(new Error('Cancel reason required'))
      }
      next()
    })
  }
}
```

### Module with page load hooks

```javascript
// scripts/weather-widget.js
module.exports = {
  init(param, api) {
    api.hooks.onPageLoad('WEATHER', async (req, elements) => {
      const city = elements.city || 'Paris'
      try {
        const data = await fetchWeather(city)
        return { key: 'weather', value: data }
      } catch (err) {
        api.log.ERROR('Weather fetch failed: ' + err.message)
        return { key: 'weather', value: { error: 'Unavailable' } }
      }
    })
  }
}
```

In the database (`_item`), set `HOOK` to `WEATHER` on the page where the widget should appear.

## Creating an EJS Helper Module

EJS modules receive a restricted API with only `log` and `app`. They export functions usable in EJS templates via the `EJSs` variable.

```javascript
// scripts/fs-tools.js
const fs = require('fs')
const path = require('path')

module.exports = {
  init(param, api) {
    api.log.INFO('fs-tools loaded')
  },

  // Callable from EJS: EJSs['fs-tools'].readdirSync(dir)
  readdirSync(dir) {
    return fs.readdirSync(dir)
  },

  readFileSync(filePath) {
    return fs.readFileSync(filePath, 'utf8')
  }
}
```

In EJS templates:
```ejs
<% const files = EJSs['fs-tools'].readdirSync(path + 'data/') %>
```

## Security Rules for Modules

- **Always use parameterized queries** — `api.db.all('SELECT ... WHERE col = ?', [value], cb)`, never string concatenation
- **Validate module names** — already enforced by the engine (`/^[a-zA-Z0-9_-]+$/`, no path traversal)
- **Don't expose internals** — the `_WATE_API` facade intentionally hides `_core` and raw `db`. Use only the provided API
- **Respect the sandbox** — page queries run in a VM with `eval` and `Function` disabled. Don't try to bypass it by storing executable code in the database
- **Clean up in `done()`** — close network connections, clear intervals, release resources

## Loading Order

Modules are loaded and initialized in the order they appear in the `mod` / `ejs` array. This matters when modules depend on each other:

```javascript
mod: ['auth=3600', 'db', 'audit']  // auth first (sessions needed by db), audit last (wraps db hooks)
```

All `init()` calls (including async ones) must complete before the engine starts listening.

---

## Links

- [API Reference](api.md) — Full engine API
- [Architecture](architecture.md) — Engine internals
- [Deployment](deploiement.md) — Docker, PM2, reverse proxy
- [CHANGELOG](../CHANGELOG.md) — Version history
- [README](../README.md) — Project overview
