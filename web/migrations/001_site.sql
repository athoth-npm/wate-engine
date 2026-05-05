/**
 * \file      (WaTE) web/migrations/001_site.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-26
 * \version   1.9.1
 * \brief     Migration initiale du site vitrine WaTE.
 *
 * \details   v1.9.1 : Section 7.5 _WATE_API alignée sur l''objet réel (retrait executeAction,
 *                     getTableWriteHook). 7.7 renommé « Pipeline de rendu et d''écriture ».
 *            Pages :
 *              - /         → template site-home,     css common.css,  accès anonymous.
 *              - /examples → template site-examples, css examples.css
 *              - /docs     → template site-docs,     css docs.css
 *
 *            IDs réservés :
 *              _list 1-107  → moteur WaTE (admin auth/db/stats).
 *              _list 200+   → site vitrine (cette migration).
 *
 *            Profil anonymous (9999) : toutes les pages sont publiques.
 *            La ghost session id='0' résout le profil anonymous sans hard-coder 9999.
 *
 *            v1.1.0 — section 2 « Architecture » de /docs : textes fr/en, libellés
 *                     pour les diagrammes <wate-stack> et <wate-flow>.
 *            v1.2.0 — sections 3-5 (Le moteur, Les modules, Structure de la DB) :
 *                     textes fr/en, libellés pour les diagrammes <wate-stack>,
 *                     <wate-flow> et <wate-tree>.
 *            v1.3.0 — popup « À propos » i18n (clés site-about-* list_id NULL)
 *                     + sous-section MCD dans la section 5.
 *            v1.4.0 — sections 6 (Écrire une application) et 7 (API des modules).
 *            v1.5.0 — sections 8 (Sécurité), 9 (i18n et glossaire), 10 (Custom
 *                     elements). Doc /docs complète.
 *            v1.6.0 — /examples étendu de 1 à 5 cas : page bilingue (ex2),
 *                     liste dynamique avec queries (ex3), hook onPageLoad (ex4),
 *                     route applicative + renderPage (ex5). Les exemples 4 et 5
 *                     montrent l'API applicative (param, api) — pas app.locals.
 *            v1.7.0 — labels du pipeline moteur (pipe-*, pipeline-*) pour le
 *                     composant <wate-path> qui visualise le chemin de chaque
 *                     exemple à travers le moteur.
 *            v1.9.0 — section 7 « API développeur » enrichie : 7.5 _WATE_API,
 *                     7.6 Créer un module, 7.7 Fonctions cœur serve()/modify().
 */

-- ── Listes ────────────────────────────────────────────────────────────
INSERT INTO _list VALUES (200);  -- page d'accueil (/)
INSERT INTO _list VALUES (201);  -- page exemples (/examples)
INSERT INTO _list VALUES (202);  -- page documentation (/docs)

-- ── Page d'accueil ────────────────────────────────────────────────────
INSERT INTO _item VALUES (200, 'template', 'site-home');
INSERT INTO _item VALUES (200, 'css',      'common.css');
INSERT INTO _item VALUES (200, 'scripts',  '{"type":"text/javascript","path":"/scripts/search.js"}');
INSERT INTO _item VALUES (200, 'title',    'home-title');
INSERT INTO _item VALUES (200, 'queries',  '');

INSERT INTO _page VALUES ('/',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 200);

-- ── Page exemples ────────────────────────────────────────────────────
INSERT INTO _item VALUES (201, 'template', 'site-examples');
INSERT INTO _item VALUES (201, 'css',      'examples.css');
INSERT INTO _item VALUES (201, 'scripts',  '{"type":"text/javascript","path":"/scripts/search.js"}');
INSERT INTO _item VALUES (201, 'title',    'examples-title');
INSERT INTO _item VALUES (201, 'queries',  '');

INSERT INTO _page VALUES ('/examples',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 201);

-- ── Page documentation ───────────────────────────────────────────────
INSERT INTO _item VALUES (202, 'template', 'site-docs');
INSERT INTO _item VALUES (202, 'css',      'docs.css');
INSERT INTO _item VALUES (202, 'scripts',  '{"type":"text/javascript","path":"/scripts/search.js"}');
INSERT INTO _item VALUES (202, 'title',    'docs-title');
INSERT INTO _item VALUES (202, 'queries',  '');

INSERT INTO _page VALUES ('/docs',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 202);

-- ── Glossaire — entête site (list_id NULL — toujours chargé) ──────────
-- NOTE : header-title est déjà défini par 001_engine.sql pour l'admin ("Administration").
-- Le site vitrine code "WaTE" en dur dans common.ejs — pas besoin de redéfinir.

-- Navigation principale (horizontale, pas hamburger)
INSERT INTO _glossary VALUES ('fr', 'site-nav-home',     'Accueil',       NULL);
INSERT INTO _glossary VALUES ('fr', 'site-nav-docs',     'Documentation', NULL);
INSERT INTO _glossary VALUES ('fr', 'site-nav-examples', 'Exemples',      NULL);
INSERT INTO _glossary VALUES ('fr', 'site-nav-demo',     'Démo live',     NULL);
INSERT INTO _glossary VALUES ('fr', 'site-nav-ai',       'IA & WaTE',     NULL);
INSERT INTO _glossary VALUES ('fr', 'site-nav-github',   'GitHub',        NULL);
INSERT INTO _glossary VALUES ('en', 'site-nav-home',     'Home',          NULL);
INSERT INTO _glossary VALUES ('en', 'site-nav-docs',     'Documentation', NULL);
INSERT INTO _glossary VALUES ('en', 'site-nav-examples', 'Examples',      NULL);
INSERT INTO _glossary VALUES ('en', 'site-nav-demo',     'Live demo',     NULL);
INSERT INTO _glossary VALUES ('en', 'site-nav-ai',       'AI & WaTE',     NULL);
INSERT INTO _glossary VALUES ('en', 'site-nav-github',   'GitHub',        NULL);

INSERT INTO _glossary VALUES ('fr', 'copy-btn', 'Copier', NULL);
INSERT INTO _glossary VALUES ('en', 'copy-btn', 'Copy',   NULL);

-- Footer
INSERT INTO _glossary VALUES ('fr', 'site-footer-tagline', 'Le CMS piloté par la donnée.', NULL);
INSERT INTO _glossary VALUES ('en', 'site-footer-tagline', 'The data-driven CMS.',         NULL);

-- Sélecteur de langue (list_id NULL — toujours chargé)
INSERT INTO _glossary VALUES ('fr', 'site-lang-fr', 'Français', NULL);
INSERT INTO _glossary VALUES ('fr', 'site-lang-en', 'Anglais',  NULL);
INSERT INTO _glossary VALUES ('en', 'site-lang-fr', 'French',   NULL);
INSERT INTO _glossary VALUES ('en', 'site-lang-en', 'English',  NULL);

-- Popup « À propos » (list_id NULL — toujours chargé)
INSERT INTO _glossary VALUES ('fr', 'site-about-title',     'À propos de WaTE',                          NULL);
INSERT INTO _glossary VALUES ('en', 'site-about-title',     'About WaTE',                                NULL);

INSERT INTO _glossary VALUES ('fr', 'site-about-product',   '<strong>Web as Table Engine</strong>',                                         NULL);
INSERT INTO _glossary VALUES ('en', 'site-about-product',   '<strong>Web as Table Engine</strong>',                                         NULL);

INSERT INTO _glossary VALUES ('fr', 'site-about-tagline',   'Moteur CMS Node.js / Express / SQLite piloté par base de données. Pages, menus et permissions vivent dans la DB — le code reste générique et minimal.', NULL);
INSERT INTO _glossary VALUES ('en', 'site-about-tagline',   'Node.js / Express / SQLite database-driven CMS engine. Pages, menus and permissions live in the DB — code stays generic and minimal.',                  NULL);

INSERT INTO _glossary VALUES ('fr', 'site-about-author',    'Auteur',     NULL);
INSERT INTO _glossary VALUES ('en', 'site-about-author',    'Author',     NULL);
INSERT INTO _glossary VALUES ('fr', 'site-about-contact',   'Contact',    NULL);
INSERT INTO _glossary VALUES ('en', 'site-about-contact',   'Contact',    NULL);
INSERT INTO _glossary VALUES ('fr', 'site-about-repo',      'Dépôt',      NULL);
INSERT INTO _glossary VALUES ('en', 'site-about-repo',      'Repository', NULL);
INSERT INTO _glossary VALUES ('fr', 'site-about-website',   'Site',       NULL);
INSERT INTO _glossary VALUES ('en', 'site-about-website',   'Website',    NULL);
INSERT INTO _glossary VALUES ('fr', 'site-about-license',   'Licence',    NULL);
INSERT INTO _glossary VALUES ('en', 'site-about-license',   'License',    NULL);
INSERT INTO _glossary VALUES ('fr', 'site-about-license-v', 'MIT — © 2023-2026 WATE Team', NULL);
INSERT INTO _glossary VALUES ('en', 'site-about-license-v', 'MIT — © 2023-2026 WATE Team', NULL);

-- ── Glossaire — page d'accueil (list 200) ─────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'home-title', 'Accueil', 200);
INSERT INTO _glossary VALUES ('en', 'home-title', 'Home',    200);

-- Hero
INSERT INTO _glossary VALUES ('fr', 'home-hero-title',
  'Le CMS piloté par la donnée.', 200);
INSERT INTO _glossary VALUES ('en', 'home-hero-title',
  'The data-driven CMS.', 200);

INSERT INTO _glossary VALUES ('fr', 'home-hero-subtitle',
  'Vos pages, menus, permissions et traductions vivent en base. Le code reste générique. Node.js + SQLite, zéro framework lourd.', 200);
INSERT INTO _glossary VALUES ('en', 'home-hero-subtitle',
  'Pages, menus, permissions and translations live in the DB. Code stays generic. Node.js + SQLite, no heavy framework.', 200);

INSERT INTO _glossary VALUES ('fr', 'home-cta-examples', 'Voir les exemples', 200);
INSERT INTO _glossary VALUES ('en', 'home-cta-examples', 'See examples',      200);
INSERT INTO _glossary VALUES ('fr', 'home-cta-docs',     'Lire la doc',       200);
INSERT INTO _glossary VALUES ('en', 'home-cta-docs',     'Read the docs',     200);
INSERT INTO _glossary VALUES ('fr', 'home-cta-demo',     'Démo live',         200);
INSERT INTO _glossary VALUES ('en', 'home-cta-demo',     'Live demo',         200);
INSERT INTO _glossary VALUES ('fr', 'home-cta-github',   'GitHub',            200);
INSERT INTO _glossary VALUES ('en', 'home-cta-github',   'GitHub',            200);

-- Cartes features
INSERT INTO _glossary VALUES ('fr', 'home-feat-1-title', 'Tout en base', 200);
INSERT INTO _glossary VALUES ('en', 'home-feat-1-title', 'All in the DB', 200);
INSERT INTO _glossary VALUES ('fr', 'home-feat-1-body',
  'Pages, permissions, traductions : le schéma SQLite décrit le site entier. Éditez la base, le rendu suit.', 200);
INSERT INTO _glossary VALUES ('en', 'home-feat-1-body',
  'Pages, permissions, translations: the SQLite schema describes the whole site. Edit the DB, rendering follows.', 200);

INSERT INTO _glossary VALUES ('fr', 'home-feat-2-title', 'Léger par nature', 200);
INSERT INTO _glossary VALUES ('en', 'home-feat-2-title', 'Lightweight by design', 200);
INSERT INTO _glossary VALUES ('fr', 'home-feat-2-body',
  'Node.js + Express + SQLite. Pas de build frontend imposé, pas de process supplémentaire. Un fichier, un port.', 200);
INSERT INTO _glossary VALUES ('en', 'home-feat-2-body',
  'Node.js + Express + SQLite. No mandatory frontend build, no extra process. One file, one port.', 200);

INSERT INTO _glossary VALUES ('fr', 'home-feat-3-title', 'Admin générique', 200);
INSERT INTO _glossary VALUES ('en', 'home-feat-3-title', 'Generic admin', 200);
INSERT INTO _glossary VALUES ('fr', 'home-feat-3-body',
  'CRUD automatique par table, pilotage fin par profil. Pas de scaffolding : l''admin EST le moteur.', 200);
INSERT INTO _glossary VALUES ('en', 'home-feat-3-body',
  'Automatic CRUD per table, fine-grained profile control. No scaffolding: the admin IS the engine.', 200);

INSERT INTO _glossary VALUES ('fr', 'home-feat-4-title', 'IA & WaTE', 200);
INSERT INTO _glossary VALUES ('en', 'home-feat-4-title', 'AI & WaTE', 200);
INSERT INTO _glossary VALUES ('fr', 'home-feat-4-body',
  'WaTE est pensé pour l''IA : 100% SQL, modules en 20 lignes, custom elements autonomes. Générez un site complet avec quelques prompts.', 200);
INSERT INTO _glossary VALUES ('en', 'home-feat-4-body',
  'WaTE is designed for AI: 100% SQL, 20-line modules, self-contained custom elements. Generate an entire website with just a few prompts.', 200);

-- ── Glossaire — page exemples (list 201) ──────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'examples-title', 'Exemples',  201);
INSERT INTO _glossary VALUES ('en', 'examples-title', 'Examples', 201);

INSERT INTO _glossary VALUES ('fr', 'examples-heading',
  'Apprendre WaTE par l''exemple', 201);
INSERT INTO _glossary VALUES ('en', 'examples-heading',
  'Learn WaTE by example', 201);

INSERT INTO _glossary VALUES ('fr', 'examples-intro',
  'Cinq cas en escalade — du simple SELECT en migration jusqu''à la route Express applicative qui invoque le pipeline de rendu. Trois voies illustrées : tout en base, hook applicatif, route Express + renderPage().',
  201);
INSERT INTO _glossary VALUES ('en', 'examples-intro',
  'Five escalating cases — from a plain SELECT in a migration to an application Express route invoking the render pipeline. Three paths illustrated: fully in DB, application hook, Express route + renderPage().',
  201);

