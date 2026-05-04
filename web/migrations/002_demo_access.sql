/**
 * \file      (WaTE) web/migrations/002_demo_access.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-26
 * \version   2.2.0
 * \brief     Profils, droits, pages et glossaire pour la démo « gestion de stock ».
 *
 * \details   Crée deux profils dédiés à la démo, distincts du vrai owner WaTE :
 *              - 10 = demo-owner       : CRUD complet sur tables métier de la démo,
 *                                        accès admin DB générique filtré.
 *              - 11 = demo-gestionnaire : SELECT/INSERT/UPDATE sur stock, pas de DELETE,
 *                                         pas d'accès aux tables système autres que celles
 *                                         de la démo.
 *
 *            AUCUN droit accordé à ces profils sur _user, _session, _profil, _access —
 *            l'admin DB générique ne montrera donc pas ces tables (cf. _db.js qui filtre
 *            via SELECT DISTINCT tablename FROM _access WHERE profil_id=?).
 *
 *            Sessions persistantes (issued lointain, ne jamais expirer) :
 *              - test-session-demo-owner → demo-owner@wate.fr (profil 10)
 *              - test-session-demo-mgr   → demo-mgr@wate.fr   (profil 11)
 *            Le visiteur les active via les boutons « Se connecter » sur /demo
 *            (cf. routes /demo/login/:role dans web/scripts/demo.js).
 *
 *            Pages :
 *              - /demo       (anonymous) — accueil démo, choix du profil
 *              - /demo/stock (profils 10 et 11) — interface métier stock
 */

-- ── Profils ────────────────────────────────────────────────────────────
INSERT INTO _profil VALUES (10, 'demo-owner');
INSERT INTO _profil VALUES (11, 'demo-gestionnaire');

-- ── Utilisateurs fictifs ──────────────────────────────────────────────
-- Mots de passe non utilisables ('x') — la connexion se fait par bouton, pas par formulaire.
-- 7 colonnes : email, password, forename, surname, profil_id, lang, verified.
-- La colonne `verified` est ajoutée par 004_auth_token.sql (module `auth` chargé).
INSERT INTO _user VALUES ('demo-owner@wate.fr', 'x', 'Demo', 'Owner',        10, 'fr', 1);
INSERT INTO _user VALUES ('demo-mgr@wate.fr',   'x', 'Demo', 'Gestionnaire', 11, 'fr', 1);

-- ── Sessions persistantes (an 2286, ne jamais expirer) ────────────────
INSERT INTO _session VALUES ('test-session-demo-owner', 'demo-owner@wate.fr', 9999999999);
INSERT INTO _session VALUES ('test-session-demo-mgr',   'demo-mgr@wate.fr',   9999999999);

-- ── Droits — owner démo (CRUD complet sur métier) ────────────────────
INSERT INTO _access VALUES ('demo_produit',   10, 'select');
INSERT INTO _access VALUES ('demo_produit',   10, 'insert');
INSERT INTO _access VALUES ('demo_produit',   10, 'update');
INSERT INTO _access VALUES ('demo_produit',   10, 'delete');
INSERT INTO _access VALUES ('demo_mouvement', 10, 'select');
INSERT INTO _access VALUES ('demo_mouvement', 10, 'insert');
INSERT INTO _access VALUES ('demo_mouvement', 10, 'update');
INSERT INTO _access VALUES ('demo_mouvement', 10, 'delete');
INSERT INTO _access VALUES ('_user',          10, 'select');
INSERT INTO _access VALUES ('_profil',        10, 'select');
INSERT INTO _access VALUES ('_audit',         10, 'select');

-- ── Droits — gestionnaire (lecture produit + mouvements seulement, pas de delete) ──
INSERT INTO _access VALUES ('demo_produit',   11, 'select');
INSERT INTO _access VALUES ('demo_produit',   11, 'update');
INSERT INTO _access VALUES ('demo_mouvement', 11, 'select');
INSERT INTO _access VALUES ('demo_mouvement', 11, 'insert');

