# Modules WaTE

## Qu'est-ce que WaTE

WaTE (Web application Template Engine) est un framework web léger construit sur Express et SQLite. Il fournit :

- **Pages pilotées par la base de données** — la structure des pages, les requêtes et les contrôles d'accès sont définis dans des tables SQLite (`_page`, `_item`, `_access`)
- **Système de modules** — extensible via les flags `--mod` (API complète) et `--ejs` (API restreinte)
- **Administration intégrée** — UI CRUD, authentification, recherche, audit et plus via les modules moteur
- **Sandbox VM** — requêtes SQL dynamiques avec syntaxe `${expr:type}`, évaluées dans un contexte sécurisé

## Démarrage

### Mode CLI

```bash
node engine.js --db ./data/app.db --port 8080 --mod auth=3600,db,audit --name "Mon Appli"
```

### Mode bibliothèque

```javascript
const wate = require('wate-engine')
wate.init({
  db: './data/app.db',
  port: 8080,
  mod: ['auth=3600', 'db', 'audit'],
  name: 'Mon Appli'
}).then(({ app, db, server, close }) => {
  console.log('WaTE démarré')
})
```

## Système de modules

### Syntaxe

Les flags `--mod` et `--ejs` utilisent la même syntaxe unifiée :

```
nom[:alias][=param]
```

| Exemple | Signification |
|---------|---------------|
| `auth=3600` | Charge `auth`, passe le paramètre `3600` (TTL en secondes) |
| `db` | Charge `db`, sans alias, sans paramètre |
| `mail:smtp={"host":"smtp.exemple.com"}` | Charge `mail` avec l'alias `smtp`, passe un paramètre JSON |

Modules multiples séparés par des virgules :
```
--mod auth=3600,db,audit,mail:smtp={"host":"smtp.exemple.com"}
```

### Modules moteur vs. modules applicatifs

**Modules moteur** (noms intégrés : `auth`, `db`, `stats`, `log`, `utils`, `mail`, `audit`, `search`, `apikey`, `cron`) sont résolus depuis `__dirname/_name` (c.-à-d. `_auth.js`, `_db.js`, etc. dans le répertoire du moteur).

**Modules applicatifs** sont résolus depuis `<appPath>/scripts/<name>`. Par exemple, `--mod monmodule` cherche `<app-root>/scripts/monmodule.js`.