-- Exemple 1 : Hello WaTE
INSERT INTO _glossary VALUES ('fr', 'ex1-num',   'Exemple 1', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-num',   'Example 1', 201);
INSERT INTO _glossary VALUES ('fr', 'ex1-title', 'Une page en trois lignes de SQL', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-title', 'A page in three lines of SQL', 201);
INSERT INTO _glossary VALUES ('fr', 'ex1-lead',
  'Une page WaTE n''est pas un fichier : c''est une ligne dans la table _page, reliée à une liste d''items qui décrivent son rendu. Créer une page revient à exécuter du SQL.', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-lead',
  'A WaTE page is not a file: it''s a row in the _page table, linked to a list of items describing its rendering. Creating a page means running SQL.', 201);

INSERT INTO _glossary VALUES ('fr', 'ex1-code-label',   'Migration SQL', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-code-label',   'SQL migration', 201);
INSERT INTO _glossary VALUES ('fr', 'ex1-result-label', 'Aperçu', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-result-label', 'Preview', 201);
INSERT INTO _glossary VALUES ('fr', 'ex1-explain-label','Explication', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-explain-label','Explanation', 201);

INSERT INTO _glossary VALUES ('fr', 'ex1-explain',
  'Trois étapes. (1) On déclare un regroupement d''items (_list). (2) On y accroche un template EJS et un titre. (3) On publie une page à l''URL /hello pour le profil anonymous. Le moteur fait tout le reste — routing, rendu, i18n.', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-explain',
  'Three steps. (1) Declare an items group (_list). (2) Attach a template and a title to it. (3) Publish a page at URL /hello for the anonymous profile. The engine does everything else — routing, rendering, i18n.', 201);

INSERT INTO _glossary VALUES ('fr', 'examples-nav-prev', '← Précédent', 201);
INSERT INTO _glossary VALUES ('en', 'examples-nav-prev', '← Previous',  201);
INSERT INTO _glossary VALUES ('fr', 'examples-nav-next', 'Suivant →',   201);
INSERT INTO _glossary VALUES ('en', 'examples-nav-next', 'Next →',      201);

INSERT INTO _glossary VALUES ('fr', 'preview-route',   'Route',   201);
INSERT INTO _glossary VALUES ('en', 'preview-route',   'Route',   201);
INSERT INTO _glossary VALUES ('fr', 'preview-status',  'Statut',  201);
INSERT INTO _glossary VALUES ('en', 'preview-status',  'Status',  201);
INSERT INTO _glossary VALUES ('fr', 'preview-hello',   'Bienvenue sur /hello.', 201);
INSERT INTO _glossary VALUES ('en', 'preview-hello',   'Welcome to /hello.',    201);

-- Labels génériques réutilisés par tous les exemples
INSERT INTO _glossary VALUES ('fr', 'ex-code-label',    'Migration SQL', 201);
INSERT INTO _glossary VALUES ('en', 'ex-code-label',    'SQL migration', 201);
INSERT INTO _glossary VALUES ('fr', 'ex-js-label',      'Module applicatif', 201);
INSERT INTO _glossary VALUES ('en', 'ex-js-label',      'Application module', 201);
INSERT INTO _glossary VALUES ('fr', 'ex-result-label',  'Aperçu', 201);
INSERT INTO _glossary VALUES ('en', 'ex-result-label',  'Preview', 201);
INSERT INTO _glossary VALUES ('fr', 'ex-explain-label', 'Explication', 201);
INSERT INTO _glossary VALUES ('en', 'ex-explain-label', 'Explanation', 201);

-- Pipeline du moteur — labels réutilisés par tous les <wate-path>
INSERT INTO _glossary VALUES ('fr', 'pipeline-title',   'Chemin dans le moteur', 201);
INSERT INTO _glossary VALUES ('en', 'pipeline-title',   'Engine path',           201);
INSERT INTO _glossary VALUES ('fr', 'pipeline-legend-title', 'Le pipeline complet d''une requête WaTE', 201);
INSERT INTO _glossary VALUES ('en', 'pipeline-legend-title', 'The complete pipeline of a WaTE request', 201);
INSERT INTO _glossary VALUES ('fr', 'pipeline-legend',
  'Six étapes potentielles. Trois sont toujours sollicitées (en orange ci-dessous) : Express, _page→_item, _glossary+EJS. Les trois autres (route applicative, queries SQL additionnelles, hook) ne sont actives que selon le cas. Dans les exemples ci-dessous, les étapes en plein sont sollicitées, celles en pointillé gris sont traversées sans être utilisées.',
  201);
INSERT INTO _glossary VALUES ('en', 'pipeline-legend',
  'Six potential stages. Three are always involved (in orange below): Express, _page→_item, _glossary+EJS. The other three (application route, additional SQL queries, hook) are only active in some cases. In the examples below, filled stages are involved; dashed-grey ones are traversed but not used.',
  201);

INSERT INTO _glossary VALUES ('fr', 'pipe-express',  'Express',           201);
INSERT INTO _glossary VALUES ('en', 'pipe-express',  'Express',           201);
INSERT INTO _glossary VALUES ('fr', 'pipe-route',    'Route app',         201);
INSERT INTO _glossary VALUES ('en', 'pipe-route',    'App route',         201);
INSERT INTO _glossary VALUES ('fr', 'pipe-page',     '_page → _item',     201);
INSERT INTO _glossary VALUES ('en', 'pipe-page',     '_page → _item',     201);
INSERT INTO _glossary VALUES ('fr', 'pipe-queries',  'queries',           201);
INSERT INTO _glossary VALUES ('en', 'pipe-queries',  'queries',           201);
INSERT INTO _glossary VALUES ('fr', 'pipe-hook',     'hook',              201);
INSERT INTO _glossary VALUES ('en', 'pipe-hook',     'hook',              201);
INSERT INTO _glossary VALUES ('fr', 'pipe-render',   '_glossary + EJS',   201);
INSERT INTO _glossary VALUES ('en', 'pipe-render',   '_glossary + EJS',   201);

-- ── Exemple 2 : page bilingue (glossaire scopé par list_id) ───────────
INSERT INTO _glossary VALUES ('fr', 'ex2-num',   'Exemple 2', 201);
INSERT INTO _glossary VALUES ('en', 'ex2-num',   'Example 2', 201);
INSERT INTO _glossary VALUES ('fr', 'ex2-title', 'Une page bilingue, sans logique applicative', 201);
INSERT INTO _glossary VALUES ('en', 'ex2-title', 'A bilingual page, no application logic',     201);
INSERT INTO _glossary VALUES ('fr', 'ex2-lead',
  'Tout ce qui s''affiche est une clé du glossaire. En attachant un list_id à chaque clé, on l''isole de la page voisine — vous pouvez réutiliser le même nom (title, lead…) sans craindre les collisions.',
  201);
INSERT INTO _glossary VALUES ('en', 'ex2-lead',
  'Everything that displays is a glossary key. By attaching a list_id to each key, you isolate it from neighboring pages — you can reuse the same name (title, lead…) without worrying about collisions.',
  201);
INSERT INTO _glossary VALUES ('fr', 'ex2-explain',
  'La même clé title est définie deux fois — une fois pour list_id 301 (anglais et français), une fois pour list_id 300 (Hello WaTE). Le moteur charge automatiquement le bon sous-ensemble selon la page consultée. Aucun fichier de traduction à compiler, aucun build : c''est de la donnée, pas du code.',
  201);
INSERT INTO _glossary VALUES ('en', 'ex2-explain',
  'The same title key is defined twice — once for list_id 301 (English and French), once for list_id 300 (Hello WaTE). The engine loads the right subset based on the page being viewed. No translation file to compile, no build: it''s data, not code.',
  201);
INSERT INTO _glossary VALUES ('fr', 'ex2-preview-h',  'Notre histoire',     201);
INSERT INTO _glossary VALUES ('en', 'ex2-preview-h',  'Our story',          201);
INSERT INTO _glossary VALUES ('fr', 'ex2-preview-p',  'Une PME française fondée en 2024.', 201);
INSERT INTO _glossary VALUES ('en', 'ex2-preview-p',  'A French SME founded in 2024.',    201);

-- ── Exemple 3 : liste dynamique avec queries SQL ──────────────────────
INSERT INTO _glossary VALUES ('fr', 'ex3-num',   'Exemple 3', 201);
INSERT INTO _glossary VALUES ('en', 'ex3-num',   'Example 3', 201);
INSERT INTO _glossary VALUES ('fr', 'ex3-title', 'Catalogue dynamique depuis la base',  201);
INSERT INTO _glossary VALUES ('en', 'ex3-title', 'Dynamic catalog straight from the DB', 201);
INSERT INTO _glossary VALUES ('fr', 'ex3-lead',
  'Une page peut déclencher des requêtes SQL additionnelles. Le moteur exécute chacune, expose le résultat sous result.<nom> dans le template, et c''est tout — pas de code applicatif requis pour lister une table métier.',
  201);
INSERT INTO _glossary VALUES ('en', 'ex3-lead',
  'A page can trigger additional SQL queries. The engine runs each, exposes the result as result.<name> in the template, and that''s it — no application code needed to list a business table.',
  201);
INSERT INTO _glossary VALUES ('fr', 'ex3-explain',
  'L''item queries de _item porte un objet JSON où chaque clé devient une entrée result.<clé> côté template. Ici, products contient un SELECT sur la table métier produit. La vue boucle dessus pour afficher chaque ligne. Le glossaire fournit les libellés — code et données restent strictement séparés.',
  201);
INSERT INTO _glossary VALUES ('en', 'ex3-explain',
  'The queries item in _item carries a JSON object where each key becomes a result.<key> entry on the template side. Here, products holds a SELECT on the business product table. The view loops through it to display each row. The glossary provides labels — code and data stay strictly separated.',
  201);

-- ── Exemple 4 : hook onPageLoad (provider applicatif) ─────────────────
INSERT INTO _glossary VALUES ('fr', 'ex4-num',   'Exemple 4', 201);
INSERT INTO _glossary VALUES ('en', 'ex4-num',   'Example 4', 201);
INSERT INTO _glossary VALUES ('fr', 'ex4-title', 'Injecter de la donnée runtime via un hook', 201);
INSERT INTO _glossary VALUES ('en', 'ex4-title', 'Inject runtime data via a hook',           201);
INSERT INTO _glossary VALUES ('fr', 'ex4-lead',
  'Quand la donnée ne vient pas de la base — un appel d''API externe, un calcul, un état système — un hook applicatif l''injecte au moment du rendu. La page reste pilotée par la DB, mais peut recevoir un complément.',
  201);
INSERT INTO _glossary VALUES ('en', 'ex4-lead',
  'When the data doesn''t come from the database — an external API call, a computation, a system state — an application hook injects it at render time. The page stays DB-driven but can receive an add-on.',
  201);
INSERT INTO _glossary VALUES ('fr', 'ex4-explain',
  'Le module weather est chargé via mod: [''weather''] dans engine.init(). Sa fonction init reçoit (param, api) et enregistre un hook nommé. Une page DB déclare HOOK = weather dans son _item ; à chaque rendu, le hook est appelé et le résultat injecté dans result.weather. Aucun couplage dur — la page existerait sans le module, simplement sans météo.',
  201);
INSERT INTO _glossary VALUES ('en', 'ex4-explain',
  'The weather module is loaded via mod: [''weather''] in engine.init(). Its init function receives (param, api) and registers a named hook. A DB page declares HOOK = weather in its _item; on every render the hook fires and its result is injected into result.weather. Zero hard coupling — the page would still work without the module, just without weather.',
  201);
INSERT INTO _glossary VALUES ('fr', 'ex4-preview-h',  'Tableau de bord',  201);
INSERT INTO _glossary VALUES ('en', 'ex4-preview-h',  'Dashboard',        201);
INSERT INTO _glossary VALUES ('fr', 'ex4-preview-p',  'Paris : 14 °C, ciel dégagé.', 201);
INSERT INTO _glossary VALUES ('en', 'ex4-preview-p',  'Paris: 57 °F, clear sky.',    201);

-- ── Exemple 5 : route applicative + renderPage() ──────────────────────
INSERT INTO _glossary VALUES ('fr', 'ex5-num',   'Exemple 5', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-num',   'Example 5', 201);
INSERT INTO _glossary VALUES ('fr', 'ex5-title', 'Une route Express qui appelle renderPage()', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-title', 'An Express route that calls renderPage()',   201);
INSERT INTO _glossary VALUES ('fr', 'ex5-lead',
  'Pour une logique métier complexe — vérifier une condition, paramétrer la page, choisir entre deux templates — déclarez une route Express applicative qui invoque renderPage() exposée par l''API. Le pipeline de rendu CMS est réutilisé tel quel.',
  201);
INSERT INTO _glossary VALUES ('en', 'ex5-lead',
  'For complex business logic — checking a condition, parameterizing the page, choosing between two templates — declare an application Express route that invokes renderPage() exposed by the API. The CMS rendering pipeline is reused as-is.',
  201);
INSERT INTO _glossary VALUES ('fr', 'ex5-explain',
  'Le module dashboard expose un init(param, api) qui enregistre une route GET sur /dashboard. La route lit la session, refuse l''accès au profil anonymous, puis appelle api.renderPage(req, res, ''/dashboard'') — qui charge la page DB de même URL et injecte le glossaire, les queries, etc. L''applicatif garde le contrôle de la condition d''accès, le moteur garde le contrôle du rendu.',
  201);
INSERT INTO _glossary VALUES ('en', 'ex5-explain',
  'The dashboard module exposes init(param, api) which registers a GET route on /dashboard. The route reads the session, denies access to the anonymous profile, then calls api.renderPage(req, res, ''/dashboard'') — which loads the DB page with that URL and injects the glossary, queries, etc. The application keeps control of the access condition, the engine keeps control of rendering.',
  201);
INSERT INTO _glossary VALUES ('fr', 'ex5-preview-h',  'Tableau de bord (privé)', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-preview-h',  'Dashboard (private)',     201);
INSERT INTO _glossary VALUES ('fr', 'ex5-preview-p',  'Bonjour, Romain. 3 nouvelles notifications.', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-preview-p',  'Hi, Romain. 3 new notifications.',           201);

-- ── Glossaire — page documentation (list 202) ─────────────────────────
INSERT INTO _glossary VALUES ('fr', 'docs-title', 'Documentation', 202);
INSERT INTO _glossary VALUES ('en', 'docs-title', 'Documentation', 202);

-- Table des matières (gauche)
INSERT INTO _glossary VALUES ('fr', 'docs-toc-label', 'Table des matières', 202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-label', 'Contents',          202);

INSERT INTO _glossary VALUES ('fr', 'docs-toc-01', '1. Vue d''ensemble',       202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-01', '1. Overview',              202);
INSERT INTO _glossary VALUES ('fr', 'docs-toc-02', '2. Architecture',          202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-02', '2. Architecture',          202);
INSERT INTO _glossary VALUES ('fr', 'docs-toc-03', '3. Le moteur',             202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-03', '3. The engine',            202);
INSERT INTO _glossary VALUES ('fr', 'docs-toc-04', '4. Les modules',           202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-04', '4. The modules',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-toc-05', '5. Structure de la DB',    202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-05', '5. Database structure',    202);
INSERT INTO _glossary VALUES ('fr', 'docs-toc-06', '7. Écrire une application',202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-06', '7. Writing an application',202);
INSERT INTO _glossary VALUES ('fr', 'docs-toc-07', '8. API développeur',      202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-07', '8. Developer API',       202);
INSERT INTO _glossary VALUES ('fr', 'docs-toc-08', '10. Sécurité',              202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-08', '10. Security',              202);
INSERT INTO _glossary VALUES ('fr', 'docs-toc-09', '11. i18n et glossaire',    202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-09', '11. i18n and glossary',    202);
INSERT INTO _glossary VALUES ('fr', 'docs-toc-10', '12. Custom elements',      202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-10', '12. Custom elements',      202);

INSERT INTO _glossary VALUES ('fr', 'docs-toc-soon', 'bientôt', 202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-soon', 'soon',    202);

-- Sommaire local (droite — "On this page")
INSERT INTO _glossary VALUES ('fr', 'docs-onthispage', 'Sur cette page', 202);
INSERT INTO _glossary VALUES ('en', 'docs-onthispage', 'On this page',   202);

-- Section 1 — Vue d'ensemble
INSERT INTO _glossary VALUES ('fr', 'docs-01-title', 'Vue d''ensemble', 202);
INSERT INTO _glossary VALUES ('en', 'docs-01-title', 'Overview',        202);

INSERT INTO _glossary VALUES ('fr', 'docs-01-lead',
  'WaTE est un moteur CMS piloté par la donnée. Tout ce qui définit un site — pages, menus, permissions, traductions — vit dans une base SQLite. Le code reste générique : le moteur consulte la base à chaque requête et assemble la réponse.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-01-lead',
  'WaTE is a data-driven CMS engine. Everything that defines a site — pages, menus, permissions, translations — lives in a SQLite database. The code stays generic: the engine queries the DB on every request and assembles the response.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-01-h-why',   'Pourquoi WaTE', 202);
INSERT INTO _glossary VALUES ('en', 'docs-01-h-why',   'Why WaTE',      202);
INSERT INTO _glossary VALUES ('fr', 'docs-01-p-why',
  'Les CMS traditionnels définissent leur contenu dans des fichiers PHP, des templates ou des schémas générés par scaffolding. À chaque ajout de fonctionnalité, il faut toucher du code. WaTE inverse le rapport : ajouter une page, un menu ou un droit se fait par une requête SQL. Le moteur n''a pas besoin d''être modifié pour étendre un site.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-01-p-why',
  'Traditional CMS define their content in PHP files, templates or scaffolded schemas. Every new feature requires touching code. WaTE flips the relationship: adding a page, a menu or a permission is done via a SQL statement. The engine doesn''t need to change to extend a site.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-01-h-stack', 'La pile technique', 202);
INSERT INTO _glossary VALUES ('en', 'docs-01-h-stack', 'The tech stack',    202);
INSERT INTO _glossary VALUES ('fr', 'docs-01-p-stack',
  'Node.js + Express pour le serveur. SQLite comme DB embarquée (un fichier). EJS pour les templates côté serveur. Custom elements natifs côté client — aucun framework imposé. L''ensemble tient dans un dossier, démarre en une commande et ne laisse aucun processus auxiliaire.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-01-p-stack',
  'Node.js + Express for the server. SQLite as the embedded database (one file). EJS for server-side templating. Native custom elements on the client — no mandatory framework. The whole thing fits in a folder, boots with one command, leaves no auxiliary process running.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-01-h-when',  'Quand l''utiliser', 202);
INSERT INTO _glossary VALUES ('en', 'docs-01-h-when',  'When to use it',    202);
INSERT INTO _glossary VALUES ('fr', 'docs-01-p-when',
  'WaTE convient aux sites où la structure évolue plus vite que la logique métier : sites vitrines, portails internes, dashboards admin, maquettes fonctionnelles. Il est moins adapté aux applications à logique métier lourde ou à très fort trafic — pour ces cas, il joue le rôle de fondation sur laquelle greffer des modules applicatifs spécifiques.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-01-p-when',
  'WaTE is suited to sites whose structure evolves faster than their business logic: showcase sites, internal portals, admin dashboards, functional mockups. It''s less suited to heavy business-logic apps or very high traffic — in those cases it serves as a foundation to attach specific application modules onto.',
  202);

-- ── Section 2 — Architecture ──────────────────────────────────────────
-- Réutilisée aussi par la section 1 pour le diagramme « pile WaTE ».
INSERT INTO _glossary VALUES ('fr', 'docs-02-title', 'Architecture', 202);
INSERT INTO _glossary VALUES ('en', 'docs-02-title', 'Architecture', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-lead',
  'WaTE est une pile à quatre couches, chacune avec une responsabilité claire. La donnée descend la pile — du navigateur vers la base — pendant qu''une requête arrive ; le rendu remonte ensuite jusqu''au client.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-02-lead',
  'WaTE is a four-layer stack, each with a clear responsibility. Data flows down the stack — from the browser to the database — when a request arrives; rendered output then flows back up to the client.',
  202);

-- Sous-section « La pile »
INSERT INTO _glossary VALUES ('fr', 'docs-02-h-stack', 'La pile', 202);
INSERT INTO _glossary VALUES ('en', 'docs-02-h-stack', 'The stack', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-p-stack',
  'Le client n''exécute que du HTML et des custom elements natifs — aucun framework imposé. Express assure le routing et les middlewares (sessions, CSRF, langue). Le moteur WaTE compose la réponse à partir des tables _page, _item et _glossary. SQLite stocke tout dans un fichier embarqué, sans process auxiliaire.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-02-p-stack',
  'The client runs only HTML and native custom elements — no mandatory framework. Express handles routing and middleware (sessions, CSRF, locale). The WaTE engine assembles the response from the _page, _item and _glossary tables. SQLite stores everything in an embedded file, no auxiliary process.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-stack-title', 'Pile WaTE',  202);
INSERT INTO _glossary VALUES ('en', 'docs-02-stack-title', 'WaTE stack', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-stack-client-l',  'Client',                          202);
INSERT INTO _glossary VALUES ('en', 'docs-02-stack-client-l',  'Client',                          202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-stack-client-s',  'HTML + custom elements natifs',   202);
INSERT INTO _glossary VALUES ('en', 'docs-02-stack-client-s',  'HTML + native custom elements',   202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-stack-express-l', 'Express',                         202);
INSERT INTO _glossary VALUES ('en', 'docs-02-stack-express-l', 'Express',                         202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-stack-express-s', 'Routing + middleware',            202);
INSERT INTO _glossary VALUES ('en', 'docs-02-stack-express-s', 'Routing + middleware',            202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-stack-engine-l',  'Moteur WaTE',                     202);
INSERT INTO _glossary VALUES ('en', 'docs-02-stack-engine-l',  'WaTE engine',                     202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-stack-engine-s',  '_core, _data, _auth, _db…',       202);
INSERT INTO _glossary VALUES ('en', 'docs-02-stack-engine-s',  '_core, _data, _auth, _db…',       202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-stack-sqlite-l',  'SQLite',                          202);
INSERT INTO _glossary VALUES ('en', 'docs-02-stack-sqlite-l',  'SQLite',                          202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-stack-sqlite-s',  'Un fichier .db, embarqué',        202);
INSERT INTO _glossary VALUES ('en', 'docs-02-stack-sqlite-s',  'One .db file, embedded',          202);

-- Sous-section « Cycle d'une requête »
INSERT INTO _glossary VALUES ('fr', 'docs-02-h-flow', 'Cycle d''une requête', 202);
INSERT INTO _glossary VALUES ('en', 'docs-02-h-flow', 'Request lifecycle',    202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-p-flow',
  'À chaque appel, Express transmet la requête au moteur. _page traduit l''URL en list_id. _item livre les méta-données de rendu (template, css, requêtes additionnelles). _glossary fournit les textes localisés. EJS assemble la page côté serveur — aucun build préalable, aucun cache obligatoire.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-02-p-flow',
  'On each call, Express forwards the request to the engine. _page maps the URL to a list_id. _item provides the rendering metadata (template, css, extra queries). _glossary supplies localized texts. EJS assembles the page server-side — no prior build, no required cache.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-title', 'Cycle d''une requête', 202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-title', 'Request lifecycle',    202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-recv-l',   'GET /url',              202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-recv-l',   'GET /url',              202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-recv-n',   'Express reçoit',        202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-recv-n',   'Express receives',      202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-page-l',   '_page',                 202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-page-l',   '_page',                 202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-page-n',   'URL → list_id',         202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-page-n',   'URL → list_id',         202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-item-l',   '_item',                 202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-item-l',   '_item',                 202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-item-n',   'template, css, queries',202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-item-n',   'template, css, queries',202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-i18n-l',   '_glossary',             202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-i18n-l',   '_glossary',             202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-i18n-n',   'Textes i18n',           202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-i18n-n',   'i18n texts',            202);

INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-render-l', 'EJS',                   202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-render-l', 'EJS',                   202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-flow-render-n', 'Rendu serveur',         202);
INSERT INTO _glossary VALUES ('en', 'docs-02-flow-render-n', 'Server render',         202);

-- Sous-section « Singleton vs per-instance »
INSERT INTO _glossary VALUES ('fr', 'docs-02-h-state', 'Singleton vs per-instance', 202);
INSERT INTO _glossary VALUES ('en', 'docs-02-h-state', 'Singleton vs per-instance', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-02-p-state',
  'Le module _core.js est mis en cache par require() — il est partagé par toutes les instances Express d''un même processus. Tout ce qui est propre à une instance (TTL de session, hooks de tables, état per-app) doit vivre dans app.locals, initialisé dans engine.js. Cette séparation rend le multi-instance possible — indispensable pour les tests qui démarrent plusieurs moteurs en parallèle.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-02-p-state',
  'The _core.js module is cached by require() — it''s shared across every Express instance in the same process. Anything tied to a specific instance (session TTL, table hooks, per-app state) must live in app.locals, initialized inside engine.js. That separation is what enables multi-instance — required by the test suite, which boots several engines in parallel.',
  202);

-- ── Section 3 — Le moteur ─────────────────────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'docs-03-title', 'Le moteur', 202);
INSERT INTO _glossary VALUES ('en', 'docs-03-title', 'The engine', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-03-lead',
  'WaTE n''est pas une commande, c''est une bibliothèque. On l''importe avec require(), on appelle init() avec quelques options, et on récupère une instance Express prête à servir.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-03-lead',
  'WaTE isn''t a command, it''s a library. You import it with require(), call init() with a few options, and you get an Express instance ready to serve.',
  202);

-- 3.1 init() et le mode bibliothèque
INSERT INTO _glossary VALUES ('fr', 'docs-03-h-init', 'init() et le mode bibliothèque', 202);
INSERT INTO _glossary VALUES ('en', 'docs-03-h-init', 'init() and the library mode', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-p-init',
  'engine.js exporte simplement { init }. L''appel init(opts) renvoie une promesse résolue avec un contexte { app, db, server, close }. C''est l''application qui décide quand démarrer, comment fermer, et quoi faire avec l''instance Express — le moteur ne s''autoexécute jamais.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-03-p-init',
  'engine.js simply exports { init }. Calling init(opts) returns a Promise that resolves to a context { app, db, server, close }. The application decides when to start, how to shut down, and what to do with the Express instance — the engine never runs itself.',
  202);

-- 3.2 Les options
INSERT INTO _glossary VALUES ('fr', 'docs-03-h-options', 'Les options d''init()', 202);
INSERT INTO _glossary VALUES ('en', 'docs-03-h-options', 'init() options',         202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-p-options',
  'db (chemin du fichier SQLite ou ":memory:"), port (numéro d''écoute, optionnel), path (préfixe du dossier applicatif servi en statique avant le moteur), mod (liste de modules à charger — auth, db, stats, mail), log (bitmask des canaux journalisés). Tout est optionnel sauf db.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-03-p-options',
  'db (SQLite file path or ":memory:"), port (listening port, optional), path (prefix of the application folder served as static before the engine), mod (list of modules to load — auth, db, stats, mail), log (bitmask of logged channels). Everything is optional except db.',
  202);

-- 3.3 Cycle de vie + diagramme flow
INSERT INTO _glossary VALUES ('fr', 'docs-03-h-lifecycle', 'Cycle de vie',  202);
INSERT INTO _glossary VALUES ('en', 'docs-03-h-lifecycle', 'Lifecycle',     202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-p-lifecycle',
  'À l''appel d''init(), le moteur ouvre la base, exécute les migrations dans l''ordre (celles du moteur, puis celles de l''application si elle en fournit), charge les modules optionnels demandés, enregistre les routes Express correspondantes, démarre le serveur HTTP et résout la promesse avec le contexte. Tout est asynchrone, rien n''est implicite.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-03-p-lifecycle',
  'On init(), the engine opens the database, runs migrations in order (engine''s first, then the application''s if any), loads requested optional modules, registers their Express routes, starts the HTTP server and resolves the Promise with the context. All asynchronous, nothing implicit.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-title', 'Cycle de vie d''init()', 202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-title', 'init() lifecycle',       202);

INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-require-l', 'require',         202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-require-l', 'require',         202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-require-n', 'Charger engine.js',202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-require-n', 'Load engine.js',  202);

INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-init-l',    'init(opts)',      202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-init-l',    'init(opts)',      202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-init-n',    'Options validées',202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-init-n',    'Options validated',202);

INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-mig-l',     'Migrations',      202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-mig-l',     'Migrations',      202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-mig-n',     'Schéma + données',202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-mig-n',     'Schema + data',   202);

INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-mod-l',     'Modules',         202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-mod-l',     'Modules',         202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-mod-n',     'auth, db, stats…',202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-mod-n',     'auth, db, stats…',202);

INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-routes-l',  'Routes',          202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-routes-l',  'Routes',          202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-routes-n',  'Express en place',  202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-routes-n',  'Express ready',   202);

INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-listen-l',  'listen()',        202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-listen-l',  'listen()',        202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-flow-listen-n',  'Promise<ctx>',    202);
INSERT INTO _glossary VALUES ('en', 'docs-03-flow-listen-n',  'Promise<ctx>',    202);

-- 3.4 Singleton vs per-instance
INSERT INTO _glossary VALUES ('fr', 'docs-03-h-state', 'Singleton vs per-instance', 202);
INSERT INTO _glossary VALUES ('en', 'docs-03-h-state', 'Singleton vs per-instance', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-03-p-state',
  'Le détail est en section 2 — résumé : ce qui est partagé entre toutes les instances Express d''un processus vit dans _core ; ce qui est propre à une instance (TTL de session, hooks de tables) vit dans app.locals, initialisé dans engine.js. C''est cette séparation qui rend possible le démarrage de plusieurs moteurs en parallèle pendant les tests.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-03-p-state',
  'Details in section 2 — summary: what''s shared across every Express instance in a process lives in _core; what''s tied to a specific instance (session TTL, table hooks) lives in app.locals, initialized inside engine.js. That separation is what enables multiple engines to start in parallel during tests.',
  202);

-- ── Section 4 — Les modules ───────────────────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'docs-04-title', 'Les modules', 202);
INSERT INTO _glossary VALUES ('en', 'docs-04-title', 'The modules', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-04-lead',
  'Le moteur de base ne sait que servir des pages CMS. Tout le reste — comptes utilisateurs, administration de la base, statistiques, e-mail — est un module optionnel chargé à la demande.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-04-lead',
  'The base engine only knows how to serve CMS pages. Everything else — user accounts, database administration, statistics, email — is an optional module loaded on demand.',
  202);

-- 4.1 Syntaxe mod
INSERT INTO _glossary VALUES ('fr', 'docs-04-h-syntax', 'Syntaxe mod', 202);
INSERT INTO _glossary VALUES ('en', 'docs-04-h-syntax', 'mod syntax',  202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-p-syntax',
  'mod accepte un tableau de chaînes au format name[:alias][=param]. Exemple : mod: [''auth=3600'', ''db'', ''stats'']. Le moteur charge __dirname/_name.js et appelle son init(param) ; chaque module enregistre ses propres routes Express.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-04-p-syntax',
  'mod takes an array of strings in the format name[:alias][=param]. Example: mod: [''auth=3600'', ''db'', ''stats'']. The engine loads __dirname/_name.js and calls its init(param); each module registers its own Express routes.',
  202);

-- 4.2 Modules du moteur + diagramme stack
INSERT INTO _glossary VALUES ('fr', 'docs-04-h-engine', 'Modules du moteur',  202);
INSERT INTO _glossary VALUES ('en', 'docs-04-h-engine', 'Engine modules',     202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-p-engine',
  '<p>Huit modules sont livrés avec le moteur. <b>auth</b> (sessions, PBKDF2), <b>db</b> (CRUD générique), <b>stats</b> (vues par page), <b>mail</b> (emails verify/reset, dégradation gracieuse), <b>audit</b> (journal des écritures), <b>search</b> (FTS5 plein texte), <b>apikey</b> (clés d''API Bearer), <b>cron</b> (purges périodiques).</p>',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-04-p-engine',
  '<p>Eight modules ship with the engine. <b>auth</b> (sessions, PBKDF2), <b>db</b> (generic CRUD), <b>stats</b> (page views), <b>mail</b> (verify/reset emails, graceful degradation), <b>audit</b> (write log), <b>search</b> (FTS5 full-text), <b>apikey</b> (Bearer API keys), <b>cron</b> (periodic purges).</p>',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-title', 'Modules du moteur', 202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-title', 'Engine modules',    202);

INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-auth-l',  'auth',                       202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-auth-l',  'auth',                       202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-auth-s',  'Sessions, signin, signup',   202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-auth-s',  'Sessions, signin, signup',   202);

INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-db-l',    'db',                         202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-db-l',    'db',                         202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-db-s',    'CRUD générique par table',   202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-db-s',    'Generic CRUD per table',     202);

INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-stats-l', 'stats',                      202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-stats-l', 'stats',                      202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-stats-s', 'Compteur de vues',           202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-stats-s', 'View counter',               202);

INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-mail-l',  'mail',                       202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-mail-l',  'mail',                       202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-mail-s',  'SMTP — dégradation gracieuse',202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-mail-s',  'SMTP — graceful degrade',    202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-title-2',  'Modules additionnels',         202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-title-2',  'Additional modules',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-audit-l',  '_audit.js',                    202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-audit-l',  '_audit.js',                    202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-audit-s',  'Journal des écritures',        202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-audit-s',  'Write audit log',              202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-search-l', '_search.js',                   202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-search-l', '_search.js',                   202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-search-s', 'Recherche FTS5',               202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-search-s', 'FTS5 full-text search',        202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-apikey-l', '_apikey.js',                   202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-apikey-l', '_apikey.js',                   202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-apikey-s', 'Clés d''API Bearer',            202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-apikey-s', 'Bearer API keys',              202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-cron-l',   '_cron.js',                     202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-cron-l',   '_cron.js',                     202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-stack-cron-s',   'Purges périodiques',           202);
INSERT INTO _glossary VALUES ('en', 'docs-04-stack-cron-s',   'Periodic purges',              202);

-- 4.3 Modules applicatifs
INSERT INTO _glossary VALUES ('fr', 'docs-04-h-app', 'Modules applicatifs', 202);
INSERT INTO _glossary VALUES ('en', 'docs-04-h-app', 'Application modules', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-p-app',
  'Une application peut fournir ses propres modules. Le moteur cherche d''abord __dirname/_name.js (modules livrés), puis path/scripts/name.js (modules de l''application). Mêmes hooks attendus : init(param) au chargement, done() à la fermeture.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-04-p-app',
  'An application can ship its own modules. The engine looks first in __dirname/_name.js (built-in modules), then in path/scripts/name.js (application modules). Same expected hooks: init(param) at load time, done() on shutdown.',
  202);

-- 4.4 Dégradation gracieuse de mail
INSERT INTO _glossary VALUES ('fr', 'docs-04-h-mail', 'Dégradation gracieuse de mail',     202);
INSERT INTO _glossary VALUES ('en', 'docs-04-h-mail', 'Graceful degradation of mail',      202);
INSERT INTO _glossary VALUES ('fr', 'docs-04-p-mail',
  'Si nodemailer n''est pas installé ou si mail.smtp.host est vide, le module annonce isAvailable() = false. Conséquences : /signup active directement les comptes (verified=1), /forgot et /reset répondent 404. Aucune erreur fatale — le site reste fonctionnel.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-04-p-mail',
  'If nodemailer is missing or mail.smtp.host is empty, the module reports isAvailable() = false. Consequences: /signup activates accounts directly (verified=1), /forgot and /reset respond with 404. No fatal error — the site keeps running.',
  202);

-- ── Section 5 — Structure de la DB ────────────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'docs-05-title', 'Structure de la DB', 202);
INSERT INTO _glossary VALUES ('en', 'docs-05-title', 'Database structure', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-05-lead',
  'Toute la connaissance d''un site WaTE vit dans une seule base SQLite. Le schéma sépare clairement les tables système — préfixées d''un underscore, réservées au moteur — et les tables applicatives, libres pour chaque projet.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-05-lead',
  'Every piece of knowledge about a WaTE site lives in a single SQLite database. The schema cleanly separates system tables — prefixed with an underscore, reserved to the engine — from application tables, free for each project.',
  202);

-- 5.1 Schéma global
INSERT INTO _glossary VALUES ('fr', 'docs-05-h-overview', 'Schéma global', 202);
INSERT INTO _glossary VALUES ('en', 'docs-05-h-overview', 'Overall schema', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-p-overview',
  'Les tables _user, _session, _profil, _access régissent l''authentification et les droits. _page, _list, _item, _glossary décrivent le contenu et son rendu. _config stocke des paires clé/valeur. _user_token et _stats sont ajoutées par les modules optionnels. Tout ce qui ne commence pas par un underscore vous appartient.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-05-p-overview',
  '_user, _session, _profil, _access drive authentication and access rights. _page, _list, _item, _glossary describe content and its rendering. _config stores key/value pairs. _user_token and _stats are added by optional modules. Anything that doesn''t start with an underscore is yours.',
  202);

-- 5.2 Tables du moteur + diagramme tree
INSERT INTO _glossary VALUES ('fr', 'docs-05-h-tables', 'Tables du moteur', 202);
INSERT INTO _glossary VALUES ('en', 'docs-05-h-tables', 'Engine tables',    202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-p-tables',
  'Douze tables centrales (préfixées _) pilotent le moteur :<br> <b>_list</b> (groupes d''items), <b>_item</b> (configuration clé/valeur), <b>_page</b> (routage URL × profil), <b>_lang</b> (langues), <b>_profil</b> (profils), <b>_user</b> (utilisateurs), <b>_session</b> (sessions), <b>_request</b> (types d''opérations), <b>_access</b> (droits), <b>_glossary</b> (textes i18n), <b>_config</b> (paramètres clé/valeur), <b>_user_token</b> (jetons verify/reset).<br> Les modules optionnels ajoutent <b>_audit</b> (journal des écritures), <b>_fts</b> (index FTS5) et <b>_stats_*</b> (statistiques d''accès).',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-05-p-tables',
  'Twelve core tables (prefixed with _) drive the engine:<br> <b>_list</b> (item groups), <b>_item</b> (key/value configuration), <b>_page</b> (URL × profile routing), <b>_lang</b> (languages), <b>_profil</b> (profiles), <b>_user</b> (users), <b>_session</b> (sessions), <b>_request</b> (operation types), <b>_access</b> (rights), <b>_glossary</b> (i18n texts), <b>_config</b> (key/value settings), <b>_user_token</b> (verify/reset tokens).<br> Optional modules add <b>_audit</b> (write log), <b>_fts</b> (FTS5 index) and <b>_stats_*</b> (access statistics).',
  202);

-- 5.3 Triangle page/list/item/glossary + diagramme flow
INSERT INTO _glossary VALUES ('fr', 'docs-05-h-content', 'Le quatuor _page / _list / _item / _glossary', 202);
INSERT INTO _glossary VALUES ('en', 'docs-05-h-content', 'The _page / _list / _item / _glossary quartet', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-p-content',
  '_page associe une URL et un profil à un identifiant de liste. _list n''est qu''un identifiant qui regroupe plusieurs items. _item porte le rendu : template EJS, fichier CSS, requêtes additionnelles, tag de titre. _glossary fournit les textes traduits, scopés par list_id pour éviter les collisions entre pages.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-05-p-content',
  '_page maps a URL and a profile to a list identifier. _list is just an identifier that groups several items. _item carries the rendering: EJS template, CSS file, extra queries, title tag. _glossary supplies translated texts, scoped by list_id to avoid collisions between pages.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-05-flow-title', 'Résolution d''une URL en page', 202);
INSERT INTO _glossary VALUES ('en', 'docs-05-flow-title', 'URL to page resolution',         202);

INSERT INTO _glossary VALUES ('fr', 'docs-05-flow-page-l',     '_page',                202);
INSERT INTO _glossary VALUES ('en', 'docs-05-flow-page-l',     '_page',                202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-flow-page-n',     'URL + profil → list_id',202);
INSERT INTO _glossary VALUES ('en', 'docs-05-flow-page-n',     'URL + profile → list_id',202);

INSERT INTO _glossary VALUES ('fr', 'docs-05-flow-list-l',     '_list',                202);
INSERT INTO _glossary VALUES ('en', 'docs-05-flow-list-l',     '_list',                202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-flow-list-n',     'Identifiant pur',      202);
INSERT INTO _glossary VALUES ('en', 'docs-05-flow-list-n',     'Pure identifier',      202);

INSERT INTO _glossary VALUES ('fr', 'docs-05-flow-item-l',     '_item',                202);
INSERT INTO _glossary VALUES ('en', 'docs-05-flow-item-l',     '_item',                202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-flow-item-n',     'template, css, queries',202);
INSERT INTO _glossary VALUES ('en', 'docs-05-flow-item-n',     'template, css, queries',202);

INSERT INTO _glossary VALUES ('fr', 'docs-05-flow-glossary-l', '_glossary',            202);
INSERT INTO _glossary VALUES ('en', 'docs-05-flow-glossary-l', '_glossary',            202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-flow-glossary-n', 'Textes par list_id',   202);
INSERT INTO _glossary VALUES ('en', 'docs-05-flow-glossary-n', 'Texts per list_id',    202);

-- 5.bis MCD (entre 5.3 et 5.4)
INSERT INTO _glossary VALUES ('fr', 'docs-05-h-mcd', 'Modèle conceptuel de données', 202);
INSERT INTO _glossary VALUES ('en', 'docs-05-h-mcd', 'Conceptual data model',        202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-p-mcd',
  'Le diagramme suivant — restreint aux six tables qui pilotent le contenu et les droits — montre les relations clés. _page rattache une URL à un profil et à une liste. _list regroupe les items de rendu. _item porte les méta-données. _glossary fournit les textes localisés. _profil et _access décrivent qui peut faire quoi.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-05-p-mcd',
  'The diagram below — restricted to the six tables that drive content and rights — shows the key relationships. _page maps a URL to a profile and a list. _list groups rendering items. _item carries metadata. _glossary supplies localized texts. _profil and _access describe who can do what.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-05-mcd-title', 'Pilotage du contenu', 202);
INSERT INTO _glossary VALUES ('en', 'docs-05-mcd-title', 'Content driving',     202);

-- 5.4 Profils et droits
INSERT INTO _glossary VALUES ('fr', 'docs-05-h-access', 'Profils et droits',     202);
INSERT INTO _glossary VALUES ('en', 'docs-05-h-access', 'Profiles and rights',   202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-p-access',
  'Convention UNIX : profil 0 = owner (tous droits sur les tables système), profil 9999 = anonymous (accès public). _access définit pour chaque (profil, table, requête) si l''opération est permise. Le moteur ne teste jamais profil_id en dur — tout est piloté par cette table. Voir la section 8 pour le détail des règles.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-05-p-access',
  'UNIX convention: profile 0 = owner (full rights on system tables), profile 9999 = anonymous (public access). _access defines, for each (profile, table, request) tuple, whether the operation is allowed. The engine never hard-codes profil_id checks — everything is driven by that table. See section 8 for detailed rules.',
  202);

-- 5.5 Session fantôme
INSERT INTO _glossary VALUES ('fr', 'docs-05-h-anon', 'Session fantôme',  202);
INSERT INTO _glossary VALUES ('en', 'docs-05-h-anon', 'Ghost session',    202);
INSERT INTO _glossary VALUES ('fr', 'docs-05-p-anon',
  'La session id=''0'' est inscrite en dur dans _session avec une expiration à l''an 2286. Un visiteur sans cookie résout cette session, qui pointe sur le profil anonymous (9999). C''est ce mécanisme qui permet à toutes les pages publiques de référencer un profil sans coder en dur une valeur magique.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-05-p-anon',
  'The session id=''0'' is hard-written in _session with an expiration in year 2286. A visitor without a cookie resolves this session, which points to the anonymous profile (9999). That mechanism lets every public page reference a profile without hard-coding a magic value.',
  202);

-- ── Section 6 — Écrire une application ───────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'docs-06-title', 'Écrire une application',  202);
INSERT INTO _glossary VALUES ('en', 'docs-06-title', 'Writing an application',  202);

INSERT INTO _glossary VALUES ('fr', 'docs-06-lead',
  'Une application WaTE tient dans un dossier et un point d''entrée. Le moteur ouvre la base, joue les migrations, charge les modules, démarre Express. Le travail se réduit à écrire les bonnes lignes de SQL pour décrire les pages et leurs textes.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-06-lead',
  'A WaTE application fits in a folder and a single entry point. The engine opens the database, runs migrations, loads modules and starts Express. Your job boils down to writing the right SQL lines to describe pages and their texts.',
  202);

-- 6.1 Structure d'un projet (+ tree)
INSERT INTO _glossary VALUES ('fr', 'docs-06-h-setup', 'Structure d''un projet', 202);
INSERT INTO _glossary VALUES ('en', 'docs-06-h-setup', 'Project structure',      202);
INSERT INTO _glossary VALUES ('fr', 'docs-06-p-setup',
  'Un point d''entrée Node.js (app.js) qui appelle engine.init() avec les options souhaitées, un dossier migrations/ pour le SQL, et autant de sous-dossiers que nécessaire pour les vues, le CSS, les scripts et les custom elements. Chacun de ces sous-dossiers est servi en statique avant ceux du moteur — vous pouvez surcharger n''importe quoi sans toucher au cœur.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-06-p-setup',
  'A Node.js entry point (app.js) that calls engine.init() with the desired options, a migrations/ folder for SQL, and as many sub-folders as needed for views, CSS, scripts and custom elements. Each of those is served statically before the engine''s own — you can override anything without touching the core.',
  202);

-- 6.2 Créer une page (+ flow 3 étapes SQL)
INSERT INTO _glossary VALUES ('fr', 'docs-06-h-page', 'Créer une page',     202);
INSERT INTO _glossary VALUES ('en', 'docs-06-h-page', 'Creating a page',    202);
INSERT INTO _glossary VALUES ('fr', 'docs-06-p-page',
  'Trois lignes de SQL suffisent. On déclare un identifiant de regroupement dans _list, on lui rattache des items de rendu (template, css, titre) dans _item, puis on publie la page à l''URL choisie pour le profil voulu dans _page. Le moteur fait le reste — pas de routage à coder, pas de fichier à créer.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-06-p-page',
  'Three SQL lines are enough. Declare a grouping id in _list, attach rendering items to it (template, css, title) in _item, then publish the page at the chosen URL for the chosen profile in _page. The engine does the rest — no routing to code, no file to create.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-06-flow-title', 'Créer une page en 3 étapes', 202);
INSERT INTO _glossary VALUES ('en', 'docs-06-flow-title', 'Create a page in 3 steps',   202);

INSERT INTO _glossary VALUES ('fr', 'docs-06-flow-list-l',  'INSERT INTO _list', 202);
INSERT INTO _glossary VALUES ('en', 'docs-06-flow-list-l',  'INSERT INTO _list', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-06-flow-list-n',  'Identifiant de regroupement', 202);
INSERT INTO _glossary VALUES ('en', 'docs-06-flow-list-n',  'Grouping id',                  202);

INSERT INTO _glossary VALUES ('fr', 'docs-06-flow-item-l',  'INSERT INTO _item', 202);
INSERT INTO _glossary VALUES ('en', 'docs-06-flow-item-l',  'INSERT INTO _item', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-06-flow-item-n',  'template, css, title', 202);
INSERT INTO _glossary VALUES ('en', 'docs-06-flow-item-n',  'template, css, title', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-06-flow-page-l',  'INSERT INTO _page', 202);
INSERT INTO _glossary VALUES ('en', 'docs-06-flow-page-l',  'INSERT INTO _page', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-06-flow-page-n',  'URL + profil + list_id', 202);
INSERT INTO _glossary VALUES ('en', 'docs-06-flow-page-n',  'URL + profile + list_id', 202);

-- 6.3 Templates EJS
INSERT INTO _glossary VALUES ('fr', 'docs-06-h-template', 'Templates EJS',      202);
INSERT INTO _glossary VALUES ('en', 'docs-06-h-template', 'EJS templates',      202);
INSERT INTO _glossary VALUES ('fr', 'docs-06-p-template',
  'Le moteur passe au template les variables elements (méta-données de l''item courant), result (résultats des requêtes additionnelles), lang (langue courante), req (requête Express) et glossaryItem — alias _gi — pour résoudre un texte traduit. Tout fichier views/X.ejs placé dans l''application supplante le views/X.ejs du moteur — vous gardez la main sur le rendu sans dupliquer le moteur.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-06-p-template',
  'The engine passes templates the variables elements (metadata of the current item), result (results of extra queries), lang (current language), req (Express request) and glossaryItem — aliased _gi — to resolve a translated text. Any views/X.ejs placed in the application overrides the engine''s views/X.ejs — you keep control of rendering without forking the engine.',
  202);

-- 6.4 Glossaire i18n
INSERT INTO _glossary VALUES ('fr', 'docs-06-h-i18n', 'Glossaire i18n',     202);
INSERT INTO _glossary VALUES ('en', 'docs-06-h-i18n', 'i18n glossary',      202);
INSERT INTO _glossary VALUES ('fr', 'docs-06-p-i18n',
  'Tout texte affiché vit dans la table _glossary, indexé par langue, nom et list_id. Un list_id à NULL rend la clé toujours chargée — utile pour le header, la navigation, les chaînes communes. Un list_id donné restreint la clé à la page concernée, ce qui évite les collisions de noms entre sections du site. Voir la section 9 pour le détail du fonctionnement.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-06-p-i18n',
  'Every displayed text lives in the _glossary table, indexed by language, name and list_id. A NULL list_id makes the key always loaded — handy for header, nav, shared strings. A specific list_id scopes the key to its page, avoiding name collisions between sections. See section 9 for details.',
  202);

-- 6.5 Requêtes dynamiques
INSERT INTO _glossary VALUES ('fr', 'docs-06-h-dynquery', 'Requêtes dynamiques SQL',     202);
INSERT INTO _glossary VALUES ('en', 'docs-06-h-dynquery', 'Dynamic SQL queries',         202);
INSERT INTO _glossary VALUES ('fr', 'docs-06-p-dynquery',
  'Les pages peuvent embarquer des requêtes SQL paramétrées dans _item (clé = queries). La valeur est un template JSON contenant des placeholders ${expr} ou ${expr:type} résolus à la volée via une VM sandboxée. Format : {"NomQuery":{"request":"SELECT ...","values":[...]}}. Chaque clé devient une requête exécutée via db.all(). Les valeurs sont bindées (?) — immunisées contre l''injection SQL classique. Types disponibles : :number (parseFloat, rejette NaN), :identifier (valide /^[a-zA-Z0-9_]+$/ pour noms de tables/colonnes), :text (force String, échappe " et \ pour la sécurité JSON). Règles : toujours typer les valeurs issues de req.query/req.body ; ne jamais concaténer une valeur utilisateur directement dans request sans :identifier ; les objets/fonctions sont rejetés (barrière anti-sandbox-escape Node < 10). Longueur max d''expression : 500 caractères.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-06-p-dynquery',
  'Pages can embed parameterized SQL queries in _item (key = queries). The value is a JSON template containing ${expr} or ${expr:type} placeholders, resolved at request time via a sandboxed VM. Format: {"QueryName":{"request":"SELECT ...","values":[...]}}. Each key becomes a query executed via db.all(). Values are bound (?) — immune to classical SQL injection. Available types: :number (parseFloat, rejects NaN), :identifier (validates /^[a-zA-Z0-9_]+$/ for table/column names), :text (forces String, escapes " and \ for JSON safety). Rules: always type values coming from req.query/req.body; never concatenate a user value directly into request without :identifier; objects and functions are rejected (anti-sandbox-escape barrier for Node < 10). Max expression length: 500 characters.',
  202);

-- ── Section 7 — API des modules ───────────────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'docs-07-title', 'API des modules', 202);
INSERT INTO _glossary VALUES ('en', 'docs-07-title', 'Module API',      202);

INSERT INTO _glossary VALUES ('fr', 'docs-07-lead',
  'Routes HTTP, API développeur (_WATE_API), création de modules applicatifs. Les modules reçoivent une API sécurisée qui donne accès à Express, la base de données, le rendu de pages et le système de hooks.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-07-lead',
  'HTTP routes, developer API (_WATE_API), application module creation. Modules receive a secure API that provides access to Express, the database, page rendering, and the hook system.',
  202);

-- 7.1 Routes CMS toujours présentes
INSERT INTO _glossary VALUES ('fr', 'docs-07-h-cms', 'Routes CMS toujours présentes', 202);
INSERT INTO _glossary VALUES ('en', 'docs-07-h-cms', 'Always-on CMS routes',          202);
INSERT INTO _glossary VALUES ('fr', 'docs-07-p-cms',
  'GET / et GET /* sont gérés par le moteur lui-même — le résolveur traduit l''URL en list_id via _page, lit les méta-données dans _item, exécute les éventuelles requêtes additionnelles, charge les textes traduits dans _glossary, puis rend le template EJS désigné. Aucune route applicative à déclarer.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-07-p-cms',
  'GET / and GET /* are handled by the engine itself — the resolver translates the URL into a list_id via _page, reads metadata from _item, runs any extra queries, loads translated texts from _glossary, then renders the designated EJS template. No application route to declare.',
  202);

-- 7.2 Module auth
INSERT INTO _glossary VALUES ('fr', 'docs-07-h-auth', 'Module auth', 202);
INSERT INTO _glossary VALUES ('en', 'docs-07-h-auth', 'auth module', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-07-p-auth',
  'API : POST /admin/api/auth/{signin,signout,signup} ; GET, PUT, DELETE /admin/api/auth/me. Vues : GET, POST /admin/form/auth/{signin,signup,me}, POST /admin/form/auth/signout. Si le module mail est actif : GET /admin/form/auth/verify pour l''activation, POST /admin/form/auth/forgot et POST /admin/form/auth/reset pour la réinitialisation par e-mail.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-07-p-auth',
  'API: POST /admin/api/auth/{signin,signout,signup}; GET, PUT, DELETE /admin/api/auth/me. Views: GET, POST /admin/form/auth/{signin,signup,me}, POST /admin/form/auth/signout. If the mail module is active: GET /admin/form/auth/verify for activation, POST /admin/form/auth/forgot and POST /admin/form/auth/reset for email-based reset.',
  202);

-- 7.3 Module db
INSERT INTO _glossary VALUES ('fr', 'docs-07-h-db', 'Module db', 202);
INSERT INTO _glossary VALUES ('en', 'docs-07-h-db', 'db module', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-07-p-db',
  'API : GET /admin/api/db/schema renvoie la liste des tables accessibles. GET, POST, PUT, DELETE /admin/api/db/:table assurent le CRUD générique. Vues : GET /admin/form/db/schema affiche le schéma sous forme de boîtes Merise ; GET /admin/form/db/:table ouvre l''éditeur tabulaire ; POST /admin/form/db/:table/:request déclenche une requête nommée définie dans _item.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-07-p-db',
  'API: GET /admin/api/db/schema lists accessible tables. GET, POST, PUT, DELETE /admin/api/db/:table provide generic CRUD. Views: GET /admin/form/db/schema renders the schema as Merise boxes; GET /admin/form/db/:table opens the tabular editor; POST /admin/form/db/:table/:request triggers a named request defined in _item.',
  202);

-- 7.4 Module stats
INSERT INTO _glossary VALUES ('fr', 'docs-07-h-stats', 'Module stats', 202);
INSERT INTO _glossary VALUES ('en', 'docs-07-h-stats', 'stats module', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-07-p-stats',
  'API : GET /admin/api/stats renvoie les compteurs de vues agrégés en JSON. Vue : GET /admin/form/stats affiche le tableau de bord. Le module utilise un cache LRU pour éviter de mitrailler la base à chaque requête.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-07-p-stats',
  'API: GET /admin/api/stats returns aggregated view counters as JSON. View: GET /admin/form/stats renders the dashboard. The module uses an LRU cache to avoid hammering the database on every request.',
  202);

-- 7.5 Interface _WATE_API
INSERT INTO _glossary VALUES ('fr', 'docs-07-h-wateapi', 'Interface _WATE_API', 202);
INSERT INTO _glossary VALUES ('en', 'docs-07-h-wateapi', '_WATE_API interface', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-07-p-wateapi',
  '<p>Chaque module reçoit l''objet <code>api</code> en argument de <code>init(param, api)</code>. Il donne accès aux primitives du moteur sans exposer ses internes :</p> <ul> <li><code>api.app</code> — instance Express partagée. <code>app.locals</code> contient <code>tableHooks</code>, <code>jsHandlers</code> et <code>SESSION_TTL_S</code></li> <li><code>api.log</code> — logger avec méthodes <code>.INFO()</code>, <code>.WARN()</code>, <code>.ERROR()</code></li> <li><code>api.db.run(sql, params, cb)</code> / <code>.all()</code> / <code>.get()</code> — requêtes SQL paramétrées, protégées via placeholders <code>?</code></li> <li><code>api.renderPage(req, res, targetUrl?, extraData?)</code> — force le rendu d''une page DB via le pipeline <code>serve()</code> standard</li> <li><code>api.renderError(req, res, code, msg, nextUrl?)</code> — affiche une page d''erreur standard</li> <li><code>api.hooks.onPageLoad(name, callback)</code> — injecte des données avant le rendu EJS. La clé doit correspondre à <code>_item.HOOK</code></li> <li><code>api.hooks.onTableWrite(table, action, callback)</code> — intercepte INSERT/UPDATE/DELETE. Le callback reçoit <code>(req, next)</code> : modifier <code>req.body</code>, appeler <code>next()</code> pour continuer ou <code>next(err)</code> pour annuler</li> </ul>',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-07-p-wateapi',
  '<p>Every module receives the <code>api</code> object as argument to <code>init(param, api)</code>. It provides access to engine primitives without exposing internals:</p> <ul> <li><code>api.app</code> — shared Express instance. <code>app.locals</code> holds <code>tableHooks</code>, <code>jsHandlers</code> and <code>SESSION_TTL_S</code></li> <li><code>api.log</code> — structured logger with <code>.INFO()</code>, <code>.WARN()</code>, <code>.ERROR()</code> methods</li> <li><code>api.db.run(sql, params, cb)</code> / <code>.all()</code> / <code>.get()</code> — parameterized SQL queries, safe from injection via <code>?</code> placeholders</li> <li><code>api.renderPage(req, res, targetUrl?, extraData?)</code> — forces a DB page render through the standard <code>serve()</code> pipeline</li> <li><code>api.renderError(req, res, code, msg, nextUrl?)</code> — renders a standard error page</li> <li><code>api.hooks.onPageLoad(name, callback)</code> — injects data before EJS render. The hook key must match <code>_item.HOOK</code></li> <li><code>api.hooks.onTableWrite(table, action, callback)</code> — intercepts INSERT/UPDATE/DELETE. Callback receives <code>(req, next)</code>: modify <code>req.body</code>, call <code>next()</code> to proceed or <code>next(err)</code> to abort</li> </ul>',
  202);

-- 7.6 Créer un module applicatif
INSERT INTO _glossary VALUES ('fr', 'docs-07-h-create', 'Créer un module', 202);
INSERT INTO _glossary VALUES ('en', 'docs-07-h-create', 'Creating a module', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-07-p-create',
  '<p>Un module WaTE exporte deux fonctions optionnelles :</p> <ul> <li><code>init(param, api)</code> — appelée au chargement. Peut être async (timeout 10 s). Reçoit la config et l''API complète (ou restreinte pour <code>--ejs</code>)</li> <li><code>done()</code> — appelée à l''arrêt pour le nettoyage (connexions, timers, ressources)</li> </ul> <p>Chargement via <code>--mod</code> (API complète) ou <code>--ejs</code> (restreint à <code>log</code>+<code>app</code>). Syntaxe : <code>nom[:alias][=param]</code>. Exemples : <code>auth=3600</code>, <code>mail:smtp={"host":"..."}</code>. Les modules moteur (auth, db, stats, mail, audit, search, apikey, cron) sont résolus depuis le répertoire du moteur. Les modules applicatifs depuis <code>&lt;app&gt;/scripts/&lt;nom&gt;</code>. Noms validés contre <code>/^[a-zA-Z0-9_-]+$/</code> (anti path-traversal).</p> <pre><code>// Module minimal (scripts/mon-module.js)
module.exports = {
  init(param, api) {
    api.log.INFO("Module chargé")
    api.app.get("/api/perso", (req, res) => res.json({ ok: true }))
  },
  done() {
    // Nettoyage : fermer connexions, annuler timers...
  }
}</code></pre> <p>Les modules peuvent enregistrer des hooks <code>onPageLoad</code> (injection avant rendu EJS) et <code>onTableWrite</code> (interception INSERT/UPDATE/DELETE).</p>',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-07-p-create',
  '<p>A WaTE module exports two optional functions:</p> <ul> <li><code>init(param, api)</code> — called at load time. Can be async (10 s timeout). Receives config and the full API (or restricted for <code>--ejs</code>)</li> <li><code>done()</code> — called at shutdown for cleanup (connections, timers, resources)</li> </ul> <p>Loading via <code>--mod</code> (full API) or <code>--ejs</code> (restricted to <code>log</code>+<code>app</code>). Syntax: <code>name[:alias][=param]</code>. Examples: <code>auth=3600</code>, <code>mail:smtp={"host":"..."}</code>. Engine modules (auth, db, stats, mail, audit, search, apikey, cron) resolve from the engine directory. Application modules from <code>&lt;app&gt;/scripts/&lt;name&gt;</code>. Names validated against <code>/^[a-zA-Z0-9_-]+$/</code> (anti path-traversal).</p> <pre><code>// Minimal module (scripts/my-module.js)
module.exports = {
  init(param, api) {
    api.log.INFO("Module loaded")
    api.app.get("/api/custom", (req, res) => res.json({ ok: true }))
  },
  done() {
    // Cleanup: close connections, clear timers...
  }
}</code></pre> <p>Modules can register <code>onPageLoad</code> hooks (inject data before EJS render) and <code>onTableWrite</code> hooks (intercept INSERT/UPDATE/DELETE).</p>',
  202);

-- 7.7 Fonctions cœur : serve() et modify()
INSERT INTO _glossary VALUES ('fr', 'docs-07-h-core', 'Pipeline de rendu et d''écriture', 202);
INSERT INTO _glossary VALUES ('en', 'docs-07-h-core', 'Render and write pipeline', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-07-p-core',
  '<p><code>serve(req, res, data?, urlOverride?)</code> — pipeline de rendu GET :</p> <ol> <li>Validation de la session</li> <li>Chargement des <code>_item</code> via UNION <code>_page</code>/<code>_item</code></li> <li>Exécution des requêtes SQL dans un sandbox VM (syntaxe <code>${expr:type}</code>)</li> <li>Fusion des résultats + chargement du glossaire scopé</li> <li>Exécution des hooks onPageLoad</li> <li>Rendu du template EJS</li> </ol> <p>Erreurs : <code>401</code> (session), <code>403</code> (accès), <code>404</code> (page), <code>500</code> (requête).</p> <p><code>modify(req, res, responder?)</code> — écriture INSERT/UPDATE/DELETE :</p> <ol> <li>Validation du nom de table (<code>/^[a-zA-Z0-9_]+$/</code>)</li> <li>Vérification de la session</li> <li>Vérification ACL via <code>_access</code></li> <li>Présence des colonnes PK pour UPDATE/DELETE</li> <li>Exécution du hook onTableWrite</li> <li>Écriture SQL</li> </ol> <p>Les opérations <code>-self</code> (update-self, delete-self) filtrent automatiquement sur la colonne <code>email</code> de la session. Utilisables directement par les modules applicatifs pour créer des routes personnalisées.</p>',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-07-p-core',
  '<p><code>serve(req, res, data?, urlOverride?)</code> — GET rendering pipeline:</p> <ol> <li>Session validation</li> <li><code>_item</code> loading via <code>_page</code>/<code>_item</code> UNION</li> <li>SQL query execution in a VM sandbox (<code>${expr:type}</code> syntax)</li> <li>Result merging + scoped glossary loading</li> <li>onPageLoad hook execution</li> <li>EJS template rendering</li> </ol> <p>Errors: <code>401</code> (session), <code>403</code> (access), <code>404</code> (page), <code>500</code> (query).</p> <p><code>modify(req, res, responder?)</code> — INSERT/UPDATE/DELETE write:</p> <ol> <li>Table name validation (<code>/^[a-zA-Z0-9_]+$/</code>)</li> <li>Session check</li> <li>ACL check via <code>_access</code></li> <li>PK columns present for UPDATE/DELETE</li> <li>onTableWrite hook execution</li> <li>SQL write</li> </ol> <p><code>-self</code> operations (update-self, delete-self) automatically filter on the session <code>email</code> column. Usable directly by application modules to create custom routes.</p>',
  202);

-- ── Section 8 — Sécurité ──────────────────────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'docs-08-title', 'Sécurité', 202);
INSERT INTO _glossary VALUES ('en', 'docs-08-title', 'Security', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-08-lead',
  'Le moteur applique des défenses standard à toutes les opérations sensibles. Cette section liste ce qui est en place par défaut et ce qu''il faut savoir pour ne pas le contourner par accident.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-lead',
  'The engine applies standard defenses to every sensitive operation. This section lists what''s in place by default and what you need to know not to bypass it by accident.',
  202);

-- 8.1 Protection CSRF
INSERT INTO _glossary VALUES ('fr', 'docs-08-h-csrf', 'Protection CSRF',  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-h-csrf', 'CSRF protection',  202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-p-csrf',
  'À chaque requête servie, le moteur émet un jeton CSRF dans une balise meta. Le script scripts/csrf.js l''injecte automatiquement dans tout formulaire avant soumission. Toute requête mutating (POST, PUT, DELETE) qui ne porte pas le bon jeton est rejetée — pas de configuration à activer, c''est le comportement par défaut.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-p-csrf',
  'On every served request, the engine emits a CSRF token in a meta tag. The scripts/csrf.js script automatically injects it into any form before submission. Any mutating request (POST, PUT, DELETE) without the correct token is rejected — no configuration to enable, that''s the default behavior.',
  202);

-- 8.2 Mots de passe
INSERT INTO _glossary VALUES ('fr', 'docs-08-h-pwd', 'Mots de passe',  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-h-pwd', 'Passwords',      202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-p-pwd',
  'Hashage PBKDF2 avec sel par utilisateur. L''utilitaire migrate-password.js permet de migrer les bases existantes qui utiliseraient un schéma plus ancien — il relit chaque _user, recalcule le hash, met à jour la ligne, le tout dans une transaction.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-p-pwd',
  'PBKDF2 hashing with per-user salt. The migrate-password.js utility migrates existing databases that use an older scheme — it reads each _user, recomputes the hash and updates the row, all within a transaction.',
  202);

-- 8.3 Sessions
INSERT INTO _glossary VALUES ('fr', 'docs-08-h-sessions', 'Sessions', 202);
INSERT INTO _glossary VALUES ('en', 'docs-08-h-sessions', 'Sessions', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-p-sessions',
  'Cookie HttpOnly, durée de vie configurable via le paramètre auth=N (en secondes). Une session expirée est filtrée à la lecture — pas besoin de tâche de nettoyage. La session fantôme id=''0'' est strictement distincte des sessions utilisateurs réelles : son expiration à l''an 2286 lui assure de ne jamais tomber dans le filtre TTL.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-p-sessions',
  'HttpOnly cookie, configurable TTL via the auth=N parameter (in seconds). An expired session is filtered at read time — no cleanup task needed. The ghost session id=''0'' is strictly distinct from real user sessions: its expiration in year 2286 ensures it never trips the TTL filter.',
  202);

-- 8.4 Contrôle d'accès
INSERT INTO _glossary VALUES ('fr', 'docs-08-h-access', 'Contrôle d''accès',  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-h-access', 'Access control',     202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-p-access',
  'Chaque opération mutating consulte la table _access pour le triplet (profil, table, requête). Convention utile : update accorde implicitement update-self (filtre sur l''email du compte), mais update-self n''accorde pas update complet. Le moteur ne teste jamais profil_id en dur : tout est piloté par cette table — vous pouvez créer autant de profils que nécessaire.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-p-access',
  'Every mutating operation checks the _access table for the (profile, table, request) triple. Useful convention: update implicitly grants update-self (filtered by account email), but update-self does not grant full update. The engine never hard-codes profil_id checks: everything is driven by that table — you can create as many profiles as needed.',
  202);

-- 8.5 XSS et templates
INSERT INTO _glossary VALUES ('fr', 'docs-08-h-xss', 'XSS et templates',   202);
INSERT INTO _glossary VALUES ('en', 'docs-08-h-xss', 'XSS and templates',  202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-p-xss',
  'La fonction parse() de custom.js échappe systématiquement les valeurs d''attributs interpolées dans les templates des custom elements. Le préfixe ! ne doit être utilisé que pour les valeurs déjà sûres (HTML maîtrisé). Côté EJS : préférer <%=…%> qui échappe ; <%-…%> ne s''utilise que pour réinjecter du HTML produit par le moteur lui-même.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-p-xss',
  'The parse() function in custom.js systematically escapes attribute values interpolated in custom-element templates. The ! prefix should only be used for already-safe values (HTML you control). On the EJS side: prefer <%=…%> which escapes; <%-…%> is only for re-injecting HTML produced by the engine itself.',
  202);

-- Diagramme flow : pipeline d'une requête mutating sécurisée
INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-title', 'Pipeline d''une requête mutating', 202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-title', 'Mutating request pipeline',       202);

INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-cookie-l', 'Cookie',           202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-cookie-l', 'Cookie',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-cookie-n', 'Session lue',      202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-cookie-n', 'Session read',     202);

INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-csrf-l',  'CSRF',              202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-csrf-l',  'CSRF',              202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-csrf-n',  'Jeton vérifié',     202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-csrf-n',  'Token verified',    202);

INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-prof-l',  'Profil',            202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-prof-l',  'Profile',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-prof-n',  'Résolu via _user',  202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-prof-n',  'Resolved via _user', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-acc-l',   '_access',           202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-acc-l',   '_access',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-acc-n',   'Droit accordé',     202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-acc-n',   'Right granted',     202);

INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-mod-l',   '_data.modify',      202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-mod-l',   '_data.modify',      202);
INSERT INTO _glossary VALUES ('fr', 'docs-08-flow-mod-n',   'INSERT/UPDATE',     202);
INSERT INTO _glossary VALUES ('en', 'docs-08-flow-mod-n',   'INSERT/UPDATE',     202);

-- ── Section 9 — i18n et glossaire ─────────────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'docs-09-title', 'i18n et glossaire',     202);
INSERT INTO _glossary VALUES ('en', 'docs-09-title', 'i18n and glossary',     202);

INSERT INTO _glossary VALUES ('fr', 'docs-09-lead',
  'WaTE traite la traduction comme du contenu : pas de fichiers .po ni .json à compiler, tous les textes vivent dans la table _glossary. Ajouter une langue revient à insérer des lignes ; corriger une faute de frappe est un UPDATE.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-09-lead',
  'WaTE treats translation as content: no .po or .json files to compile, every text lives in the _glossary table. Adding a language is just inserting rows; fixing a typo is an UPDATE.',
  202);

-- 9.1 Table _glossary
INSERT INTO _glossary VALUES ('fr', 'docs-09-h-glossary', 'La table _glossary', 202);
INSERT INTO _glossary VALUES ('en', 'docs-09-h-glossary', 'The _glossary table', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-09-p-glossary',
  'Schéma : (language, name, content, list_id). Le triplet (language, name, list_id) forme la clé. content porte le texte traduit ; il peut contenir du HTML maîtrisé si la vue qui le consomme utilise <%-…%>.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-09-p-glossary',
  'Schema: (language, name, content, list_id). The (language, name, list_id) triple forms the key. content carries the translated text; it may include controlled HTML if the consuming view uses <%-…%>.',
  202);

-- 9.2 Portée par list_id
INSERT INTO _glossary VALUES ('fr', 'docs-09-h-scope', 'Portée par list_id',  202);
INSERT INTO _glossary VALUES ('en', 'docs-09-h-scope', 'Scoping by list_id',  202);
INSERT INTO _glossary VALUES ('fr', 'docs-09-p-scope',
  'list_id NULL signifie « toujours chargé » — utile pour le header, la nav, les chaînes communes du footer. Un list_id non nul restreint la clé à la page concernée. Ce mécanisme évite les collisions de noms entre sections d''un site : une clé title peut signifier des choses différentes sur deux pages distinctes.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-09-p-scope',
  'A NULL list_id means "always loaded" — useful for header, nav, shared footer strings. A non-null list_id scopes the key to its page. This mechanism avoids name collisions between sections of a site: a title key can mean different things on two distinct pages.',
  202);

-- 9.3 Détection de langue
INSERT INTO _glossary VALUES ('fr', 'docs-09-h-lang', 'Détection de langue',  202);
INSERT INTO _glossary VALUES ('en', 'docs-09-h-lang', 'Language detection',   202);
INSERT INTO _glossary VALUES ('fr', 'docs-09-p-lang',
  'Le moteur cherche la langue dans cet ordre : query string ?lang=fr|en, en-tête HTTP Accept-Language, défaut configurable. La langue résolue est passée aux templates via la variable lang et préservée dans tous les liens internes pour ne pas perdre le choix utilisateur en navigant.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-09-p-lang',
  'The engine looks for the language in this order: query string ?lang=fr|en, HTTP Accept-Language header, configurable default. The resolved language is passed to templates as the lang variable and preserved in every internal link so the user''s choice doesn''t vanish on navigation.',
  202);

-- 9.4 Helper _gi
INSERT INTO _glossary VALUES ('fr', 'docs-09-h-gi', 'Helper _gi(result, name)',     202);
INSERT INTO _glossary VALUES ('en', 'docs-09-h-gi', 'The _gi(result, name) helper', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-09-p-gi',
  'Dans tout template, _gi(result, ''docs-09-title'') retourne le content correspondant à la langue courante et au list_id de la page. Le moteur charge automatiquement le sous-ensemble pertinent à chaque requête — pas besoin de filtrer manuellement.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-09-p-gi',
  'In any template, _gi(result, ''docs-09-title'') returns the content matching the current language and the page''s list_id. The engine automatically loads the relevant subset on each request — no manual filtering needed.',
  202);

-- ── Section 10 — Custom elements ──────────────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'docs-10-title', 'Custom elements',  202);
INSERT INTO _glossary VALUES ('en', 'docs-10-title', 'Custom elements',  202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-lead',
  'Côté client, WaTE n''impose aucun framework. Les morceaux d''interface réutilisables sont déclarés via des web components natifs, encapsulés dans le shadow DOM. Une seule fonction d''aide — customHTMLElement.create — suffit à en définir un.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-10-lead',
  'On the client side, WaTE imposes no framework. Reusable UI parts are declared as native web components, encapsulated in the shadow DOM. A single helper — customHTMLElement.create — is enough to define one.',
  202);

-- 10.1 customHTMLElement.create()
INSERT INTO _glossary VALUES ('fr', 'docs-10-h-base', 'customHTMLElement.create()', 202);
INSERT INTO _glossary VALUES ('en', 'docs-10-h-base', 'customHTMLElement.create()', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-p-base',
  'Signature : create(tagName, tagStyle, tagHTML, beforeScript, afterScript). Les chaînes tagStyle et tagHTML supportent l''interpolation ${attr} qui injecte la valeur d''un attribut, échappée pour neutraliser les XSS. Ajouter un ! devant le nom (${!attr}) saute l''échappement — réservé aux valeurs déjà sûres.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-10-p-base',
  'Signature: create(tagName, tagStyle, tagHTML, beforeScript, afterScript). The tagStyle and tagHTML strings support ${attr} interpolation which injects an attribute value, escaped to neutralize XSS. Adding ! before the name (${!attr}) skips escaping — reserved for already-safe values.',
  202);

-- 10.2 Catalogue moteur (+ stack)
INSERT INTO _glossary VALUES ('fr', 'docs-10-h-engine', 'Catalogue du moteur',  202);
INSERT INTO _glossary VALUES ('en', 'docs-10-h-engine', 'Engine catalog',       202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-p-engine',
  'Le moteur livre six éléments réutilisables, principalement orientés administration. Ils restent skinnables : placer un fichier de même nom dans custom/ de l''application surcharge le rendu visuel sans rien casser du comportement.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-10-p-engine',
  'The engine ships six reusable elements, mostly admin-oriented. They remain skinnable: dropping a file with the same name in the application''s custom/ overrides the visual rendering without breaking behavior.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-engine-title', 'Catalogue moteur', 202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-engine-title', 'Engine catalog',   202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-row-l',     'admin-row',           202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-row-l',     'admin-row',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-row-s',     'Ligne CRUD éditable', 202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-row-s',     'Editable CRUD row',   202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-list-l',    'admin-list',          202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-list-l',    'admin-list',          202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-list-s',    'Liste déroulante FK', 202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-list-s',    'FK dropdown',         202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-schema-l',  'schema-table',        202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-schema-l',  'schema-table',        202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-schema-s',  'Boîte Merise admin',  202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-schema-s',  'Admin Merise box',    202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-icon-l',    'icon-menu',           202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-icon-l',    'icon-menu',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-icon-s',    'Menu icône responsive', 202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-icon-s',    'Responsive icon menu',  202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-image-l',   'show-image',          202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-image-l',   'show-image',          202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-image-s',   'Image zoomable',      202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-image-s',   'Zoomable image',      202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-modal-l',   'modal-popup',         202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-modal-l',   'modal-popup',         202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-modal-s',   'alert/confirm + API', 202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-modal-s',   'alert/confirm + API', 202);

-- 10.3 Catalogue site vitrine (+ stack)
INSERT INTO _glossary VALUES ('fr', 'docs-10-h-site', 'Catalogue site vitrine', 202);
INSERT INTO _glossary VALUES ('en', 'docs-10-h-site', 'Showcase-site catalog',  202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-p-site',
  'Le site vitrine apporte ses propres éléments dédiés à la documentation : carte d''appel à l''action, schéma en pile, flux d''étapes, arbre de fichiers et MCD Merise interactif. Aucun n''est livré par le moteur — ils vivent sous web/custom/ et illustrent qu''une application peut étendre WaTE sans le toucher.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-10-p-site',
  'The showcase site brings its own documentation-oriented elements: call-to-action card, stack schema, step flow, file tree and interactive Merise MCD. None ship with the engine — they live under web/custom/ and illustrate how an application can extend WaTE without touching it.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-site-title', 'Catalogue vitrine', 202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-site-title', 'Showcase catalog',  202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-card-l',    'wate-card',           202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-card-l',    'wate-card',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-card-s',    'Carte features',      202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-card-s',    'Feature card',        202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-stk-l',     'wate-stack',          202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-stk-l',     'wate-stack',          202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-stk-s',     'Pile de couches',     202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-stk-s',     'Layered stack',       202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-flow-l',    'wate-flow',           202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-flow-l',    'wate-flow',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-flow-s',    'Flux d''étapes',      202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-flow-s',    'Step flow',           202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-tree-l',    'wate-tree',           202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-tree-l',    'wate-tree',           202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-tree-s',    'Arbre de fichiers',   202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-tree-s',    'File tree',           202);

INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-mcd-l',     'wate-mcd',            202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-mcd-l',     'wate-mcd',            202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-stack-mcd-s',     'MCD Merise SVG',      202);
INSERT INTO _glossary VALUES ('en', 'docs-10-stack-mcd-s',     'Merise MCD SVG',      202);

-- 10.4 Override d'un custom element
INSERT INTO _glossary VALUES ('fr', 'docs-10-h-override', 'Override d''un custom element', 202);
INSERT INTO _glossary VALUES ('en', 'docs-10-h-override', 'Overriding a custom element',  202);
INSERT INTO _glossary VALUES ('fr', 'docs-10-p-override',
  'Express sert le premier fichier trouvé : placer custom/icon-menu/def.css dans le dossier statique de l''application supplante celui du moteur, sans toucher au comportement défini dans le def.js. C''est exactement ce que fait le site vitrine pour habiller le sélecteur de langue à sa charte.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-10-p-override',
  'Express serves the first file found: dropping custom/icon-menu/def.css in the application''s static folder overrides the engine''s, without touching the behavior defined in def.js. That''s exactly what the showcase site does to skin the language selector to its own charter.',
  202);

-- Section 11 — Déploiement (list 202)
INSERT INTO _glossary VALUES ('fr', 'docs-toc-11', '13. Déploiement', 202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-11', '13. Deployment',  202);

INSERT INTO _glossary VALUES ('fr', 'docs-11-lead',
  'Mettre WaTE en production : reverse proxy HTTPS, gestionnaire de processus, Docker, sauvegardes.',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-11-lead',
  'Taking WaTE to production: HTTPS reverse proxy, process manager, Docker, backups.',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-11-h-proxy', 'Reverse proxy et HTTPS', 202);
INSERT INTO _glossary VALUES ('en', 'docs-11-h-proxy', 'Reverse proxy and HTTPS', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-11-p-proxy',
  '<p>WaTE tourne en HTTP local et délègue le HTTPS à un reverse proxy. Le moteur est déjà configuré avec <code>trust proxy</code> (Express), donc les headers <code>X-Forwarded-*</code> sont respectés.</p> <ul> <li><b>Nginx</b> : <code>proxy_pass http://localhost:3011</code> + <code>certbot</code> pour Let''s Encrypt</li> <li><b>Caddy</b> : <code>reverse_proxy localhost:3011</code> (HTTPS automatique)</li> <li><b>Squid</b> : utilisé en interne par l''auteur pour exposer plusieurs services derrière une seule IP</li> </ul>',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-11-p-proxy',
  '<p>WaTE runs locally in HTTP and delegates HTTPS to a reverse proxy. The engine is already configured with <code>trust proxy</code> (Express), so <code>X-Forwarded-*</code> headers are honored.</p> <ul> <li><b>Nginx</b>: <code>proxy_pass http://localhost:3011</code> + <code>certbot</code> for Let''s Encrypt</li> <li><b>Caddy</b>: <code>reverse_proxy localhost:3011</code> (automatic HTTPS)</li> <li><b>Squid</b>: used internally by the author to expose multiple services behind a single IP</li> </ul>',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-11-h-process', 'Gestionnaire de processus (PM2)', 202);
INSERT INTO _glossary VALUES ('en', 'docs-11-h-process', 'Process manager (PM2)', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-11-p-process',
  '<p>PM2 maintient WaTE en vie et le relance en cas de crash.</p> <p>Configuration minimale :</p> <pre><code>pm2 start engine.js --name wate -- --port 3011 --db app.db --path ./ --mod auth,db</code></pre> <p>Options utiles : <code>--watch</code> (redémarrage si fichiers modifiés), <code>-i max</code> (cluster sur tous les cœurs CPU). <code>pm2 save</code> + <code>pm2 startup</code> pour le démarrage automatique au boot.</p>',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-11-p-process',
  '<p>PM2 keeps WaTE alive and restarts it on crash.</p> <p>Minimal setup:</p> <pre><code>pm2 start engine.js --name wate -- --port 3011 --db app.db --path ./ --mod auth,db</code></pre> <p>Useful options: <code>--watch</code> (restart on file changes), <code>-i max</code> (cluster across all CPU cores). <code>pm2 save</code> + <code>pm2 startup</code> for automatic boot startup.</p>',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-11-h-docker', 'Docker', 202);
INSERT INTO _glossary VALUES ('en', 'docs-11-h-docker', 'Docker', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-11-p-docker',
  '<p>Un <code>DockerFile</code> et un <code>docker-compose.yml</code> sont fournis. L''image utilise Node 4.9.1 (dernière release Node 4). <code>docker compose up -d</code> lance le conteneur en arrière-plan sur le port <code>8080:3011</code>. La base de données et les uploads sont montés en volumes pour persister entre les redéploiements. Pensez à adapter le <code>CMD</code> du <code>DockerFile</code> aux modules chargés (<code>--mod auth,db</code>).</p>',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-11-p-docker',
  '<p>A <code>DockerFile</code> and <code>docker-compose.yml</code> are provided. The image uses Node 4.9.1 (last Node 4 release). <code>docker compose up -d</code> starts the container in the background on port <code>8080:3011</code>. The database and uploads are mounted as volumes to persist across redeployments. Adjust the <code>DockerFile</code> <code>CMD</code> to match your loaded modules (<code>--mod auth,db</code>).</p>',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-11-h-backup', 'Sauvegarde de la base', 202);
INSERT INTO _glossary VALUES ('en', 'docs-11-h-backup', 'Database backup', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-11-p-backup',
  '<p>SQLite se sauvegarde en copiant le fichier <code>.db</code>, mais <b>ATTENTION</b> : ne jamais copier pendant une écriture.</p> <pre><code>sqlite3 app.db ".backup app-backup.db"</code></pre> <p>Cette commande pose un verrou le temps de la copie, garantissant une sauvegarde cohérente. En production, un cron ou une tâche planifiée l''exécute toutes les heures. Les fichiers WAL (<code>-wal</code>, <code>-shm</code>) sont automatiquement fusionnés au checkpoint.</p>',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-11-p-backup',
  '<p>SQLite backup is as simple as copying the <code>.db</code> file, but <b>CAUTION</b>: never copy during a write.</p> <pre><code>sqlite3 app.db ".backup app-backup.db"</code></pre> <p>This command holds a lock during the copy, guaranteeing a consistent backup. In production, a cron job or scheduled task runs this command hourly. WAL files (<code>-wal</code>, <code>-shm</code>) are automatically merged on checkpoint.</p>',
  202);

INSERT INTO _glossary VALUES ('fr', 'docs-11-h-env', 'Variables d''environnement', 202);
INSERT INTO _glossary VALUES ('en', 'docs-11-h-env', 'Environment variables', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-11-p-env',
  '<p><code>WATE_CSRF_SECRET</code> : secret CSRF (<code>SHA256(sessionId + secret)</code>). En production, ne pas le définir — le moteur en génère un aléatoire à chaque démarrage, invalidant les anciens tokens. En test, le fixer à une valeur connue pour pré-calculer les tokens.</p> <p><code>NODE_ENV=production</code> : désactive les logs verbeux de certaines dépendances. Les paramètres DB, port et modules se passent en ligne de commande (<code>--db</code>, <code>--port</code>, <code>--mod</code>).</p>',
  202);
INSERT INTO _glossary VALUES ('en', 'docs-11-p-env',
  '<p><code>WATE_CSRF_SECRET</code>: CSRF secret (<code>SHA256(sessionId + secret)</code>). In production, leave it unset — the engine generates a random one at each startup, invalidating old tokens. In tests, set it to a known value to pre-compute tokens.</p> <p><code>NODE_ENV=production</code>: disables verbose logs from some dependencies. DB, port and module parameters are passed via command line (<code>--db</code>, <code>--port</code>, <code>--mod</code>).</p>',
  202);

-- ── Code des exemples (list 201, lang_id NULL = indépendant de la langue) ─
-- Exemple 1 — Hello WaTE
INSERT INTO _glossary VALUES ('fr', 'ex1-sublabel-1', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-sublabel-1', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('fr', 'ex1-code-1',
'-- 1. Déclarer un regroupement d''items
INSERT INTO _list VALUES (300);

-- 2. Y attacher un template et un titre
INSERT INTO _item VALUES (300, ''template'', ''hello'');
INSERT INTO _item VALUES (300, ''title'',    ''hello-title'');

-- 3. Publier la page /hello pour le profil anonymous
INSERT INTO _page VALUES (''/hello'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id
     AND u.email = s.user_email
     AND s.id = ''0''), 300);

-- (Optionnel) Traduire le titre
INSERT INTO _glossary
  VALUES (''fr'', ''hello-title'', ''Bonjour'', NULL);
INSERT INTO _glossary
  VALUES (''en'', ''hello-title'', ''Hello'',   NULL);', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-code-1',
'-- 1. Declare an items group
INSERT INTO _list VALUES (300);

-- 2. Attach a template and a title
INSERT INTO _item VALUES (300, ''template'', ''hello'');
INSERT INTO _item VALUES (300, ''title'',    ''hello-title'');

-- 3. Publish the /hello page for the anonymous profile
INSERT INTO _page VALUES (''/hello'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id
     AND u.email = s.user_email
     AND s.id = ''0''), 300);

-- (Optional) Translate the title
INSERT INTO _glossary
  VALUES (''fr'', ''hello-title'', ''Bonjour'', NULL);
INSERT INTO _glossary
  VALUES (''en'', ''hello-title'', ''Hello'',   NULL);', 201);

INSERT INTO _glossary VALUES ('fr', 'ex1-sublabel-2', 'views/hello.ejs', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-sublabel-2', 'views/hello.ejs', 201);
INSERT INTO _glossary VALUES ('fr', 'ex1-code-2',
'<h1><%=_gi(result, ''hello-title'')%></h1>
<p>Bienvenue sur /hello.</p>', 201);
INSERT INTO _glossary VALUES ('en', 'ex1-code-2',
'<h1><%=_gi(result, ''hello-title'')%></h1>
<p>Welcome to /hello.</p>', 201);

-- Exemple 2 — Page bilingue
INSERT INTO _glossary VALUES ('fr', 'ex2-sublabel-1', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('en', 'ex2-sublabel-1', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('fr', 'ex2-code-1',
'-- Page /a-propos rendue par le template ''about''
INSERT INTO _list VALUES (301);
INSERT INTO _item VALUES (301, ''template'', ''about'');
INSERT INTO _item VALUES (301, ''title'',    ''title'');

INSERT INTO _page VALUES (''/a-propos'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id
     AND u.email = s.user_email
     AND s.id = ''0''), 301);

-- Glossaire SCOPÉ : list_id = 301 → réservé à cette page
INSERT INTO _glossary VALUES
  (''fr'', ''title'',  ''Notre histoire'',                   301),
  (''en'', ''title'',  ''Our story'',                        301),
  (''fr'', ''about-h'',''Notre histoire'',                   301),
  (''en'', ''about-h'',''Our story'',                        301),
  (''fr'', ''about-p'',''Une PME française fondée en 2024.'',301),
  (''en'', ''about-p'',''A French SME founded in 2024.'',    301);', 201);
INSERT INTO _glossary VALUES ('en', 'ex2-code-1',
'-- Page /a-propos rendered by the template ''about''
INSERT INTO _list VALUES (301);
INSERT INTO _item VALUES (301, ''template'', ''about'');
INSERT INTO _item VALUES (301, ''title'',    ''title'');

INSERT INTO _page VALUES (''/a-propos'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id
     AND u.email = s.user_email
     AND s.id = ''0''), 301);

-- SCOPED glossary: list_id = 301 → reserved to this page
INSERT INTO _glossary VALUES
  (''fr'', ''title'',  ''Notre histoire'',                   301),
  (''en'', ''title'',  ''Our story'',                        301),
  (''fr'', ''about-h'',''Notre histoire'',                   301),
  (''en'', ''about-h'',''Our story'',                        301),
  (''fr'', ''about-p'',''Une PME française fondée en 2024.'',301),
  (''en'', ''about-p'',''A French SME founded in 2024.'',    301);', 201);

INSERT INTO _glossary VALUES ('fr', 'ex2-sublabel-2', 'views/about.ejs', 201);
INSERT INTO _glossary VALUES ('en', 'ex2-sublabel-2', 'views/about.ejs', 201);
INSERT INTO _glossary VALUES ('fr', 'ex2-code-2',
'<h1><%=_gi(result, ''about-h'')%></h1>
<p><%=_gi(result, ''about-p'')%></p>', 201);
INSERT INTO _glossary VALUES ('en', 'ex2-code-2',
'<h1><%=_gi(result, ''about-h'')%></h1>
<p><%=_gi(result, ''about-p'')%></p>', 201);

-- Exemple 3 — Catalogue dynamique
INSERT INTO _glossary VALUES ('fr', 'ex3-sublabel-1', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('en', 'ex3-sublabel-1', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('fr', 'ex3-code-1',
'-- Table métier
CREATE TABLE produit (
  id    INTEGER PRIMARY KEY,
  nom   TEXT NOT NULL,
  prix  REAL NOT NULL
);
INSERT INTO produit VALUES
  (1, ''Carafe en grès'',   24.00),
  (2, ''Plateau en chêne'', 38.00),
  (3, ''Bol émaillé'',      14.50);

-- Page /catalogue : queries pointe sur SELECT * FROM produit
INSERT INTO _list VALUES (302);
INSERT INTO _item VALUES (302, ''template'', ''catalogue'');
INSERT INTO _item VALUES (302, ''title'',    ''cat-title'');
INSERT INTO _item VALUES (302, ''queries'',
  ''"products": { "request": "SELECT * FROM produit ORDER BY nom",
                 "values":  [] }'');

INSERT INTO _page VALUES (''/catalogue'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id
     AND u.email = s.user_email
     AND s.id = ''0''), 302);', 201);
INSERT INTO _glossary VALUES ('en', 'ex3-code-1',
'-- Business table
CREATE TABLE product (
  id    INTEGER PRIMARY KEY,
  name  TEXT NOT NULL,
  price REAL NOT NULL
);
INSERT INTO product VALUES
  (1, ''Stoneware carafe'', 24.00),
  (2, ''Oak tray'',         38.00),
  (3, ''Enamel bowl'',      14.50);

-- Page /catalog : queries points at SELECT * FROM product
INSERT INTO _list VALUES (302);
INSERT INTO _item VALUES (302, ''template'', ''catalogue'');
INSERT INTO _item VALUES (302, ''title'',    ''cat-title'');
INSERT INTO _item VALUES (302, ''queries'',
  ''"products": { "request": "SELECT * FROM product ORDER BY name",
                 "values":  [] }'');

INSERT INTO _page VALUES (''/catalogue'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id
     AND u.email = s.user_email
     AND s.id = ''0''), 302);', 201);

INSERT INTO _glossary VALUES ('fr', 'ex3-sublabel-2', 'views/catalogue.ejs', 201);
INSERT INTO _glossary VALUES ('en', 'ex3-sublabel-2', 'views/catalogue.ejs', 201);
INSERT INTO _glossary VALUES ('fr', 'ex3-code-2',
'<h1>Catalogue</h1>
<ul>
<% result.products.rows.forEach(function(p) { %>
  <li><strong><%=p.nom%></strong> — <%=p.prix.toFixed(2)%> €</li>
<% }) %>
</ul>', 201);
INSERT INTO _glossary VALUES ('en', 'ex3-code-2',
'<h1>Catalog</h1>
<ul>
<% result.products.rows.forEach(function(p) { %>
  <li><strong><%=p.name%></strong> — <%=p.price.toFixed(2)%> €</li>
<% }) %>
</ul>', 201);

-- Exemple 4 — Hook onPageLoad
INSERT INTO _glossary VALUES ('fr', 'ex4-sublabel-1', 'scripts/weather.js', 201);
INSERT INTO _glossary VALUES ('en', 'ex4-sublabel-1', 'scripts/weather.js', 201);
INSERT INTO _glossary VALUES ('fr', 'ex4-code-1',
'// Module applicatif chargé via : init({ mod: [''weather''] })
// L''API officielle est passée en 2e argument : api.hooks, api.db, …
// Ne jamais utiliser app.locals (réservé aux modules internes).
exports.init = function(param, api) {
  api.hooks.onPageLoad(''weather'', async function(req, elements) {
    const data = await fetchWeather(''Paris'')
    return { key: ''weather'', value: data }
  })
}
async function fetchWeather(city) {
  return { city, temp: 14, sky: ''clear'' }
}', 201);
INSERT INTO _glossary VALUES ('en', 'ex4-code-1',
'// Application module loaded via: init({ mod: [''weather''] })
// The official API is passed as 2nd argument: api.hooks, api.db, …
// Never use app.locals (reserved for internal engine modules).
exports.init = function(param, api) {
  api.hooks.onPageLoad(''weather'', async function(req, elements) {
    const data = await fetchWeather(''Paris'')
    return { key: ''weather'', value: data }
  })
}
async function fetchWeather(city) {
  return { city, temp: 57, sky: ''clear'' }
}', 201);

INSERT INTO _glossary VALUES ('fr', 'ex4-sublabel-2', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('en', 'ex4-sublabel-2', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('fr', 'ex4-code-2',
'INSERT INTO _list VALUES (303);
INSERT INTO _item VALUES (303, ''template'', ''dashboard'');
INSERT INTO _item VALUES (303, ''title'',    ''dash-title'');
INSERT INTO _item VALUES (303, ''HOOK'',     ''weather'');

INSERT INTO _page VALUES (''/dashboard'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id
     AND u.email = s.user_email
     AND s.id = ''0''), 303);', 201);
INSERT INTO _glossary VALUES ('en', 'ex4-code-2',
'INSERT INTO _list VALUES (303);
INSERT INTO _item VALUES (303, ''template'', ''dashboard'');
INSERT INTO _item VALUES (303, ''title'',    ''dash-title'');
INSERT INTO _item VALUES (303, ''HOOK'',     ''weather'');

INSERT INTO _page VALUES (''/dashboard'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id
     AND u.email = s.user_email
     AND s.id = ''0''), 303);', 201);

INSERT INTO _glossary VALUES ('fr', 'ex4-sublabel-3', 'views/dashboard.ejs', 201);
INSERT INTO _glossary VALUES ('en', 'ex4-sublabel-3', 'views/dashboard.ejs', 201);
INSERT INTO _glossary VALUES ('fr', 'ex4-code-3',
'<h1>Tableau de bord</h1>
<p>
  <%=result.weather.city%> :
  <%=result.weather.temp%> °C, <%=result.weather.sky%>.
</p>', 201);
INSERT INTO _glossary VALUES ('en', 'ex4-code-3',
'<h1>Dashboard</h1>
<p>
  <%=result.weather.city%>:
  <%=result.weather.temp%> °F, <%=result.weather.sky%>.
</p>', 201);

-- Exemple 5 — Route applicative + renderPage()
INSERT INTO _glossary VALUES ('fr', 'ex5-sublabel-1', 'scripts/dashboard.js', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-sublabel-1', 'scripts/dashboard.js', 201);
INSERT INTO _glossary VALUES ('fr', 'ex5-code-1',
'// Module applicatif chargé via : init({ mod: [''dashboard''] })

exports.init = function(param, api) {
  // Route Express applicative : on passe par api.app, jamais app.locals.
  api.app.get(''/dashboard'', function(req, res) {
    // Refus du profil anonymous (session.id === 0) → 401
    if (!req.cookies.session) {
      return api.renderError(req, res, 401, null, ''/admin/form/auth/signin'')
    }
    // Délégation au pipeline CMS — le moteur charge _item,
    // _glossary, queries, puis rend le template.
    api.renderPage(req, res, ''/dashboard'')
  })
}', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-code-1',
'// Application module loaded via: init({ mod: [''dashboard''] })

exports.init = function(param, api) {
  // Application Express route: use api.app, never app.locals.
  api.app.get(''/dashboard'', function(req, res) {
    // Deny anonymous profile (session.id === 0) → 401
    if (!req.cookies.session) {
      return api.renderError(req, res, 401, null, ''/admin/form/auth/signin'')
    }
    // Delegate to the CMS pipeline — engine loads _item,
    // _glossary, queries, then renders the template.
    api.renderPage(req, res, ''/dashboard'')
  })
}', 201);

INSERT INTO _glossary VALUES ('fr', 'ex5-sublabel-2', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-sublabel-2', 'migrations/001_app.sql', 201);
INSERT INTO _glossary VALUES ('fr', 'ex5-code-2',
'INSERT INTO _list VALUES (304);
INSERT INTO _item VALUES (304, ''template'', ''dashboard'');
INSERT INTO _item VALUES (304, ''title'',    ''dash-title'');

-- Profil 2 (admin) — la route applicative gère le contrôle d''accès
INSERT INTO _page VALUES (''/dashboard'', 2, 304);', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-code-2',
'INSERT INTO _list VALUES (304);
INSERT INTO _item VALUES (304, ''template'', ''dashboard'');
INSERT INTO _item VALUES (304, ''title'',    ''dash-title'');

-- Profile 2 (admin) — the application route handles access control
INSERT INTO _page VALUES (''/dashboard'', 2, 304);', 201);

INSERT INTO _glossary VALUES ('fr', 'ex5-sublabel-3', 'views/dashboard.ejs', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-sublabel-3', 'views/dashboard.ejs', 201);
INSERT INTO _glossary VALUES ('fr', 'ex5-code-3',
'<h1>Tableau de bord (privé)</h1>
<p>Bonjour, <%=req.cookies.userName || ''utilisateur''%>.
   3 nouvelles notifications.</p>', 201);
INSERT INTO _glossary VALUES ('en', 'ex5-code-3',
'<h1>Dashboard (private)</h1>
<p>Hi, <%=req.cookies.userName || ''user''%>.
   3 new notifications.</p>', 201);

-- ═══════════════════════════════════════════════════════════════════════
-- Section 12 — API CRUD avancée (tri, filtre, recherche, export)
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO _glossary VALUES ('fr', 'docs-toc-12', '6. API CRUD — tri, filtre, recherche, export', 202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-12', '6. CRUD API — sort, filter, search, export',  202);

INSERT INTO _glossary VALUES ('fr', 'docs-12-lead',
  'L''API CRUD de WaTE s''enrichit de paramètres de requête pour trier, filtrer et rechercher les données. Un endpoint d''export CSV/JSON complète le dispositif pour extraire les données au format souhaité.', 202);
INSERT INTO _glossary VALUES ('en', 'docs-12-lead',
  'The WaTE CRUD API accepts query parameters to sort, filter and search data. A CSV/JSON export endpoint allows extracting data in the desired format.', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-12-h-sort',  'Tri des résultats', 202);
INSERT INTO _glossary VALUES ('en', 'docs-12-h-sort',  'Sorting results',   202);
INSERT INTO _glossary VALUES ('fr', 'docs-12-p-sort',
  '<p>Le paramètre <code>sort</code> accepte un nom de colonne. Seules les colonnes réelles de la table (validées via PRAGMA table_info) sont autorisées — toute colonne inconnue est ignorée sans erreur. La direction se contrôle avec <code>dir=asc</code> (défaut) ou <code>dir=desc</code>. Exemple : <code>GET /admin/api/db/produit?sort=prix&amp;dir=desc</code>. La clause ORDER BY est construite avec des identifiants double-quotés pour se protéger des mots-clés réservés SQL.</p>', 202);
INSERT INTO _glossary VALUES ('en', 'docs-12-p-sort',
  '<p>The <code>sort</code> parameter accepts a column name. Only real table columns (validated via PRAGMA table_info) are allowed — unknown columns are silently ignored. Direction is controlled with <code>dir=asc</code> (default) or <code>dir=desc</code>. Example: <code>GET /admin/api/db/product?sort=price&amp;dir=desc</code>. The ORDER BY clause uses double-quoted identifiers to protect against SQL reserved keywords.</p>', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-12-h-filter',  'Filtrage exact', 202);
INSERT INTO _glossary VALUES ('en', 'docs-12-h-filter',  'Exact filtering', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-12-p-filter',
  '<p>Le paramètre <code>filter</code> accepte une liste de paires <code>colonne:valeur</code> séparées par des virgules. Chaque colonne est validée contre le schéma réel. Les valeurs passent par des paramètres préparés (<code>?</code>) — aucune interpolation SQL. Les filtres sont combinés en AND. Exemple : <code>GET /admin/api/db/produit?filter=categorie:livre,stock:0</code> retourne les produits de la catégorie ''livre'' avec un stock de 0.</p>', 202);
INSERT INTO _glossary VALUES ('en', 'docs-12-p-filter',
  '<p>The <code>filter</code> parameter accepts a comma-separated list of <code>column:value</code> pairs. Each column is validated against the real schema. Values use prepared statement placeholders (<code>?</code>) — no SQL interpolation. Filters are combined with AND. Example: <code>GET /admin/api/db/product?filter=category:book,stock:0</code> returns products in the ''book'' category with zero stock.</p>', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-12-h-search',  'Recherche texte', 202);
INSERT INTO _glossary VALUES ('en', 'docs-12-h-search',  'Text search',     202);
INSERT INTO _glossary VALUES ('fr', 'docs-12-p-search',
  '<p>Le paramètre <code>search</code> effectue une recherche LIKE sur toutes les colonnes de type texte (CHAR, TEXT, CLOB) de la table. Le terme est encadré par des wildcards <code>%</code> et les recherches sur plusieurs colonnes sont combinées en OR. Les valeurs passent par des paramètres préparés. Exemple : <code>GET /admin/api/db/produit?search=chêne</code> trouve tous les produits contenant "chêne" dans leurs colonnes texte. Cette recherche est distincte du module FTS5 (section 13) qui indexe le glossaire et les items de page.</p>', 202);
INSERT INTO _glossary VALUES ('en', 'docs-12-p-search',
  '<p>The <code>search</code> parameter performs a LIKE search across all text-type columns (CHAR, TEXT, CLOB) of the table. The term is wrapped with <code>%</code> wildcards and multi-column searches are combined with OR. Values use prepared statement placeholders. Example: <code>GET /admin/api/db/product?search=oak</code> finds all products containing "oak" in their text columns. This search is distinct from the FTS5 module (section 13) which indexes glossary and page items.</p>', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-12-h-export',  'Export CSV/JSON', 202);
INSERT INTO _glossary VALUES ('en', 'docs-12-h-export',  'CSV/JSON export', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-12-p-export',
  '<p>Le endpoint <code>GET /admin/api/db/:table/export?format=csv|json</code> exporte toutes les lignes correspondant aux filtres en cours. Le CSV respecte la norme RFC 4180 (guillemets échappés, délimiteurs protégés) et inclut un BOM UTF-8 pour la compatibilité Excel. Le JSON utilise <code>Content-Disposition: attachment</code> pour déclencher le téléchargement. La limite d''export est configurable via <code>_config</code> (clé <code>db.maxExport</code>, défaut 10 000 lignes). Tous les paramètres de tri/filtre/recherche sont respectés.</p>', 202);
INSERT INTO _glossary VALUES ('en', 'docs-12-p-export',
  '<p>The <code>GET /admin/api/db/:table/export?format=csv|json</code> endpoint exports all rows matching current filters. CSV follows RFC 4180 (escaped quotes, protected delimiters) and includes a UTF-8 BOM for Excel compatibility. JSON uses <code>Content-Disposition: attachment</code> to trigger download. The export limit is configurable via <code>_config</code> (key <code>db.maxExport</code>, default 10,000 rows). All sort/filter/search parameters are respected.</p>', 202);

-- ═══════════════════════════════════════════════════════════════════════
-- Section 13 — Modules audit et recherche plein texte
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO _glossary VALUES ('fr', 'docs-toc-13', '9. Modules audit et recherche plein texte', 202);
INSERT INTO _glossary VALUES ('en', 'docs-toc-13', '9. Audit and full-text search modules',     202);

INSERT INTO _glossary VALUES ('fr', 'docs-13-lead',
  'Deux nouveaux modules optionnels enrichissent le moteur : <code>--mod audit</code> journalise toutes les écritures, <code>--mod search</code> indexe le contenu du site en FTS5.', 202);
INSERT INTO _glossary VALUES ('en', 'docs-13-lead',
  'Two new optional modules extend the engine: <code>--mod audit</code> logs all write operations, <code>--mod search</code> indexes site content with FTS5.', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-13-h-audit',  'Module audit', 202);
INSERT INTO _glossary VALUES ('en', 'docs-13-h-audit',  'Audit module', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-13-p-audit',
  '<p>Le module <code>--mod audit</code> enregistre automatiquement chaque INSERT, UPDATE et DELETE sur les tables applicatives dans une table <code>_audit</code>. Pour chaque écriture, il capture : la table concernée, le type d''opération, l''utilisateur (email de session), les anciennes valeurs (JSON), les nouvelles valeurs (JSON), et un horodatage. Le module s''appuie sur le mécanisme <code>tableHooks</code> existant — il wrappe les hooks sans les écraser. La table <code>_audit</code> est accessible en lecture seule via l''admin DB générique par le profil owner. La route <code>POST /admin/api/db/:table/undo</code> permet d''annuler la dernière écriture (insert/update/delete) d''un utilisateur — l''owner peut annuler n''importe quelle écriture avec <code>?all=true</code>. Aucune dépendance externe.</p>', 202);
INSERT INTO _glossary VALUES ('en', 'docs-13-p-audit',
  '<p>The <code>--mod audit</code> module automatically logs every INSERT, UPDATE and DELETE on application tables into an <code>_audit</code> table. For each write, it captures: the target table, operation type, user (session email), old values (JSON), new values (JSON), and a timestamp. The module leverages the existing <code>tableHooks</code> mechanism — it wraps hooks without overwriting them. The <code>_audit</code> table is read-accessible via the generic DB admin by the owner profile. The <code>POST /admin/api/db/:table/undo</code> route reverses the last write (insert/update/delete) by a user — the owner can undo any user''s write with <code>?all=true</code>. Zero external dependencies.</p>', 202);

INSERT INTO _glossary VALUES ('fr', 'docs-13-h-search',  'Module FTS5', 202);
INSERT INTO _glossary VALUES ('en', 'docs-13-h-search',  'FTS5 module', 202);
INSERT INTO _glossary VALUES ('fr', 'docs-13-p-search',
  '<p>Le module <code>--mod search</code> crée une table virtuelle FTS5 (<code>_fts</code>) qui indexe <code>_glossary.label</code> (les textes traduits du site) et <code>_item.value</code> (la configuration des pages). Des triggers SQLite maintiennent l''index automatiquement à chaque modification. La route <code>GET /admin/api/search?q=terme&amp;lang=fr</code> (admin, session requise) et <code>GET /api/search?q=terme&amp;lang=fr</code> (public, contenu du site uniquement) retournent les résultats avec snippets et URLs des pages associées. Une barre de recherche est intégrée au header admin et au header du site vitrine. Zéro dépendance externe — FTS5 est inclus dans SQLite 3.9+.</p>', 202);
INSERT INTO _glossary VALUES ('en', 'docs-13-p-search',
  '<p>The <code>--mod search</code> module creates an FTS5 virtual table (<code>_fts</code>) indexing <code>_glossary.label</code> (translated site texts) and <code>_item.value</code> (page configuration). SQLite triggers maintain the index automatically on every change. The <code>GET /admin/api/search?q=term&amp;lang=en</code> (admin, session required) and <code>GET /api/search?q=term&amp;lang=en</code> (public, site content only) routes return results with snippets and associated page URLs. A search bar is integrated into both the admin header and the showcase site header. Zero external dependencies — FTS5 is included in SQLite 3.9+.</p>', 202);

-- ═══════════════════════════════════════════════════════════════════════
-- Exemple 6 — Filtrer, trier et exporter les données
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO _glossary VALUES ('fr', 'ex6-num',   'Exemple 6', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-num',   'Example 6', 201);
INSERT INTO _glossary VALUES ('fr', 'ex6-title', 'Filtrer, trier et exporter les données', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-title', 'Filter, sort and export data', 201);
INSERT INTO _glossary VALUES ('fr', 'ex6-lead',
  'L''API CRUD de WaTE accepte des paramètres de requête pour trier (<code>sort</code>), filtrer (<code>filter</code>) et rechercher (<code>search</code>). Un endpoint d''export CSV/JSON permet de télécharger les données filtrées.', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-lead',
  'The WaTE CRUD API accepts query parameters to sort (<code>sort</code>), filter (<code>filter</code>) and search (<code>search</code>). A CSV/JSON export endpoint lets you download the filtered data.', 201);
INSERT INTO _glossary VALUES ('fr', 'ex6-explain',
  'La migration crée une table <code>article</code> et donne les droits au profil owner. Via l''API CRUD, on peut lister les articles triés par prix décroissant, filtrer par auteur, rechercher un mot dans le titre ou le contenu, et exporter le résultat en CSV.', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-explain',
  'The migration creates an <code>article</code> table and grants rights to the owner profile. Through the CRUD API, you can list articles sorted by price descending, filter by author, search for a word in the title or content, and export the result as CSV.', 201);

INSERT INTO _glossary VALUES ('fr', 'ex6-preview-h',  'GET /admin/api/db/article?sort=prix&dir=desc&filter=auteur:Hugo&search=Paris&limit=10', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-preview-h',  'GET /admin/api/db/article?sort=price&dir=desc&filter=author:Hugo&search=Paris&limit=10', 201);
INSERT INTO _glossary VALUES ('fr', 'ex6-preview-p',  'Trie les articles par prix décroissant, filtre sur l''auteur "Hugo", recherche "Paris" dans les colonnes texte, limite à 10 résultats. L''export CSV s''obtient en remplaçant /db/article par /db/article/export?format=csv avec les mêmes paramètres.', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-preview-p',  'Sorts articles by price descending, filters on author "Hugo", searches for "Paris" in text columns, limits to 10 results. CSV export is obtained by replacing /db/article with /db/article/export?format=csv with the same parameters.', 201);

INSERT INTO _glossary VALUES ('fr', 'ex6-sublabel-1', 'migrations/001_blog.sql', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-sublabel-1', 'migrations/001_blog.sql', 201);
INSERT INTO _glossary VALUES ('fr', 'ex6-code-1',
'CREATE TABLE article (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  titre   TEXT NOT NULL,
  contenu TEXT,
  auteur  TEXT,
  prix    REAL
);

INSERT INTO _list VALUES (301);
INSERT INTO _item VALUES (301, ''template'', ''blog-list'');
INSERT INTO _item VALUES (301, ''title'',    ''Articles'');
INSERT INTO _item VALUES (301, ''queries'',
  ''"_articles": {"request": "SELECT * FROM article ORDER BY titre","values":[]}'');

INSERT INTO _page VALUES (''/articles'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = ''0''), 301);

INSERT INTO _access VALUES (''article'', 0, ''select'');
INSERT INTO _access VALUES (''article'', 0, ''insert'');', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-code-1',
'CREATE TABLE article (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  title   TEXT NOT NULL,
  content TEXT,
  author  TEXT,
  price   REAL
);

INSERT INTO _list VALUES (301);
INSERT INTO _item VALUES (301, ''template'', ''blog-list'');
INSERT INTO _item VALUES (301, ''title'',    ''Articles'');
INSERT INTO _item VALUES (301, ''queries'',
  ''"_articles": {"request": "SELECT * FROM article ORDER BY title","values":[]}'');

INSERT INTO _page VALUES (''/articles'',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = ''0''), 301);

INSERT INTO _access VALUES (''article'', 0, ''select'');
INSERT INTO _access VALUES (''article'', 0, ''insert'');', 201);

INSERT INTO _glossary VALUES ('fr', 'ex6-sublabel-2', 'Exemples d''appels API', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-sublabel-2', 'API call examples', 201);
INSERT INTO _glossary VALUES ('fr', 'ex6-code-2',
'# Tri décroissant par prix
GET /admin/api/db/article?sort=prix&dir=desc

# Filtre exact sur auteur
GET /admin/api/db/article?filter=auteur:Hugo

# Recherche texte dans titre et contenu
GET /admin/api/db/article?search=Paris

# Combiné : tri + filtre + recherche + pagination
GET /admin/api/db/article?sort=prix&dir=desc&filter=auteur:Hugo&search=Paris&limit=10

# Export CSV des résultats filtrés
GET /admin/api/db/article/export?format=csv&filter=auteur:Hugo&sort=date&dir=desc

# Export JSON (défaut)
GET /admin/api/db/article/export?search=Paris', 201);
INSERT INTO _glossary VALUES ('en', 'ex6-code-2',
'# Sort descending by price
GET /admin/api/db/article?sort=price&dir=desc

# Exact filter on author
GET /admin/api/db/article?filter=author:Hugo

# Text search in title and content
GET /admin/api/db/article?search=Paris

# Combined: sort + filter + search + pagination
GET /admin/api/db/article?sort=price&dir=desc&filter=author:Hugo&search=Paris&limit=10

# CSV export of filtered results
GET /admin/api/db/article/export?format=csv&filter=author:Hugo&sort=date&dir=desc

# JSON export (default)
GET /admin/api/db/article/export?search=Paris', 201);

-- ═══════════════════════════════════════════════════════════════════════
-- Exemple 7 — Tracer les écritures avec le module audit
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO _glossary VALUES ('fr', 'ex7-num',   'Exemple 7', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-num',   'Example 7', 201);
INSERT INTO _glossary VALUES ('fr', 'ex7-title', 'Tracer les écritures avec le module audit', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-title', 'Trace writes with the audit module', 201);
INSERT INTO _glossary VALUES ('fr', 'ex7-lead',
  'Activez <code>--mod audit</code> pour journaliser automatiquement chaque INSERT, UPDATE et DELETE dans une table <code>_audit</code>. Consultez l''historique via l''admin DB générique.', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-lead',
  'Enable <code>--mod audit</code> to automatically log every INSERT, UPDATE and DELETE into an <code>_audit</code> table. Browse the history through the generic DB admin.', 201);
INSERT INTO _glossary VALUES ('fr', 'ex7-explain',
  'La migration crée la table <code>_audit</code> et donne les droits au profil owner. Le module <code>_audit.js</code> s''enregistre via <code>tableHooks</code> sur toutes les tables applicatives. Chaque écriture capture l''ancien et le nouvel état en JSON, avec l''email de l''utilisateur et un horodatage. L''admin DB générique permet de filtrer (<code>?filter=table_name:article</code>) et rechercher (<code>?search=admin@test</code>) dans l''historique.', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-explain',
  'The migration creates the <code>_audit</code> table and grants rights to the owner profile. The <code>_audit.js</code> module registers via <code>tableHooks</code> on all application tables. Each write captures the old and new state as JSON, with the user email and a timestamp. The generic DB admin allows filtering (<code>?filter=table_name:article</code>) and searching (<code>?search=admin@test</code>) in the history.', 201);

INSERT INTO _glossary VALUES ('fr', 'ex7-preview-h',  'Consultation de l''historique d''audit', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-preview-h',  'Audit history viewer',                 201);
INSERT INTO _glossary VALUES ('fr', 'ex7-preview-p',  'La table <code>_audit</code> est accessible dans l''admin DB générique. Chaque ligne montre : table modifiée, opération, utilisateur, anciennes valeurs, nouvelles valeurs, date. Filtrable et exportable comme toute autre table.', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-preview-p',  'The <code>_audit</code> table is accessible in the generic DB admin. Each row shows: modified table, operation, user, old values, new values, date. Filterable and exportable like any other table.', 201);

INSERT INTO _glossary VALUES ('fr', 'ex7-sublabel-1', 'migrations/001_audit.sql', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-sublabel-1', 'migrations/001_audit.sql', 201);
INSERT INTO _glossary VALUES ('fr', 'ex7-code-1',
'CREATE TABLE _audit (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  operation  TEXT NOT NULL,
  record_key TEXT,
  old_values TEXT,
  new_values TEXT,
  user_email TEXT NOT NULL,
  changed_at INTEGER NOT NULL DEFAULT (strftime(''%s'', ''now''))
);

INSERT INTO _access VALUES (''_audit'', 0, ''select'');', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-code-1',
'CREATE TABLE _audit (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  operation  TEXT NOT NULL,
  record_key TEXT,
  old_values TEXT,
  new_values TEXT,
  user_email TEXT NOT NULL,
  changed_at INTEGER NOT NULL DEFAULT (strftime(''%s'', ''now''))
);

INSERT INTO _access VALUES (''_audit'', 0, ''select'');', 201);

INSERT INTO _glossary VALUES ('fr', 'ex7-sublabel-2', 'Démarrage avec audit activé', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-sublabel-2', 'Startup with audit enabled',   201);
INSERT INTO _glossary VALUES ('fr', 'ex7-code-2',
'# Ligne de commande
node engine.js --mod auth=3600,db,audit --db app.db --port 8080

# Mode bibliothèque
wate.init({
  db: ''./app.db'',
  port: 8080,
  mod: [''auth=3600'', ''db'', ''audit'']
})', 201);
INSERT INTO _glossary VALUES ('en', 'ex7-code-2',
'# Command line
node engine.js --mod auth=3600,db,audit --db app.db --port 8080

# Library mode
wate.init({
  db: ''./app.db'',
  port: 8080,
  mod: [''auth=3600'', ''db'', ''audit'']
})', 201);

/* (WaTE) web/migrations/001_site.sql v1.8.0 */
