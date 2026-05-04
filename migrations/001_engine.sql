/**
 * \file      (WaTE) engine.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   2.6.0
 * \brief     Création de la base de données (DB) minimale de (WaTE) engine.js
 *
 * \details   La DB contient quatre parties définies par des tables techniques
 *            dont le nom est préfixé par underscore '_' :
 *            1) l'une avec les tables de gestion des site pour générer les
 *               pages HTML.
 *            2) l'autre avec les tables de gestion des profils, utilisateurs
 *               et sessions.
 *              2a) il existe un profil owner (id = 0, convention UNIX root)
 *                  et un profil anonymous (id = 9999) avec un utilisateur anonyme.
 *              2b) toutes des pages en accès libre doivent utiliser le profil
 *                  anonymous (id = 9999).
 *              2c) le profil owner (id = 0) a des droits d'accès aux tables
 *                  système dans _access — tout est piloté par la DB, aucun
 *                  test hard-codé dans le moteur.
 *            3) pour la modification des tables propres à chaque site, une
 *               table donne les droits d'accès suivant le profil utilisateur.
 *               SELECT est implicitement autorisé dès qu'une entrée existe
 *               dans _access pour (tablename, profil_id).
 *            4) un glossaire donnant la traduction multilingues des éléments
 *               textuels (TAG) apparaissant dans les page du site.
 *
 *   v1.0.1 : - Le profil par défaut d'un nouvel utilisateur est 0 (anonyme).
 *            - La colonne echeance de _session est renommée issued
 *            - On ajoute ON DELETE CASCADE ON UPDATE CASCADE sur profil_id de
 *              la table _page pour ne pas avoir des _page sans profil associé.
 *   v1.1.0 : - Ajout d'index explicites sur les colonnes de jointure critiques.
 *   v1.2.0 : - Convention UNIX : owner = profil_id 0 (root), anonymous = profil_id 9999.
 *            - owner a des droits INSERT/UPDATE/DELETE sur toutes les tables système.
 *            - _access : ajout de 'select' dans _request.
 *   v1.2.1 : - NOTE signup : le profil anonymous n'a PAS insert sur _user par défaut
 *              (signup public désactivé — sécurité).
 *              Pour activer le signup public, ajouter dans la DB applicative :
 *                INSERT INTO _access VALUES ('_user', (SELECT U.profil_id FROM _user U
 *                  JOIN _session S ON U.email = S.user_email WHERE S.id = '0'), 'insert');
 *              Pour réserver le signup aux owners uniquement (défaut), aucune
 *              modification n'est nécessaire — owner a déjà insert sur _user.
 *   v1.2.2 : - Session fantôme anonymous : issued 0 → 9999999999 (an 2286) —
 *              toujours valide même quand la clause TTL est active.
 *   v1.3.0 : - Langues par défaut : fr, en.
 *            - Pages d'administration : /admin/form/auth/* et /admin/form/db/*.
 *              Accessibles via jsHandlers auth:renderSignin/Signup/Me et
 *              db:renderSchema/Table — enregistrés par _auth.js et _db.js dans init().
 *            - _list 1-6 réservés aux pages d'administration moteur.
 *   v1.4.0 : - JS items activés pour auth:renderSignin/Signup/Me et db:renderSchema/Table.
 *   v1.5.0 : - auth:renderMe et db:renderSchema supprimés — serve() rend directement.
 *              Query _user ajoutée aux lists 3 (me), 4 (schema), 5 (table) :
 *              résultat disponible via result["_user"].rows[0] dans les templates.
 *   v1.6.0 : - db:renderTable supprimé — serve() rend directement.
 *   v1.8.0 : - Utilisateur owner par défaut inséré dans _user (email='owner',
 *              mot de passe par défaut 'owner' — à changer à la première connexion).
 *              Hash : PBKDF2-SHA512 100k itérations, sha256pwd=SHA256('owner'),
 *              sel=SHA256('owner'). Plus de dépendance à un script de setup externe.
 *   v1.7.0 : - profil_id anonymous (9999) et nom 'anonymous' définis une seule fois
 *              dans _profil — aucune des deux valeurs ne se propage ailleurs.
 *              _user et _session anonymous sont insérés par SELECT depuis _profil
 *              (WHERE id != 0) : email/user_email = _profil.name, profil_id = _profil.id.
 *              Les INSERTs _page (signin/signup) dérivent le profil_id anonymous via
 *              la sous-requête session fantôme :
 *                (SELECT p.id FROM _profil p, _user u, _session s
 *                 WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0')
 *              Conséquence : la session fantôme (id='0') est obligatoire au démarrage.
 *              Queries PRAGMA ajoutées à list 5 :
 *                _columns : PRAGMA table_info(${req.query.table:identifier})
 *                _fk      : PRAGMA foreign_key_list(${req.query.table:identifier})
 *                _meta    : SELECT sql FROM sqlite_master WHERE type='table' AND name=?
 *              Note : la forme table-valued pragma_foreign_key_list() n'est pas
 *              supportée par la version SQLite utilisée — on passe par PRAGMA direct.
 *              title_param='table' dans list 5 → titre = req.query.table dynamique.
 *              URL form table : /admin/form/db?table=<name> (query param, pas path).
 *              catch-all engine.js suffit — plus besoin de route /:table dans _db.js.
 *   v2.5.0 : - Formulaire auth unifié avec <admin-row> — rendu piloté par PRAGMA.
 *              List 100 queries : _columns (PRAGMA table_info(_user)) + _fk (PRAGMA
 *              foreign_key_list(_user)) + _fk_lang (SELECT _lang) remplacent
 *              l'ancienne query "_lang".
 *              List 3 : query "_schema" supprimée (remplacée par list 100 _columns/_fk).
 *              List 107 : "source":"_lang" retiré du champ lang_id — FK déduite du PRAGMA.
 *   v2.4.0 : - Champs de formulaire auth pilotés par la DB via key='fields' dans _item.
 *              Chaque champ : {"name":"...", "mandatory":true|false, "order":N}.
 *              List 106 : email (shared signin+signup+me). Lists 1/2 : passwd mandatory:true.
 *              List 3 : passwd mandatory:false (/me — laisser vide = conserver le mdp).
 *              List 107 : passwd-confirm + forename + lastname + lang-select (signup+me).
 *              admin-auth.ejs : rendu dynamique via JSON.parse('['+elements.fields+']').
 *   v2.3.0 : - Colonne list_id ajoutée à _glossary (NULL = chargé sur toutes les pages,
 *              N = chargé uniquement pour les pages référençant ce list_id dans _page).
 *              Listes 106 (champs auth communs : email, passwd) et 107 (champs auth
 *              étendus : passwd-confirm, forename, lastname, lang-select) créées.
 *              Requête _glossary retirée de list 103 — serve() charge le glossaire
 *              directement via LEFT JOIN _page (même hiérarchie que _item/_page).
 *              _page : listes 106 et 107 ajoutées aux pages auth concernées.
 *              Index idx_glossary_list_id ajouté.
 *   v2.6.0 : - Glossaire « À propos WaTE » (wate-about-title, wate-copyright, wate-intro,
 *              wate-feat-*) ajouté en list_id NULL (toujours chargé, click sur le logo).
 *              wate-version est injecté au boot depuis package.json par _migration.js
 *              (upsertWateVersion) — pas d'INSERT ici pour garder la source unique.
 */

