/**
 * \file      (WaTE) web/custom/wate-tree/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-25
 * \version   1.0.0
 * \brief     Custom element <wate-tree> — arbre de fichiers/dossiers pour la doc.
 *
 * \details   Composition par JSON dans l'attribut data (les structures imbriquées
 *            seraient illisibles avec des enfants déclaratifs).
 *
 *            Attributs :
 *              title — légende (optionnel, masqué si vide).
 *              data  — JSON Array<Node> obligatoire ; Node :
 *                {
 *                  name:     string,           // nom affiché
 *                  type:     'dir' | 'file',   // détermine l'icône 📁/📄
 *                  note:     string?,          // texte gris à droite (optionnel)
 *                  children: Node[]?           // sous-arbre (uniquement pour 'dir')
 *                }
 *
 *            Rendu : <ul> imbriqués dans le shadow DOM, indentation CSS pure,
 *            police monospace pour lisibilité d'arbo. Pas de fold/expand —
 *            l'arbre est statique (cas d'usage doc, pas explorateur de fichiers).
 *
 *            Données invalides : on log une erreur console et on rend un message
 *            visible dans le shadow DOM (dégradation gracieuse, pas de crash).
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'

/**
 * \fn _renderNodes
 * \brief Construit récursivement le HTML d'un sous-arbre.
 * \param nodes  Array<Node> à rendre.
 * \return       Chaîne HTML <ul>...</ul> (vide si nodes vide).
 */
function _renderNodes(nodes) {
  if(!nodes || !nodes.length) return ''
  let html = '<ul class="tree-list">'
  for(let i = 0; i < nodes.length; i++) {
    const n        = nodes[i]
    const isDir    = n.type === 'dir'
    const name     = _escape(n.name || '')
    const note     = n.note ? '<span class="node-note">' + _escape(n.note) + '</span>' : ''
    const children = isDir && n.children ? _renderNodes(n.children) : ''
    html += '<li class="node" data-type="' + (isDir ? 'dir' : 'file') + '">'
         +    '<span class="node-row">'
         +      '<span class="node-icon" aria-hidden="true">' + (isDir ? '📁' : '📄') + '</span>'
         +      '<span class="node-name">' + name + '</span>'
         +      note
         +    '</span>'
         +    children
         + '</li>'
  }
  return html + '</ul>'
}

/**
 * \fn _escape
 * \brief Échappement HTML minimal (le pipeline parse() de custom.js ne nous
 *        protège pas ici car on construit le HTML hors template ${}).
 */
function _escape(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

customHTMLElement.create('wate-tree',
  '@import "/custom/wate-tree/def.css"',
  '<figure class="tree">'
+   '<figcaption class="tree-title">${title}</figcaption>'
+   '<div class="tree-body"></div>'
+ '</figure>',
  null,
  function(element) {
    const body = this.querySelector('.tree-body')
    if(!body) return
    const raw = element.getAttribute('data')
    if(!raw) {
      body.innerHTML = '<p class="tree-error">Attribut <code>data</code> manquant.</p>'
      return
    }
    let nodes
    try { nodes = JSON.parse(raw) }
    catch(e) {
      console.error('<wate-tree> JSON invalide :', e.message)
      body.innerHTML = '<p class="tree-error">JSON invalide dans <code>data</code>.</p>'
      return
    }
    if(!Array.isArray(nodes)) {
      body.innerHTML = '<p class="tree-error">L\'attribut <code>data</code> doit être un Array.</p>'
      return
    }
    body.innerHTML = _renderNodes(nodes)
  }
)

/* (WaTE) web/custom/wate-tree/def.js v1.0.0 */
