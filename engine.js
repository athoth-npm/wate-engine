/**
 * \file      (WaTE) engine.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/09/2025
 * \version   3.19.5
 * \brief     Points d'entrée des requêtes HTTP pour servir des applications Web
 *
 * \details   v1.5.0 : PRAGMA foreign_keys → db.run() avec callback d'erreur.
 *                     reduceImageSize : resolve() déplacé dans le callback de fs.rename ;
 *                       throw err → reject(err) pour propager dans la Promise.
 *                       console.log debug supprimé.
 *                     buildSelectSQL() extrait — remplace le one-liner IIFE illisible.
 *                     Vérification d'expiration de session (S.issued) ajoutée dans
 *                       modifyTable et pageData.
 *                     SESSION_TTL_S centralisé — doit correspondre à maxAge du cookie.
 *            v1.6.0 : httpError 401 → next='signin' ajouté — session expirée
 *                       redirige vers /signin au lieu de history.back().
 *                     SESSION_TTL_S sans valeur par défaut — undefined si aucun
 *                       module ne gère les sessions ; clauses d'expiration
 *                       désactivées dans ce cas, accès via profil_id uniquement.
 *            v1.7.0 : multer dest — chemin relatif corrigé en path+'store'.
 *            v1.8.0 : Limitation MIME documentée. fs retiré de res.render
 *                     → à remplacer par un module -ejs dédié par application.
 *            v1.9.0 : path ajouté dans res.render — permet aux EJS de construire
 *                     des chemins absolus via EJSs['fs-tools'].readdirSync(path+...).
 *            v2.0.0 : route statique engine/custom ajoutée avant celle de
 *                     l'application — custom.js, icon-menu/def.js et show-image/def.js
 *                     sont partagés entre toutes les applications. Le def.css de
 *                     chaque application surcharge le commun (même chemin, Express
 *                     sert le premier fichier trouvé).
 *            v2.1.0 : error.ejs et error.js mutualisés dans engine/views/ et
 *                     engine/scripts/ — _core.app.set(views) accepte un tableau (Express 4)
 *                     et engine/scripts/ est servi avant l'application.
 *                     engine/scripts/ ajouté comme route statique commune.
 *            v2.2.0 : route engine/custom corrigée — préfixe /custom ajouté pour
 *                     que icon-menu/def.js soit à /custom/icon-menu/def.js.
 *                     custom.js déplacé dans engine/scripts/ (pas engine/custom/).
 *            v2.3.0 : upload.array() middleware global restauré.
 *            v2.4.0 : _core.app.set('trust proxy', 1) — Squid reverse proxy HTTPS.
 *            v2.7.0 : dbRequest, glossaryItem, buildSelectSQL, httpError, pageData
 *                     déplacés avant loadModules(-mod) — dépendances résolues avant
 *                     chargement des modules. _core.app.listen déplacé après les routes.
 *                     HTTP_ERRORS map statique — httpError rend error.ejs directement
 *                     sans redirection vers /error. Charge le glossaire depuis la DB
 *                     si disponible — sinon TAG brut + code HTTP.
 *                     Routes statiques engine/images/ et engine/css/ ajoutées —
 *                     images d'erreur centralisées, error.css surchargeables.
 *            v2.8.0 : PRAGMA journal_mode=WAL — SQLite mode delete causait
 *                     des blocages aléatoires quand home et nav (iframe) faisaient
 *                     des requêtes DB simultanées (SQLITE_BUSY → onglet bloqué).
 *            v2.9.1 : Les erreurs de rendu sont interceptées pour garder le layout.
 *            v2.10.0: On utilise le module 'minimist' pour parser la ligne de commande.
 *                     Les options sont précédées d'un double '-' au lieu d'un unique '-'.
 *            v2.10.1: Vérification avancée des options de la ligne de commande.
 *            v2.10.2: Ajout de 'use strict' et globals explicites pas global.* = ...
 *            v2.10.3: Vérification de la valeur du port TCP (1-65535).
 *                     On fixe une limite de timeout à 5s pour que la DB réponde.
 *            v2.11.0: res.headersSent guard dans httpError — évite double réponse
 *                       si une erreur survient après le début du streaming.
 *                     Arrêt propre SIGTERM/SIGINT — db.close() + process.exit(0).
 *                     errorNext 'none' dans HTTP_ERRORS pour les codes sans
 *                       redirection (403,405,410,413,500,502,503,504) — évite
 *                       history.back() non désiré. Nécessite error.js v2.1.0.
 *                     Code 429 ajouté à HTTP_ERRORS (rate limiting POST).
 *                     Cache glossaire par langue (_glossaryCache) — évite un
 *                       SELECT _glossary à chaque appel httpError.
 *                     vm.createContext factorisé une fois par requête dans pageData
 *                       — évite une allocation V8 par query JSON.
 *                     Cache des queries JSON par URL (_queriesCache) — évite
 *                       JSON.parse à chaque GET sur la même page.
 *                     Rate limiting POST intégré (30 req/min/IP) sans dépendance
 *                       — protège modifyTable des rafales et de la force brute.
 *                     Log RUN 'LEAVE modifyTable' déplacé en fin de callback
 *                       réel — trace désormais la durée effective de l'opération.
 *                     reduceImageSize : fs.unlink du fichier '-mini' partiel en
 *                       cas d'erreur de renommage — évite les orphelins dans store/.
 *            v2.11.1: Modification des 'next' du map des erreurs.
 *            v2.11.2: BUG A.request → A.request_name dans modifyTable (colonne inexistante).
 *                     BUG sanitization lang dans httpError : replace remplaçait par 'fr'
 *                       au lieu de supprimer — langue fantôme possible.
 *                     BUG chemin favicon relatif → absolu (cohérence avec les autres ressources).
 *                     BUG triggers SQLite sans callback → erreurs silencieuses au démarrage.
 *                     BUG ordre des répertoires de vues inversé — les vues applicatives
 *                       ne pouvaient pas surcharger celles du moteur.
 *                     STYLE == → === dans doSql (cohérence avec 'use strict').
 *            v2.12.0: reduceImageSize : imageSize() supprimé — image.bitmap.{width,height}
 *                       déjà disponible après jimp.read(), évite une I/O disque redondante.
 *                       Dépendance 'image-size' retirée.
 *                     _postRateInterval référencé — clearInterval() dans _shutdown()
 *                       pour un arrêt propre sans mutation post-fermeture.
 *                     CSP : partie statique pré-calculée au démarrage (_cspStatic) —
 *                       seul le nonce est reconstruit par requête.
 *                     pageData : 401 uniquement si la session est expirée (issued),
 *                       404 si la page n'existe dans aucun profil — distingue session
 *                       expirée / profil sans accès / page absente.
 *            v2.12.1: La colonne echeance de la table _session est renommée issued.
 *            v2.12.2: - On valide une session par la présence d'un cookie, d'un objet session
 *                       et d'un ID.
 *                     - On neutralise explicitement eval() et Function() dans la sandbox
 *                     - Parsing préventif du nom de la table dans modifyTable.
 *            v2.13.0: On utilise une UNION pour déterminer si une page existe et si elle
 *                     existe pour le profil de l'utilisateur.
 *                     On forme expiryClause complètement en évitant plusieurs instructions et tests.
 *            v2.13.1: la clef du cache dépend de la page ET du profil.
 *            v2.13.2: - La colonne 'request' de la table '_access' a été renommée 'request_name'.
 *                     - On ne fait plus un request_name LIKE pour connaître le droit d'accès,
 *                       on utilise IN avec deux valeurs => request_name et request_name + '-self'
 *            v2.13.3: email est une colonne de référence obligatoire dans les tables pour
 *                     toutes les opérations 'update-self' et 'delete-self'.
 *            v2.13.4: Suppression de la ligne _core.app.use(upload.array()) qui interceptait
 *                     les formulaires avant la fonction POST /:request/:table !
 *            v2.14.0: Corrections multiples et améliorations :
 *                     - FIX pageData : logique UNION corrigée —
 *                         items.length === 0 → 404 garanti (page inexistante) ;
 *                         items.length === 1, value null → id session inconnu, clearCookie + 401 ;
 *                         items.length === 1, value === 0 → mauvais profil, cookie conservé + 401.
 *                     - FIX _cspScriptSrcBase réellement utilisé dans setSecurityHeaders
 *                         (était déclarée mais ignorée — cspBase['script-src'].join()
 *                         était recalculé à chaque requête).
 *                     - FIX _core.app.listen : erreurs de démarrage (port occupé, permissions)
 *                         capturées via server.on('error') — le callback de _core.app.listen
 *                         ne reçoit jamais d'argument err.
 *                     - FIX code mort supprimé après return dans reduceImageSize.
 *                     - FIX sessionId harmonisé en string '0' dans modifyTable
 *                         (cohérence avec pageData et le type TEXT de _session.id).
 *                     - FIX delete req.body.email déplacé après la boucle PK dans
 *                         modifyTable — évite l'échec 400 si email est aussi PK.
 *                     - FIX lang sanitisé dans pageData (même logique que httpError).
 *                     - NOTE vm : contextCodeGeneration ignoré sous Node < 10 —
 *                         seules eval:undefined et Function:undefined sont actifs.
 *                     - _boundedCache : factory LRU bornée remplace les maps nues {}
 *                         pour _glossaryCache, _queriesCache et _tableInfoCache.
 *                     - Rate limiter : token bucket remplace la fenêtre fixe —
 *                         évite le burst en bordure de fenêtre (30 req en 2s).
 *                     - HSTS : Strict-Transport-Security ajouté dans setSecurityHeaders.
 *                     - Promise.all : Object.keys() rend le couplage index/résultat explicite.
 *                     - Doxygen : commentaires ajoutés sur toutes les fonctions,
 *                         variables et routes.
 *            v2.15.0: Implémentation d'une vrai LRU en utilisant Map().
 *            v2.15.1: On effite d'appeler deux fois _glossaryCache.get(lang).
 *            v2.15.2: - On évite d'appeler deux fois le cache LRU dans pageData().
 *                     - On fixe une limite pour éviter les attaques DoS 10 Mo max, 5 fichiers max.
 *            v3.0.0 : Passage de script à bibliothèque importable.
 *                     - Tout le code de démarrage encapsulé dans init(options).
 *                     - process.exit() remplacé par throw/reject dans init() —
 *                         le processus de test n'est plus tué.
 *                     - _parseArgv() extrait — CLI lit process.argv, tests passent options.
 *                     - init() retourne une Promise<{app,db,server?,close}>.
 *                     - ':memory:' accepté comme db — bypass fs.existsSync pour les tests.
 *                     - SIGTERM/SIGINT enregistrés uniquement en mode CLI.
 *                     - module.exports = { init }
 *            v3.1.0 : Administration intégrée — API JSON + UI EJS surchargeables.
 *                     - Convention profils UNIX : owner=0 (root), anonymous=9999.
 *                       Tout piloté par _access — aucun test hard-codé sur profil_id.
 *                     - _adminSession(req, res, cb) : middleware interne vérifiant
 *                       la session et retournant { email, profil_id, lang_id }.
 *                     - Routes API JSON (/admin/api/...) :
 *                         POST   /admin/api/auth/signin   — authentification PBKDF2
 *                         POST   /admin/api/auth/signout  — déconnexion
 *                         GET    /admin/api/auth/me       — profil courant
 *                         GET    /admin/api/db/schema     — liste des tables accessibles
 *                         GET    /admin/api/db/:table     — SELECT paginé (offset/limit)
 *                         POST   /admin/api/db/:table     — INSERT
 *                         PUT    /admin/api/db/:table     — UPDATE
 *                         DELETE /admin/api/db/:table     — DELETE
 *                     - Routes UI EJS (/admin/...) :
 *                         GET    /admin/auth              — rendu views/admin-auth.ejs
 *                                                           si session valide → redirect ?next ou /admin/me
 *                         GET    /admin/me                — rendu views/admin-me.ejs (landing post-login)
 *                         GET    /admin/db                — rendu views/admin-db.ejs (liste des tables)
 *                         GET    /admin/db/:table         — rendu views/admin-data.ejs (CRUD)
 *                       Les vues sont cherchées dans l'app d'abord, fallback moteur.
 *                       Les routes UI protégées redirigent vers /admin/auth?next=<path>.
 *                     - _adminHashPassword(sha256pwd, email, cb) : PBKDF2 partagé avec
 *                       session-routes.js (même paramètres, même sel déterministe).
 *            v3.1.1 : Option init({ sessionTTL }) — priorité sur --mod, utile pour les tests
 *                       sans charger session-routes.js. Corrige les sessions expirées
 *                       non détectées quand SESSION_TTL_S reste undefined.
 *            v3.1.2 : FIX pageData — items.length === 0 (→ 404) inatteignable car la Part 2
 *                       de la UNION retournait toujours au moins une ligne.
 *                       Part 2 redessinée : GROUP BY P.url sans filtre URL, valeur
 *                       MAX((profil_id=subq)*(1+profil_id)) — NULL/0/≥1 discriminent
 *                       session fantôme, mauvais profil et accès accordé.
 *                       Session expirée détectée par Part 1 vide quand Part 2 ≥ 1.
 *            v3.2.0 : Modules engine optionnels — auth et db extraits dans scripts/.
 *                       Chargés via init({ mod: ['auth=TTL', 'db'] }) ou --mod auth=TTL,db.
 *                       SESSION_TTL_S retiré de la closure — géré par authMod.SESSION_TTL_S.
 *                       argv.sessionTTL supprimé — durée de session = paramètre du module auth.
 *                       loadModules étendu : tableau en mode bibliothèque, syntaxe name=param,
 *                         modules engine depuis __dirname/scripts/, applicatifs depuis argv.path/scripts/.
 *            v3.3.0 : modifyTable, reduceImageSize, upload et _tableInfoCache déplacés dans db.js.
 *                       La route POST /:request/:table appartient au module db — les accès
 *                       sont validés par _access, comme toutes les autres routes db.
 *                       multer et jimp retirés de engine.js.
 *            v3.4.0 : loadModules — syntaxe unifiée name[:alias][=param] pour --mod et --ejs.
 *                       Retourne l'objet plat { alias: module }.
 *                       Appel automatique de module.init(param) si la fonction est exportée.
 *                       Appel de module.done() dans _shutdown et _close pour tous les mods.
 *                       Initialisation auth déplacée dans _auth.js init() — plus dans engine.js.
 *                       _core.EJSs = EJSs ajouté — était manquant (auth/db utilisaient _core.EJSs null).
 *                       Modules engine renommés auth.js/db.js → _auth.js/_db.js.
 *                       Chemin engine mods : __dirname/name → __dirname/_name.
 *                       FIX adminLang(req) → _utils.adminLang(req) dans GET /.
 *                       FIX global.app → _core.app dans resolve().
 *            v3.6.0 : adminSession, tableHooks, SESSION_TTL_S initialisés dans app.locals
 *                       après express() — état per-instance isolé du singleton _core.
 *            v3.7.0 : serve() (ex-pageData) + buildSelectSQL + _queriesCache + vm migrés
 *                       dans _data.js. engine.js délègue toutes les routes GET à _data.serve().
 *                       jsHandlers : registre des handlers JS escape — déplacé de _core singleton
 *                       vers app.locals.jsHandlers (per-instance, comme adminSession/tableHooks).
 *                       Un handler absent dans une instance retourne 404 sans polluer les autres.
 *                       serve() : fallback profil — quand l'utilisateur n'a aucune entrée _page
 *                       pour l'URL, charge les items de n'importe quel profil ; si elements.JS est
 *                       défini et le handler enregistré, délègue l'auth au handler (redirect/401) ;
 *                       si le handler n'est pas enregistré pour cette instance, retourne 401.
 *                       views/common.ejs : template maître — charte graphique unifiée,
 *                       inclusion du fragment elements.template.
 *                       engine.sql v1.4.0 : items JS décommentés pour les pages admin auth
 *                       (listes 1/2/3) — permettent à serve() d'invoquer les jsHandlers auth.
 *             v3.7.1 : regex affecté en dehors de la fonction => évalué 1 seulle fois
 *                      test() au lieu de match() pour éviter la contruction d'un tableau
 *                      Ne supprime que les IP qui n'ont pas fait de requête depuis 60s.
 *             v3.8.0 : Middleware exigeant un token CRSF (Cross-Site Request Forgery) valide.
 *             v3.9.0 : Moteur de migration SQL
 *             v3.10.0: Restructuration architecturale majeure (Single Responsibility).
 *                      - Moteur de migration externalisé dans _migration.js (apply).
 *                      - Chargeur de modules externalisé dans _modules.js (Promise load).
 *                      - Flux d'initialisation 100% asynchrone via Promises.
 *                      - Hydratation différée des variables CSP (Closure pattern) pour
 *                        garantir le montage sécurisé des middlewares Express.
 *             v3.10.1: Lecture de _config après migration — hydrate _core.config et
 *                      redimensionne les caches LRU (tableInfo, fkList, queries).
 *                      log.level reste CLI uniquement (fixé avant ouverture DB).
 *             v3.11.0: dbRequest est définie dans _core.js. On utilise un setter pour
 *                       initialiser _core_db qui devient privée au module.
 *             v3.12.0: Alignement de la version engine.js sur package.json (source de
 *                       vérité publique). À partir de maintenant, toute release
 *                       package.json vX.Y.Z bump engine.js à la même valeur.
 *                       Couvre les ajouts : module mail (_mail.js, dégradation
 *                       gracieuse via nodemailer optionnel >=2.3.2), migration 004
 *                       _mail.sql.
 *            v3.12.1 : migration var → const/let.
 *                       (_user.verified, _user_token, flows verify/forgot/reset),
 *                       custom element modal-popup (remplace alert/confirm natifs).
 *            v3.12.2 : CSRF renforcé — token = SHA256(sessionId + secret).
 *                       Secret aléatoire à chaque redémarrage (invalide les
 *                       anciens tokens). Surchargeable via WATE_CSRF_SECRET
 *                       (tests). Sans le secret, un attaquant connaissant le
 *                       sessionId ne peut pas forger de token valide.
 *            v3.15.1 : Tri/recherche/filtrage sur API CRUD + export CSV/JSON.
 *                     Modules audit, search (FTS5), apikey (Bearer),
 *                     cron (purges). Health check /health. Whitelist
 *                     executeAction. getTableWriteHook. Corrections
 *                     commentaires et LEAVE asynchrone.
 *            v3.16.0 : Undo — POST /admin/api/db/:table/undo annule la
 *                     dernière écriture (insert/update/delete) en
 *                     restaurant la ligne via les données capturées
 *                     par le module audit. L'owner peut annuler toute
 *                     écriture avec ?all=true.
 *            v3.16.1 : FIX _apikey.js — key.length < 70 → !== 69.
 *                     Une clé valide = 'wate_' (5) + 64 hex = 69.
 *                     < 70 toujours vrai → middleware bypassé.
 *                     FIX _apikey.js — LIKE injection prefix DELETE.
 *                     Validation regex /^wate_[0-9a-f]{7}$/ avant
 *                     suppression. % et autres patterns rejetés 400.
 *                     FIX common.ejs + engine.js — for...in sans
 *                     hasOwnProperty → Object.keys().forEach()
 *                     (buildMenu, mergeCsp, _postRateBuckets,
 *                     _shutdown, _close, hydratation CSP).
 *                     encodeURIComponent() sur valeurs query params
 *                     (anti-injection menu via | et ,).
 *                     FIX icon-menu/def.js — innerHTML → textContent
 *                     sur le label (anti-XSS).
 *                     FIX error.ejs — <%- → <%= glossaryItem()
 *                     (sortie non échappée, injection HTML possible).
 *                     FIX _db.js csvEscape — préfixe ' anti-injection
 *                     formules CSV (= + - @) à l'export.
 *                     FIX _audit.js — SQL d'abord, audit ensuite
 *                     (writeAuditRecord après next) : évite les
 *                     entrées _audit orphelines si le SQL échoue.
 *                     Ajout unregisterTableWriteHook (_data.js) +
 *                     cleanup dans _audit.done() — évite accumulation
 *                     de hooks si init() rappelée.
 *                     FIX _cron.js — double init() safe : done()
 *                     appelé en début d'init() pour stopper les
 *                     anciens setInterval avant d'en créer.
 *                     FIX _stats.js — for...in → Object.keys.
 *                     FIX session.id cohérence type — _session.id
 *                     est TEXT. getSession() initialise '0' (string).
 *                     Tous les === 0 → === '0' (_auth, _data, _audit,
 *                     CSRF engine.js).
 *                     _shutdown/_close gèrent done() async —
 *                     collecte des Promises, Promise.all()
 *                     avant db.close().
 *                     FIX _migration.js — DROP TRIGGER erreurs
 *                     logguées (res(err) avalait l'erreur).
 *                     FIX _core.js dbRequest — callback wrappé
 *                     try-catch (anti-crash si exception).
 *                     Code bancal: _RE_TABLE unifié (_utils),
 *                     boundedCache.get() single lookup,
 *                     _SQLS module-level, _search.js scope/minList,
 *                     _postRateBuckets garde-fou >10000 IPs,
 *                     FTS5 - filtré, _modules.js API restreinte
 *                     pour --ejs, <form> hors <p> admin-auth.
 *            v3.17.1 : Sprint corrections ANALYSIS.md — top 5 + bugs :
 *                     - _core.js: \p{L} → \w (compat Node 4.6.1)
 *                     - custom.js: const→let attr réassigné
 *                     - show-image/def.js: 2 const→let manquants
 *                     - engine.js: --root validé, argv.path null guard
 *                     - csrf.js: sélecteur Safari compatible
 *                     - _data.js: PK falsy (0,"",false), resolveParams
 *                       JSON.stringify, done() try-catch
 *                     - _auth.js: verified NULL-safe, INSERT colonnes
 *                       nommées, rate limit signin 10/min/IP
 *                     - _apikey.js: session ORDER BY, INSERT colonnes
 *                     - _audit.js: PK "" → null fix
 *                     - _migration.js: triggers après échec, async init
 *                     - _modules.js: init() async support + timeout
 *                     - shutdown/close: timeout 5s, try-catch done()
 *                     Ajout POST /admin/api/auth/verify/resend +
 *                     /admin/form/auth/verify/resend + formulaire
 *                     admin-auth.ejs. Glossaire verify-resend*.
 *                     dans while → TypeError mode strict.
 *                     const → let (imagePrev + imageNext).
 *                     FIX _migration.js — _core.log.WARN → WARNING.
 *                     _log.js exporte WARNING, pas WARN.
 *                     FIX _data.js — DELETE/UPDATE sans PK : where
 *                     vide → table entière effacée. Bloque 400.
 *                     Ajout middleware d'erreur Express — capture
 *                     exceptions (JSON malformé...) sans divulguer
 *                     la stack trace, rend error.ejs 500.
 *            v3.18.0 : Sprint ANALYSIS.md v2 — 35 corrections :
 *                     - Engine: _close() try-catch, argv.name nettoyé.
 *                     - XSS: snippet échappé search.js+ejs, </script>
 *                       neutralisé admin-db.ejs, esc() unifié.
 *                     - _data.js: mutation req.body éliminée,
 *                       urls.find() dédoublonné.
 *                     - _log.js: ANSI conditionné à isTTY.
 *                     - _apikey.js: prefix SELECT, req.cookies garde-fou.
 *                     - _auth.js: verify-invalid, hash dummy adaptatif,
 *                       var→const, callback arrow, LEAVE dans callback.
 *                     - _modules.js: regex backtracking fix.
 *                     - _cron.js: constante PURGE_TOKENS_S.
 *                     - admin-row: _collectBody textarea/checkbox/radio,
 *                       resize largeurs. show-image: isConnected.
 *                     - admin-auth.ejs: _RE_MSG majuscule. admin-stats:
 *                       null-check getElementById.
 *            v3.19.0 : Sprint ANALYSIS.md v4 — 5 correctifs critiques :
 *                     - #1 Injection SQL: valeurs resolveParams échappées
 *                       pour JSON (["\\]), objets/fonctions rejetés.
 *                     - #2 XSS </script>: common.ejs JSON.stringify protégé.
 *                     - #3 Rate limiter: éviction inline >10000 IPs au lieu
 *                       du bypass. Compteur _postRateCount.
 *                     - #4 PRAGMA foreign_keys: reject() au lieu de FATAL
 *                       log seul — démarrage bloqué si FK inactif.
 *                     - #5 VM sandbox: resolveParams rejette objets et
 *                       fonctions (barrière Node < 10 constructor chain).
 *            v3.19.1 : Sprint ANALYSIS.md v4 — 13 correctifs HIGH :
 *                     - #6 safeUrl() anti-javascript: dans search.js+ejs
 *                     - #7 NaN bloque validation port (isNaN)
 *                     - #8 String() protege req.query.lang contre array
 *                     - #9 path traversal .. bloque dans _modules.js
 *                     - #10 hasOwnProperty securise (Object.prototype)
 *                     - #11 trigger echec → FATAL log, pas rejet migration
 *                     - #12-13 getElementById null-checks admin-stats
 *                     - #14 {once:true} sur listener admin-db.js
 *                     - #15 textarea rendu correctement admin-row/def.js
 *                     - #16 mass assignment file.fieldname garde-fou
 *                     - #17 /api/search scopeSQL par defaut (public)
 *                     - #18 X-CSRF-Token ajoute a adminSignout()
 *                     Doc: _data.js, architecture.{md,fr.md}, site-docs.ejs
 *                     Harmo: Web as Table Engine partout, CLI node engine.js
 *            v3.19.2 : Sprint ANALYSIS.md final — MEDIUM #20 (cache key),
 *                     LOW #25-28, #31-32 corrigés. #19, #21, #23-24, #29-30,
 *                     #33 acceptés. ANALYSIS.md 33/33 traités.
 *            v3.19.3 : Audit CSS — variables --wate-* utilisées, box-sizing,
 *                     --wate-error, code mort nettoyé. Layout admin restauré
 *                     (fond, police, centrage). Logo modal vitrine --mp-icon-src.
 *                     CHANGELOG.md + CHANGELOG.fr.md + test/test-content.sh.
 *            v3.19.4 : Sprint ANALYSIS v5 — 11/28 corrigés (5 HIGH + 6 MEDIUM).
 *                     LEAVE modify() + serve() + _reduceImageSize + _audit.init()
 *                     + _search. Whitelist signup. Rate limit bypass → 429.
 *                     hasOwnProperty protégé. icon-menu a11y. common.ejs null-check.
 *            v3.19.5 : Documentation — JSDoc complet de init() accessible en mode
 *                     bibliothèque (require('wate-engine')). Tous les paramètres
 *                     documentés (@param), valeur de retour Promise<ctx> décrite
 *                     (@returns), exemple d'utilisation (@example). Alignement
 *                     version engine.js sur package.json (source de vérité).
 */

