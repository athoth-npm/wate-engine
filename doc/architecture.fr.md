# Architecture de WaTE

WaTE (Web as Table Engine) est un moteur CMS Node.js/Express/SQLite fondé sur un paradigme **Data-First** : le schéma SQL pilote l'UI, le routage, l'ACL et l'i18n. Le code reste générique — toute la logique métier est en base de données.

## Noyau moteur

| Fichier | Rôle | Chargement |
|---------|------|------------|
| `engine.js` | Point d'entrée, init Express, orchestration | `require('wate-engine')` |
| `_core.js` | Registre central (state manager) | Singleton via `require()` |
| `_data.js` | Accès aux données — `serve()` (lecture) + `modify()` (écriture) | Interne |
| `_modules.js` | Chargeur de modules — syntaxe unifiée, façade `_WATE_API` | Interne |
| `_auth.js` | Sessions, signin/signup/me, verify/forgot/reset | `--mod auth=TTL` |
| `_db.js` | CRUD API + UI, tri/filtre/export | `--mod db` |
| `_stats.js` | Statistiques d'accès (cache LRU) | `--mod stats` |
| `_mail.js` | Emails de vérification/récupération (nodemailer) | `--mod mail` |
| `_audit.js` | Journal d'audit + undo | `--mod audit` |
| `_search.js` | Recherche plein texte FTS5 | `--mod search` |
| `_apikey.js` | Clés d'API Bearer pour accès M2M | `--mod apikey` |
| `_cron.js` | Tâches de maintenance périodiques | `--mod cron` |
| `_migration.js` | Moteur de migration SQL (001 → N) | Interne |
| `_modules.js` | Chargeur de modules applicatifs et WaTE | Interne |
| `_utils.js` | Fonctions pures partagées (crypto, CSRF, cookies, LRU) | Interne |
| `_log.js` | Logger interne | Interne |

## Tables système

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

Tables des modules optionnels :
  _audit    (module audit) — journal des écritures
  _fts      (module search) — index FTS5
  _stats_*  (module stats) — statistiques d'accès
```

### Tables centrales (12)

| Table | Rôle |
|-------|------|
| `_list` | Identifiant de regroupement d'items |
| `_item` | Configuration clé/valeur (template, CSS, queries, titre…) |
| `_page` | Routage URL × profil → list_id |
| `_lang` | Langues disponibles (fr, en) |
| `_profil` | Profils utilisateurs (0=owner, 9999=anonymous) |
| `_user` | Comptes (email, mot de passe PBKDF2, profil) |
| `_session` | Sessions + session fantôme id='0' |
| `_request` | Opérations autorisées (select, insert, update, update-self, delete, delete-self) |
| `_access` | Matrice ACL : profil × table × opération |
| `_glossary` | Textes i18n scopés par list_id |
| `_config` | Paramètres clé/valeur d'exécution |
| `_user_token` | Jetons verify/reset (module auth) |

### Tables des modules optionnels

| Table | Module | Contenu |
|-------|--------|---------|
| `_audit` | audit | Journal INSERT/UPDATE/DELETE avec old_values/new_values JSON |
| `_fts` | search | Table virtuelle FTS5 indexant le glossaire et les items |
| `_stats_*` | stats | Compteurs de vues par page |
| `_api_key` | apikey | Tokens Bearer pour accès M2M |

## La session fantôme

La session `id='0'` est permanente : `INSERT INTO _session VALUES ('0', 'anonymous', 9999999999)`.
- Sans cookie → `getSession()` retourne `{id: 0}` → profil anonymous 9999
- `issued=9999999999` (an 2286) → jamais filtrée par TTL

## Requêtes dynamiques — `_item.queries`

Les pages peuvent définir des requêtes SQL paramétrées dans `_item` (clé = `queries`). La valeur est un **template JSON** contenant des placeholders `${expr}` ou `${expr:type}`, résolus à la volée via une VM sandboxée.

### Format du template

```json
{"NomQuery": {
  "request": "SELECT * FROM t WHERE col IN (${req.query.filter:text})",
  "values":  ["${lang}", ${req.query.limit:number}]
}}
```

Chaque clé devient une requête exécutée via `db.all(request, values, callback)`.

### Syntaxe de substitution

| Syntaxe | Comportement |
|---------|-------------|
| `${expr}` | Évalue `expr` dans la VM sandbox, injecte le résultat |
| `${expr:number}` | Force `parseFloat()`, rejette NaN |
| `${expr:identifier}` | Valide contre `/^[a-zA-Z0-9_]+$/` (noms de tables/colonnes) |
| `${expr:text}` | Force `String()`, échappe `"` et `\` pour la sécurité JSON |

### Deux contextes d'injection

1. **Contexte JSON** : les valeurs sont injectées dans une chaîne JSON avant `JSON.parse()`. Les caractères `"` et `\` sont échappés. Les objets et fonctions sont rejetés (barrière de sécurité).
2. **Contexte SQL** : après `JSON.parse()`, `request` est exécutée par `db.all()`. Les `values` sont passées en paramètres bindés (`?`) — immunisées contre l'injection SQL classique.

### Règles pour les développeurs

- **Toujours utiliser un type** (`:number`, `:identifier`, `:text`) pour les valeurs provenant de `req.query` ou `req.body`. Le type force une conversion stricte avant injection.
- **Ne jamais** concaténer une `${...}` directement dans `request` sans `:identifier` s'il s'agit d'un nom de table ou colonne. `:identifier` valide la valeur.
- **Les valeurs sont bindées** (`?`) : une string contenant `'; DROP--` est inoffensive. Ne PAS contourner ce mécanisme en concaténant des valeurs utilisateur directement dans `request`.
- Une expression sans type retournant un objet ou une fonction est **rejetée** (log ERROR, remplacée par `null`).
- Longueur max d'une expression : **500 caractères** (anti-DoS sur la sandbox VM).

### Expressions valides

```
${req.query.id:number}      → force un nombre (NaN → erreur)
${req.query.table:identifier} → valide un nom de table (regex)
${req.query.name:text}      → force String, échappe " et \
${lang}                     → valeur interne (langue courante), sûr
```

### Expression invalide (rejetée)

```
${req.query.raw}            → pas de type, objet/fonction rejeté
```


## Système ACL

`_data.modify()` vérifie les droits en deux étapes :
1. Vérification de la session → 401 si absente/expirée
2. `_access(profil, table, opération)` → 403 si refusée

Les opérations `-self` exigent une colonne `email` et filtrent automatiquement sur l'email de la session.

## Cycle de vie d'une requête

```
Requête HTTP → cookieParser → json/urlencoded → fichiers statiques → favicon
→ disablePageCache → setSecurityHeaders (CSP+nonce) → CSRFProtection
→ postRateLimit → Routes → serve()/modify() → Réponse
```

---

## Liens

- [README](../README.fr.md) — Vue d'ensemble & démarrage rapide
- [API Reference](api.fr.md) — Routes & modules
- [Modules](module.fr.md) — Guide de création de modules
- [Déploiement](deploiement.fr.md) — Docker, PM2, reverse proxy
- [CHANGELOG](../CHANGELOG.fr.md) — Historique des versions
- [Site WaTE](https://www.wate.fr) — Démo & documentation en ligne