-- ── Pages — accueil démo (/demo, anonymous) ──────────────────────────
INSERT INTO _list VALUES (400);
INSERT INTO _item VALUES (400, 'template', 'demo-home');
INSERT INTO _item VALUES (400, 'css',      'demo.css');
INSERT INTO _item VALUES (400, 'scripts',  '{"type":"text/javascript","path":"/scripts/search.js"}');
INSERT INTO _item VALUES (400, 'title',    'demo-title');
INSERT INTO _item VALUES (400, 'queries',  '');
INSERT INTO _item VALUES (400, 'HOOK',     'demo-code');

INSERT INTO _page VALUES ('/demo',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 400);

-- ── Pages — stock démo (/demo/stock, profils 10 et 11) ───────────────
INSERT INTO _list VALUES (401);
INSERT INTO _item VALUES (401, 'template', 'demo-stock');
INSERT INTO _item VALUES (401, 'css',      'demo.css');
INSERT INTO _item VALUES (401, 'scripts',  '{"type":"text/javascript","path":"/scripts/demo-stock.js"},{"type":"text/javascript","path":"/scripts/search.js"}');
INSERT INTO _item VALUES (401, 'title',    'demo-stock-title');
INSERT INTO _item VALUES (401, 'queries',
  '"products": {"request":"SELECT * FROM demo_produit ORDER BY ref","values":[]}, "movements": {"request":"SELECT m.id, m.date, m.type, m.quantite, m.motif, p.ref AS produit_ref, p.nom AS produit_nom FROM demo_mouvement m JOIN demo_produit p ON p.id = m.produit_id ORDER BY m.date DESC, m.id DESC LIMIT 20","values":[]}');

INSERT INTO _page VALUES ('/demo/stock', 10, 401);
INSERT INTO _page VALUES ('/demo/stock', 11, 401);

-- ── Glossaire — démo (list_id 400 et 401) ────────────────────────────
-- Page d'accueil démo (400)
INSERT INTO _glossary VALUES ('fr', 'demo-title',           'Démo',                                                                  400);
INSERT INTO _glossary VALUES ('en', 'demo-title',           'Demo',                                                                  400);

INSERT INTO _glossary VALUES ('fr', 'demo-hero-title',      'WaTE en action — gestion de stock',                                     400);
INSERT INTO _glossary VALUES ('en', 'demo-hero-title',      'WaTE in action — stock management',                                     400);

INSERT INTO _glossary VALUES ('fr', 'demo-hero-subtitle',
  'Une mini-application de gestion de stock construite avec WaTE. Connectez-vous comme owner ou comme gestionnaire pour voir comment les profils filtrent l''accès aux mêmes tables.',
  400);
INSERT INTO _glossary VALUES ('en', 'demo-hero-subtitle',
  'A small stock-management app built with WaTE. Sign in as owner or as manager to see how profiles filter access to the same tables.',
  400);

INSERT INTO _glossary VALUES ('fr', 'demo-login-owner',     'Se connecter en tant qu''owner démo',                                   400);
INSERT INTO _glossary VALUES ('en', 'demo-login-owner',     'Sign in as demo owner',                                                 400);

INSERT INTO _glossary VALUES ('fr', 'demo-login-mgr',       'Se connecter en tant que gestionnaire',                                 400);
INSERT INTO _glossary VALUES ('en', 'demo-login-mgr',       'Sign in as manager',                                                    400);

INSERT INTO _glossary VALUES ('fr', 'demo-roles-title',     'Deux profils, deux périmètres',                                         400);
INSERT INTO _glossary VALUES ('en', 'demo-roles-title',     'Two profiles, two scopes',                                              400);

