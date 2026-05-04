# WaTE (Web as Table Engine)

[![npm version](https://img.shields.io/npm/v/wate-engine.svg)](https://www.npmjs.com/package/wate-engine)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Node.js](https://img.shields.io/badge/Node.js-%3E%3D4.6.1-green.svg)](https://nodejs.org/)
[![GitHub](https://img.shields.io/badge/GitHub-athoth--npm%2Fwate-engine-181717?logo=github)](https://github.com/athoth-npm/wate-engine)

**WaTE** est un moteur d'administration et de rendu **Data-First** haute performance. Il génère instantanément des interfaces back-office et des API CRUD directement à partir d'un schéma SQLite — sans aucun boilerplate.

---

## Démarrage rapide

### Installation

```bash
npm install wate-engine
```

### Mode CLI

```bash
node engine.js --port 8080 --db ./ma-base.db --mod auth,db
```

### Mode Bibliothèque

```javascript
const wate = require('wate-engine');
wate.init({ port: 8080, db: './data/app.db', mod: ['auth', 'db'] })
  .then(({ app, db, server }) => console.log('WaTE démarré.'))
  .catch(err => console.error('Erreur:', err));
```

---

## Philosophie

WaTE est fondé sur un paradigme **Data-Driven UI**. Le schéma SQL pilote les Web Components, les routes, l'ACL et l'i18n. Pas d'ORM, pas de SPA, zéro boilerplate.

---

## Structure interne

| Fichier | Description |
|---|---|
| `engine.js` | Point d'entrée et orchestration du serveur |
| `_core.js` | Registre central et gestionnaire d'état |
| `_data.js` | Couche d'accès aux données (lecture et écriture) |
| `_auth.js` | Module de sécurité (sessions, PBKDF2) |
| `_db.js` | API CRUD, tri/filtre/recherche, export CSV/JSON |
| `_migration.js` | Versionnement automatisé du schéma SQL |
| `_modules.js` | Chargeur de modules applicatifs |
| `_mail.js` | Emails de validation et récupération |
| `_audit.js` | Journal d'audit des écritures + undo (`--mod audit`) |
| `_search.js` | Recherche plein texte FTS5 (`--mod search`) |
| `_apikey.js` | Clés d'API Bearer (`--mod apikey`) |
| `_cron.js` | Tâches de maintenance périodiques (`--mod cron`) |
| `_stats.js` | Statistiques d'accès et de cache |
| `_utils.js` | Utilitaires communs du moteur |

---

## Documentation technique

- [Architecture et concepts](doc/architecture.fr.md)
- [Référence API](doc/api.fr.md)
- [Guide de création de modules](doc/module.fr.md)
- [Déploiement et sécurité](doc/deploiement.fr.md)

## Liens

- Site web : [https://www.wate.fr](https://www.wate.fr)
- NPM : [https://www.npmjs.com/package/wate-engine](https://www.npmjs.com/package/wate-engine)
- GitHub : [https://github.com/athoth-npm/wate-engine](https://github.com/athoth-npm/wate-engine)
- Journal des modifications : [CHANGELOG.fr.md](CHANGELOG.fr.md) ([en](CHANGELOG.md))
- Architecture : [doc/architecture.fr.md](doc/architecture.fr.md) ([en](doc/architecture.md))
- Référence API : [doc/api.fr.md](doc/api.fr.md) ([en](doc/api.md))
- Guide module : [doc/module.fr.md](doc/module.fr.md) ([en](doc/module.md))
- Déploiement : [doc/deploiement.fr.md](doc/deploiement.fr.md) ([en](doc/deploiement.md))

## Licence

MIT — Copyright © 2023–2026 WATE Team.