'use strict'

const express     = require('express')
const cookieParser= require('cookie-parser')
const crypto      = require('crypto')
const sqlite3     = process.env.NODE_ENV === 'production' ? require('sqlite3') : require('sqlite3').verbose()
const fs          = require('fs')
const path        = require('path')
const favicon     = require('serve-favicon')
const _utils      = require('./_utils')
const _core       = require('./_core')
const _data       = require('./_data')
const _migration  = require('./_migration')
const _modules    = require('./_modules')



/**
 * \fn usage
 * \brief Affiche la syntaxe d'invocation de l'application sur la sortie de trace.
 */
function usage() {
  _core.log.print(_core.log.WARNING, 'Usage: node ' + __filename + ' [--log <log level>] --db <database\'s file> --port <listen port> [--path <app path>] [--root <root page>] [--mod <module>,...] [--ejs <module>,...]')
}



/**
 * \fn _parseArgv
 * \brief Parse les arguments de la ligne de commande via minimist.
 * \return Objet argv normalisé (doublons écrasés, types validés par minimist).
 */
function _parseArgv() {
  const a = require('minimist')(process.argv.slice(2), {
    alias: { d: 'db', l: 'log', p: 'port' },
    string: ['db', 'ejs', 'mod', 'path', 'root'],
    number: ['port', 'log'],
    default: { log: _core.log.FATAL | _core.log.ERROR | _core.log.WARNING, path: '' }
  })
  // Assainissement : chaque argument est une valeur unique et non un tableau
  ;['db', 'log', 'port', 'path', 'root', 'mod', 'ejs'].forEach(key => {
    if (a[key] !== undefined) a[key] = [].concat(a[key]).pop()
  })
  return a
}