Les noms de module sont validés contre `/^[a-zA-Z0-9_-]+$/`. Les tentatives de path traversal (`/`, `\`, `..`) sont rejetées.

### `--mod` vs `--ejs`

| Flag | Portée API | Utilisation |
|------|-----------|-------------|
| `--mod` | `_WATE_API` complète | Modules applicatifs avec accès DB, hooks, rendu |
| `--ejs` | Restreinte `{ log, app }` | Modules helpers EJS (fonctions de template, utilitaires lecture seule) |

### Cycle de vie d'un module

1. **Chargement** — `_modules.load()` parse la chaîne d'entrée, résout le chemin de chaque module et le `require()`
2. **Initialisation** — Si le module exporte `init(param, api)`, elle est appelée. L'init asynchrone (retournant une Promise) est supportée avec un timeout de 10 secondes
3. **Exécution** — Le module a accès à `api` et peut enregistrer des routes, hooks, middlewares
4. **Arrêt** — Lors du `close()`, `module.done()` est appelée pour chaque module chargé si elle est exportée

## L'interface `_WATE_API`

Passée comme second argument à `module.init(param, api)`. Pour les modules `--ejs`, seul `{ log, app }` est exposé.

### `api.app`

L'instance Express partagée. Propriétés clés :

```javascript
api.app.locals.tableHooks    // registre des hooks d'écriture
api.app.locals.jsHandlers    // handlers JS côté client
api.app.locals.SESSION_TTL_S // TTL de session en secondes
```

Utilisez `api.app` pour enregistrer des routes personnalisées, des middlewares ou des gestionnaires de fichiers statiques.

### `api.log`

Logger structuré :

```javascript
api.log.INFO('Serveur démarré')
api.log.WARN('Limite de débit approchée')
api.log.ERROR('Échec connexion base de données')
```

### `api.db`

Accès paramétré à la base de données (enveloppe `sqlite3`) :

```javascript
// Écriture
api.db.run('INSERT INTO users (email, name) VALUES (?, ?)', [email, name], (err) => { ... })

// Lire toutes les lignes
api.db.all('SELECT * FROM users WHERE active = ?', [1], (err, rows) => { ... })

// Lire une seule ligne
api.db.get('SELECT * FROM users WHERE email = ?', [email], (err, row) => { ... })
```

Toutes les valeurs sont paramétrées via les placeholders `?` — protégées contre l'injection SQL.

### `api.renderPage(req, res, targetUrl?, extraData?)`

Force le rendu d'une page pilotée par la base de données en utilisant le pipeline `serve()` standard.

```javascript
api.app.get('/page-perso', (req, res) => {
  api.renderPage(req, res)                                          // utilise req.path
  api.renderPage(req, res, '/admin/tableau-de-bord')                // URL explicite
  api.renderPage(req, res, '/admin/tableau-de-bord', { key: 'extra', value: { ... } })
})
```

### `api.renderError(req, res, code, msg, nextUrl?)`

Affiche une page d'erreur standard :

```javascript
api.renderError(req, res, 404, 'Élément introuvable')
api.renderError(req, res, 403, 'Accès refusé', '/connexion')
```

### `api.hooks`

#### `api.hooks.onPageLoad(name, callback)`

Injecte des données avant le rendu EJS. Le `name` doit correspondre à `elements.HOOK` de la définition `_item`.

```javascript
api.hooks.onPageLoad('FOURNISSEUR', (req, elements) => {
  // Récupérer des données externes et retourner { key, value }
  return fetchExternalData(req).then(data => ({ key: 'external', value: data }))
})
```

#### `api.hooks.onTableWrite(tableName, action, callback)`

Intercepte les écritures en base de données. `action` est parmi `'insert'`, `'update'`, `'delete'`, `'update-self'`, `'delete-self'`.

```javascript
api.hooks.onTableWrite('commandes', 'insert', (req, next) => {
  // Ajouter des champs calculés
  req.body.date_creation = new Date().toISOString()
  req.body.cree_par = req.session?.email

  // Appeler next() pour continuer, ou next(err) pour annuler
  next()
})
```

Le callback reçoit `(req, next)` :
- Modifiez `req.body` avant d'appeler `next()` — les changements sont appliqués à l'écriture SQL
- Appelez `next(err)` pour annuler l'écriture avec une erreur

### `api.executeAction(action, params)`

Exécute une action whitelistée. Retourne `Promise`.

### `api.getTableWriteHook(table, action)`

Retourne le hook actuellement enregistré, s'il existe. Utilisé pour le chaînage :

```javascript
const existant = api.getTableWriteHook('commandes', 'insert')
api.hooks.onTableWrite('commandes', 'insert', (req, next) => {
  // Logique personnalisée d'abord
  req.body.audite = true
  // Chaîner au hook existant
  if (existant) {
    existant(req, (err, onSuccess) => next(err, onSuccess))
  } else {
    next()
  }
})
```

## Créer un module applicatif

### Module minimal

```javascript
// scripts/mon-module.js
module.exports = {
  init(param, api) {
    api.log.INFO('mon-module initialisé avec paramètre : ' + param)

    // Enregistrer une route personnalisée
    api.app.get('/api/perso', (req, res) => {
      res.json({ ok: true, module: 'mon-module' })
    })
  },

  done() {
    // Nettoyage : fermer les connexions, annuler les intervalles, etc.
  }
}
```

### Module avec init asynchrone

```javascript
// scripts/sync-donnees.js
module.exports = {
  async init(config, api) {
    api.log.INFO('sync-donnees : connexion à l\'API externe...')

    // Configuration asynchrone (doit se terminer en moins de 10 secondes)
    const client = await createExternalClient(config)

    // Enregistrer une route qui utilise le client
    api.app.get('/api/statut-sync', async (req, res) => {
      const statut = await client.getStatus()
      res.json(statut)
    })

    // Garder une référence pour le nettoyage
    this._client = client
  },

  async done() {
    if (this._client) {
      await this._client.disconnect()
    }
  }
}
```

### Module avec hooks d'écriture

```javascript
// scripts/audit-commandes.js
module.exports = {
  init(param, api) {
    // Journaliser chaque création de commande
    api.hooks.onTableWrite('commandes', 'insert', (req, next) => {
      api.log.INFO('Nouvelle commande créée par : ' + req.session?.email)
      req.body.piste_audit = JSON.stringify({
        cree: new Date().toISOString(),
        ip: req.ip
      })
      next()
    })

    // Valider avant modification
    api.hooks.onTableWrite('commandes', 'update', (req, next) => {
      if (req.body.statut === 'annulee' && !req.body.motif_annulation) {
        return next(new Error('Motif d\'annulation requis'))
      }
      next()
    })
  }
}
```

### Module avec hooks de chargement de page

```javascript
// scripts/widget-meteo.js
module.exports = {
  init(param, api) {
    api.hooks.onPageLoad('METEO', async (req, elements) => {
      const ville = elements.ville || 'Paris'
      try {
        const data = await fetchMeteo(ville)
        return { key: 'meteo', value: data }
      } catch (err) {
        api.log.ERROR('Échec récupération météo : ' + err.message)
        return { key: 'meteo', value: { erreur: 'Indisponible' } }
      }
    })
  }
}
```

Dans la base de données (`_item`), définissez `HOOK` à `METEO` sur la page où le widget doit apparaître.

## Créer un module helper EJS

Les modules EJS reçoivent une API restreinte avec seulement `log` et `app`. Ils exportent des fonctions utilisables dans les templates EJS via la variable `EJSs`.

```javascript
// scripts/fs-tools.js
const fs = require('fs')
const path = require('path')

module.exports = {
  init(param, api) {
    api.log.INFO('fs-tools chargé')
  },

  // Appelable depuis EJS : EJSs['fs-tools'].readdirSync(rep)
  readdirSync(rep) {
    return fs.readdirSync(rep)
  },

  readFileSync(cheminFichier) {
    return fs.readFileSync(cheminFichier, 'utf8')
  }
}
```

Dans les templates EJS :
```ejs
<% const fichiers = EJSs['fs-tools'].readdirSync(path + 'data/') %>
```

## Règles de sécurité pour les modules

- **Toujours utiliser des requêtes paramétrées** — `api.db.all('SELECT ... WHERE col = ?', [valeur], cb)`, jamais de concaténation de chaînes
- **Noms de module validés** — déjà appliqué par le moteur (`/^[a-zA-Z0-9_-]+$/`, sans path traversal)
- **Ne pas exposer les internes** — la façade `_WATE_API` cache intentionnellement `_core` et `db` brut. Utilisez uniquement l'API fournie
- **Respecter le sandbox** — les requêtes de page s'exécutent dans une VM avec `eval` et `Function` désactivés. Ne pas tenter de le contourner en stockant du code exécutable dans la base de données
- **Nettoyer dans `done()`** — fermer les connexions réseau, annuler les intervalles, libérer les ressources

## Ordre de chargement

Les modules sont chargés et initialisés dans l'ordre où ils apparaissent dans le tableau `mod` / `ejs`. Cela importe quand des modules dépendent les uns des autres :

```javascript
mod: ['auth=3600', 'db', 'audit']  // auth d'abord (sessions nécessaires à db), audit en dernier (enveloppe les hooks db)
```

Tous les appels `init()` (y compris asynchrones) doivent se terminer avant que le moteur ne commence à écouter.

---

## Liens

- [Référence API](api.fr.md) — API complète du moteur
- [Architecture](architecture.fr.md) — Fonctionnement interne du moteur
- [Déploiement](deploiement.fr.md) — Docker, PM2, reverse proxy
- [CHANGELOG](../CHANGELOG.fr.md) — Historique des versions
- [README](../README.fr.md) — Vue d'ensemble