INSERT INTO _glossary VALUES ('fr', 'demo-role-owner-h',    'Owner démo',                                                            400);
INSERT INTO _glossary VALUES ('en', 'demo-role-owner-h',    'Demo owner',                                                            400);
INSERT INTO _glossary VALUES ('fr', 'demo-role-owner-p',
  'CRUD complet sur les tables métier (produit, mouvement). Accès au bouton « Réinitialiser » pour restaurer les données initiales. Aucun accès aux tables système — son scope s''arrête au stock.',
  400);
INSERT INTO _glossary VALUES ('en', 'demo-role-owner-p',
  'Full CRUD on business tables (produit, mouvement). Has access to a « Reset » button to restore initial data. No access to system tables — scope ends at stock.',
  400);

INSERT INTO _glossary VALUES ('fr', 'demo-role-mgr-h',      'Gestionnaire',                                                          400);
INSERT INTO _glossary VALUES ('en', 'demo-role-mgr-h',      'Manager',                                                               400);
INSERT INTO _glossary VALUES ('fr', 'demo-role-mgr-p',
  'Lecture des produits, ajout d''entrées et de sorties de stock. Pas de suppression, pas de modification de la fiche produit, pas de bouton « Réinitialiser ».',
  400);
INSERT INTO _glossary VALUES ('en', 'demo-role-mgr-p',
  'Reads products, adds stock movements (in/out). No deletion, no product editing, no « Reset » button.',
  400);

INSERT INTO _glossary VALUES ('fr', 'demo-already-in',      'Vous êtes déjà connecté à la démo.',                                    400);
INSERT INTO _glossary VALUES ('en', 'demo-already-in',      'You are already signed in to the demo.',                                400);
INSERT INTO _glossary VALUES ('fr', 'demo-continue',        'Continuer',                                                             400);
INSERT INTO _glossary VALUES ('en', 'demo-continue',        'Continue',                                                              400);
INSERT INTO _glossary VALUES ('fr', 'demo-logout',          'Se déconnecter',                                                        400);
INSERT INTO _glossary VALUES ('en', 'demo-logout',          'Sign out',                                                              400);

-- Page stock (401)
INSERT INTO _glossary VALUES ('fr', 'demo-stock-title',     'Stock',                                                                 401);
INSERT INTO _glossary VALUES ('en', 'demo-stock-title',     'Stock',                                                                 401);

INSERT INTO _glossary VALUES ('fr', 'demo-stock-h',         'Inventaire',                                                            401);
INSERT INTO _glossary VALUES ('en', 'demo-stock-h',         'Inventory',                                                             401);

INSERT INTO _glossary VALUES ('fr', 'demo-stock-intro',
  'Page applicative rendue par le moteur. Les produits ci-dessous viennent d''une requête SELECT déclarée dans _item, et la liste des mouvements vient d''une seconde requête JOIN.',
  401);
INSERT INTO _glossary VALUES ('en', 'demo-stock-intro',
  'Application page rendered by the engine. The products below come from a SELECT query declared in _item; the movement list comes from a second JOIN query.',
  401);

INSERT INTO _glossary VALUES ('fr', 'demo-col-ref',         'Référence',                                                             401);
INSERT INTO _glossary VALUES ('en', 'demo-col-ref',         'Reference',                                                             401);
INSERT INTO _glossary VALUES ('fr', 'demo-col-nom',         'Désignation',                                                           401);
INSERT INTO _glossary VALUES ('en', 'demo-col-nom',         'Name',                                                                  401);
INSERT INTO _glossary VALUES ('fr', 'demo-col-prix',        'Prix unitaire',                                                         401);
INSERT INTO _glossary VALUES ('en', 'demo-col-prix',        'Unit price',                                                            401);
INSERT INTO _glossary VALUES ('fr', 'demo-col-stock',       'Stock',                                                                 401);
INSERT INTO _glossary VALUES ('en', 'demo-col-stock',       'Stock',                                                                 401);

