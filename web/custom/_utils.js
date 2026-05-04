/**
 * \file      (WaTE) web/custom/_utils.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-29
 * \version   1.0.0
 * \brief     Utilitaires partagés entre les custom elements.
 */

'use strict'

/**
 * \brief Marque le dernier enfant d'un conteneur avec data-last="1".
 *        Utilisé par wate-flow et wate-path pour masquer la flèche après
 *        la dernière étape via :host([data-last])::after { display:none }.
 */
export function markLastChild(container, childSelector) {
  const children = container.querySelectorAll(':scope > ' + childSelector)
  children.forEach((el, i) => {
    if (i === children.length - 1) el.setAttribute('data-last', '1')
    else el.removeAttribute('data-last')
  })
}

/* (WaTE) web/custom/_utils.js v1.0.0 */