PRAGMA foreign_keys = ON;

-- =============================================================================
-- TABLES TECHNIQUES
-- =============================================================================

CREATE TABLE _list     (id INTEGER PRIMARY KEY);
CREATE TABLE _item     (list_id INTEGER, key TEXT, value TEXT,
                        PRIMARY KEY(list_id, key),
                        FOREIGN KEY (list_id) REFERENCES _list(id) ON DELETE CASCADE ON UPDATE CASCADE);
CREATE TABLE _page     (url TEXT, profil_id INTEGER, list_id INTEGER,
                        PRIMARY KEY(url, profil_id, list_id),
                        FOREIGN KEY (profil_id) REFERENCES _profil(id) ON DELETE CASCADE ON UPDATE CASCADE,
                        FOREIGN KEY (list_id) REFERENCES _list(id) ON DELETE CASCADE ON UPDATE CASCADE);
CREATE TABLE _lang     (id TEXT, name TEXT NOT NULL,
                        PRIMARY KEY(id));
CREATE TABLE _profil   (id INTEGER, name TEXT,
                        PRIMARY KEY (id)) WITHOUT ROWID;
CREATE TABLE _user     (email TEXT, password TEXT NOT NULL, forename TEXT, lastname TEXT,
                        profil_id INTEGER DEFAULT 0, lang_id TEXT,
                        PRIMARY KEY (email),
                        FOREIGN KEY (profil_id) REFERENCES _profil(id) ON DELETE CASCADE ON UPDATE CASCADE,
                        FOREIGN KEY (lang_id) REFERENCES _lang(id));
CREATE TABLE _session  (id TEXT NOT NULL, user_email TEXT, issued INTEGER NOT NULL,
                        PRIMARY KEY (id),
                        FOREIGN KEY (user_email) REFERENCES _user(email) ON DELETE CASCADE ON UPDATE CASCADE);
CREATE TABLE _request  (name TEXT PRIMARY KEY);
CREATE TABLE _access   (tablename TEXT, profil_id INTEGER, request_name TEXT,
                        PRIMARY KEY (tablename, profil_id, request_name),
                        FOREIGN KEY (profil_id) REFERENCES _profil (id) ON DELETE CASCADE ON UPDATE CASCADE,
                        FOREIGN KEY (request_name) REFERENCES _request (name) ON DELETE CASCADE ON UPDATE CASCADE);
