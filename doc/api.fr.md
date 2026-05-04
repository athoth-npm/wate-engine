# Référence API

## `init(options)`

Initialise et démarre le moteur WaTE. En mode CLI, le port et la DB sont lus depuis `process.argv`. En mode bibliothèque, toutes les options sont passées via l'objet `options`. Les modules sont chargés dans l'ordre déclaré dans `mod`.

```javascript
const wate = require('wate-engine')
wate.init({
  db: './data/app.db',      // requis — chemin DB ou ':memory:'
  port: 8080,               // requis — port TCP (1-65535)
  path: './',               // optionnel — dossier racine de l'application
  root: '/home',            // optionnel — redirige '/' vers cette URL
  mod: ['auth=3600', 'db', 'audit'],
  ejs: ['fs-tools'],        // optionnel — modules helpers EJS
  log: 7,                   // optionnel — niveau de log (bitmask: 1=ERROR 2=WARN 4=INFO)
  listen: true,             // optionnel — false = init sans démarrer le serveur HTTP
  name: 'Mon Appli',        // optionnel — nom affiché dans les logs et l'interface admin
  sessionTTL: 3600          // optionnel — TTL de session en secondes (priorité sur --mod auth=TTL)
}).then(({ app, db, server, close }) => {
  // Enregistrer des hooks métier
  // app.locals.tableHooks, app.locals.jsHandlers disponibles
}).catch(err => console.error('Erreur démarrage:', err))
```

| Option | Type | Défaut | Description |
|--------|------|--------|-------------|
| `db` | `string` | **requis** | Chemin vers la base SQLite ou `':memory:'` |
| `port` | `number` | **requis** | Port TCP (1-65535) |
| `path` | `string` | `'./'` | Dossier racine de l'application |
| `root` | `string` | — | Redirige `'/'` vers cette URL |
| `mod` | `string[]\|string` | — | Modules à charger. Syntaxe : `nom[:alias][=param]` |
| `ejs` | `string[]\|string` | — | Modules helpers EJS (API restreinte) |
| `log` | `number` | `7` | Niveau de log : 1=ERROR, 2=WARN, 4=INFO |
| `listen` | `boolean` | `true` | Mettre `false` pour ne pas démarrer le serveur HTTP |
| `name` | `string` | — | Nom affiché dans les logs et l'interface admin |
| `sessionTTL` | `number` | — | TTL de session en secondes (priorité sur `--mod auth=TTL`) |

Retourne `Promise<{app, db, server?, close}>` :
- `app` — instance Express configurée
- `db` — instance sqlite3 connectée
- `server` — http.Server (absent si `listen: false`)
- `close()` — fonction d'arrêt propre → Promise (attend les `done()` des modules)

## Routes API JSON

### Authentification — `/admin/api/auth/*`

| Méthode | Route | Description |
|---------|-------|-------------|
| `POST` | `/admin/api/auth/signin` | Connexion. Body: `{email, password}` → `{ok, lang, csrf}` |
| `POST` | `/admin/api/auth/signout` | Déconnexion → `{ok: true}` |
| `GET` | `/admin/api/auth/me` | Profil courant → `{email, profil_id, lang, csrf}` |
| `PUT` | `/admin/api/auth/me` | Mise à jour du profil (update-self sur `_user`) |
| `DELETE` | `/admin/api/auth/me` | Suppression du compte (delete-self) |
| `POST` | `/admin/api/auth/signup` | Inscription. `{email, password}` |
| `POST` | `/admin/api/auth/forgot` | Demande de réinitialisation (module mail requis) |
| `POST` | `/admin/api/auth/reset` | Appliquer nouveau mot de passe. `{token, password}` |

### Clés d'API — `/admin/api/auth/apikey`

| Méthode | Route | Description |
|---------|-------|-------------|
| `GET` | `/admin/api/auth/apikey` | Lister les clés (masquées) |
| `POST` | `/admin/api/auth/apikey` | Créer une clé → `{ok, key, prefix, label}` |
| `DELETE` | `/admin/api/auth/apikey` | Révoquer par préfixe |

Utilisation : header `Authorization: Bearer wate_xxx`. Module `--mod apikey`.

### Base de données — `/admin/api/db/*`

**`GET /admin/api/db/schema`** — Liste les tables accessibles avec leurs colonnes.

**`GET /admin/api/db/:table?sort=col&dir=asc|desc&search=terme&filter=col:val,col2:val2&offset=0&limit=50`** — SELECT paginé. Tous les paramètres sont validés contre PRAGMA.

