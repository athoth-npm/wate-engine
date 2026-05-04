/**
 * \file      test.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   3.2.0
 * \brief     Crée et peuple la DB de test WaTE (test/test.db).
 *
 * \details   v1.x  : création initiale, profils, sessions, pages, droits, glossaire.
 *            v2.0.0 : mise à jour pour auth.js/db.js v2.2.0.
 *            v2.1.0 : IDs _list décalés à 11-17 (1-5 réservés engine.sql admin pages).
 *                     - INSERT _user pour profil anonymous (id=9999) activé pour tester
 *                       le signup public (non présent dans engine.sql par défaut).
 *                     - Profil 6 + utilisateur signup-test@test.com + session
 *                       test-session-signup pour tester GET /admin/form/auth/me
 *                       après un signup.
 *            v2.2.0 : _page pour admin (profil 2) sur /admin/form/db/schema —
 *                     liste 4 (template+css) + liste 101 (query _user).
 *            v2.3.0 : _page pour profils 2 et 6 sur /admin/form/auth/me —
 *                     engine.sql n'accorde /me qu'au profil 0 (owner).
 *                     Les tests vérifient que tout profil authentifié peut voir
 *                     son profil → les profils de test doivent avoir accès.
 *            v3.0.0 : migration depuis setup-db.js qui devient obsolète.
 *            v3.2.0 : _user gagne la colonne 'verified' (004_auth_token.sql) — tous
 *                     les INSERT _user passent à 7 valeurs (verified=1).
 *            v3.1.0 : _glossary passe à 4 colonnes (list_id ajouté — 001_engine.sql v2.3.0).
 *                     error-* : list_id=NULL (httpError charge via SELECT LIKE 'error-%',
 *                     sans filtre list_id — valeur sémantiquement neutre mais obligatoire).
 *                     _page profils 2/6 sur /me : ajout listes 103, 106, 107.
 *                     _page profil 2 sur /db/schema : ajout liste 103.
 */

-- NOTE : _lang fr/en déjà insérés par engine.sql v1.3.0.

-- Profil admin-test (id=2)
INSERT INTO _profil VALUES (2, 'admin-test');

-- Utilisateurs
INSERT INTO _user VALUES ('owner@test.com', 'x', 'Owner', 'Test', 0, 'fr', 1);
INSERT INTO _user VALUES ('admin@test.com', 'x', 'Admin', 'Test', 2, 'fr', 1);

-- Sessions actives
INSERT INTO _session VALUES ('test-session-owner',   'owner@test.com', strftime('%s','now'));
INSERT INTO _session VALUES ('test-session-admin',   'admin@test.com', strftime('%s','now'));
INSERT INTO _session VALUES ('test-session-expired', 'admin@test.com', 0);

-- ── Pages ────────────────────────────────────────────────────────────
-- NOTE : IDs 1-5 réservés par engine.sql (pages admin moteur).
INSERT INTO _list VALUES (11);
INSERT INTO _item VALUES (11, 'queries', '');
INSERT INTO _page VALUES ('/home',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 11);

INSERT INTO _list VALUES (12);
INSERT INTO _item VALUES (12, 'queries', '');
INSERT INTO _page VALUES ('/admin-test', 2, 12);

-- ── Profils supplémentaires ───────────────────────────────────────
INSERT INTO _profil VALUES (3, 'profil-3-test');
INSERT INTO _profil VALUES (4, 'profil-4-test');

INSERT INTO _user VALUES ('p3@test.com', 'x', 'User', 'P3', 3, 'fr', 1);
INSERT INTO _user VALUES ('p4@test.com', 'x', 'User', 'P4', 4, 'fr', 1);

INSERT INTO _session VALUES ('test-session-p3', 'p3@test.com', strftime('%s','now'));
INSERT INTO _session VALUES ('test-session-p4', 'p4@test.com', strftime('%s','now'));

-- ── Table applicative 'sample' ────────────────────────────────────
CREATE TABLE sample (id TEXT PRIMARY KEY, name TEXT NOT NULL);
INSERT INTO sample VALUES ('s1', 'Sample One');

INSERT INTO _access VALUES ('sample', 2, 'select');
INSERT INTO _access VALUES ('sample', 2, 'insert');
INSERT INTO _access VALUES ('sample', 2, 'update');
INSERT INTO _access VALUES ('sample', 2, 'delete');