CREATE TABLE _glossary (lang_id TEXT, tag TEXT, label TEXT, list_id INTEGER,
                        PRIMARY KEY (lang_id, tag),
                        FOREIGN KEY (lang_id) REFERENCES _lang(id) ON DELETE CASCADE ON UPDATE CASCADE,
                        FOREIGN KEY (list_id) REFERENCES _list(id) ON DELETE CASCADE ON UPDATE CASCADE);

-- =============================================================================
-- DONNÉES PAR DÉFAUT
-- =============================================================================

INSERT INTO _profil  VALUES (0, 'owner');
INSERT INTO _profil  VALUES (9999, 'anonymous');

-- Utilisateur owner@wate par défaut — mot de passe 'owner' à changer à la première connexion.
-- Hash : PBKDF2-SHA512 100k it., sha256pwd = SHA256('owner'), sel = SHA256('owner@wate').
INSERT INTO _user    VALUES ('owner@wate', 'f9d86a48199a38bcaf273bf2a7c76668fe359c1c4f9709459dd603f233e944ad3a6c40720858c58ec352a4cf786f723f9d1962abb7d0fd4d6c7ac06a72b800da', NULL, NULL, (SELECT id FROM _profil WHERE name = 'owner'), NULL);

-- Utilisateur anonymous — email et profil_id dérivés de _profil (WHERE id != 0 = non-owner).
INSERT INTO _user    SELECT name, '', NULL, NULL, id, NULL FROM _profil WHERE id != 0;

INSERT INTO _session SELECT '0', name, 9999999999 FROM _profil WHERE id != 0;

INSERT INTO _request VALUES ('select');
INSERT INTO _request VALUES ('insert');
INSERT INTO _request VALUES ('update');
INSERT INTO _request VALUES ('update-self');
INSERT INTO _request VALUES ('delete');
INSERT INTO _request VALUES ('delete-self');

-- Droits owner (profil 0) sur les tables système
INSERT INTO _access VALUES ('_lang',     0, 'select');
INSERT INTO _access VALUES ('_lang',     0, 'insert');
INSERT INTO _access VALUES ('_lang',     0, 'update');
INSERT INTO _access VALUES ('_lang',     0, 'delete');
INSERT INTO _access VALUES ('_profil',   0, 'select');
INSERT INTO _access VALUES ('_profil',   0, 'insert');
INSERT INTO _access VALUES ('_profil',   0, 'update');
INSERT INTO _access VALUES ('_profil',   0, 'delete');
INSERT INTO _access VALUES ('_user',     0, 'select');
INSERT INTO _access VALUES ('_user',     0, 'insert');
INSERT INTO _access VALUES ('_user',     0, 'update');
INSERT INTO _access VALUES ('_user',     0, 'delete');
INSERT INTO _access VALUES ('_session',  0, 'select');
INSERT INTO _access VALUES ('_session',  0, 'delete');
INSERT INTO _access VALUES ('_request',  0, 'select');
INSERT INTO _access VALUES ('_access',   0, 'select');
INSERT INTO _access VALUES ('_access',   0, 'insert');
INSERT INTO _access VALUES ('_access',   0, 'update');
INSERT INTO _access VALUES ('_access',   0, 'delete');
INSERT INTO _access VALUES ('_list',     0, 'select');
INSERT INTO _access VALUES ('_list',     0, 'insert');
INSERT INTO _access VALUES ('_list',     0, 'delete');
INSERT INTO _access VALUES ('_page',     0, 'select');
INSERT INTO _access VALUES ('_page',     0, 'insert');
INSERT INTO _access VALUES ('_page',     0, 'update');
INSERT INTO _access VALUES ('_page',     0, 'delete');
INSERT INTO _access VALUES ('_glossary',  0, 'select');
INSERT INTO _access VALUES ('_glossary',  0, 'insert');
INSERT INTO _access VALUES ('_glossary',  0, 'update');
INSERT INTO _access VALUES ('_glossary',  0, 'delete');
INSERT INTO _access VALUES ('_item',      0, 'select');
INSERT INTO _access VALUES ('_item',      0, 'insert');
INSERT INTO _access VALUES ('_item',      0, 'update');
INSERT INTO _access VALUES ('_item',      0, 'delete');
INSERT INTO _access VALUES ('_migration', 0, 'select');

