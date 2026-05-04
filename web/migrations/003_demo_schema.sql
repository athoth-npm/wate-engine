/**
 * \file      (WaTE) web/migrations/003_demo_schema.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-29
 * \version   1.0.0
 * \brief     Tables et trigger de la démo « gestion de stock ».
 *
 * \details   Crée les tables métier demo_produit et demo_mouvement dans
 *            site.db (préfixe demo_), ainsi que le trigger qui maintient
 *            demo_produit.stock à jour après chaque INSERT dans demo_mouvement.
 *            IF NOT EXISTS → idempotent, ne recrée pas si les tables existent.
 */

CREATE TABLE IF NOT EXISTS demo_produit (
  id    INTEGER PRIMARY KEY,
  ref   TEXT UNIQUE NOT NULL,
  nom   TEXT NOT NULL,
  prix  REAL NOT NULL,
  stock INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS demo_mouvement (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  date       TEXT NOT NULL DEFAULT (datetime('now')),
  produit_id INTEGER NOT NULL REFERENCES demo_produit(id),
  type       TEXT NOT NULL CHECK(type IN ('entree', 'sortie')),
  quantite   INTEGER NOT NULL CHECK(quantite > 0),
  motif      TEXT
);

CREATE TRIGGER IF NOT EXISTS demo_trg_mouvement_stock
AFTER INSERT ON demo_mouvement
BEGIN
  UPDATE demo_produit SET stock = stock +
    (CASE NEW.type WHEN 'entree' THEN NEW.quantite ELSE -NEW.quantite END)
  WHERE id = NEW.produit_id;
END;

/* (WaTE) web/migrations/003_demo_schema.sql v1.0.0 */