/**
 * \const _STATIC_EXT_RE
 * \brief Regex pré-compilée pour identifier les ressources statiques.
 */
const _STATIC_EXT_RE = /\.(css|js|png|jpg|ico)$/
// FIX v3.19.4 #32: rejette //evil.com (protocol-relative)
// FIX v3.19.4: regex statiques module-level (pas dans la boucle de requête)
const _RE_TRAIL_SLASH = /\/+$/
const _RE_ROOT       = /^\/(?!\/)/
const _RE_BLOCKED    = /\.db$|\.md$/i

/**
 * @brief Initialise et démarre le moteur WaTE.
 *
 * En mode CLI, le port et la DB sont lus depuis argv.
 * En mode bibliothèque, toutes les options sont passées via l'objet @p options.
 * Les modules sont chargés dans l'ordre déclaré dans @p mod.
 *
 * @param {Object}          options              - Options d'initialisation.
 * @param {string}          options.db           - Chemin vers la DB SQLite ou ':memory:'.
 * @param {number}          options.port         - Port TCP (1-65535).
 * @param {string}         [options.path='./']   - Chemin racine de l'application.
 * @param {string}         [options.root]        - Redirection de '/' vers cette URL.
 * @param {string[]|string}[options.mod]         - Modules à charger ex: ['auth=3600','db','audit'].
 * @param {string[]|string}[options.ejs]         - Modules EJS personnalisés à charger.
 * @param {number}         [options.log=7]       - Niveau de log (bitmask: 1=ERROR 2=WARN 4=INFO).
 * @param {boolean}        [options.listen=true] - false = initialise sans démarrer le serveur HTTP.
 * @param {string}         [options.name]        - Nom affiché dans les logs et l'interface admin.
 * @param {number}         [options.sessionTTL]  - TTL de session en secondes (priorité sur --mod auth=TTL).
 *
 * @returns {Promise<{app: Express, db: Database, server?: Server, close: Function}>}
 *   - app    : instance Express configurée.
 *   - db     : instance sqlite3 connectée.
 *   - server : instance http.Server (absent si listen=false).
 *   - close  : fonction de shutdown propre → Promise (attend les modules done()).
 *
 * @throws {Error} Si le port est invalide, la DB inaccessible ou les FK inactives.
 *
 * @example
 * const wate = require('wate-engine');
 * wate.init({
 *   port: 8080,
 *   db: './data/app.db',
 *   mod: ['auth=3600', 'db', 'audit'],
 *   name: 'Mon Application'
 * }).then(({ app, db, server, close }) => {
 *   // Enregistrer des hooks métier
 *   app.locals.tableHooks['commandes'] = { insert: (req, next) => next() };
 * }).catch(err => console.error('Erreur démarrage:', err));
 */