-- NOTE v1.2.1 : signup public (anonymous insert sur _user) NON activé par défaut.
-- Pour l'activer :
--   INSERT INTO _access VALUES ('_user',
--     (SELECT p.id FROM _profil p, _user u, _session s
--      WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'),
--     'insert');

-- =============================================================================
-- LANGUES PAR DÉFAUT — v1.3.0
-- =============================================================================

INSERT INTO _lang VALUES ('fr', 'Français');
INSERT INTO _lang VALUES ('en', 'English');

-- =============================================================================
-- LISTES — créées avant le glossaire pour satisfaire les FK _glossary.list_id
-- =============================================================================
-- _list 1-6   : pages moteur (auth, db, stats) — réservés WaTE.
-- _list 100+  : listes partagées transverses.
-- _list 106   : champ auth email — signin + signup + me (shared).
-- _list 107   : champs auth étendus (passwd-confirm, forename, lastname, lang-select) — signup + me.

INSERT INTO _list VALUES (1);    -- /admin/form/auth/signin
INSERT INTO _list VALUES (2);    -- /admin/form/auth/signup
INSERT INTO _list VALUES (3);    -- /admin/form/auth/me
INSERT INTO _list VALUES (4);    -- /admin/form/db/schema
INSERT INTO _list VALUES (5);    -- /admin/form/db?table=...
INSERT INTO _list VALUES (100);  -- template + css admin-auth
INSERT INTO _list VALUES (101);  -- query _user courante
INSERT INTO _list VALUES (103);  -- scripts partagés (admin-common.js) + lang-menu
INSERT INTO _list VALUES (104);  -- nav-menu owner
INSERT INTO _list VALUES (105);  -- nav-menu anonymous
INSERT INTO _list VALUES (106);  -- champs auth communs (glossaire seulement pour l'instant)
INSERT INTO _list VALUES (107);  -- champs auth étendus (glossaire seulement pour l'instant)

-- =============================================================================
-- GLOSSAIRE — v2.3.0 : list_id NULL = chargé partout, list_id N = page scopée.
--
-- Hiérarchie _glossary/_page identique à _item/_page :
--   serve() charge via LEFT JOIN _page sur (list_id, url, profil_id).
--   list_id NULL → toujours chargé (entête : nav-*, header-*, lang-*).
--   list_id N    → chargé si la page courante a ce list_id dans _page.
-- =============================================================================

-- Entête navigation (list_id NULL — toujours chargé).
INSERT INTO _glossary VALUES ('fr', 'nav-me',      'Mon profil',       NULL);
INSERT INTO _glossary VALUES ('fr', 'nav-db',      'Base de données',  NULL);
INSERT INTO _glossary VALUES ('fr', 'nav-stats',   'Statistiques',     NULL);
INSERT INTO _glossary VALUES ('fr', 'nav-signout', 'Déconnexion',      NULL);
INSERT INTO _glossary VALUES ('fr', 'nav-search', 'Recherche',         NULL);
INSERT INTO _glossary VALUES ('fr', 'nav-signin',  'Connexion',        NULL);
INSERT INTO _glossary VALUES ('fr', 'nav-signup',  'Inscription',      NULL);
INSERT INTO _glossary VALUES ('en', 'nav-me',      'My profile',       NULL);
INSERT INTO _glossary VALUES ('en', 'nav-db',      'Database',         NULL);
INSERT INTO _glossary VALUES ('en', 'nav-stats',   'Statistics',       NULL);
INSERT INTO _glossary VALUES ('en', 'nav-signout', 'Sign out',         NULL);
INSERT INTO _glossary VALUES ('en', 'nav-search', 'Search',            NULL);
INSERT INTO _glossary VALUES ('en', 'nav-signin',  'Sign in',          NULL);
INSERT INTO _glossary VALUES ('en', 'nav-signup',  'Sign up',          NULL);

-- Entête commun (list_id NULL — toujours chargé).
INSERT INTO _glossary VALUES ('fr', 'header-title',  'Administration', NULL);
INSERT INTO _glossary VALUES ('fr', 'header-profil', 'Profil',         NULL);
INSERT INTO _glossary VALUES ('fr', 'header-search-placeholder', 'Rechercher…', NULL);
INSERT INTO _glossary VALUES ('en', 'header-title',  'Administration', NULL);
INSERT INTO _glossary VALUES ('en', 'header-profil', 'Profile',        NULL);
INSERT INTO _glossary VALUES ('en', 'header-search-placeholder', 'Search…',    NULL);

-- Modal « À propos WaTE » (list_id NULL — toujours chargé, click sur le logo).
-- wate-version est injecté au boot depuis package.json (_migration.js upsertWateVersion).
INSERT INTO _glossary VALUES ('fr', 'wate-about-title', 'À propos de WaTE',            NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-copyright',   '© 2023-2026 WATE Team',       NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-intro',       'WaTE est un moteur CMS Node.js / SQLite orienté données : pages, menus et permissions sont définis en base, le code reste générique.', NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-feat-auth',   'Authentification + profils + CSRF',     NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-feat-db',     'Administration CRUD automatique',       NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-feat-stats',  'Statistiques LRU',                      NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-feat-i18n',   'Internationalisation (glossaire par page)', NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-feat-mail',   'Emails verify/reset + dégradation gracieuse',   NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-feat-audit',  'Journal d''audit des écritures',                NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-feat-search', 'Recherche plein texte FTS5',                    NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-feat-apikey', 'Clés d''API Bearer',                            NULL);
INSERT INTO _glossary VALUES ('fr', 'wate-feat-cron',   'Purges périodiques automatiques',               NULL);
INSERT INTO _glossary VALUES ('en', 'wate-about-title', 'About WaTE',                  NULL);
INSERT INTO _glossary VALUES ('en', 'wate-copyright',   '© 2023-2026 WATE Team',       NULL);
INSERT INTO _glossary VALUES ('en', 'wate-intro',       'WaTE is a data-driven Node.js / SQLite CMS engine: pages, menus and permissions live in the DB, the code stays generic.', NULL);
INSERT INTO _glossary VALUES ('en', 'wate-feat-auth',   'Auth + profiles + CSRF',                NULL);
INSERT INTO _glossary VALUES ('en', 'wate-feat-db',     'Auto CRUD administration',              NULL);
INSERT INTO _glossary VALUES ('en', 'wate-feat-stats',  'LRU statistics',                        NULL);
INSERT INTO _glossary VALUES ('en', 'wate-feat-i18n',   'Internationalization (per-page glossary)', NULL);
INSERT INTO _glossary VALUES ('en', 'wate-feat-mail',   'Verify/reset emails + graceful degradation',    NULL);
INSERT INTO _glossary VALUES ('en', 'wate-feat-audit',  'Write audit log',                               NULL);
INSERT INTO _glossary VALUES ('en', 'wate-feat-search', 'FTS5 full-text search',                         NULL);
INSERT INTO _glossary VALUES ('en', 'wate-feat-apikey', 'Bearer API keys',                               NULL);
INSERT INTO _glossary VALUES ('en', 'wate-feat-cron',   'Automatic periodic purges',                     NULL);

-- Noms de langues (list_id NULL — toujours chargés, utilisés dans le sélecteur de langue).
INSERT INTO _glossary VALUES ('fr', 'lang-fr', 'Français', NULL);
INSERT INTO _glossary VALUES ('fr', 'lang-en', 'English',  NULL);
INSERT INTO _glossary VALUES ('en', 'lang-fr', 'Français', NULL);
INSERT INTO _glossary VALUES ('en', 'lang-en', 'English',  NULL);

-- Page signin (list_id 1).
INSERT INTO _glossary VALUES ('fr', 'btn-signin',        'Se connecter',  1);
INSERT INTO _glossary VALUES ('fr', 'btn-signin-other',  'S''inscrire',   1);
INSERT INTO _glossary VALUES ('fr', 'next-signin-other', 'signup',        1);
INSERT INTO _glossary VALUES ('en', 'btn-signin',        'Connect',       1);
INSERT INTO _glossary VALUES ('en', 'btn-signin-other',  'Register',      1);
INSERT INTO _glossary VALUES ('en', 'next-signin-other', 'signup',        1);

-- Page signup (list_id 2).
INSERT INTO _glossary VALUES ('fr', 'btn-signup',        'S''inscrire',      2);
INSERT INTO _glossary VALUES ('fr', 'btn-signup-other',  'Déjà inscrit ?',   2);
INSERT INTO _glossary VALUES ('fr', 'next-signup-other', 'signin',           2);
INSERT INTO _glossary VALUES ('en', 'btn-signup',        'Register',         2);
INSERT INTO _glossary VALUES ('en', 'btn-signup-other',  'Already registered ?', 2);
INSERT INTO _glossary VALUES ('en', 'next-signup-other', 'signin',           2);

-- Page me / profil (list_id 3).
INSERT INTO _glossary VALUES ('fr', 'btn-me',        'Sauvegarder',      3);
INSERT INTO _glossary VALUES ('fr', 'btn-me-other',  'Se désinscrire',   3);
INSERT INTO _glossary VALUES ('fr', 'next-me-other', 'signup',           3);
INSERT INTO _glossary VALUES ('fr', 'btn-signout',         'Se déconnecter',   3);
INSERT INTO _glossary VALUES ('fr', 'passwd-hint',         'vide = inchangé',  3);
INSERT INTO _glossary VALUES ('fr', 'confirm-unregister',  'Êtes-vous sûr de vouloir supprimer votre compte ? Cette action est irréversible.', 3);
INSERT INTO _glossary VALUES ('en', 'btn-me',              'Save',             3);
INSERT INTO _glossary VALUES ('en', 'btn-me-other',        'Unregister',       3);
INSERT INTO _glossary VALUES ('en', 'next-me-other',       'signup',           3);
INSERT INTO _glossary VALUES ('en', 'btn-signout',         'Disconnect',       3);
INSERT INTO _glossary VALUES ('en', 'passwd-hint',         'empty = unchanged', 3);
INSERT INTO _glossary VALUES ('en', 'confirm-unregister',  'Are you sure you want to delete your account? This action cannot be undone.', 3);

-- Page DB schema (list_id 4).
INSERT INTO _glossary VALUES ('fr', 'db-title',      'Base de données',        4);
INSERT INTO _glossary VALUES ('fr', 'db-tables',     'Tables accessibles',     4);
INSERT INTO _glossary VALUES ('fr', 'db-loading',    'Chargement…',            4);
INSERT INTO _glossary VALUES ('fr', 'db-empty',      'Aucune table accessible.', 4);
INSERT INTO _glossary VALUES ('fr', 'db-load-error', 'Erreur de chargement',   4);
INSERT INTO _glossary VALUES ('en', 'db-title',      'Database',               4);
INSERT INTO _glossary VALUES ('en', 'db-tables',     'Accessible tables',      4);
INSERT INTO _glossary VALUES ('en', 'db-loading',    'Loading…',               4);
INSERT INTO _glossary VALUES ('en', 'db-empty',      'No accessible table.',   4);
INSERT INTO _glossary VALUES ('en', 'db-load-error', 'Loading error',          4);

-- Page DB table/CRUD (list_id 5).
INSERT INTO _glossary VALUES ('fr', 'db-insert',         '+ Insérer',               5);
INSERT INTO _glossary VALUES ('fr', 'db-insert-title',   'Insérer une nouvelle ligne', 5);
INSERT INTO _glossary VALUES ('fr', 'db-required',       'requis',                  5);
INSERT INTO _glossary VALUES ('fr', 'db-edit',           'Modifier',                5);
INSERT INTO _glossary VALUES ('fr', 'db-delete',         'Supprimer',               5);
INSERT INTO _glossary VALUES ('fr', 'db-confirm-delete', 'Supprimer cette ligne ?', 5);
INSERT INTO _glossary VALUES ('en', 'db-insert',         '+ Insert',                5);
INSERT INTO _glossary VALUES ('en', 'db-insert-title',   'Insert a new row',        5);
INSERT INTO _glossary VALUES ('en', 'db-required',       'required',                5);
INSERT INTO _glossary VALUES ('en', 'db-edit',           'Edit',                    5);
INSERT INTO _glossary VALUES ('en', 'db-delete',         'Delete',                  5);
INSERT INTO _glossary VALUES ('en', 'db-confirm-delete', 'Delete this row?',        5);

-- Champs auth communs (list_id 106 — signin + signup + me).
INSERT INTO _glossary VALUES ('fr', 'email',  'Adresse mail', 106);
INSERT INTO _glossary VALUES ('fr', 'passwd', 'Mot de passe', 106);
INSERT INTO _glossary VALUES ('en', 'email',  'EMail',        106);
INSERT INTO _glossary VALUES ('en', 'passwd', 'Password',     106);

-- Champs auth étendus (list_id 107 — signup + me uniquement).
INSERT INTO _glossary VALUES ('fr', 'passwd-confirm', 'Confirmation',  107);
INSERT INTO _glossary VALUES ('fr', 'forename',       'Prénom',        107);
INSERT INTO _glossary VALUES ('fr', 'lastname',       'Nom',           107);
INSERT INTO _glossary VALUES ('fr', 'lang-select',    'Langue',        107);
INSERT INTO _glossary VALUES ('en', 'passwd-confirm', 'Confirm password', 107);
INSERT INTO _glossary VALUES ('en', 'forename',       'First name',    107);
INSERT INTO _glossary VALUES ('en', 'lastname',       'Last name',     107);
INSERT INTO _glossary VALUES ('en', 'lang-select',    'Language',      107);

-- =============================================================================
-- PAGES D'ADMINISTRATION — v1.3.0
-- _list 1-6 réservés au moteur WaTE (ne pas utiliser dans les apps).
-- =============================================================================

-- _list 100 — template + css admin-auth.
INSERT INTO _item VALUES (100, 'template', 'admin-auth');
INSERT INTO _item VALUES (100, 'css',      'admin-auth.css');
INSERT INTO _item VALUES (100, 'scripts',  '{"type":"module","path":"/scripts/admin-auth.js"}');
INSERT INTO _item VALUES (100, 'queries',  '"_columns": {"request": "PRAGMA table_info(_user)"}, "_fk": {"request": "PRAGMA foreign_key_list(_user)"}, "_fk_lang": {"request": "SELECT id, name FROM _lang ORDER BY id"}');

-- _list 101 — requête partagée : user connecté (result["_user"].rows[0]).
--             Incluse dans _page pour toute page nécessitant les infos du user courant.
INSERT INTO _item VALUES (101, 'queries', '"_user": {"request": "SELECT email, forename, lastname, profil_id, lang_id FROM _user U JOIN _session S ON U.email = S.user_email WHERE S.id = ?", "values": "[req.cookies.session.id]"}');

-- _list 103 — liste partagée (tous profils) : scripts communs + menu langue.
--             Incluse dans _page pour toute page admin, owner ET anonymous.
--             Fournit : elements['lang-menu'], charge admin-common.js.
--             NOTE : le glossaire n'est plus chargé ici — serve() le charge directement
--             via LEFT JOIN _page (même hiérarchie que _item/_page, v2.3.0).
INSERT INTO _item VALUES (103, 'scripts',   '{"type":"text/javascript","path":"/scripts/admin-common.js"},{"type":"text/javascript","path":"/scripts/search.js"}');
INSERT INTO _item VALUES (103, 'lang-menu', '{"rank":1,"text":"lang-fr","icon":"fr.png","params":{"lang":"fr"}},{"rank":2,"text":"lang-en","icon":"en.png","params":{"lang":"en"}}');

-- _list 104 — nav-menu owner (mon profil, base de données, stats, déconnexion).
--             Incluse dans _page pour toutes les pages accessibles au profil owner (0).
INSERT INTO _item VALUES (104, 'nav-menu', '{"rank":1,"text":"nav-me","href":"/admin/form/auth/me","icon":"nav-me.svg"},{"rank":2,"text":"nav-db","href":"/admin/form/db/schema","icon":"nav-db.svg"},{"rank":3,"text":"nav-stats","href":"/admin/form/stats","icon":"nav-stats.svg"},{"rank":4,"text":"nav-search","href":"/admin/form/search","icon":"nav-search.svg"},{"rank":5,"text":"nav-signout","href":"@wate.signout()","icon":"nav-signout.svg"}');

-- _list 105 — nav-menu anonymous (connexion, inscription).
--             Incluse dans _page pour signin/signup profil anonymous uniquement.
INSERT INTO _item VALUES (105, 'nav-menu', '{"rank":1,"text":"nav-signin","href":"/admin/form/auth/signin","icon":"nav-signin.svg"},{"rank":2,"text":"nav-signup","href":"/admin/form/auth/signup","icon":"nav-signup.svg"}');

-- _list 106 — email partagé (signin + signup + me).
INSERT INTO _item VALUES (106, 'fields', '{"name":"email","type":"email","mandatory":true,"order":1}');

-- _list 107 — champs étendus (signup + me) : passwd-confirm, forename, lastname, lang-select.
INSERT INTO _item VALUES (107, 'fields', '{"name":"password_confirm","type":"password","mandatory":false,"order":3,"tag":"passwd-confirm"},{"name":"forename","type":"text","mandatory":false,"order":4},{"name":"lastname","type":"text","mandatory":false,"order":5},{"name":"lang_id","type":"select","mandatory":false,"order":6,"tag":"lang-select"}');

-- Sous-requête session fantôme (réutilisée par tous les INSERTs profil anonymous)
-- ANON = (SELECT p.id FROM _profil p, _user u, _session s
--          WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0')

-- /admin/form/auth/signin — accessible aux profils anonymous uniquement
INSERT INTO _item VALUES (1, 'title',    'Connexion');
INSERT INTO _item VALUES (1, 'mode',     'signin');
INSERT INTO _item VALUES (1, 'next',     '/admin/form/auth/me');
INSERT INTO _item VALUES (1, 'fields',   '{"name":"password","type":"password","mandatory":true,"order":2,"tag":"passwd"}');
INSERT INTO _page VALUES ('/admin/form/auth/signin',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 1);
INSERT INTO _page VALUES ('/admin/form/auth/signin',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 100);
INSERT INTO _page VALUES ('/admin/form/auth/signin',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 103);
INSERT INTO _page VALUES ('/admin/form/auth/signin',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 105);
INSERT INTO _page VALUES ('/admin/form/auth/signin',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 106);

-- /admin/form/auth/signup — accessible aux profils anonymous uniquement
INSERT INTO _item VALUES (2, 'title',    'Inscription');
INSERT INTO _item VALUES (2, 'mode',     'signup');
INSERT INTO _item VALUES (2, 'next',     '/admin/form/auth/signin');
INSERT INTO _item VALUES (2, 'fields',   '{"name":"password","type":"password","mandatory":true,"order":2,"tag":"passwd"}');
INSERT INTO _page VALUES ('/admin/form/auth/signup',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 2);
INSERT INTO _page VALUES ('/admin/form/auth/signup',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 100);
INSERT INTO _page VALUES ('/admin/form/auth/signup',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 103);
INSERT INTO _page VALUES ('/admin/form/auth/signup',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 105);
INSERT INTO _page VALUES ('/admin/form/auth/signup',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 106);
INSERT INTO _page VALUES ('/admin/form/auth/signup',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 107);

-- /admin/form/auth/me — accessible au profil owner (0)
INSERT INTO _item VALUES (3, 'title',    'Mon profil');
INSERT INTO _item VALUES (3, 'mode',     'me');
INSERT INTO _item VALUES (3, 'next',     '/admin/form/auth/me');
INSERT INTO _item VALUES (3, 'record',   '_user');
INSERT INTO _item VALUES (3, 'fields',   '{"name":"password","type":"password","mandatory":false,"order":2,"tag":"passwd","hint":"passwd-hint"}');
INSERT INTO _page VALUES ('/admin/form/auth/me', 0, 3);
INSERT INTO _page VALUES ('/admin/form/auth/me', 0, 100);
INSERT INTO _page VALUES ('/admin/form/auth/me', 0, 101);
INSERT INTO _page VALUES ('/admin/form/auth/me', 0, 103);
INSERT INTO _page VALUES ('/admin/form/auth/me', 0, 104);
INSERT INTO _page VALUES ('/admin/form/auth/me', 0, 106);
INSERT INTO _page VALUES ('/admin/form/auth/me', 0, 107);

-- /admin/form/db/schema — accessible au profil owner (0)
-- Queries server-side : _schema (DDL complet) + _allowed (tables en select pour le profil).
-- Le filtrage (intersection) et le parsing DDL sont faits côté EJS (admin-db.ejs).
INSERT INTO _item VALUES (4, 'template', 'admin-db');
INSERT INTO _item VALUES (4, 'title',    'Base de données');
INSERT INTO _item VALUES (4, 'css',      'admin-db.css');
INSERT INTO _item VALUES (4, 'queries',  '"_schema": {"request": "SELECT name, sql FROM sqlite_master WHERE type=''table'' AND name NOT LIKE ''sqlite_%'' ORDER BY name"}, "_allowed": {"request": "SELECT DISTINCT a.tablename AS name FROM _access a JOIN _user U ON U.profil_id = a.profil_id JOIN _session S ON S.user_email = U.email WHERE S.id = ? AND a.request_name = ''select'' ORDER BY a.tablename", "values": "[req.cookies.session.id]"}');
INSERT INTO _page VALUES ('/admin/form/db/schema', 0, 4);
INSERT INTO _page VALUES ('/admin/form/db/schema', 0, 101);
INSERT INTO _page VALUES ('/admin/form/db/schema', 0, 103);
INSERT INTO _page VALUES ('/admin/form/db/schema', 0, 104);

-- /admin/form/db?table=<name> — form CRUD générique, owner uniquement.
-- Queries PRAGMA via table-valued functions SQLite (3.16+) — req.query.table.
INSERT INTO _item VALUES (5, 'template',    'admin-db');
INSERT INTO _item VALUES (5, 'title',       'Table');
INSERT INTO _item VALUES (5, 'title_param', 'table');
INSERT INTO _item VALUES (5, 'css',         'admin-db.css');
INSERT INTO _item VALUES (5, 'queries',     '"_columns": {"request": "PRAGMA table_info(${req.query.table:identifier})"}, "_fk": {"request": "PRAGMA foreign_key_list(${req.query.table:identifier})"}, "_meta": {"request": "SELECT sql FROM sqlite_master WHERE type=''table'' AND name=?", "values": "[req.query.table]"}, "_fk_profil": {"request": "SELECT id, name FROM _profil ORDER BY id"}, "_fk_lang": {"request": "SELECT id, name FROM _lang ORDER BY id"}, "_fk_request": {"request": "SELECT name FROM _request ORDER BY name"}, "_fk_list": {"request": "SELECT id FROM _list ORDER BY id"}, "_fk_user": {"request": "SELECT email FROM _user ORDER BY email"}, "_fk_session": {"request": "SELECT id FROM _session ORDER BY id"}');
INSERT INTO _page VALUES ('/admin/form/db', 0, 5);
INSERT INTO _page VALUES ('/admin/form/db', 0, 101);
INSERT INTO _page VALUES ('/admin/form/db', 0, 103);
INSERT INTO _page VALUES ('/admin/form/db', 0, 104);

-- =============================================================================
-- INDEX — v1.1.0 + idx_glossary_list_id v2.3.0
-- =============================================================================

CREATE INDEX idx_item_list_id     ON _item    (list_id);
CREATE INDEX idx_page_url         ON _page    (url);
CREATE INDEX idx_page_profil_id   ON _page    (profil_id);
CREATE INDEX idx_user_profil_id   ON _user    (profil_id);
CREATE INDEX idx_session_email    ON _session (user_email);
CREATE INDEX idx_access_table     ON _access  (tablename, profil_id);
CREATE INDEX idx_glossary_lang_id ON _glossary(lang_id);
CREATE INDEX idx_glossary_list_id ON _glossary(list_id);

/* (WaTE) engine.sql v2.6.0 */
