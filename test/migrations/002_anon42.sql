/**
 * \file      (WaTE) 002_anon42.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   1.0.0
 * \brief     Migration de test — profil anonymous id=9999 → 42.
 *
 * \details   Valide que le moteur WaTE est agnostique au profil_id anonymous :
 *            aucune valeur 9999 n'est codée en dur dans les modules JS.
 *            ON UPDATE CASCADE propage vers _user.profil_id, _access.profil_id,
 *            _page.profil_id — toutes les références dérivent de la ghost session.
 *            Après cette migration, toute la suite de tests passe avec id=42 :
 *            c'est la preuve que le moteur fonctionne quel que soit le profil_id.
 */

-- Changement profil_id anonymous : 9999 → 42
-- ON UPDATE CASCADE propage vers _user.profil_id, _access.profil_id, _page.profil_id.
UPDATE _profil SET id = 42 WHERE id = 9999;

/* (WaTE) 002_anon42.sql v1.0.0 */
