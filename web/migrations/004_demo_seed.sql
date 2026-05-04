/**
 * \file      (WaTE) web/migrations/004_demo_seed.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-29
 * \version   1.0.0
 * \brief     Seed data — produits et mouvements initiaux de la démo.
 *
 * \details   Chargé par demo.js au boot (si tables vides) et au reset.
 *            Les produits sont insérés avec stock=0 ; le trigger
 *            demo_trg_mouvement_stock recalcule le stock après chaque mouvement.
 */

-- FIX v1.0.1 #112: nettoyer _audit au reset (évite accumulation ~5475/an)
DELETE FROM _audit;
DELETE FROM demo_mouvement;
DELETE FROM demo_produit;

INSERT INTO demo_produit (id, ref, nom, prix, stock) VALUES
  (1, 'CRF-001', 'Carafe en grès',         24.00, 0),
  (2, 'PLT-002', 'Plateau en chêne',       38.00, 0),
  (3, 'BOL-003', 'Bol émaillé',            14.50, 0),
  (4, 'TAS-004', 'Tasse à expresso',        9.90, 0),
  (5, 'POT-005', 'Pot à confiture',         6.20, 0);

INSERT INTO demo_mouvement (produit_id, type, quantite, motif) VALUES
  (1, 'entree',  40, 'Réception fournisseur Pottery Lab'),
  (2, 'entree',  25, 'Réception fournisseur Forêt Vivante'),
  (3, 'entree', 100, 'Réception fournisseur Ceramica'),
  (4, 'entree', 200, 'Réception fournisseur Ceramica'),
  (5, 'entree', 150, 'Réception fournisseur Verrerie de la Loire'),
  (3, 'sortie',  18, 'Vente boutique en ligne'),
  (4, 'sortie',  46, 'Vente boutique en ligne'),
  (5, 'sortie',  22, 'Vente marché de Saint-Étienne'),
  (1, 'sortie',   3, 'Casse — incident logistique'),
  (2, 'sortie',   7, 'Vente boutique en ligne');

-- Journal d'audit — reflète les insertions seed comme si elles avaient été
-- faites via l'admin CRUD (qui passe par _data.modify et déclenche le hook).
INSERT INTO _audit (table_name, operation, record_key, new_values, user_email, changed_at) VALUES
  ('demo_produit', 'insert', '{"id":1}', '{"id":1,"ref":"CRF-001","nom":"Carafe en grès","prix":24,"stock":0}',       'demo-owner@wate.fr', strftime('%s', 'now', '-120 seconds')),
  ('demo_produit', 'insert', '{"id":2}', '{"id":2,"ref":"PLT-002","nom":"Plateau en chêne","prix":38,"stock":0}',     'demo-owner@wate.fr', strftime('%s', 'now', '-120 seconds')),
  ('demo_produit', 'insert', '{"id":3}', '{"id":3,"ref":"BOL-003","nom":"Bol émaillé","prix":14.5,"stock":0}',        'demo-owner@wate.fr', strftime('%s', 'now', '-120 seconds')),
  ('demo_produit', 'insert', '{"id":4}', '{"id":4,"ref":"TAS-004","nom":"Tasse à expresso","prix":9.9,"stock":0}',    'demo-owner@wate.fr', strftime('%s', 'now', '-120 seconds')),
  ('demo_produit', 'insert', '{"id":5}', '{"id":5,"ref":"POT-005","nom":"Pot à confiture","prix":6.2,"stock":0}',     'demo-owner@wate.fr', strftime('%s', 'now', '-120 seconds')),
  ('demo_mouvement', 'insert', '{"id":1}', '{"id":1,"produit_id":1,"type":"entree","quantite":40,"motif":"Réception fournisseur Pottery Lab"}',          'demo-owner@wate.fr', strftime('%s', 'now', '-60 seconds')),
  ('demo_mouvement', 'insert', '{"id":2}', '{"id":2,"produit_id":2,"type":"entree","quantite":25,"motif":"Réception fournisseur Forêt Vivante"}',         'demo-owner@wate.fr', strftime('%s', 'now', '-60 seconds')),
  ('demo_mouvement', 'insert', '{"id":3}', '{"id":3,"produit_id":3,"type":"entree","quantite":100,"motif":"Réception fournisseur Ceramica"}',             'demo-owner@wate.fr', strftime('%s', 'now', '-60 seconds')),
  ('demo_mouvement', 'insert', '{"id":4}', '{"id":4,"produit_id":4,"type":"entree","quantite":200,"motif":"Réception fournisseur Ceramica"}',             'demo-owner@wate.fr', strftime('%s', 'now', '-60 seconds')),
  ('demo_mouvement', 'insert', '{"id":5}', '{"id":5,"produit_id":5,"type":"entree","quantite":150,"motif":"Réception fournisseur Verrerie de la Loire"}', 'demo-owner@wate.fr', strftime('%s', 'now', '-60 seconds'));

/* (WaTE) web/migrations/004_demo_seed.sql v1.0.0 */