INSERT INTO _glossary VALUES ('fr', 'demo-add-h',           'Enregistrer un mouvement',                                              401);
INSERT INTO _glossary VALUES ('en', 'demo-add-h',           'Record a movement',                                                     401);
INSERT INTO _glossary VALUES ('fr', 'demo-add-product',     'Produit',                                                               401);
INSERT INTO _glossary VALUES ('en', 'demo-add-product',     'Product',                                                               401);
INSERT INTO _glossary VALUES ('fr', 'demo-add-type',        'Type',                                                                  401);
INSERT INTO _glossary VALUES ('en', 'demo-add-type',        'Type',                                                                  401);
INSERT INTO _glossary VALUES ('fr', 'demo-add-type-in',     'Entrée',                                                                401);
INSERT INTO _glossary VALUES ('en', 'demo-add-type-in',     'In',                                                                    401);
INSERT INTO _glossary VALUES ('fr', 'demo-add-type-out',    'Sortie',                                                                401);
INSERT INTO _glossary VALUES ('en', 'demo-add-type-out',    'Out',                                                                   401);
INSERT INTO _glossary VALUES ('fr', 'demo-add-qty',         'Quantité',                                                              401);
INSERT INTO _glossary VALUES ('en', 'demo-add-qty',         'Quantity',                                                              401);
INSERT INTO _glossary VALUES ('fr', 'demo-add-motif',       'Motif',                                                                 401);
INSERT INTO _glossary VALUES ('en', 'demo-add-motif',       'Reason',                                                                401);
INSERT INTO _glossary VALUES ('fr', 'demo-add-submit',      'Enregistrer',                                                           401);
INSERT INTO _glossary VALUES ('en', 'demo-add-submit',      'Save',                                                                  401);

INSERT INTO _glossary VALUES ('fr', 'demo-history-h',       'Derniers mouvements',                                                   401);
INSERT INTO _glossary VALUES ('en', 'demo-history-h',       'Recent movements',                                                      401);
INSERT INTO _glossary VALUES ('fr', 'demo-history-empty',   'Aucun mouvement enregistré.',                                           401);
INSERT INTO _glossary VALUES ('en', 'demo-history-empty',   'No movement recorded yet.',                                             401);

INSERT INTO _glossary VALUES ('fr', 'demo-reset-h',         'Réinitialiser la démo',                                                 401);
INSERT INTO _glossary VALUES ('en', 'demo-reset-h',         'Reset the demo',                                                        401);
INSERT INTO _glossary VALUES ('fr', 'demo-reset-p',
  'Restaure les produits et mouvements à leur état initial. Disponible uniquement à l''owner démo.',
  401);
INSERT INTO _glossary VALUES ('en', 'demo-reset-p',
  'Restores products and movements to their initial state. Available only to the demo owner.',
  401);
INSERT INTO _glossary VALUES ('fr', 'demo-reset-btn',       'Réinitialiser maintenant',                                              401);
INSERT INTO _glossary VALUES ('en', 'demo-reset-btn',       'Reset now',                                                             401);
INSERT INTO _glossary VALUES ('fr', 'demo-reset-done',      'Démo réinitialisée.',                                                   401);
INSERT INTO _glossary VALUES ('en', 'demo-reset-done',      'Demo reset.',                                                           401);

INSERT INTO _glossary VALUES ('fr', 'demo-admin-link',      'Ouvrir l''admin DB générique',                                          401);
INSERT INTO _glossary VALUES ('en', 'demo-admin-link',      'Open generic DB admin',                                                 401);

-- ── Accès aux pages du site pour les profils démo ─────────────────────
-- Les pages /, /examples et /docs ne sont publiées que pour anonymous (9999)
-- dans 001_site.sql. On les ouvre aussi aux profils démo pour que la
-- navigation du site reste fonctionnelle même avec un cookie de session
-- démo actif.
INSERT INTO _page VALUES ('/',         10, 200);
INSERT INTO _page VALUES ('/',         11, 200);
INSERT INTO _page VALUES ('/examples', 10, 201);
INSERT INTO _page VALUES ('/examples', 11, 201);
INSERT INTO _page VALUES ('/docs',     10, 202);
INSERT INTO _page VALUES ('/docs',     11, 202);
INSERT INTO _page VALUES ('/demo',     10, 400);
INSERT INTO _page VALUES ('/demo',     11, 400);