-- ── Table dédiée aux tests undo ────────────────────────────────────
CREATE TABLE undo_test (id TEXT PRIMARY KEY, name TEXT NOT NULL);
INSERT INTO _access VALUES ('undo_test', 0, 'select');
INSERT INTO _access VALUES ('undo_test', 0, 'insert');
INSERT INTO _access VALUES ('undo_test', 0, 'update');
INSERT INTO _access VALUES ('undo_test', 0, 'delete');
INSERT INTO _access VALUES ('undo_test', 2, 'select');
INSERT INTO _access VALUES ('undo_test', 2, 'insert');
INSERT INTO _access VALUES ('undo_test', 2, 'update');
INSERT INTO _access VALUES ('undo_test', 2, 'delete');

-- ── Table sans PK pour test DELETE sans WHERE ────────────────────
CREATE TABLE no_pk (col1 TEXT, col2 TEXT);
INSERT INTO _access VALUES ('no_pk', 2, 'select');
INSERT INTO _access VALUES ('no_pk', 2, 'delete');

-- ── Table avec PK=0 pour test PK falsy ────────────────────────────
CREATE TABLE pk_zero (id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO pk_zero VALUES (0, 'Row Zero');
INSERT INTO pk_zero VALUES (1, 'Row One');
INSERT INTO _access VALUES ('pk_zero', 0, 'select');
INSERT INTO _access VALUES ('pk_zero', 0, 'insert');
INSERT INTO _access VALUES ('pk_zero', 0, 'update');
INSERT INTO _access VALUES ('pk_zero', 0, 'delete');

-- ── Droits update-self sur _user pour admin-test (profil 2) ──────
INSERT INTO _access VALUES ('_user', 2, 'update-self');

-- ── Profil 5 + utilisateur delete-me pour DELETE /admin/api/auth/me
INSERT INTO _profil VALUES (5, 'self-delete-test');
INSERT INTO _user VALUES ('delete-me@test.com', 'x', 'Delete', 'Me', 5, 'fr', 1);
INSERT INTO _session VALUES ('test-session-delete-me', 'delete-me@test.com', strftime('%s','now'));
INSERT INTO _access VALUES ('_user', 5, 'delete-self');

-- ── Signup public : INSERT _user autorisé pour le profil anonymous ──
-- Non présent dans engine.sql (sécurité). Activé ici uniquement pour les tests.
-- La session fantôme '0' identifie le profil anonymous sans hardcoder sa valeur.
-- Toute requête sans cookie peut donc insérer un compte via signup.
INSERT INTO _access VALUES ('_user',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'),
  'insert');

-- ── Profil 6 + utilisateur post-signup pour tester GET /admin/form/auth/me
INSERT INTO _profil VALUES (6, 'signup-test');
INSERT INTO _user VALUES ('signup-test@test.com', 'x', 'Signup', 'Test', 6, 'fr', 1);
INSERT INTO _session VALUES ('test-session-signup', 'signup-test@test.com', strftime('%s','now'));

-- ── Accès admin (profil 2) à /admin/form/db/schema ─────────────
INSERT INTO _page VALUES ('/admin/form/db/schema', 2, 4);
INSERT INTO _page VALUES ('/admin/form/db/schema', 2, 101);
INSERT INTO _page VALUES ('/admin/form/db/schema', 2, 103);

-- ── v2.3.0 / v3.1.0 : Accès /admin/form/auth/me pour les profils de test ──
-- engine.sql n'accorde /me qu'au profil 0 (owner).
-- Les tests vérifient que admin (profil 2) et signup-test (profil 6) peuvent
-- voir leur propre profil après connexion — il faut leurs _page en DB.
-- Listes 103 (admin-common.js), 106 (email/passwd labels), 107 (champs étendus)
-- ajoutées pour que le formulaire charge ses labels via le glossaire scopé.

-- Profil 2 (admin-test) : accès /admin/form/auth/me
INSERT INTO _page VALUES ('/admin/form/auth/me', 2, 3);
INSERT INTO _page VALUES ('/admin/form/auth/me', 2, 100);
INSERT INTO _page VALUES ('/admin/form/auth/me', 2, 101);
INSERT INTO _page VALUES ('/admin/form/auth/me', 2, 103);
INSERT INTO _page VALUES ('/admin/form/auth/me', 2, 106);
INSERT INTO _page VALUES ('/admin/form/auth/me', 2, 107);

-- Profil 6 (signup-test) : accès /admin/form/auth/me
INSERT INTO _page VALUES ('/admin/form/auth/me', 6, 3);
INSERT INTO _page VALUES ('/admin/form/auth/me', 6, 100);
INSERT INTO _page VALUES ('/admin/form/auth/me', 6, 101);
INSERT INTO _page VALUES ('/admin/form/auth/me', 6, 103);
INSERT INTO _page VALUES ('/admin/form/auth/me', 6, 106);
INSERT INTO _page VALUES ('/admin/form/auth/me', 6, 107);

-- ── Pages /shared et /exclusive ───────────────────────────────────
INSERT INTO _list VALUES (13);
INSERT INTO _item VALUES (13, 'queries', '"_profil":{"columns":{"id":null,"name":null},"where":{"clause":"id = 2"}}');
INSERT INTO _page VALUES ('/shared', 2, 13);

INSERT INTO _list VALUES (14);
INSERT INTO _item VALUES (14, 'queries', '"_profil":{"columns":{"id":null,"name":null},"where":{"clause":"id = 3"}}');
INSERT INTO _page VALUES ('/shared', 3, 14);

INSERT INTO _list VALUES (15);
INSERT INTO _item VALUES (15, 'queries', '"_profil":{"columns":{"id":null,"name":null},"where":{"clause":"id = 4"}}');
INSERT INTO _page VALUES ('/shared', 4, 15);

INSERT INTO _list VALUES (16);
INSERT INTO _item VALUES (16, 'queries', '"_profil":{"columns":{"id":null,"name":null},"where":{"clause":"id = 3"}}');
INSERT INTO _page VALUES ('/exclusive', 3, 16);

INSERT INTO _list VALUES (17);
INSERT INTO _item VALUES (17, 'queries', '"_profil":{"columns":{"id":null,"name":null},"where":{"clause":"id = 4"}}');
INSERT INTO _page VALUES ('/exclusive', 4, 17);

-- ── Glossaire FR / EN ─────────────────────────────────────────────
-- list_id=NULL : httpError charge via SELECT LIKE 'error-%' sans filtre list_id.
INSERT INTO _glossary VALUES ('fr', 'error-not-found',          'Page introuvable',       NULL);
INSERT INTO _glossary VALUES ('fr', 'error-unauthorized',       'Accès non autorisé',     NULL);
INSERT INTO _glossary VALUES ('fr', 'error-internal',           'Erreur interne',         NULL);
INSERT INTO _glossary VALUES ('fr', 'error-bad-request',        'Requête invalide',       NULL);
INSERT INTO _glossary VALUES ('fr', 'error-forbidden',          'Accès interdit',         NULL);
INSERT INTO _glossary VALUES ('fr', 'error-too-many-requests',  'Trop de requêtes',       NULL);
INSERT INTO _glossary VALUES ('fr', 'error-too-large',          'Fichier trop volumineux', NULL);
INSERT INTO _glossary VALUES ('fr', 'error-method-not-allowed', 'Méthode non autorisée',  NULL);
INSERT INTO _glossary VALUES ('fr', 'error-gone',               'Ressource supprimée',    NULL);

INSERT INTO _glossary VALUES ('en', 'error-not-found',          'Page not found',         NULL);
INSERT INTO _glossary VALUES ('en', 'error-unauthorized',       'Unauthorized',           NULL);
INSERT INTO _glossary VALUES ('en', 'error-internal',           'Internal server error',  NULL);
INSERT INTO _glossary VALUES ('en', 'error-bad-request',        'Bad request',            NULL);
INSERT INTO _glossary VALUES ('en', 'error-forbidden',          'Forbidden',              NULL);
INSERT INTO _glossary VALUES ('en', 'error-too-many-requests',  'Too many requests',      NULL);
INSERT INTO _glossary VALUES ('en', 'error-too-large',          'Payload too large',      NULL);
INSERT INTO _glossary VALUES ('en', 'error-method-not-allowed', 'Method not allowed',     NULL);
INSERT INTO _glossary VALUES ('en', 'error-gone',               'Gone',                   NULL);

/* (WaTE) test.sql v3.2.0 */