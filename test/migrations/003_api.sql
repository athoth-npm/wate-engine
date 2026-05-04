/**
 * \file      (WaTE) 003_api.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-24
 * \version   1.0.0
 * \brief     Migration de test — pages /style2 et /style3 pour valider les
 *            trois styles d'écriture d'une appli WaTE.
 *
 * \details   Complète le module applicatif test/scripts/test-routes.js :
 *
 *            - /style1 : géré par une route module (GET /test/style1). Aucune
 *                        entrée DB nécessaire — le module appelle renderPage
 *                        sur /home existant.
 *
 *            - /style2 : page DB avec elements.HOOK = test_page_hook. Le hook
 *                        est enregistré par test-routes.js via onPageLoad.
 *                        list_id=18 — queries vide, HOOK seul.
 *
 *            - /style3 : page DB pure — queries SELECT sur _profil. Aucun code
 *                        applicatif, preuve que le CMS sert de la data sans JS.
 *                        list_id=19.
 *
 *            Les deux pages sont accordées au profil anonymous via la ghost
 *            session id='0' — même pattern que /home dans 001_test.sql pour
 *            rester agnostique au profil_id (9999 ou 42 selon 002_anon42.sql).
 */

-- ── /style2 : page DB + hook onPageLoad ──────────────────────────────
INSERT INTO _list VALUES (18);
INSERT INTO _item VALUES (18, 'queries', '');
INSERT INTO _item VALUES (18, 'HOOK',    'test_page_hook');
INSERT INTO _page VALUES ('/style2',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 18);

-- ── /style3 : page DB pure (queries SELECT _profil) ───────────────────
INSERT INTO _list VALUES (19);
INSERT INTO _item VALUES (19, 'queries', '"_profil":{"columns":{"id":null,"name":null},"where":{"clause":"id = 2"}}');
INSERT INTO _page VALUES ('/style3',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 19);

/* (WaTE) 003_api.sql v1.0.0 */
