/**
 * \file      (WaTE) web/custom/wate-stack/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-25
 * \version   1.0.0
 * \brief     Custom elements <wate-stack> et <wate-stack-box> — schéma de couches/composants pour la doc.
 *
 * \details   <wate-stack> est un conteneur qui empile ses enfants <wate-stack-box>.
 *            Composition par enfants déclaratifs (pas de JSON) — lisible côté EJS,
 *            facile à i18n via _gi() pour chaque label/sub.
 *
 *            Attributs <wate-stack> :
 *              title       — légende affichée au-dessus (optionnel, masqué si vide).
 *              orientation — 'vertical' (défaut) | 'horizontal'.
 *
 *            Attributs <wate-stack-box> :
 *              label — texte principal (gros, gras).
 *              sub   — texte secondaire (petit, optionnel).
 *              tone  — 'navy' (défaut) | 'orange' | 'muted'.
 *
 *            Mise en page 100% CSS (flex). En horizontal, retombe en column < 720px.
 *            Aucun JS hors enregistrement — tout passe par le pipeline parse() de custom.js.
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'

customHTMLElement.create('wate-stack',
  '@import "/custom/wate-stack/def.css"',
  '<figure class="stack" data-orientation="${orientation?vertical}">'
+   '<figcaption class="stack-title">${title}</figcaption>'
+   '<div class="stack-inner"><slot></slot></div>'
+ '</figure>'
)

customHTMLElement.create('wate-stack-box',
  '@import "/custom/wate-stack/def.css"',
  '<div class="box" data-tone="${tone?navy}">'
+   '<span class="box-label">${label}</span>'
+   '<span class="box-sub">${sub}</span>'
+ '</div>'
)

/* (WaTE) web/custom/wate-stack/def.js v1.0.0 */
