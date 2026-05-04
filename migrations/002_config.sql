/**
 * \file      (WaTE) 002_config.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      16/04/2026
 * \version   1.0.0
 * \brief     Migration — création de la table _config et ses valeurs par défaut.
 *
 * \details   _config centralise les paramètres du moteur WaTE qui étaient
 *            précédemment codés en dur dans les modules JS.
 *            Chaque clé correspond à un paramètre moteur ; la valeur est
 *            toujours stockée en TEXT, castée par le moteur selon la clé.
 *
 *            Clés définies (toutes moteur — aucune clé applicative ici) :
 *              session.ttl       — durée de vie des sessions en secondes
 *              cache.tableInfo   — taille max du cache PRAGMA table_info
 *              cache.fkList      — taille max du cache PRAGMA foreign_key_list
 *              cache.queries     — taille max du cache queries JSON (_data.js)
 *              upload.maxFileSize — taille max d'un fichier uploadé (octets)
 *              upload.maxFiles    — nombre max de fichiers par requête
 *              db.defaultLimit   — nombre de lignes par défaut (GET /api/db/:table)
 *              db.maxLimit       — nombre max de lignes autorisé par requête
 *
 *            NOTE : log.level est intentionnellement absent — il est positionné
 *            avant l'ouverture de la DB (parsing argv) et ne peut donc pas
 *            être lu depuis _config au démarrage.
 *
 *            Droits : owner (profil_id=0) a SELECT/INSERT/UPDATE/DELETE.
 *            Le profil anonymous n'a aucun droit sur _config.
 */

CREATE TABLE _config (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- =============================================================================
-- DROITS D'ACCÈS — owner uniquement
-- =============================================================================

INSERT INTO _access VALUES ('_config', 0, 'select');
INSERT INTO _access VALUES ('_config', 0, 'insert');
INSERT INTO _access VALUES ('_config', 0, 'update');
INSERT INTO _access VALUES ('_config', 0, 'delete');

-- =============================================================================
-- VALEURS PAR DÉFAUT
-- =============================================================================

-- Durée de vie des sessions (secondes). Priorité : CLI > _config > 'undefined'.
INSERT INTO _config VALUES ('session.ttl',        '3600');

-- Tailles des caches LRU (nombre d'entrées). Relus au démarrage, après migration.
INSERT INTO _config VALUES ('cache.tableInfo',    '100');
INSERT INTO _config VALUES ('cache.fkList',       '100');
INSERT INTO _config VALUES ('cache.queries',      '200');

-- Limites upload multer (_db.js).
INSERT INTO _config VALUES ('upload.maxFileSize', '10485760');
INSERT INTO _config VALUES ('upload.maxFiles',    '5');

-- Pagination GET /admin/api/db/:table.
INSERT INTO _config VALUES ('db.defaultLimit',    '50');
INSERT INTO _config VALUES ('db.maxLimit',        '200');

/* (WaTE) 002_config.sql v1.0.0 */
