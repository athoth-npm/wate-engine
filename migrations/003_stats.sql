/**
 * \file      (WaTE) 003_stats.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      16/04/2026
 * \version   1.3.0
 * \brief     Migration — page d'administration /admin/form/stats (module _stats).
 *
 * \details   Crée le _list 6 et les _page associées pour la page stats.
 *            La page est accessible uniquement au profil owner (profil_id=0).
 *            Les données sont chargées côté client via GET /admin/api/stats
 *            (enregistré par _stats.js). Ce fichier ne crée pas de routes —
 *            le catch-all de engine.js sert la page via _data.serve().
 *
 *            _list 1-6 réservés aux pages d'administration moteur.
 *
 *            v1.2.0 : glossaire stats-* (fr + en) pour admin-stats.ejs / admin-stats.js.
 *            v1.3.0 : list_id=6 ajouté aux entrées _glossary (v2.3.0 de 001_engine.sql).
 *                     UPDATE _item list 103 supprimé — serve() charge le glossaire
 *                     directement, plus de requête _glossary dans les _item.
 */

-- _list 6 — /admin/form/stats — page stats LRU, owner uniquement
INSERT INTO _list VALUES (6);
INSERT INTO _item VALUES (6, 'template', 'admin-stats');
INSERT INTO _item VALUES (6, 'title',    'Statistiques');
INSERT INTO _item VALUES (6, 'css',      'admin-stats.css');
INSERT INTO _item VALUES (6, 'scripts',  '{"type":"module","path":"/scripts/admin-stats.js"}');

INSERT INTO _page VALUES ('/admin/form/stats', 0, 6);
INSERT INTO _page VALUES ('/admin/form/stats', 0, 101);
INSERT INTO _page VALUES ('/admin/form/stats', 0, 103);
INSERT INTO _page VALUES ('/admin/form/stats', 0, 104);

-- Glossaire page stats (list_id=6 — chargé uniquement pour /admin/form/stats).
INSERT INTO _glossary VALUES ('fr', 'stats-loading',    'Chargement…',                                     6);
INSERT INTO _glossary VALUES ('fr', 'stats-empty',      'Aucun cache disponible.',                         6);
INSERT INTO _glossary VALUES ('fr', 'stats-col-cache',  'Cache',                                           6);
INSERT INTO _glossary VALUES ('fr', 'stats-col-hits',   'Hits',                                            6);
INSERT INTO _glossary VALUES ('fr', 'stats-col-misses', 'Misses',                                          6);
INSERT INTO _glossary VALUES ('fr', 'stats-col-ratio',  'Ratio',                                           6);
INSERT INTO _glossary VALUES ('fr', 'stats-col-evict',  'Évictions',                                       6);
INSERT INTO _glossary VALUES ('fr', 'stats-col-size',   'Taille / Max',                                    6);
INSERT INTO _glossary VALUES ('fr', 'stats-note',       'Compteurs cumulatifs depuis le démarrage du serveur.', 6);
INSERT INTO _glossary VALUES ('fr', 'stats-refresh',    'Rafraîchir',                                      6);
INSERT INTO _glossary VALUES ('fr', 'stats-error',      'Erreur : ',                                       6);
INSERT INTO _glossary VALUES ('en', 'stats-loading',    'Loading…',                                        6);
INSERT INTO _glossary VALUES ('en', 'stats-empty',      'No cache available.',                             6);
INSERT INTO _glossary VALUES ('en', 'stats-col-cache',  'Cache',                                           6);
INSERT INTO _glossary VALUES ('en', 'stats-col-hits',   'Hits',                                            6);
INSERT INTO _glossary VALUES ('en', 'stats-col-misses', 'Misses',                                          6);
INSERT INTO _glossary VALUES ('en', 'stats-col-ratio',  'Ratio',                                           6);
INSERT INTO _glossary VALUES ('en', 'stats-col-evict',  'Evictions',                                       6);
INSERT INTO _glossary VALUES ('en', 'stats-col-size',   'Size / Max',                                      6);
INSERT INTO _glossary VALUES ('en', 'stats-note',       'Cumulative counters since server start.',         6);
INSERT INTO _glossary VALUES ('en', 'stats-refresh',    'Refresh',                                         6);
INSERT INTO _glossary VALUES ('en', 'stats-error',      'Error: ',                                         6);

/* (WaTE) 003_stats.sql v1.3.0 */
