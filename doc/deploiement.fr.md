# Déploiement et sécurité

## Configuration

### Table `_config`

| Clé | Défaut | Description |
|-----|--------|-------------|
| `session.ttl` | — | Durée de vie des sessions (secondes) |
| `cache.tableInfo` | 100 | Cache LRU PRAGMA table_info |
| `cache.fkList` | 100 | Cache LRU PRAGMA foreign_key_list |
| `cache.queries` | 200 | Cache LRU queries JSON |
| `upload.maxFileSize` | 10 Mo | Taille max des uploads |
| `upload.maxFiles` | 5 | Nombre max de fichiers par requête |
| `db.defaultLimit` | 50 | LIMIT par défaut |
| `db.maxLimit` | 200 | LIMIT maximale |
| `db.maxExport` | 10000 | Lignes max par export |
| `cron.purgeInterval` | 300 | Intervalle de purge cron (secondes) |
| `cron.auditRetention` | 90 jours | Rétention des enregistrements d'audit |

### Variables d'environnement
`WATE_CSRF_SECRET`, `NODE_ENV=production`.

## Sécurité

### CSRF
Token = `SHA256(sessionId + secret)`. Envoyé via `X-CSRF-Token` ou `_csrf`. Comparaison timing-safe. Ignoré pour GET/HEAD/OPTIONS et signin.

### CSP
Nonce par requête. Base : `default-src 'self'; script-src 'nonce-...' 'self'`. Extensible via `module.csp`.

### Headers HTTP
`X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Strict-Transport-Security` (HTTPS).

### Rate Limiting
Token bucket : 30 POST/min/IP, recharge 0,5 tokens/s. Purge après 60s.

### Hachage des mots de passe
PBKDF2-SHA512, 100k itérations, sel = `SHA256(email)`. Comparaison timing-safe.

### Sandbox VM
Expressions `${expr}` dans `vm.createContext` isolé : `eval`/`Function` désactivés, timeout 50ms, 500 chars max.

### Validation
Noms de table : `/^[a-zA-Z0-9_]+$/`. Messages d'erreur filtrés, 120 chars max. Body limité à 100 Ko.

## Health Check
`GET /health` → `{ status: 'ok', uptime: <s> }`. Sans auth.

## Reverse proxy
WaTE en HTTP local, HTTPS délégué à Nginx/Caddy. `trust proxy: 1` activé.

## Déploiement
PM2 : `pm2 start engine.js --name wate -- --port 8080 --db app.db --mod auth=3600,db`
Docker : `DockerFile` et `docker-compose.yml` fournis.

## Sauvegarde
`sqlite3 app.db ".backup app-backup.db"`. Ne jamais copier le fichier pendant une écriture. Mode WAL activé.

## Tests
`node test/app.js` (5 instances, ports 3001-3005). `bash test/test-wate.sh` (~290 tests curl).

## Migrations
Nommage : `NNN_<scope>_<desc>.sql`. Scope `engine` toujours exécuté. `auth`, `db`, `stats`, `mail`, `audit`, `search`, `apikey`, `cron` selon `--mod`.

| Migration | Scope | Crée |
|-----------|-------|------|
| `001_engine.sql` | (toujours) | Schéma central + défauts |
| `002_config.sql` | (toujours) | Table `_config` |
| `003_stats.sql` | `stats` | Tables `_stats_*` + page admin |
| `004_auth_token.sql` | `auth` | Table `_user_token` + verify/reset |
| `005_audit_audit.sql` | `audit` | Table `_audit` |
| `006_search_search.sql` | `search` | Table virtuelle FTS5 `_fts` + triggers |
| `007_apikey.sql` | `apikey` | Table `_api_key` |

---

## Liens

- [README](../README.fr.md) — Vue d'ensemble
- [Architecture](architecture.fr.md) — Moteur interne
- [API Reference](api.fr.md) — Routes & modules
- [Modules](module.fr.md) — Création de modules applicatifs
- [CHANGELOG](../CHANGELOG.fr.md) — Historique des versions
