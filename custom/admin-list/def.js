/**
 * \file      (WaTE) custom/admin-list/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      17/04/2026
 * \version   1.0.1
 * \brief     Custom element générique <admin-list> — liste déroulante FK pour <admin-row>.
 *
 * \details   Remplace les éléments nommés par table (<lang-list>, <profil-list>…)
 *            générés dynamiquement par admin-list.ejs + adminListStatic().
 *            Un seul élément réutilisable, plusieurs instances possibles dans un même
 *            <admin-row> (ex : profil_id + lang_id dans _user).
 *
 *            Attributs :
 *              items    — JSON Array<{label:string, value:string}>.
 *                         Premier item avec value="" → placeholder (disabled selected).
 *              value    — Valeur courante à sélectionner après population.
 *              disabled — Présence seule suffit → <select> désactivé (PK+FK en édition).
 *
 *            Chargé par custom/admin-row/def.js via import — pas besoin d'un <script>
 *            séparé dans les pages EJS.
 *
 *            Importé par custom/admin-row/def.js — pas de <script> séparé.
 */

'use strict'

import { customFormHTMLElement } from '/custom/custom.js'

customFormHTMLElement.create('admin-list',
  '@import "/custom/admin-list/def.css"',
  '<select bind></select>',
  null,
  function(element) {
    const select = this.querySelector('[bind]')
    if(!select) return

    // FIX v1.0.1 #67: try-catch protège contre attribut JSON corrompu
    let items; try { items = JSON.parse(element.getAttribute('items') || '[]') } catch(e) { items = [] }
    const current = element.getAttribute('value') || ''

    items.forEach(item => {
      const opt         = document.createElement('option')
      opt.value       = item.value == null ? '' : String(item.value)
      opt.textContent = item.label || ''
      if(opt.value === '') {
        opt.disabled = true
        opt.selected = true
      }
      select.appendChild(opt)
    })

    if(current !== '') select.value = current

    if(element.hasAttribute('disabled')) select.disabled = true
  }
)

/* (WaTE) custom/admin-list/def.js v1.0.1 */