**`POST /admin/api/db/:table`** — INSERT. Vérifie le droit `insert`.

**`PUT /admin/api/db/:table`** — UPDATE. Vérifie le droit `update`/`update-self`. Colonnes PK obligatoires.

**`DELETE /admin/api/db/:table`** — DELETE. Vérifie le droit `delete`/`delete-self`.

**`GET /admin/api/db/:table/export?format=csv|json[&sort=&filter=&search=]`** — Export avec filtres. CSV respecte RFC 4180 avec BOM UTF-8. Limité par `db.maxExport` (défaut 10000).

**`POST /admin/api/db/:table/undo`** — Annule la dernière écriture (insert/update/delete) via les données capturées par le module audit (`--mod audit`). L'owner peut passer `?all=true` pour annuler l'écriture de n'importe quel utilisateur. Retourne `{ok: true}` ou 404 `{error: "Nothing to undo"}`.

### Recherche — `/admin/api/search`

**`GET /admin/api/search?q=terme&lang=fr[&scope=demo]`** — Recherche FTS5. Session requise.

**`GET /api/search?q=terme&lang=fr[&scope=demo]`** — Endpoint public (list_id ≥ 200 uniquement).

Réponse : `{ results: [{ source, tag, text, snippet, urls }] }`. Module `--mod search`.

### Statistiques — `/admin/api/stats`

`GET /admin/api/stats` — Statistiques du cache LRU. Module `--mod stats`.

### Health — `/health`

`GET /health` — `{ status: 'ok', uptime: <secondes> }`. Sans auth.

## Codes HTTP

| Code | Signification |
|------|---------------|
| 400 | Bad Request — paramètres manquants, nom de table invalide |
| 401 | Unauthorized — session absente ou expirée |
| 403 | Forbidden — droits `_access` insuffisants, CSRF invalide |
| 404 | Not Found — page/table inexistante |
| 429 | Rate limit exceeded (30 POST/min/IP) |
| 500 | Internal Server Error |

## Modules moteur

| Module | CLI | Description |
|--------|-----|-------------|
| `auth` | `--mod auth=3600` | Sessions, PBKDF2, CSRF. TTL en secondes. |
| `db` | `--mod db` | API CRUD + UI admin, tri/filtre/export. |
| `stats` | `--mod stats` | Statistiques du cache LRU. |
| `mail` | `--mod mail` | Emails de vérification/réinitialisation (nodemailer). |
| `audit` | `--mod audit` | Journal d'audit des écritures (table `_audit`). |
| `search` | `--mod search` | Recherche plein texte FTS5 (table `_fts`). |
| `apikey` | `--mod apikey` | Clés d'API Bearer pour accès M2M. |
| `cron` | `--mod cron` | Purge périodique des sessions/tokens/audit. |

## Hooks

**`tableHooks`** — Intercepter INSERT/UPDATE/DELETE :
```javascript
_data.registerTableWriteHook('nomTable', 'insert', function(req, next) {
  // modifier req.body, puis appeler next() ou next(err)
})
```

**`getTableWriteHook(table, action)`** — Récupérer un hook existant (pour chaînage, utilisé par le module audit).

**`pageLoadHooks`** — Injecter des données avant le rendu EJS via la clé `_item` `HOOK`.

## Fonctions cœur

### `serve(req, res, data?, urlOverride?)`

Résout et renvoie les données d'une page au client. C'est le pipeline de rendu GET principal.

1. Valide la session depuis `req.cookies.sid`
2. Charge les `_item` de la page via une requête UNION `_page` / `_item`
3. Exécute les requêtes SQL définies dans `_item.queries` via un sandbox VM
4. Fusionne les résultats, charge le glossaire scopé, exécute les hooks de chargement
5. Rend le template EJS (`common.ejs`) ou délègue à un handler JS

```
serve(req, res)                        // rendu de page standard
serve(req, res, extraData)             // avec données supplémentaires injectées
serve(req, res, extraData, '/url/perso') // override d'URL pour les routes dynamiques
```

- `req` — Requête Express (doit avoir `req.cookies.sid`, `req.query.lang`, `req.path`)
- `res` — Réponse Express
- `data` — Optionnel `{ key, value }` injecté dans le résultat du rendu
- `urlOverride` — Optionnel, URL à chercher dans `_page` au lieu de `req.path`

Réponses d'erreur : 401 (session expirée/absente), 403 (interdit), 404 (page introuvable), 500 (erreur requête/config).