function init(options) {
  _core.log.print(_core.log.RUN, 'ENTER engine.init()')
  return new Promise((resolve, reject) => {

    // --- ARGUMENTS ---

    /**
     * \const argv
     * \brief Options de démarrage normalisées.
     *        En mode CLI : issues de process.argv via _parseArgv().
     *        En mode bibliothèque : objet options complété par les valeurs par défaut.
     */
    // Note : Object.assign mute le 1er argument (objet frais), pas options.
    const argv = (options !== undefined)
      ? Object.assign({ path: '', log: _core.log.FATAL | _core.log.ERROR | _core.log.WARNING }, options)
      : _parseArgv()

    // Validation des arguments obligatoires
    try {
      ['db', 'port'].forEach(key => {
        if(argv[key] === undefined || argv[key] === true || argv[key] === '') {
          _core.log.print(_core.log.FATAL, 'Missing mandatory argument: --' + key)
          usage()
          throw new Error('Missing mandatory argument: --' + key)
        }
      })
    } catch(err) {
      _core.log.print(_core.log.RUN, 'LEAVE engine.init() (missing arg)')
      return reject(err)
    }

    // --- NIVEAU DE TRACE ---

    /**
     * \brief Initialisation du niveau de trace d'après argv._core.log.
     *        Si la valeur est absente ou non numérique, le niveau par défaut
     *        (FATAL | ERROR | WARNING) est appliqué.
     */
    // FIX v3.19.4 #155: NaN n'est plus accepté (NaN & 63 === 0 → logging silencieux)
    if(typeof argv.log === 'number' && !isNaN(argv.log)) {
      _core.log.level = argv.log
    } else {
      _core.log.level = _core.log.FATAL|_core.log.ERROR|_core.log.WARNING
      if (argv.log !== undefined) _core.log.print(_core.log.WARNING, 'Invalid log level, using default value !')
    }
    _core.log.print(_core.log.INFO, 'log instance initialized with level ' + _core.log.level + '.')

    // --- APPLICATION EXPRESS ---

    /**
     * \var app
     * \brief Instance Express globale — exposée sur global pour les modules -mod et les EJS.
     *        Middlewares de parsing activés : cookieParser, json, urlencoded.
     *        trust proxy = 1 pour fonctionner derrière Squid (reverse proxy HTTPS).
     */
    _core.app = express()
    // FIX v3.19.4 #48: secret signe les cookies (anti-hijacking). Fallback aléatoire.
    _core.app.use(cookieParser(process.env.WATE_COOKIE_SECRET || crypto.randomBytes(32).toString('hex')))
    _core.app.use(express.json({ limit: '100kb' }))
    // NOTE: extended:true dépend de qs, mitigé par limit 100kb. Accepté ANALYSIS v5 #25.
    _core.app.use(express.urlencoded({ extended: true, limit: '100kb' }))

    // FIX v2.4.0 : trust proxy — nécessaire derrière Squid (reverse proxy HTTPS).
    _core.app.set('trust proxy', 1)

    // --- CHEMIN DE L'APPLICATION ---

    /**
     * \brief Normalisation et validation du chemin de l'application.
     *        argv.path est normalisé pour toujours se terminer par un slash.
     */
    // Garde-fou : argv.path peut être null/undefined en mode bibliothèque
    if(argv.path && argv.path !== '') {
      argv.path = argv.path.replace(_RE_TRAIL_SLASH, '') + '/'
      if(!fs.existsSync(argv.path)) {
        _core.log.print(_core.log.FATAL, 'Path "' + argv.path + '" does not exist!')
        _core.log.print(_core.log.RUN, 'LEAVE engine.init() (bad path)')
        return reject(new Error('Path "' + argv.path + '" does not exist!'))
      }
      _core.path = argv.path
    }
    _core.log.print(_core.log.INFO, '__dirname = "', __dirname + '"')
    _core.log.print(_core.log.INFO, 'App\'s folder = "' + argv.path + '"')

    // --- PORT TCP ---

    /**
     * \brief Validation du port TCP d'écoute.
     */
    if(typeof argv.port !== 'number' || isNaN(argv.port) || argv.port < 1 || argv.port > 65535) {
      _core.log.print(_core.log.FATAL, 'No valid TCP port to listen !')
      _core.log.print(_core.log.RUN, 'LEAVE engine.init() (bad port)')
      return reject(new Error('No valid TCP port to listen !'))
    }

    // --- CONFIGURATION DES VUES ---

    _core.app.set('views', [process.cwd() + '/' + argv.path + 'views', __dirname + '/views'])
    _core.app.set('view engine', 'ejs')



    // =======================================================================
    // VARIABLES GLOBALES DE CLOSURE (Hydratées par l'orchestrateur)
    // =======================================================================
    /**
     * \let EJSs
     * \brief Modules utilitaires chargés via --ejs. Exposés dans les vues.
     */
    let EJSs

    /**
     * \let mods
     * \brief Modules chargés via --mod. (Hydraté après chargement).
     */
    let mods = {}

    /**
     * \let _cspStatic
     * \brief Partie statique du header CSP — pré-calculée au démarrage.
     */
    let _cspStatic = ''

    /**
     * \let _cspScriptSrcBase
     * \brief Valeurs de script-src hors nonce, pré-jointes en string.
     */
    let _cspScriptSrcBase = ''

    /**
     * \let server
     * \brief Instance net.Server retournée par _core.app.listen().
     */
    let server = null

    /**
     * \const cspBase
     * \brief Directives Content-Security-Policy de base communes à tous les sites.
     */
    const cspBase = {
      'default-src':  ["'self'"],
      'script-src':   ["'self'"],
      'style-src':    ["'self'", "'unsafe-inline'"],
      'font-src':     ["'self'"],
      'img-src':      ["'self'", 'data:'],
      'frame-src':    ["'self'"],
      'media-src':    ["'self'"],
      'connect-src':  ["'self'"]
    }

    /**
     * \fn mergeCsp
     * \brief Fusionne les directives CSP d'un module dans cspBase (mutation directe).
     */
    function mergeCsp(extra) {
      Object.keys(extra).forEach(directive => {
        if(!cspBase[directive]) cspBase[directive] = []
        for(let vi = 0; vi < extra[directive].length; vi++) {
          if(cspBase[directive].indexOf(extra[directive][vi]) < 0) {
            cspBase[directive].push(extra[directive][vi])
          }
        }
      })
    }

    /**
     * \const _postRateBuckets
     * \brief Table de token buckets par IP pour le rate limiting POST.
     */
    const _postRateBuckets = {}
    let   _postRateCount   = 0

    /**
     * \const _postRateInterval
     * \brief Référence de l'interval de purge des buckets.
     */
    // NOTE: cleanup dans _shutdown/_close. Accepté ANALYSIS v5 #23.
    const _postRateInterval = setInterval(() => {
      const now = Date.now()
      Object.keys(_postRateBuckets).forEach(key => {
        if (now - _postRateBuckets[key].last > 60000) {
          delete _postRateBuckets[key]; _postRateCount--
        }
      })
    }, 60000)


    // =======================================================================
    // MONTAGE DES MIDDLEWARES EXPRESS
    // =======================================================================

    /**
     * \const staticOptions
     * \brief Options Express pour les fichiers statiques — cache long navigateur.
     */
    const staticOptions = { maxAge: 31536000000 }

    // FIX v3.19.4 #69, #73: bloquer .md et .db en statique
    _core.app.use(function(req, res, next) {
      if(_RE_BLOCKED.test(req.path)) return res.status(404).end()
      next()
    })
    // Garde-fou : argv.path vide → ne pas servir le CWD en statique (expo code source)
    if(argv.path) _core.app.use(express.static(process.cwd() + '/' + argv.path, staticOptions))
    _core.app.use('/scripts', express.static(__dirname + '/scripts', staticOptions))
    _core.app.use('/custom',  express.static(__dirname + '/custom',  staticOptions))
    _core.app.use('/images', express.static(__dirname + '/images', staticOptions))
    _core.app.use('/css',    express.static(__dirname + '/css',    staticOptions))

    try {
      _core.app.use(favicon(process.cwd() + '/' + argv.path + 'images/favicon.ico'))
    } catch(e) {
      _core.log.print(_core.log.WARNING, 'Unable to find "' + argv.path + 'images/favicon.ico" !')
    }

    /**
     * \brief Middleware — désactive le cache navigateur pour les pages dynamiques.
     */
    _core.app.use(function disablePageCache(req, res, next) {
      if (req.method === 'GET' && !_STATIC_EXT_RE.test(req.path)) {
        res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate')
        res.setHeader('Pragma', 'no-cache')
        res.setHeader('Expires', '0')
      }
      next()
    })

    /**
     * \brief Middleware — pose les headers de sécurité HTTP sur chaque réponse.
     */
    _core.app.use(function setSecurityHeaders(req, res, next) {
      const nonce = crypto.randomBytes(16).toString('base64')
      res.locals.nonce = nonce

      res.setHeader('X-Frame-Options', 'SAMEORIGIN')
      res.setHeader('X-Content-Type-Options', 'nosniff')
      res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin')
      if(req.secure) res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains')
      
      res.setHeader('Content-Security-Policy',
        "script-src 'nonce-" + nonce + "' " + _cspScriptSrcBase + '; ' + _cspStatic
      )
      next()
    })

    /**
     * \brief Route — Health check pour les proxies.
     */
    _core.app.get('/health', (req, res) => {
      res.json({ status: 'ok', uptime: process.uptime() })
    })

    function _getIp(req) { return req.ip || (req.socket && req.socket.remoteAddress) }

    /**
     * \brief Middleware — Protection CSRF (Cross-Site Request Forgery).
     */
    _core.app.use(function CSRFProtection(req, res, next) {
      if (req.method === 'GET' || req.method === 'HEAD' || req.method === 'OPTIONS') return next()
      if (req.path === '/admin/api/auth/signin' || req.path === '/admin/form/auth/signin') return next()

      const session = _utils.getSession(req)
      if (session.id === '0') return next()

      const expectedToken = _utils.generateCSRFToken(session.id)
      const providedToken = req.headers['x-csrf-token'] || (req.body && req.body._csrf)

      if (!providedToken || typeof providedToken !== 'string' || providedToken.length !== 64 || !_utils.adminTimingSafeEqual(expectedToken, providedToken)) {
        _core.log.print(_core.log.WARNING, 'CSRF verification failed for ' + req.path + ' (IP: ' + _getIp(req) + ')')
        
        if (req.path.indexOf('/api/') >= 0) {
          return res.status(403).json({ error: 'CSRF token invalid or missing' })
        } else {
          return _core.httpError(req, res, 403, 'Invalid CSRF Token')
        }
      }
      next()
    })

    /**
     * \brief Middleware — rate limiting POST par token bucket.
     */
    _core.app.use(function postRateLimit(req, res, next) {
      if(req.method !== 'POST') return next()
      const ip  = _getIp(req)
      if(!ip) {
        _core.log.print(_core.log.WARNING, 'POST sans adresse IP — rejeté')
        return _core.httpError(req, res, 400)
      }
      const now = Date.now()
      // Garde-fou mémoire : éviction inline si plus de 10000 IPs en attente.
      // Le cleanup périodique (60s) les évacue aussi mais peut prendre du retard.
      if(_postRateCount > 10000) {
        const cutoff = now - 120000
        // NOTE: var obligatoire (Node 4.6.1). Clé = ip|prefix.
        for(var _key in _postRateBuckets) {
          if(_postRateBuckets[_key].last < cutoff) { delete _postRateBuckets[_key]; _postRateCount-- }
        }
      }
      // FIX v3.19.4 #58: bucket par IP + prefix (isole /signin de /forgot)
      const rateKey = ip + '|' + (req.path.substring(0, 20) || '/')
      if(_postRateCount > 10000) return _core.httpError(req, res, 429, 'Too many requests')
      if(!_postRateBuckets[rateKey]) { _postRateBuckets[rateKey] = { tokens: 30, last: now }; _postRateCount++ }
      const b = _postRateBuckets[rateKey]
      const elapsed = (now - b.last) / 1000
      b.tokens = Math.min(30, b.tokens + elapsed * 0.5)
      b.last   = now
      if(b.tokens < 1) {
        _core.log.print(_core.log.WARNING, 'Rate limit exceeded for IP ' + ip)
        return _core.httpError(req, res, 429, 'Too many requests')
      }
      b.tokens -= 1
      next()
    })


    // --- BASE DE DONNÉES ---

    let dbPath = argv.path + argv.db
    let dbMode = sqlite3.OPEN_READWRITE
    /**
     * \brief Vérification de l'existence du fichier DB.
     *        ':memory:' est accepté sans vérification (SQLite in-memory, usage test).
     */
    if(argv.db === ':memory:') {
      dbPath = argv.db
      dbMode |= sqlite3.OPEN_CREATE
    }
    else if(!fs.existsSync(dbPath)) {
      _core.log.print(_core.log.FATAL, 'No valid database\'s file specified !')
      _core.log.print(_core.log.RUN, 'LEAVE engine.init() (no DB)')
      return reject(new Error('No valid database\'s file specified !'))
    }

    /**
     * \const db
     * \brief Instance sqlite3.Database — connexion unique partagée par l'application.
     *        Ouverte en lecture/écriture, avec foreign_keys, WAL mode, busyTimeout 5s,
     *        et triggers de protection sur _item.
     */
    const db = new sqlite3.Database(dbPath, dbMode, (err) => {
      if(err) {
        _core.log.print(_core.log.FATAL, err.message)
        _core.log.print(_core.log.RUN, 'LEAVE engine.init() (db open error)')
        return reject(err)
      }

      // configure() existe depuis sqlite3 v5.0.0. Garde pour compatibilité v4.x.
      if(typeof db.configure === 'function') db.configure("busyTimeout", 5000)

      db.run('PRAGMA foreign_keys = ON', err => {
        // FIX v3.19.4 #33: reject + return pour ne pas continuer l'init en état half-started
        if(err) { _core.log.print(_core.log.FATAL, 'PRAGMA foreign_keys failed: ' + err.message); reject(err); return }
      })

      if(argv.db !== ':memory:') {
        db.run('PRAGMA journal_mode=WAL', err => {
          if(err) _core.log.print(_core.log.FATAL, 'PRAGMA journal_mode=WAL failed: ' + err.message)
          else    _core.log.print(_core.log.INFO,  'SQLite WAL mode enabled.')
        })
      }

      // FIX v3.11.0 : On utilise le setter de _core pour initialiser une fois pour toute l'instance
      _core.db = db;

      _core.log.print(_core.log.INFO, 'DB instance initialized.')

      /**
       * \fn _shutdown
       * \brief Arrêt propre sur signal système — stoppe le rate limiter, ferme la DB
       *        et quitte proprement.
       */
      function _shutdown(signal) {
        _core.log.print(_core.log.INFO, signal + ' received — closing DB and exiting.')
        clearInterval(_postRateInterval)
        const donePromises = []
        Object.keys(mods).forEach(_k => {
          if(mods[_k] && typeof mods[_k].done === 'function') {
            _core.log.print(_core.log.INFO, '[' + _k + '] done()')
            try { let ret = mods[_k].done(); if(ret && typeof ret.then === 'function') donePromises.push(ret) } catch(e) { _core.log.print(_core.log.ERROR, '[' + _k + '] done() threw: ' + e.message) }
          }
        })
        function closeAndExit() {
          db.close(err => {
            if(err) _core.log.print(_core.log.ERROR, 'db.close on shutdown: ' + err.message)
            process.exit(0)
          })
        }
        // Garde-fou : timeout 5s si un done() async pend
        if(donePromises.length) { Promise.race([Promise.all(donePromises), new Promise(r => setTimeout(r, 5000))]).then(closeAndExit).catch(e => { _core.log.print(_core.log.ERROR, 'shutdown error: ' + e.message); closeAndExit() }) } else { closeAndExit() }
      }

      /**
       * \fn _close
       * \brief Arrêt propre pour usage programmatique (tests).
       */
      function _close() {
        return new Promise(resolveClose => {
          clearInterval(_postRateInterval)
          const donePromises = []
          // NOTE: typeof guard = _stats.js/_search.js sans done() safe. Accepté ANALYSIS v6 #40.
          Object.keys(mods).forEach(_k => {
            if(mods[_k] && typeof mods[_k].done === 'function') {
              _core.log.print(_core.log.INFO, '[' + _k + '] done()')
              let ret; try { ret = mods[_k].done() } catch(e) { _core.log.print(_core.log.ERROR, '[' + _k + '] done() threw: ' + e.message); return }
              if(ret && typeof ret.then === 'function') donePromises.push(ret)
            }
          })
          function closeDb() {
            db.close(err => {
              if(err) _core.log.print(_core.log.ERROR, 'db.close on _close: ' + err.message)
              resolveClose()
            })
          }
          function closeAll() { if(server) { server.close(closeDb) } else { closeDb() } }
          // FIX v3.19.4 #30: .catch() évite que _close() pende si un done() rejette
          if(donePromises.length) { Promise.race([Promise.all(donePromises), new Promise(r => setTimeout(r, 5000))]).then(closeAll).catch(e => { _core.log.print(_core.log.ERROR, '_close error: ' + e.message); closeAll() }) } else { closeAll() }
        })
      }

      if(require.main === module) {
        process.on('SIGTERM', () => { _shutdown('SIGTERM') })
        process.on('SIGINT',  () => { _shutdown('SIGINT')  })
      }



      // =======================================================================
      // locals pour les modules internes
      // =======================================================================

      _core.app.locals.glossaryItem     = _utils.glossaryItem;
      _core.app.locals.httpError        = _core.httpError;
      _core.app.locals.SESSION_TTL_S    = undefined

      // Pass-through par défaut — toutes les routes admin ouvertes en anonymous.
      // _auth.js:init écrase ce fallback si chargé. Jamais undefined.
      _core.app.locals.adminSession     = (req, res, cb) => {
        cb({ email: 'anonymous', profil_id: req.app.locals.PROFIL_ANONYMOUS, lang_id: _utils.adminLang(req) })
      }



      // =======================================================================
      // ORCHESTRATION ASYNCHRONE GLOBALE
      // =======================================================================

      // Parsing préalable des noms de modules pour permettre à _migration.apply
      // de filtrer les migrations moteur par scope (NNN_<scope>_<desc>.sql).
      // Le chargement effectif des modules se fait plus tard via _modules.load.
      const _modNames = _modules.parseNames(argv.mod)

      _migration.apply(db, argv.path, _modNames)
        .then(() => new Promise((res, rej) => {
          db.get(
            'SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = ?',
            ['0'],
            (err, row) => {
              if(err) return rej(err)
              if(!row) return rej(new Error('Session fantôme (id=\'0\') introuvable — base de données non initialisée.'))
              _core.app.locals.PROFIL_OWNER     = 0
              _core.app.locals.PROFIL_ANONYMOUS = row.id
              _core.log.print(_core.log.INFO, 'PROFIL_OWNER=' + _core.app.locals.PROFIL_OWNER + ' PROFIL_ANONYMOUS=' + _core.app.locals.PROFIL_ANONYMOUS)
              res()
            }
          )
        }))
        .then(() => new Promise(res => {
          // Lecture de _config — non fatale si la table est absente (app sans migration).
          db.all('SELECT key, value FROM _config', [], (err, rows) => {
            if(err) {
              _core.log.print(_core.log.WARNING, '_config non disponible : ' + err.message)
              return res()
            }
            _core.config = {}
            rows.forEach(r => { _core.config[r.key] = r.value })

            // Initialisation du secret CSRF — variable d'environnement ou aléatoire.
            // Aléatoire à chaque redémarrage = anciens tokens CSRF invalidés.
            // Le secret empêche un attaquant connaissant le sessionId de forger
            // un token valide : token = SHA256(sessionId + secret).
            const csrfSecret = process.env.WATE_CSRF_SECRET || crypto.randomBytes(32).toString('hex')
            _utils.setCSRFSecret(csrfSecret)
            _core.log.print(_core.log.INFO, 'CSRF secret ' + (process.env.WATE_CSRF_SECRET ? '(from env)' : '(random)'))

            // Redimensionnement des caches LRU si la config diffère des valeurs par défaut.
            // Sûr ici : aucune requête n'a encore été servie, les caches sont vides.
            const ti = parseInt(_core.config['cache.tableInfo'], 10)
            const fk = parseInt(_core.config['cache.fkList'],    10)
            const q  = parseInt(_core.config['cache.queries'],   10)
            if(ti > 0) _core.dbCaches.tableInfo = _utils.boundedCache(ti)
            if(fk > 0) _core.dbCaches.fkList    = _utils.boundedCache(fk)
            if(q  > 0) _core.dbCaches.queries   = _utils.boundedCache(q)

            _core.log.print(_core.log.INFO, '_config chargée (' + rows.length + ' entrées).')
            res()
          })
        }))
        .then(() => _modules.load('ejs', argv.ejs, argv.path))
        .then(loadedEJSs => {
          EJSs = loadedEJSs
          _core.EJSs = EJSs
          
          return _modules.load('mod', argv.mod, argv.path)
        })
        .then(loadedMods => {
          mods = loadedMods
          
          // --- HYDRATATION DES CONFIGURATIONS POST-CHARGEMENT ---
          
          Object.keys(mods).forEach(_modKey => {
            if(mods[_modKey] && mods[_modKey].csp) mergeCsp(mods[_modKey].csp)
          })

          _cspStatic = Object.keys(cspBase)
            .filter(d => d !== 'script-src')
            .map(d => d + ' ' + cspBase[d].join(' '))
            .join('; ')
            
          _cspScriptSrcBase = cspBase['script-src'].join(' ')


          // --- ROUTES PAR DÉFAUT (TOUJOURS EN DERNIER) ---

          _core.root = argv.root

          /**
           * \brief Route GET / — racine de l'application.
           */
          _core.app.get('/', (req, res) => {
            _core.log.print(_core.log.RUN, 'ENTER GET ' + req.path)
            // Garde-fou : --root doit commencer par '/' (pas d'open redirect)
            if(argv.root && _RE_ROOT.test(argv.root)) {
              res.redirect(argv.root + '?lang=' + _utils.adminLang(req))
            } else {
              _data.serve(req, res)
            }
            _core.log.print(_core.log.RUN, 'LEAVE GET ' + req.path)
          })

          /**
           * \brief Route GET * — route par défaut pour toutes les pages dynamiques.
           */
          _core.app.get('*', (req, res) => {
            _core.log.print(_core.log.RUN, 'ENTER GET(default) ' + req.path)
            _data.serve(req, res)
            _core.log.print(_core.log.RUN, 'LEAVE GET(default) ' + req.path)
          })

          // Middleware d'erreur Express — capture les exceptions (JSON malformé, etc.)
          // sans divulguer la stack trace.
          _core.app.use((err, req, res, next) => {
            // FIX v3.19.4 #66: err peut être une string (next("message"))
            _core.log.print(_core.log.ERROR, 'Uncaught error: ' + (err.message || String(err)))
            _core.httpError(req, res, 500, 'Internal server error')
          })

          // --- DÉMARRAGE DU SERVEUR ---

          if(argv.listen === false) {
            _core.log.print(_core.log.INFO, 'Engine ready (listen=false).')
            _core.log.print(_core.log.RUN, 'LEAVE engine.init()')
            resolve({ app: _core.app, db: db, server: null, close: _close })
          } else {
            server = _core.app.listen(argv.port, () => {
              _core.log.print(_core.log.INFO, 'Application' + ' is listening on port ' + argv.port + '.')
              _core.log.print(_core.log.RUN, 'LEAVE engine.init()')
              resolve({ app: _core.app, db: db, server: server, close: _close })
            })
            server.on('error', err => {
              // FIX v3.19.4 #38: nettoyage interval + DB avant reject
              clearInterval(_postRateInterval)
              _core.log.print(_core.log.FATAL, err.message)
              _core.log.print(_core.log.RUN, 'LEAVE engine.init() (server error)')
              db.close(() => { reject(err) })
            })
          }
        })
        .catch(err => reject(err))

    }) // fin db open callback
  }) // fin Promise
} // fin init()



