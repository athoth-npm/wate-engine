# CHANGELOG — WaTE Engine

Toutes les modifications notables de ce projet sont documentées dans ce fichier.
Format basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).
Versionné en [SemVer](https://semver.org/).

---

## [v3.19.5] — 2026-05-04

### Ajouté — Documentation (FR/EN)
- `doc/module.fr.md` / `doc/module.md` — Guide de création de modules : interface `_WATE_API`, `init()`/`done()`, hooks, syntaxe `--mod`/`--ejs`, exemples complets.
- `doc/api.fr.md` / `doc/api.md` — Tableau des options `init()`. Nouvelles sections : `serve()`, `modify()`, `_WATE_API`, système de modules.
- `doc/architecture.fr.md` / `doc/architecture.md` — `_modules.js` ajouté au noyau. Liens croisés vers la doc module.
- Page web `/docs` — 3 nouvelles sous-sections (7.5 Interface `_WATE_API`, 7.6 Créer un module, 7.7 Pipeline de rendu et d''écriture).
- Page web `/docs` — Formatage HTML : `<code>` (monospace inline), `<pre>` (blocs sombres), `<ul>`/`<ol>` (puces/numéros) sur les sections 4, 7, 11, 12, 13.

### Modifié — Documentation source
- `engine.js init()` — JSDoc complet (options, retour, exemple).
- `_data.js serve()` — JSDoc complet (pipeline, paramètres, erreurs, historique).
- `_data.js modify()` — JSDoc complet (chaîne de validation, opérations `-self`).
- `_modules.js _WATE_API` — `@typedef` aligné sur l''objet `_WATE_API` réel.
- `_modules.js load()` — JSDoc complet (paramètres, validation, cycle de vie, timeout).

### Corrigé — Documentation
- `doc/api.md` / `doc/api.fr.md` — Retrait de `api.executeAction` et `api.getTableWriteHook` (non exposés par `_WATE_API`).
- `doc/deploiement.md` / `doc/deploiement.fr.md` — `007_apikey.sql` replacé dans le tableau des migrations ; lien module ajouté.
- `web/migrations/001_site.sql` — Section 7.5 `_WATE_API` alignée sur le code ; 7.7 renommée « Pipeline de rendu et d''écriture ».
- `_data.js` Doxygen — Signatures `serve()` et `modify()` corrigées.
- `_modules.js` Doxygen — Noms des paramètres de `load()` corrigés.
- `CHANGELOG.md` / `CHANGELOG.fr.md` — Nom de la section 7.7 mis à jour.

### Ajouté — CI/CD
- `.github/workflows/ci.yml` — Push/PR sur main : matrice Node 18/20/22, install, audit, tests.
- `.github/workflows/release.yml` — Tag `v*` : tests, auto GitHub Release avec le CHANGELOG.

### Modifié — Versioning
- `package.json` version 3.19.5 (source de vérité).
- `engine.js` en-tête et pied alignés sur `package.json` (v3.19.5).

### Corrigé — Logs RUN
- `_data.js modify()` — LEAVE sur 10+ chemins d'erreur.
- `_db.js`, `_audit.js`, `_search.js`, `_auth.js` — LEAVE manquants ajoutés.
- `_data.js serve()` — LEAVE déplacé dans le callback asynchrone.

### Corrigé — Sécurité
- `_auth.js signup` — Whitelist colonnes (anti mass assignment).
- `_auth.js` — Password max 1024 chars. `_mail()` retourne `{isAvailable:false}`.
- `_db.js` — `hasOwnProperty.call`. `_RE_TABLE` sur route formulaire.
- `_data.js` — `__proto__`/`constructor` filtrés. `hasOwnProperty.call` sur `req.body`.
- `engine.js` — CookieParser avec secret. `_RE_ROOT` anti open redirect. Rate limit → 429.
- `engine.js` — Blocage `.md`/`.db` en statique. `!isNaN(argv.log)`.
- `_modules.js` + `engine.js` — `.catch()` sur `Promise.race`.
- `web/scripts/demo.js` — Sessions random, CSRF, cookie secure.
- `web/app.js` — DB dans `data/` (hors static).
- `custom/custom.js` — `hasOwnProperty` + skip `__proto__`. Escape `"` dans sélecteur CSS.
- `web/scripts/site-menu.js` — `hasOwnProperty` + `encodeURIComponent`.
- `views/*.ejs` — Nonce conditionnel partout. Template include validé.

### Corrigé — Rate limiting
- `engine.js` — Bucket par IP+prefix (isole `/signin` de `/forgot`).

### Corrigé — Promesses & robustesse
- 15+ corrections : `catch()`, `AbortController`, `try-catch`, `composed:true`, focus restore, Content-Type check, timers nettoyés, `clipboard.catch()`.

### Corrigé — CSS & layout
- `css/common.css` v2.5.3 — Variables `--wate-*`. `box-sizing: border-box`. `--wate-error`.
- `custom/modal-popup/def.css` — `.icon` en `background-image` via `--mp-icon-src`.
- `web/css/common.css` — `--mp-icon-src` pour logo vitrine. Doublons retirés.
- `web/css/admin-db.css` — `10pt` → `0.833rem`. `max-height` → `80vh`.
- `web/css/docs.css` — `scroll-margin-top` → `5em`.
- `web/custom/wate-mcd/` — Grid slot fix (colonnes égales). Commentaire obsolète corrigé.

### Corrigé — Accessibilité
- Focus trapping Tab/Shift+Tab modale. Flèches show-image focusables + `aria-label`.
- `aria-expanded`/`aria-haspopup` icon-menu. Escape ferme dropdown.
- Émojis + SVG `aria-hidden="true"`. Search `aria-label`. Attributs HTML quotés.

### Corrigé — Performance
- `isTTY` caché module. Regex statiques module-level (8 fichiers).
- `_fkCacheGlobal` partagé (admin-db.js).

### Ajouté
- `test/test-content.sh` — 90+ assertions HTML/CSS/JS + JS sanity.
- `CHANGELOG.md` + `CHANGELOG.fr.md` — Historique complet.
- `DockerFile` — Healthcheck, non-root, strict-ssl retiré.
- `docker-compose.yml` — Volume dossier (WAL safe), secret CSRF.

### Modifié
- `package.json` — Toutes les dépendances en `^`.
- `_data.js` — `unregisterPageLoadHook`.
- `web/views/common.ejs` — About modal unifié avec l'admin.
- Voir aussi [v3.19.3] ci-dessous.

---

## [v3.19.3] — 2026-05-03

### Corrigé
- Layout admin restauré : fond `#001633`, police, centrage vertical (perdus avec `@import error.css` retiré).
- Scrollbar parasite sur pages admin (`margin: 0` sur body).
- Bouton signout décollé (sélecteur `.nav-info` corrigé, `margin-top` ajouté).
- Modale À propos vitrine : logo piloté par `--mp-icon-src` (logo foncé sur fond clair, blanc sur fond foncé).
- Balises `<strong>` échappées dans about (`<%=` → `<%-` pour `site-about-product`).

### Modifié
- `css/common.css` v2.5.3 : utilise ses propres variables `--wate-*`, `box-sizing: border-box`, nouveau `--wate-error`.
- `css/admin-auth.css` v1.5.2 : commentaire mort retiré, `p.error` → `var(--wate-error)`.
- `custom/admin-row/def.css` v1.5.1 : `p.error` → `var(--wate-error)`.
- `custom/modal-popup/def.css` v1.3.3 : `.icon` en `background-image` via `--mp-icon-src`, `<img>` retiré du shadow DOM.
- `web/css/common.css` v1.5.2 : doublons `--wate-orange`/`--wate-orange-dk` retirés.
- `web/css/admin-db.css` v1.2.1 : `10pt` → `0.833rem`, `max-height: 680px` → `80vh`.
- `web/css/docs.css` v1.4.1 : `scroll-margin-top: 80px` → `5em`.
- `web/custom/wate-mcd/def.css` v2.2.3 : commentaire grid obsolète corrigé.
- Conventions CSS documentées (`rem`/`em`/`px`).

### Ajouté
- `CHANGELOG.md` (EN) + `CHANGELOG.fr.md` (FR) : historique complet du projet (v1.5.0 → v3.19.3).
- `test/test-content.sh` : 68 assertions structure/i18n/CSS/JS pour pages admin + vitrine.

---

## [v3.19.2] — 2026-05-03

### Corrigé
- `_core.js` — LEAVE `dbRequest()` déplacé dans le callback asynchrone (était synchrone avant exécution SQL).
- `_data.js` — Cache key `substring(0,50)` sur `req.query.table` (pollution LRU).
- `_log.js` — `isTTY` caché au niveau module (évite un accès propriété à chaque `print()`).
- `css/admin-auth.css` — Version header synchronisée avec le footer (1.5.0 → 1.5.1).
- `custom/icon-menu/def.js` — `margin:20px` → `1.25rem` (responsive). `alt` ajouté sur `<img>` (accessibilité).
- `scripts/admin-db.js` — Callbacks `function()` résiduels → arrow functions.

### Accepté (limitations documentées)
- `_audit.js` — TOCTOU dans la capture d'audit (atténué par SQLite single-writer).
- `engine.js` — `donePromises` ignorées après timeout 5s (intentionnel, évite blocage shutdown).
- `_auth.js` — Compte créé même si `_sendTokenMail` échoue (design : l'utilisateur peut redemander).
- `_mail.js` — Variables module-level incompatibles multi-instance (cas rare).
- `custom/modal-popup/def.js` — `innerHTML` sans validation (API appels de confiance uniquement).
- `_db.js` — Parsing filtres cassé si valeur contient `,` ou `:` (admin-only, edge case).
- `_utils.js` — `require('./_core')` dans `glossaryItem()` à chaque appel (dépendance circulaire évitée).

---

## [v3.19.1] — 2026-05-02

### Corrigé
- **#6** `scripts/search.js` + `views/search.ejs` — XSS via protocole `javascript:` bloqué par `safeUrl()`.
- **#7** `engine.js` — `NaN` ne passe plus la validation du port (`isNaN`).
- **#8** `_utils.js` — `String()` protège `req.query.lang` contre les tableaux Express/qs.
- **#9** `_modules.js` — Path traversal `..` bloqué dans les noms de modules.
- **#10** `_modules.js` — `Object.prototype.hasOwnProperty.call()` sécurise l'accès aux propriétés.
- **#11** `_migration.js` — Échec de trigger → FATAL log, ne rejette plus la migration.
- **#12-13** `scripts/admin-stats.js` — Null-checks `getElementById` ajoutés dans le bloc catch et `btn-refresh`.
- **#14** `scripts/admin-db.js` — `{once:true}` sur le listener `admin-row:done` (évite empilement).
- **#15** `custom/admin-row/def.js` — `textarea` rendu correctement (type dédié).
- **#16** `_db.js` — Mass assignment `file.fieldname` avec garde-fou.
- **#17** `_search.js` — Route publique `/api/search` avec `scopeSQL` par défaut (contenu public uniquement).
- **#18** `scripts/admin-auth.js` — `X-CSRF-Token` ajouté à `adminSignout()` API.

### Modifié
- Doc: `_data.js`, `architecture.md`, `architecture.fr.md`, `site-docs.ejs`.
- Harmo: "Web as Table Engine" partout, CLI `node engine.js`.

---

## [v3.19.0] — 2026-05-02

### Corrigé
- **#1** `_data.js` — Injection SQL via `${...}` dans les queries JSON (valeurs JSON-échappées, objets/fonctions rejetés).
- **#2** `views/common.ejs` — XSS `</script>` dans `JSON.stringify` (`.replace(/\//g, '\\/')`).
- **#3** `engine.js` — Rate limiter : éviction inline >10000 IPs au lieu du bypass. Compteur `_postRateCount`.
- **#4** `engine.js` — `PRAGMA foreign_keys` : `reject()` au lieu de FATAL log seul (démarrage bloqué si FK inactif).
- **#5** `_data.js` — VM sandbox : `resolveParams` rejette objets et fonctions (barrière anti-sandbox-escape Node < 10).

---

## [v3.18.0] — 2026-05-01

### Corrigé
- Engine: `_close()` try-catch, `argv.name` nettoyé.
- XSS: snippet échappé dans `search.js` + `search.ejs`, `</script>` neutralisé dans `admin-db.ejs`, `esc()` unifié.
- `_data.js`: mutation `req.body` éliminée, `urls.find()` dédoublonné.
- `_log.js`: ANSI conditionné à `process.stdout.isTTY`.
- `_apikey.js`: prefix SELECT, `req.cookies` garde-fou.
- `_auth.js`: verify-invalid, hash dummy adaptatif, var→const, callback arrow, LEAVE dans callback.
- `_modules.js`: regex backtracking fix.
- `_cron.js`: constante `PURGE_TOKENS_S`.
- `custom/admin-row`: `_collectBody` textarea/checkbox/radio, resize largeurs.
- `custom/show-image`: `isConnected`.
- `admin-auth.ejs`: `_RE_MSG` majuscule.
- `scripts/admin-stats`: null-check `getElementById`.

---

## [v3.17.2] — 2026-04-30

### Corrigé
- `_core.js`: `\p{L}` → `\w` (compat Node 4.6.1).
- `custom.js`: `const`→`let` attr réassigné.
- `show-image/def.js`: 2 `const`→`let` manquants.
- `engine.js`: `--root` validé, `argv.path` null guard.
- `csrf.js`: sélecteur Safari compatible.
- `_data.js`: PK falsy (0, "", false), `resolveParams` JSON.stringify, `done()` try-catch.
- `_auth.js`: `verified` NULL-safe, INSERT colonnes nommées, rate limit signin 10/min/IP.
- `_apikey.js`: session ORDER BY, INSERT colonnes nommées.
- `_audit.js`: PK "" → null fix.
- `_migration.js`: triggers après échec, async init.
- `_modules.js`: `init()` async support + timeout.
- Shutdown/close: timeout 5s, try-catch `done()`.

### Ajouté
- `POST /admin/api/auth/verify/resend` + formulaire.
- Glossaire `verify-resend*`.
- Middleware d'erreur Express (capture exceptions sans divulguer la stack trace).
- `DELETE`/`UPDATE` sans PK → bloque 400.
- `_migration.js` — `_core.log.WARN` → `WARNING`.

---

## [v3.16.1] — 2026-04-29

### Corrigé
- `_apikey.js` — `key.length < 70` → `!== 69`. LIKE injection prefix DELETE. Validation regex.
- `common.ejs` + `engine.js` — `for...in` → `Object.keys().forEach()`. `encodeURIComponent()` sur query params.
- `icon-menu/def.js` — `innerHTML` → `textContent` (anti-XSS).
- `error.ejs` — `<%-` → `<%=` glossaryItem.
- `_db.js` — `csvEscape` préfixe `'` anti-injection formules CSV.
- `_audit.js` — SQL d'abord, audit ensuite (évite entrées `_audit` orphelines).
- `_data.js` — `unregisterTableWriteHook` + cleanup dans `_audit.done()`.
- `_cron.js` — Double `init()` safe (`done()` avant nouvelle création).
- `_stats.js` — `for...in` → `Object.keys`.
- `session.id` cohérence type (string `'0'` partout).
- `_shutdown`/`_close` gèrent `done()` async (collecte Promises, `Promise.all()`).
- `_migration.js` — DROP TRIGGER erreurs logguées.
- `_core.js` — `dbRequest` callback wrappé try-catch.

### Modifié
- Code bancal: `_RE_TABLE` unifié, `boundedCache.get()` single lookup, `_SQLS` module-level, `_search.js` scope/minList, `_postRateBuckets` garde-fou >10000 IPs, FTS5 `-` filtré, `_modules.js` API restreinte pour `--ejs`.

---

## [v3.16.0] — 2026-04-28

### Ajouté
- **Undo** — `POST /admin/api/db/:table/undo` annule la dernière écriture. L'owner peut annuler toute écriture avec `?all=true`.

---

## [v3.15.1] — 2026-04-27

### Ajouté
- Tri/recherche/filtrage sur API CRUD (`?sort=`, `?search=`, `?filter=`).
- Export CSV/JSON (`?format=csv`).
- Modules: `audit` (journal des écritures), `search` (FTS5), `apikey` (Bearer tokens), `cron` (purges périodiques).
- Health check `GET /health`.
- `getTableWriteHook` exposé.
- Whitelist `executeAction`.

### Corrigé
- Commentaires et LEAVE asynchrone.

---

## [v3.12.2] — 2026-04-26

### Ajouté
- **CSRF renforcé** — Token = `SHA256(sessionId + secret)`. Secret aléatoire à chaque redémarrage (rotation automatique). Surchargeable via `WATE_CSRF_SECRET`.

---

## [v3.12.1] — 2026-04-25

### Ajouté
- `_user.verified` + `_user_token` (flows verify/forgot/reset).
- Custom element `modal-popup` (remplace `alert()`/`confirm()` natifs).

### Modifié
- Migration `var` → `const`/`let`.

---

## [v3.12.0] — 2026-04-24

### Ajouté
- Module mail (`_mail.js`, dégradation gracieuse via nodemailer optionnel ≥2.3.2).
- Migration `004_mail.sql`.

### Modifié
- Alignement version `engine.js` sur `package.json` (source de vérité publique).

---

## [v3.11.0] — 2026-04-23

### Modifié
- `dbRequest` définie dans `_core.js`, setter pour injection privée `_core_db`.

---

## [v3.10.1] — 2026-04-22

### Corrigé
- Lecture de `_config` après migration — hydrate `_core.config` et redimensionne les caches LRU.

---

## [v3.10.0] — 2026-04-21

### Modifié
- **Restructuration architecturale** — Single Responsibility.
- Moteur de migration externalisé dans `_migration.js`.
- Chargeur de modules externalisé dans `_modules.js` (Promise `load`).
- Flux d'initialisation 100% asynchrone via Promises.
- Hydratation différée des variables CSP (Closure pattern).

---

## [v3.9.0] — 2026-04-20

### Ajouté
- **Moteur de migration SQL** — exécution séquentielle des `.sql` non appliqués.

---

## [v3.8.0] — 2026-04-19

### Ajouté
- **Middleware CSRF** — token requis sur toutes les requêtes modifiantes (POST/PUT/DELETE).

---

## [v3.7.1] — 2026-04-18

### Corrigé
- Regex statiques évaluées une seule fois (`test()` au lieu de `match()`).
- IP rate-limit : suppression uniquement des IP inactives depuis 60s.

---

## [v3.7.0] — 2026-04-17

### Modifié
- `serve()` (ex-`pageData`) + `buildSelectSQL` + `_queriesCache` + `vm` migrés dans `_data.js`.
- `jsHandlers` déplacé dans `app.locals` (per-instance).
- `views/common.ejs` : template maître — charte graphique unifiée.

---

## [v3.6.0] — 2026-04-16

### Modifié
- `adminSession`, `tableHooks`, `SESSION_TTL_S` initialisés dans `app.locals` (état per-instance isolé du singleton `_core`).

---

## [v3.4.0] — 2026-04-15

### Modifié
- `loadModules` — syntaxe unifiée `name[:alias][=param]` pour `--mod` et `--ejs`.
- Appel automatique de `module.init(param)` et `module.done()`.
- Modules engine renommés `_auth.js`/`_db.js`.
- `_core.EJSs` ajouté.

---

## [v3.3.0] — 2026-04-14

### Modifié
- `modifyTable`, `reduceImageSize`, `upload`, `_tableInfoCache` déplacés dans `_db.js`.
- `multer` et `jimp` retirés de `engine.js`.

---

## [v3.2.0] — 2026-04-13

### Ajouté
- **Modules engine optionnels** — auth et db extraits dans `scripts/`.
- Chargement via `init({ mod: [...] })` ou `--mod name=param,...`.

---

## [v3.1.2] — 2026-04-12

### Corrigé
- `pageData` — UNION Part 2 redessinée, session expirée correctement détectée.

---

## [v3.1.1] — 2026-04-11

### Ajouté
- Option `init({ sessionTTL })` — priorité sur `--mod`, utile pour les tests.

---

## [v3.1.0] — 2026-04-10

### Ajouté
- **Administration intégrée** — API JSON + UI EJS surchargeables.
- Convention profils UNIX : owner=0 (root), anonymous=9999.
- `_adminSession(req, res, cb)` — middleware de vérification de session.
- Routes API JSON : `POST /admin/api/auth/signin|signout`, `GET|PUT|DELETE /admin/api/auth/me`, `GET /admin/api/db/schema`, `GET|POST|PUT|DELETE /admin/api/db/:table`.
- Routes UI EJS : `GET /admin/auth|me|db|db/:table`.
- `_adminHashPassword` — PBKDF2 partagé.

---

## [v3.0.0] — 2026-04-09

### Ajouté
- **Mode bibliothèque** — `module.exports = { init }`.
- `init(options)` retourne `Promise<{app, db, server?, close}>`.
- `':memory:'` accepté comme DB (tests).
- `_parseArgv()` extrait.

### Modifié
- `process.exit()` remplacé par `throw`/`reject()` dans `init()`.
- `SIGTERM`/`SIGINT` enregistrés uniquement en mode CLI.

---

## [v2.15.2] — 2026-04-08

### Corrigé
- Double appel `_glossaryCache.get(lang)` évité.
- Limite DoS : 10 Mo max, 5 fichiers max pour les uploads.

---

## [v2.15.0] — 2026-04-07

### Modifié
- Cache LRU : implémentation via `Map` ES6 (O(1) eviction).

---

## [v2.14.0] — 2026-04-06

### Corrigé
- `pageData` : logique UNION corrigée (404/401 discriminés correctement).
- `_cspScriptSrcBase` réellement utilisé dans `setSecurityHeaders`.
- `_core.app.listen` : erreurs de démarrage capturées via `server.on('error')`.
- Code mort supprimé après `return` dans `reduceImageSize`.
- `sessionId` harmonisé en string `'0'`.
- `delete req.body.email` déplacé après la boucle PK.

### Ajouté
- `_boundedCache` : factory LRU bornée pour `_glossaryCache`, `_queriesCache`, `_tableInfoCache`.
- Rate limiter : token bucket remplace la fenêtre fixe.
- HSTS : `Strict-Transport-Security` dans `setSecurityHeaders`.
- Doxygen : commentaires sur toutes les fonctions, variables et routes.

---

## [v2.13.4] — 2026-04-05

### Corrigé
- Suppression de `_core.app.use(upload.array())` qui interceptait les formulaires avant la route POST.

---

## [v2.13.0] — 2026-04-04

### Modifié
- UNION pour déterminer si une page existe ET si elle existe pour le profil de l'utilisateur.

### Corrigé
- Colonne `request` de `_access` renommée `request_name`.
- Droit d'accès via `IN(request, baseRight)` au lieu de `LIKE`.

---

## [v2.12.2] — 2026-04-03

### Corrigé
- Validation session par présence cookie + objet session + ID.
- `eval()` et `Function()` neutralisés dans la sandbox VM.
- Parsing préventif du nom de table dans `modifyTable`.

---

## [v2.12.0] — 2026-04-02

### Modifié
- `reduceImageSize` : `image-size` retiré, `image.bitmap` utilisé directement.
- CSP : partie statique pré-calculée au démarrage (`_cspStatic`).

### Corrigé
- `pageData` : 401 si session expirée, 404 si page absente.

---

## [v2.11.2] — 2026-04-01

### Corrigé
- `A.request` → `A.request_name` dans `modifyTable`.
- Sanitization `lang` dans `httpError`.
- Chemin favicon relatif → absolu.
- Triggers SQLite sans callback → erreurs silencieuses.
- Ordre des répertoires de vues inversé.

---

## [v2.11.0] — 2026-03-31

### Ajouté
- `res.headersSent` guard dans `httpError`.
- Arrêt propre `SIGTERM`/`SIGINT`.
- Code 429 (rate limiting POST).
- Cache glossaire par langue.
- Rate limiting POST intégré (30 req/min/IP).

---

## Versions antérieures (v1.5.0 — v2.10.3)

### Ajouté
- PRAGMA `foreign_keys`, `journal_mode=WAL`, `busyTimeout`.
- `SESSION_TTL_S` centralisé.
- Routes statiques `engine/custom/`, `engine/images/`, `engine/css/`.
- `minimist` pour le parsing CLI.
- Validation port TCP (1-65535).
- `trust proxy` pour reverse proxy HTTPS.

### Corrigé
- `httpError` 401 → `next='signin'`.
- Erreurs de rendu interceptées.
- `console.log` debug supprimé.
- `buildSelectSQL()` extrait.

### Modifié
- `modifyTable` et `pageData` dans `engine.js` (avant migration vers `_data.js`/`_db.js`).
- `views` Express accepte un tableau (moteur + app).
---