### `modify(req, res, responder?)`

Exécute une opération d'écriture (INSERT, UPDATE, DELETE) sur une table.

Ordre de validation :
1. Nom de table validé contre `/^[a-zA-Z0-9_]+$/`
2. Session active requise (401 si absente)
3. Vérification ACL via `_access` pour le profil courant (403 si refusé)
4. Colonnes PK présentes pour UPDATE/DELETE (400 si manquantes)
5. `tableWriteHook` enregistré exécuté (si présent)
6. Écriture SQL exécutée (INSERT/UPDATE/DELETE)

Les opérations `-self` (`update-self`, `delete-self`) filtrent automatiquement sur la colonne `email` de la session courante.

- `req` — Requête Express (`req.body` = valeurs des colonnes, `req.params.table` = table cible, `req.params.request` = action)
- `res` — Réponse Express
- `responder` — Optionnel, responder personnalisé `{ success(), error(code, msg) }`. Défaut : redirige vers `../data-<table>?lang=<lang>`

## API Module (`_WATE_API`)

L'objet `_WATE_API` est passé à la fonction `init(api)` de chaque module. Il donne accès aux primitives du moteur sans exposer les internes.

| Propriété | Type | Description |
|-----------|------|-------------|
| `api.app` | `Express.Application` | Instance Express partagée. `app.locals` contient `tableHooks`, `jsHandlers`, `SESSION_TTL_S` |
| `api.log` | `Logger` | Logger avec méthodes `.INFO(msg)`, `.WARN(msg)`, `.ERROR(msg)` |
| `api.db.run()` | `Function` | `db.run(sql, params, callback)` — requêtes d'écriture |
| `api.db.all()` | `Function` | `db.all(sql, params, callback)` — SELECT retournant toutes les lignes |
| `api.db.get()` | `Function` | `db.get(sql, params, callback)` — SELECT retournant la première ligne |
| `api.renderPage(req, res, targetUrl?, extraData?)` | `Function` | Force le rendu d'une page DB. Utilise `serve()` en interne |
| `api.renderError(req, res, code, msg, nextUrl?)` | `Function` | Affiche une page d'erreur |
| `api.hooks.onPageLoad(name, callback)` | `Function` | Enregistre un hook de chargement de page |
| `api.hooks.onTableWrite(table, action, callback)` | `Function` | Enregistre un hook d'écriture sur table |

### `api.executeAction(action, params)`

Exécute une action whitelistée sur le moteur. Retourne `Promise`.

### `api.getTableWriteHook(table, action)`

Retourne le hook existant pour `(table, action)`. Utile pour chaîner sans écraser (pattern utilisé par le module audit).

## Système de modules

Les modules sont chargés via `_modules.load(flag, rawInput, appPath)`. La syntaxe unifiée pour `--mod` et `--ejs` est :

```
nom[:alias][=param]
```

Exemples : `auth=3600`, `db`, `audit`, `mail:smtp={"host":"..."}`

**Modules moteur** (noms dans la liste intégrée) : résolus depuis `__dirname/_name`. **Modules applicatifs** : résolus depuis `<appPath>/scripts/<name>`.

Les noms de module sont validés contre `/^[a-zA-Z0-9_-]+$/` (anti path-traversal). Les séparateurs de chemin (`/`, `\`, `..`) sont rejetés.

Chaque module peut exporter :
- `init(param, api)` — appelée au chargement (peut être async → Promise). Pour les modules `--ejs`, `api` est restreint à `{ log, app }`
- `done()` — appelée pendant l'arrêt

L'init asynchrone a un timeout de 10 secondes. Si l'init d'un module rejette, le démarrage du moteur échoue.

## Web Components

| Élément | Rôle |
|---------|------|
| `<admin-row>` | Ligne de formulaire CRUD (s'adapte au type de colonne) |
| `<schema-table>` | Diagramme de schéma style Merise |
| `<icon-menu>` | Menu hamburger responsive |
| `<show-image>` | Affichage d'image zoomable |
| `<admin-list>` | Liste déroulante FK |
| `<modal-popup>` | Remplace alert/confirm natifs |

---

## Liens

- [README](../README.fr.md) — Vue d'ensemble
- [Modules](module.fr.md) — Création de modules et API
- [Architecture](architecture.fr.md) — Moteur interne
- [Déploiement](deploiement.fr.md) — Docker, PM2, reverse proxy
- [CHANGELOG](../CHANGELOG.fr.md) — Historique des versions
