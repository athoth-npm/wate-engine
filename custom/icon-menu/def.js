/**
 * \file      (WaTE: icon-menu) def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/09/2025
 * \version   2.0.4
 * \brief     Fusionné Figur'In + Chéri's Aparts.
 *
 * \details   Format item : "icon,label,href" ou "icon,label,@expr"
 *            Les items préfixés "@" exécutent une expression sans eval() via executeAction().
 *            Un item à 2 éléments insère un séparateur <hr>.
 *            window.innerWidth remplace window.screen.width.
 *
 *            V2.0.1 : - forEach() au lieu de map() pour itérer sur les items du menu.
 *                     - shadowRoot.querySelector('a') au lieu de shadowRoot.lastElementChild.firstElementChild
 *            V2.0.2 : - querySelector('a') extrait avant le forEach — évite N appels DOM
 *                       redondants sur le même élément à chaque itération.
 *            V2.0.3 : - itemElements.length == 3 → === (cohérence strict mode).
 *            V2.0.4 : - FIX innerHTML → textContent — anti-XSS sur
 *                       le label du menu (itemElements[1]).
 */

import { customHTMLElement } from '/custom/custom.js'

/**
 * \fn executeAction
 * \brief Exécute une expression "obj.method('arg')" sans eval().
 *        Résout la chaîne de propriétés sur window et appelle la méthode trouvée.
 *
 * \param expr  Chaîne de la forme "a.b.c.method('arg')" ou "a.b.c.method()"
 *
 * \details Formes reconnues :
 *   - "obj.method('arg')" — appel avec un argument string entre guillemets simples
 *   - 'obj.method("arg")' — appel avec un argument string entre guillemets doubles
 *   - "obj.method()"      — appel sans argument
 *   Toute autre forme génère un avertissement console et est ignorée.
 */
// FIX v2.0.6: regex statiques module-level
const _allowedActions = ['wate.signout']
const _RE_ACTION_DQ = /^([\w.]+)\.([\w]+)\("([^"]*)"\)$/
const _RE_ACTION_SQ = /^([\w.]+)\.([\w]+)\('([^']*)'\)$/
const _RE_ACTION_NO = /^([\w.]+)\.([\w]+)\(\)$/

function executeAction(expr) {
  const match = expr.match(_RE_ACTION_DQ) ||
              expr.match(_RE_ACTION_SQ) ||
              expr.match(_RE_ACTION_NO)
  if(!match) { console.warn('icon-menu: unsupported action expression:', expr); return }
  const path = match[1] + '.' + match[2]
  if(_allowedActions.indexOf(path) < 0) { console.warn('icon-menu: action not allowed:', expr); return }
  const obj = match[1].split('.').reduce((o, k) => o && o[k], window)
  if(!obj || typeof obj[match[2]] !== 'function') { console.warn('icon-menu: action not found:', expr); return }
  obj[match[2]](match[3] || undefined)
}

/**
 * \brief Définition du custom element <icon-menu>.
 *        Affiche une icône cliquable qui déroule un menu de navigation.
 *        Les items sont passés via l'attribut "items" (séparateur '|').
 *        L'attribut "href" définit la page courante (item courant désactivé).
 *        L'attribut "icon" définit l'image de l'icône principale.
 *        Le menu s'ouvre à droite ou à gauche selon la position horizontale de l'élément.
 *
 * \details Structure HTML générée dans le shadow DOM :
 *   <div class="iconMenu">
 *     <a href="${href}"><img src="${icon}" /></a>   ← icône principale (pointer-events:none après init)
 *     <div>                                         ← conteneur des items (ajouté par le script)
 *       <a>...</a> | <hr>                           ← items ou séparateurs
 *     </div>
 *   </div>
 */
customHTMLElement.create('icon-menu',
  '@import "/custom/icon-menu/def.css"',
  '<div class="iconMenu">\
    <a href="${href}"><img src="${icon}" alt="" /></a>\
  </div>',
  null,
  function(element, signal) {
    const shadowRoot = this
    const items   = element.getAttribute('items')
    const onRight = (element.getBoundingClientRect().x > window.innerWidth / 2)

    if(items) {
      const div = document.createElement('div')

      // FIX v2.0.2 : querySelector extrait avant le forEach — même référence,
      // N appels DOM redondants évités (un par item de menu).
      const iconAnchor = shadowRoot.querySelector('a')
      // FIX v2.0.6 #119: aria-expanded/haspopup pour lecteurs d'écran
      iconAnchor.setAttribute('aria-expanded', 'false')
      iconAnchor.setAttribute('aria-haspopup', 'true')
      iconAnchor.style = 'pointer-events:none'

      // FIX v2.0.6 #95: Escape ferme le dropdown
      shadowRoot.addEventListener('keydown', function(e) { if(e.key === 'Escape') { div.remove(); shadowRoot.querySelector('a').style = '' } }, {signal})

      // FIX v2.0.1 : forEach() au lieu de map()
      items.split('|').forEach(item => {
        const itemElements = item.split(',').map(s => {
          try { return decodeURIComponent(s) } catch(e) { return s }
        })
        if(itemElements.length === 3) {
          const a = document.createElement('a')
          if(itemElements[2].substring(0, 1) === '@') {
            // Action JavaScript — pas de href, exécution via executeAction()
            const expr = itemElements[2].substring(1)
            a.href = '#'
            a.setAttribute('role', 'button')
            a.addEventListener('click', e => { e.preventDefault(); executeAction(expr) }, { signal })
          } else {
            // Lien href standard — désactivé visuellement si c'est la page courante
            a.href = itemElements[2]
            if(a.href === iconAnchor.href) {
              a.style = 'pointer-events:none;opacity:0.5'
            }
          }
          // FIX v2.0.4 : textContent au lieu de innerHTML — anti-XSS
          const span = document.createElement('span')
          span.textContent = itemElements[1]
          a.appendChild(span)
          const img = document.createElement('img')
          img.src = itemElements[0]
          img.alt = itemElements[1]
          a.prepend(img)
          div.appendChild(a)
        } else {
          // Item à 2 éléments → séparateur visuel
          div.appendChild(document.createElement('hr'))
        }
      })

      if(onRight) div.style = 'left:auto;right:0'
      shadowRoot.lastElementChild.appendChild(div)
    }
    // FIX v2.0.5: px → rem (responsive)
    element.style = onRight ? 'margin-left:1.25rem' : 'margin-right:1.25rem'
  }
)

/* (WaTE: icon-menu) def.js v2.0.6 */