// --- POINT D'ENTRÉE CLI ---

/**
 * \brief En mode CLI (node engine.js ...), démarre le moteur avec les arguments de la
 *        ligne de commande. Les erreurs de démarrage sont fatales (process.exit(1)).
 *        En mode bibliothèque (require('./engine')), seul init() est exporté —
 *        aucun code ne s'exécute automatiquement.
 *
 * \param options  Options de démarrage. Si undefined, les arguments sont lus depuis
 *                 process.argv (mode CLI). Sinon, objet avec les propriétés :
 *                   - db     {string}  Chemin du fichier DB ou ':memory:' pour les tests.
 *                   - port   {number}  Port TCP d'écoute.
 *                   - path   {string}  Chemin de l'application (défaut '').
 *                   - root   {string}  Page racine (optionnel).
 *                   - mod    {string}  Modules --mod séparés par virgule (optionnel).
 *                   - ejs    {string}  Modules --ejs séparés par virgule (optionnel).
 *                   - log    {number}  Niveau de trace (défaut FATAL|ERROR|WARNING).
 *                   - listen {boolean} false pour ne pas appeler _core.app.listen() (défaut true).
 *
 * \return Promise<{app, db, server?, close}> résolue quand la DB et le serveur sont prêts.
 *         close() : function() → Promise — arrête proprement le serveur et la DB.
 *
 * \note En mode CLI (require.main === module), les erreurs de démarrage appellent
 *       process.exit(1). En mode bibliothèque, la Promise est rejetée avec l'erreur.
 */
if(require.main === module) {
  init().catch(err => {
    _core.log.print(_core.log.FATAL, err.message)
    process.exit(1)
  })
}

module.exports = { init }

/* (WaTE) engine.js v3.19.5 */