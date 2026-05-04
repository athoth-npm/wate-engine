/**
 * \file      (WaTE) web/custom/wate-flow/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-25
 * \version   1.0.0
 * \brief     Custom elements <wate-flow> et <wate-flow-step> — diagramme de flux d'étapes.
 *
 * \details   <wate-flow> aligne ses enfants <wate-flow-step> en suite ordonnée
 *            avec flèches CSS entre les étapes (pas de SVG).
 *            Composition par enfants déclaratifs (cohérent avec <wate-stack>).
 *
 *            Attributs <wate-flow> :
 *              title       — légende (optionnel, masqué si vide).
 *              orientation — 'horizontal' (défaut) | 'vertical'.
 *
 *            Attributs <wate-flow-step> :
 *              label — texte principal (requis).
 *              note  — texte secondaire (optionnel).
 *
 *            Numérotation : le parent <wate-flow>, dans son hook _onConnect,
 *            écrit le numéro 1..N directement dans le shadow DOM de chaque step
 *            (les compteurs CSS ne traversent pas la frontière shadow).
 *            Le dernier step reçoit l'attribut data-last="1" qui masque sa flèche
 *            via :host([data-last]) dans le CSS.
 *            Responsive : horizontal retombe en vertical < 720px (CSS @media).
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'
import { markLastChild } from '/custom/_utils.js'

customHTMLElement.create('wate-flow',
  '@import "/custom/wate-flow/def.css"',
  '<figure class="flow" data-orientation="${orientation?horizontal}">'
+   '<figcaption class="flow-title">${title}</figcaption>'
+   '<ol class="flow-inner"><slot></slot></ol>'
+ '</figure>',
  null,
  function(element) {
    // Propage à chaque enfant step : son numéro, l'orientation du parent (le
    // shadow DOM de l'enfant ne sait pas dans quelle direction il est), et un
    // marqueur data-last sur le dernier pour masquer sa flèche.
    const orientation = element.getAttribute('orientation') || 'horizontal'
    const steps = element.querySelectorAll(':scope > wate-flow-step')
    steps.forEach((s, i) => {
      const numEl = s.shadowRoot && s.shadowRoot.querySelector('.step-num')
      if(numEl) numEl.textContent = String(i + 1)
      s.setAttribute('data-orientation', orientation)
    })
    markLastChild(element, 'wate-flow-step')
  }
)

customHTMLElement.create('wate-flow-step',
  '@import "/custom/wate-flow/def.css"',
  '<div class="step">'
+   '<span class="step-num"></span>'
+   '<span class="step-body">'
+     '<span class="step-label">${label}</span>'
+     '<span class="step-note">${note}</span>'
+   '</span>'
+ '</div>'
)

/* (WaTE) web/custom/wate-flow/def.js v1.0.0 */
