/**
 * \file      (WaTE) custom/schema-table/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      17/04/2026
 * \version   1.0.0
 * \brief     Custom element <schema-table> — boîte Merise d'une table SQLite.
 *
 * \details   Attributs :
 *              name  — Nom de la table.
 *              href  — URL de navigation vers le mode CRUD de la table.
 *              cols  — JSON Array<{name, pk?, fk?}> — colonnes à afficher.
 *
 *            Rendu :
 *              - Colonne PK      : icône 🔑, classe li.pk.
 *              - Colonne FK      : icône 🔗, classe li.fk, suffixe " → table".
 *              - Séparateur      : li.sep entre les colonnes PK et non-PK.
 *
 *            Extrait de admin-db.ejs v6.1.0 (v6.0.0 : code inline dans le <script>).
 *            Chargé par admin-db.ejs via import — pas de <script> séparé dans les pages.
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'

customHTMLElement.create('schema-table',
  '@import "/custom/schema-table/def.css"',
  '<a class="box" href="${href}"><div class="box-title">${name}</div><ul class="box-cols"></ul></a>',
  null,
  function(element, signal) {
    // FIX v1.0.2 #109: try-catch protège contre JSON corrompu
    let cols; try { cols = JSON.parse(element.getAttribute('cols') || '[]') } catch(e) { console.error('schema-table: invalid cols JSON', e); return }
    const ul      = this.querySelector('.box-cols')
    const hasPk   = cols.some(function(c) { return c.pk })
    let sepDone = false
    cols.forEach(function(c) {
      if(hasPk && !c.pk && !sepDone) {
        const sep = document.createElement('li')
        sep.className = 'sep'
        ul.appendChild(sep)
        sepDone = true
      }
      const li = document.createElement('li')
      if(c.pk)      li.className = 'pk'
      else if(c.fk) li.className = 'fk'
      const icon = document.createElement('span')
      icon.className   = 'icon'
      // FIX v1.0.2 #121: aria-hidden sur \u00E9mojis d\u00E9coratifs
      icon.setAttribute('aria-hidden', 'true')
      icon.textContent = c.pk ? '\uD83D\uDD11' : c.fk ? '\uD83D\uDD17' : ''
      const name = document.createElement('span')
      name.textContent = c.name
      if(c.fk) {
        const ref = document.createElement('span')
        ref.className   = 'fk-ref'
        ref.textContent = ' \u2192 ' + c.fk
        name.appendChild(ref)
      }
      li.appendChild(icon)
      li.appendChild(name)
      ul.appendChild(li)
    })
  }
)

/* (WaTE) custom/schema-table/def.js v1.0.1 */