-- ── Accès à l'admin DB pour les profils démo ──────────────────────────
-- Les pages d'administration DB (schema, table CRUD) ne sont publiées
-- que pour owner (0) dans 001_engine.sql. On les ouvre aux profils démo
-- pour que le bouton « Ouvrir l'admin DB générique » fonctionne.
-- _adminCheckAccess filtre les tables selon _access — profil 10 verra
-- demo_produit+demo_mouvement+_user+_profil, profil 11 demo_produit+demo_mouvement.
INSERT INTO _page VALUES ('/admin/form/db/schema', 10, 4);
INSERT INTO _page VALUES ('/admin/form/db/schema', 10, 101);
INSERT INTO _page VALUES ('/admin/form/db/schema', 10, 103);
INSERT INTO _page VALUES ('/admin/form/db/schema', 10, 104);
INSERT INTO _page VALUES ('/admin/form/db/schema', 11, 4);
INSERT INTO _page VALUES ('/admin/form/db/schema', 11, 101);
INSERT INTO _page VALUES ('/admin/form/db/schema', 11, 103);
INSERT INTO _page VALUES ('/admin/form/db/schema', 11, 104);

INSERT INTO _page VALUES ('/admin/form/db',        10, 5);
INSERT INTO _page VALUES ('/admin/form/db',        10, 101);
INSERT INTO _page VALUES ('/admin/form/db',        10, 103);
INSERT INTO _page VALUES ('/admin/form/db',        10, 104);
INSERT INTO _page VALUES ('/admin/form/db',        11, 5);
INSERT INTO _page VALUES ('/admin/form/db',        11, 101);
INSERT INTO _page VALUES ('/admin/form/db',        11, 103);
INSERT INTO _page VALUES ('/admin/form/db',        11, 104);

-- Anti-boucle : si _adminSession redirige vers signin, la page doit
-- être accessible aux profils démo pour éviter une 404 en chaîne.
INSERT INTO _page VALUES ('/admin/form/auth/signin', 10, 1);
INSERT INTO _page VALUES ('/admin/form/auth/signin', 10, 100);
INSERT INTO _page VALUES ('/admin/form/auth/signin', 10, 103);
INSERT INTO _page VALUES ('/admin/form/auth/signin', 10, 105);
INSERT INTO _page VALUES ('/admin/form/auth/signin', 10, 106);
INSERT INTO _page VALUES ('/admin/form/auth/signin', 11, 1);
INSERT INTO _page VALUES ('/admin/form/auth/signin', 11, 100);
INSERT INTO _page VALUES ('/admin/form/auth/signin', 11, 103);
INSERT INTO _page VALUES ('/admin/form/auth/signin', 11, 105);
INSERT INTO _page VALUES ('/admin/form/auth/signin', 11, 106);

-- ── Section code source (list 400) ──────────────────────────────────────
INSERT INTO _glossary VALUES ('fr', 'demo-code-title',  'Code source',                    400);
INSERT INTO _glossary VALUES ('en', 'demo-code-title',  'Source code',                    400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-intro',
  'Copiez ces fichiers dans un dossier, lancez <code>node app.js</code> avec WaTE (<code>npm install wate-engine</code>), et vous obtenez la même application de gestion de stock.',
  400);
