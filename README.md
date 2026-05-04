# WaTE (Web as Table Engine)

[![npm version](https://img.shields.io/npm/v/wate-engine.svg)](https://www.npmjs.com/package/wate-engine)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D4.6.1-green.svg)](https://nodejs.org/)
[![GitHub](https://img.shields.io/badge/GitHub-athoth--npm%2Fwate-engine-181717?logo=github)](https://github.com/athoth-npm/wate-engine)

**WaTE** is a high-performance, **Data-First** rendering and administration engine. It lets you instantly generate professional back-office interfaces and CRUD APIs directly from a simple SQLite schema — with zero boilerplate.

---

## 🚀 Quick Start

### Installation

```bash
npm install wate-engine
```

### 1. CLI Mode

Perfect for micro-services, local tools, or rapid prototyping. WaTE serves your database immediately with zero code:

```bash
node engine.js --port 8080 --db ./my-database.db --mod auth,db
```

### 2. Library Mode

Integrate WaTE as a core component within your own Node.js application:

```javascript
const wate = require('wate-engine');

wate.init({
    port: 8080,
    db: './data/app.db',
    mod: ['auth', 'db'],
    name: 'My Enterprise Admin'
}).then(({ app, db, server }) => {
    console.log('WaTE engine is up and running.');
}).catch(err => {
    console.error('Startup error:', err);
});
```

---

## 🏗 Philosophy: The "Lean" Architecture

WaTE is built on a **Data-Driven UI** paradigm. Unlike traditional frameworks requiring complex ORMs and redundant boilerplate, WaTE maps your SQL structure directly to dynamic Web Components.

- **No ORM** — Direct, transparent, and high-performance SQL usage.
- **No SPA Overhead** — A Multi-Page / Multi-Component architecture for instant loading, high reliability, and zero technical debt.
- **AI-Ready** — A flat and predictable architecture (Core / Data / Auth) perfectly suited for generation and management by AI agents.
- **Standards-Based** — Relies on native JS, CSS, and SQL to keep your application maintainable for decades.

---

## ⚙️ Core Concepts

WaTE uses internal technical tables (prefixed with `_`) to drive the entire system:

| Table | Role |
|---|---|
| `_item` | The heart of the engine — defines UI components, SQL queries, themes, and JS handlers. |
| `_page` | Handles routing by linking URLs to specific items or logic. |
| `_access` | Manages granular permissions (ACL) per user profile. |

**`tableHooks`** — A robust middleware system that lets you intercept database writes (Insert / Update) for business logic, data validation, or security (e.g. password hashing), without ever modifying the core engine.

---

## 📂 Internal Structure

| File | Description |
|---|---|
| `engine.js` | Main entry point and server orchestration. |
| `_core.js` | Central registry and State Manager (replaces global variables). |
| `_data.js` | High-performance data access layer (read & write). |
| `_auth.js` | Security module (session management, PBKDF2). |
| `_db.js` | Automated CRUD API and form routes. |
| `_migration.js` | Automated SQL schema versioning and maintenance. |
| `_modules.js` | Application module loader. |
| `_mail.js` | Mailing for account validation, forgot password, and reset flows. |
| `_audit.js` | Write audit log + undo last write (optional, `--mod audit`). |
| `_search.js` | Full-text search via FTS5 (optional, `--mod search`). |
| `_apikey.js` | API keys for machine-to-machine access (optional, `--mod apikey`). |
| `_cron.js` | Periodic maintenance tasks (optional, `--mod cron`). |
| `_stats.js` | Cache and DB call statistics. |
| `_utils.js` | Common engine utilities. |

---

## 🛠 Advanced Customization

You can extend WaTE by creating your own **Web Components** and registering them in the `_item` table. Using `custom.js` on the client side, you can transform raw data into rich UI elements such as image galleries, audio players, or interactive charts.

---

## 🔗 Links

- 🌐 Website: [https://www.wate.fr](https://www.wate.fr)
- 📦 NPM: [https://www.npmjs.com/package/wate-engine](https://www.npmjs.com/package/wate-engine)
- 🐙 GitHub: [https://github.com/athoth-npm/wate-engine](https://github.com/athoth-npm/wate-engine)
- 📝 Changelog: [CHANGELOG.md](CHANGELOG.md) ([fr](CHANGELOG.fr.md))
- 📖 Architecture: [doc/architecture.md](doc/architecture.md) ([fr](doc/architecture.fr.md))
- 🔌 API Reference: [doc/api.md](doc/api.md) ([fr](doc/api.fr.md))
- 🧩 Module Guide: [doc/module.md](doc/module.md) ([fr](doc/module.fr.md))
- 🚀 Deployment: [doc/deploiement.md](doc/deploiement.md) ([fr](doc/deploiement.fr.md))

---

## 📄 License

Distributed under the [MIT License](https://opensource.org/licenses/MIT).  
Copyright © 2023–2026 WATE Team.