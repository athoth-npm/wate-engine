/**
 * \file      (WaTE) scripts/admin-common.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      16/04/2026
 * \version   1.0.0
 * \brief     Script commun à toutes les pages d'administration WaTE.
 *            Chargé via list 103 (_item scripts) — présent sur toutes les pages admin.
 *
 * \details   Expose window.wate.signout() pour le menu hamburger owner
 *            (item nav-signout, action @wate.signout()).
 */

'use strict'

window.wate = window.wate || {}

/**
 * \fn wate.signout
 * \brief Soumet un formulaire POST à /admin/form/auth/signout avec le jeton CSRF.
 *        Appelé depuis le menu hamburger via l'action @wate.signout() dans def.js.
 *
 * \details Lit le jeton depuis <meta name="csrf-token">.
 *          Crée un formulaire temporaire, l'ajoute au body, et le soumet.
 *          Le formulaire est détruit automatiquement lors de la navigation.
 */
window.wate.signout = function() {
  const csrf = document.querySelector('meta[name="csrf-token"]')
  const form = document.createElement('form')
  form.method = 'POST'
  form.action = '/admin/form/auth/signout'
  if(csrf) {
    const input = document.createElement('input')
    input.type  = 'hidden'
    input.name  = '_csrf'
    input.value = csrf.content
    form.appendChild(input)
  }
  // FIX v1.0.1 #145: form invisible avant soumission
  form.style.display = 'none'
  document.body.appendChild(form)
  form.submit()
}

/* (WaTE) scripts/admin-common.js v1.0.1 */