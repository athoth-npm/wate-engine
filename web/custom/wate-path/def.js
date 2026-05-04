/**
 * \file      (WaTE) web/custom/wate-path/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-26
 * \version   1.0.0
 * \brief     Custom elements <wate-path> et <wate-path-step> — pipeline d'une requête WaTE.
 *
 * \details   Représente le chemin d'une requête à travers le moteur, étape par étape.
 *            Chaque étape est soit "active" (sollicitée par l'exemple courant), soit
 *            "pass-through" (présente dans le pipeline mais inutilisée par cet exemple).
 *
 *            Composition par enfants déclaratifs :
 *
 *              <wate-path>
 *                <wate-path-step label="Express"        active></wate-path-step>
 *                <wate-path-step label="Route app"></wate-path-step>
 *                <wate-path-step label="_page → _item"  active note="list_id=302"></wate-path-step>
 *                <wate-path-step label="queries"        active note="products"></wate-path-step>
 *                <wate-path-step label="hook"></wate-path-step>
 *                <wate-path-step label="_glossary + EJS" active></wate-path-step>
 *              </wate-path>
 *
 *            Attributs <wate-path> :
 *              title — légende au-dessus (optionnel, masqué si vide).
 *
 *            Attributs <wate-path-step> :
 *              label  — texte principal (requis).
 *              note   — annotation sous le label (optionnel).
 *              active — présence = étape sollicitée (orange, plein).
 *                       absent  = étape pass-through (gris, contour seul).
 *
 *            Layout : étapes alignées horizontalement avec flèches → entre elles ;
 *            sous 720px, retombe en colonne verticale avec flèches ↓.
 *            Aucun JS de runtime — tout passe par le pipeline parse() de custom.js.
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'
import { markLastChild } from '/custom/_utils.js'

customHTMLElement.create('wate-path',
  '@import "/custom/wate-path/def.css"',
  '<figure class="path">'
+   '<figcaption class="path-title">${title}</figcaption>'
+   '<div class="path-inner"><slot></slot></div>'
+ '</figure>',
  null,
  function(element) {
    markLastChild(element, 'wate-path-step')
  }
)

customHTMLElement.create('wate-path-step',
  '@import "/custom/wate-path/def.css"',
  '<div class="step">'
+   '<span class="step-label">${label}</span>'
+   '<span class="step-note">${note}</span>'
+ '</div>',
  null,
  function(element) {
    // Pose data-active sur le shadow root host pour piloter le style via :host([data-active])
    if(element.hasAttribute('active')) element.setAttribute('data-active', '1')
    else                               element.removeAttribute('data-active')
  }
)

/* (WaTE) web/custom/wate-path/def.js v1.0.0 */