INSERT INTO _glossary VALUES ('en', 'demo-code-intro',
  'Copy these files into a folder, run <code>node app.js</code> with WaTE (<code>npm install wate-engine</code>), and you get the same stock management application.',
  400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-tree',
'demo-stock/
├── app.js
├── migrations/
│   ├── 001_site.sql
│   ├── 002_demo_access.sql
│   ├── 003_demo_schema.sql
│   ├── 004_demo_seed.sql
│   └── 005_ai.sql
├── scripts/
│   ├── demo.js
│   ├── demo-stock.js
│   └── btn-action.js
├── views/
│   ├── common.ejs
│   ├── demo-home.ejs
│   └── demo-stock.ejs
└── css/
    ├── common.css
    ├── admin-db.css
    └── demo.css', 400);
INSERT INTO _glossary VALUES ('en', 'demo-code-tree',
'demo-stock/
├── app.js
├── migrations/
│   ├── 001_site.sql
│   ├── 002_demo_access.sql
│   ├── 003_demo_schema.sql
│   ├── 004_demo_seed.sql
│   └── 005_ai.sql
├── scripts/
│   ├── demo.js
│   ├── demo-stock.js
│   └── btn-action.js
├── views/
│   ├── common.ejs
│   ├── demo-home.ejs
│   └── demo-stock.ejs
└── css/
    ├── common.css
    ├── admin-db.css
    └── demo.css', 400);

INSERT INTO _glossary VALUES ('fr', 'demo-code-app-label',      'app.js — point d''entrée',         400);
INSERT INTO _glossary VALUES ('en', 'demo-code-app-label',      'app.js — entry point',             400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-site-label',     'migrations/001_site.sql — structure', 400);
INSERT INTO _glossary VALUES ('en', 'demo-code-site-label',     'migrations/001_site.sql — structure', 400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-access-label',   'migrations/002_demo_access.sql',    400);
INSERT INTO _glossary VALUES ('en', 'demo-code-access-label',   'migrations/002_demo_access.sql',    400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-schema-label',   'migrations/003_demo_schema.sql',    400);
INSERT INTO _glossary VALUES ('en', 'demo-code-schema-label',   'migrations/003_demo_schema.sql',    400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-seed-label',     'migrations/004_demo_seed.sql',      400);
INSERT INTO _glossary VALUES ('en', 'demo-code-seed-label',     'migrations/004_demo_seed.sql',      400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-ai-label',       'migrations/005_ai.sql',              400);
INSERT INTO _glossary VALUES ('en', 'demo-code-ai-label',       'migrations/005_ai.sql',              400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-module-label',   'scripts/demo.js — module WaTE',    400);
INSERT INTO _glossary VALUES ('en', 'demo-code-module-label',   'scripts/demo.js — WaTE module',    400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-stockjs-label',  'scripts/demo-stock.js — tri/filtre',400);
INSERT INTO _glossary VALUES ('en', 'demo-code-stockjs-label',  'scripts/demo-stock.js — sort/filter',400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-btnaction-label','scripts/btn-action.js',            400);
INSERT INTO _glossary VALUES ('en', 'demo-code-btnaction-label','scripts/btn-action.js',            400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-common-label',   'views/common.ejs — layout maître', 400);
INSERT INTO _glossary VALUES ('en', 'demo-code-common-label',   'views/common.ejs — master layout', 400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-home-label',     'views/demo-home.ejs',              400);
INSERT INTO _glossary VALUES ('en', 'demo-code-home-label',     'views/demo-home.ejs',              400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-stock-label',    'views/demo-stock.ejs — page métier', 400);
INSERT INTO _glossary VALUES ('en', 'demo-code-stock-label',    'views/demo-stock.ejs — stock page',  400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-csscommon-label','css/common.css — thème',            400);
INSERT INTO _glossary VALUES ('en', 'demo-code-csscommon-label','css/common.css — theme',            400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-admindb-label',  'css/admin-db.css — tables',         400);
INSERT INTO _glossary VALUES ('en', 'demo-code-admindb-label',  'css/admin-db.css — tables',         400);
INSERT INTO _glossary VALUES ('fr', 'demo-code-democss-label',  'css/demo.css',                       400);
INSERT INTO _glossary VALUES ('en', 'demo-code-democss-label',  'css/demo.css',                       400);

/* (WaTE) web/migrations/002_demo_access.sql v2.2.0 */
