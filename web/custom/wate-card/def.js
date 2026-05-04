/**
 * \file      (WaTE) web/custom/wate-card/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-24
 * \version   1.0.0
 * \brief     Custom element <wate-card> — carte "feature" du site vitrine.
 *
 * \details   Attributs :
 *              icon  — identifiant de l'icône SVG inline (db | light | shield).
 *              title — titre de la carte.
 *              body  — texte descriptif.
 *
 *            Les icônes sont des SVG inline (pas de dépendance réseau).
 *            La carte utilise le shadow DOM via customHTMLElement.create —
 *            même pipeline que <schema-table>.
 *
 *            Reste portable et léger : pas de JS supplémentaire dans onConnect,
 *            tout est en CSS + templates ${attr}.
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'

const ICONS = {
  db:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v6c0 1.66 4 3 9 3s9-1.34 9-3V5"/><path d="M3 11v6c0 1.66 4 3 9 3s9-1.34 9-3v-6"/></svg>',
  light:  '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18h6"/><path d="M10 22h4"/><path d="M12 2a7 7 0 0 0-4 12.7c.6.6 1 1.4 1 2.3v1h6v-1c0-.9.4-1.7 1-2.3A7 7 0 0 0 12 2z"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 2l8 4v6c0 5-3.5 9.5-8 10-4.5-.5-8-5-8-10V6l8-4z"/><path d="M9 12l2 2 4-4"/></svg>',
  ai:     '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15 9 22 9 16 14 18 21 12 17 6 21 8 14 2 9 9 9"/></svg>'
}

customHTMLElement.create('wate-card',
  '@import "/custom/wate-card/def.css"',
  '<article class="card">'
+   '<div class="card-icon" data-icon="${icon?db}" aria-hidden="true"></div>'
+   '<h3 class="card-title">${title}</h3>'
+   '<p class="card-body">${body}</p>'
+ '</article>',
  null,
  function(element) {
    // Injection du SVG choisi — on passe par JS car les templates parse()
    // échappent le contenu et ne gèrent pas les lookups dans une table.
    const icon = element.getAttribute('icon') || 'db'
    const box  = this.querySelector('.card-icon')
    if(box) box.innerHTML = ICONS[icon] || ICONS.db
  }
)

/* (WaTE) web/custom/wate-card/def.js v1.0.0 */
