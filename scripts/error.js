/**
 *  \file     (WaTE) error.js
 *  \author   Romain Légault
 *  \date     21/03/2026
 *  \version  2.1.0
 *  \brief    Gestion de la redirection après affichage de la page d'erreur.
 *
 *  \details  v1.1.0 : DOMContentLoaded supprimé — script déclaré defer.
 *            v2.0.0 : gestion de errorNext :
 *                       undefined/'' → history.back() après 3s
 *                       'back'       → history.back() après 3s
 *                       'root'       → rootRoute lu depuis data-root-route
 *                       string       → redirection vers cette URL après 3s
 *                     Chargé via <script src="/scripts/error.js" defer> hardcodé
 *                     dans error.ejs — ne dépend plus de la DB.
 *            v2.1.0 : Ajout d'un 'next' === 'none' => ne rien faire
 */

'use strict'

const div       = document.querySelector('[data-error-next]')
const errorNext = div && div.getAttribute('data-error-next')
const rootRoute = div && div.getAttribute('data-root-route')

setTimeout(function() {
  if (!errorNext || errorNext === 'back') { history.back() }
  else if (errorNext === 'none')          { /* rester sur la page */ }
  else if (errorNext === 'root')          { window.location = rootRoute || '/' }
  else                                    { window.location = errorNext }
}, 3000)

/* (WaTE) error.js v2.1.0 */