/**
 * \file      (WaTE) web/custom/wate-mcd/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-25
 * \version   2.3.0
 * \brief     Custom elements <wate-mcd>, <wate-table> et <wate-link> — schéma Merise pour la doc.
 *
 * \details   Approche v2 — vrai MCD avec traits SVG ancrés sur les bords des boîtes,
 *            pastilles de cardinalité aux deux extrémités, redessin automatique sur resize.
 *
 *            v2.1.0 — placement déclaratif row/col sur <wate-table> (propagés en
 *                     grid-row / grid-column), grille à largeur fixe (~220px).
 *            v2.3.0 — épuration : suppression du routage Manhattan avec évitement
 *                     d'obstacles, suppression de l'attribut `route`. Tracé en
 *                     L simple ou ligne droite. Ancrage explicite des liens via
 *                     sideFrom/sideTo — l'auteur contrôle par où sortent les traits.
 *
 *            <wate-mcd> est un conteneur qui empile :
 *              - une grille CSS auto-fit de <wate-table> (slot par défaut),
 *              - un calque <svg> absolu superposé qui dessine les liens.
 *
 *            Composition par enfants déclaratifs :
 *
 *              <wate-mcd title="Pilotage du contenu">
 *                <wate-table name="_page" cols='[
 *                  {"name":"url","pk":1},
 *                  {"name":"profil_id","fk":"_profil"},
 *                  {"name":"list_id","fk":"_list"}
 *                ]'></wate-table>
 *                ...
 *                <wate-link from="_page" to="_profil" cardFrom="0,n" cardTo="1,1"></wate-link>
 *                ...
 *              </wate-mcd>
 *
 *            Attributs <wate-mcd> :
 *              title — légende au-dessus de la grille (optionnel).
 *
 *            Attributs <wate-table> :
 *              name — nom de la table (sert d'ancre pour les liens).
 *              cols — JSON Array<{name, pk?, fk?}> — colonnes et leur rôle.
 *
 *            Attributs <wate-link> :
 *              from     — nom de la table source (doit correspondre à un <wate-table name=…>).
 *              to       — nom de la table cible.
 *              cardFrom — cardinalité côté source (ex: "0,n", "1,1").
 *              cardTo   — cardinalité côté cible.
 *              label    — verbe optionnel placé au milieu du trait (ex: "héberge").
 *              sideFrom — optionnel : "left" | "right" | "top" | "bottom" — force
 *                         le bord d'ancrage côté source (sinon choisi automatiquement).
 *              sideTo   — optionnel : idem côté cible.
 *
 *            Calcul des ancres : pour chaque lien (from→to), JS calcule le centre
 *            de chaque boîte, projette sur le bord (haut/bas/gauche/droite) le plus
 *            proche du centre de l'autre boîte, et tire un trait droit. Si les deux
 *            sont alignés horizontalement → ancrage gauche/droite ; verticalement →
 *            haut/bas. Sinon, le bord choisi est celui qui maximise le côté de
 *            la projection.
 *
 *            Redessin : le composant observe son propre redimensionnement via
 *            ResizeObserver et redessine au resize de la fenêtre + au scroll
 *            (les sticky du layout peuvent bouger les positions relatives).
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'

const SVG_NS = 'http://www.w3.org/2000/svg'

function svgEl(tag, attrs) {
  const el = document.createElementNS(SVG_NS, tag)
  if (attrs) for (var k in attrs) el.setAttribute(k, attrs[k])
  return el
}

/**
 * \brief Calcule le point d'ancrage du segment AB sur le bord d'un rectangle.
 *
 * Pour le bord choisi (celui qui « regarde » l'autre boîte), retourne un point
 * sur ce bord plus l'orientation du bord. Le bord est choisi en testant les
 * 4 candidats (haut, bas, gauche, droite) et en prenant celui dont le centre
 * est le plus proche du centre de l'autre rectangle.
 *
 * \param rect    Rectangle de la boîte (x, y, width, height) dans l'espace SVG.
 * \param target  Rectangle cible — sert à choisir le bord.
 * \return        { x, y, side } où side ∈ {'top','bottom','left','right'}.
 */
function _anchorPoint(rect, target) {
  const cx = rect.x + rect.width  / 2
  const cy = rect.y + rect.height / 2
  const tx = target.x + target.width  / 2
  const ty = target.y + target.height / 2

  const dx = tx - cx
  const dy = ty - cy

  // Le bord choisi est celui qui regarde la boîte cible :
  //   |dx|/w > |dy|/h  → ancrage horizontal (gauche/droite)
  //   sinon            → ancrage vertical (haut/bas)
  const ratioX = Math.abs(dx) / (rect.width  / 2 || 1)
  const ratioY = Math.abs(dy) / (rect.height / 2 || 1)

  if(ratioX > ratioY) {
    if(dx > 0) return { x: rect.x + rect.width, y: cy, side: 'right'  }
    else       return { x: rect.x,              y: cy, side: 'left'   }
  } else {
    if(dy > 0) return { x: cx, y: rect.y + rect.height, side: 'bottom' }
    else       return { x: cx, y: rect.y,               side: 'top'    }
  }
}

/**
 * \brief Retourne le point central d'un bord donné — ancrage explicite.
 */
function _anchorOnSide(rect, side) {
  const cx = rect.x + rect.width  / 2
  const cy = rect.y + rect.height / 2
  if(side === 'left')   return { x: rect.x,                y: cy, side: 'left'   }
  if(side === 'right')  return { x: rect.x + rect.width,   y: cy, side: 'right'  }
  if(side === 'top')    return { x: cx, y: rect.y,                 side: 'top'    }
  /* bottom */          return { x: cx, y: rect.y + rect.height,   side: 'bottom' }
}

function _pathFromPoints(points) {
  let d = 'M' + points[0].x + ',' + points[0].y
  for(let i = 1; i < points.length; i++) d += ' L' + points[i].x + ',' + points[i].y
  return d
}

/**
 * \brief Génère un chemin orthogonal en L entre deux ancres.
 *        L'ancre source détermine l'axe de départ : horizontal (left/right)
 *        ou vertical (top/bottom). Si les ancres sont parfaitement alignées,
 *        on rend une ligne droite.
 */
function _routePath(a, b) {
  const lAxisHoriz = (a.side === 'left' || a.side === 'right')

  // Ligne droite quand parfaitement alignées
  if(lAxisHoriz && Math.abs(a.y - b.y) < 1) {
    return _pathFromPoints([{x:a.x,y:a.y},{x:b.x,y:b.y}])
  }
  if(!lAxisHoriz && Math.abs(a.x - b.x) < 1) {
    return _pathFromPoints([{x:a.x,y:a.y},{x:b.x,y:b.y}])
  }

  // Coude en L — on part dans l'axe de l'ancre source.
  if(lAxisHoriz) {
    return _pathFromPoints([{x:a.x,y:a.y},{x:b.x,y:a.y},{x:b.x,y:b.y}])
  }
  return _pathFromPoints([{x:a.x,y:a.y},{x:a.x,y:b.y},{x:b.x,y:b.y}])
}

/**
 * \brief Crée une pastille de cardinalité (cercle + texte) sur un point d'ancre.
 *        Décalée de quelques pixels vers l'intérieur (côté trait) pour ne pas
 *        chevaucher la bordure de la boîte.
 */
function _cardBadge(anchor, text) {
  let dx = 0, dy = 0
  if(anchor.side === 'right')  dx =  14
  if(anchor.side === 'left')   dx = -14
  if(anchor.side === 'bottom') dy =  14
  if(anchor.side === 'top')    dy = -14

  const g = svgEl('g', {
    class: 'mcd-card',
    transform: 'translate(' + (anchor.x + dx) + ',' + (anchor.y + dy) + ')'
  })
  const rect = svgEl('rect', {
    class: 'mcd-card-bg', x: -16, y: -9, width: 32, height: 18, rx: 9
  })
  const t = svgEl('text', {
    class: 'mcd-card-text', 'text-anchor': 'middle', 'dominant-baseline': 'central'
  })
  t.textContent = text
  g.appendChild(rect)
  g.appendChild(t)
  return g
}

customHTMLElement.create('wate-mcd',
  '@import "/custom/wate-mcd/def.css"',
  '<figure class="mcd">'
+   '<figcaption class="mcd-title">${title}</figcaption>'
+   '<div class="mcd-stage">'
+     '<div class="mcd-grid"><slot></slot></div>'
+     '<svg class="mcd-svg" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"></svg>'
+   '</div>'
+ '</figure>',
  null,
  function(element, signal) {
    const shadowRoot = this
    const stage      = shadowRoot.querySelector('.mcd-stage')
    const svg        = shadowRoot.querySelector('.mcd-svg')

    /**
     * \brief Redessine tous les liens — appelé au connect, sur resize, sur scroll.
     *        Coût : O(N liens) ; getBoundingClientRect() est rapide.
     */
    function redraw() {
      // Reset SVG
      while(svg.firstChild) svg.removeChild(svg.firstChild)

      const stageRect = stage.getBoundingClientRect()
      svg.setAttribute('viewBox', '0 0 ' + stageRect.width + ' ' + stageRect.height)
      svg.setAttribute('width',   stageRect.width)
      svg.setAttribute('height',  stageRect.height)

      // Index des rects de chaque table par nom (espace stage)
      const tableRects = {}
      element.querySelectorAll(':scope > wate-table').forEach(t => {
        const n = t.getAttribute('name')
        if(!n) return
        const r = t.getBoundingClientRect()
        tableRects[n] = {
          x: r.left - stageRect.left,
          y: r.top  - stageRect.top,
          width: r.width, height: r.height
        }
      })

      // Pour chaque <wate-link>, calcule les ancres et trace
      const links = element.querySelectorAll(':scope > wate-link')
      links.forEach(link => {
        const fromName = link.getAttribute('from')
        const toName   = link.getAttribute('to')
        const rA       = tableRects[fromName]
        const rB       = tableRects[toName]
        if(!rA || !rB) return

        // Ancres : automatiques par défaut, ou explicites via sideFrom/sideTo.
        const sideFrom = link.getAttribute('sideFrom') || link.getAttribute('sidefrom')
        const sideTo   = link.getAttribute('sideTo')   || link.getAttribute('sideto')
        const anchorA = sideFrom ? _anchorOnSide(rA, sideFrom) : _anchorPoint(rA, rB)
        const anchorB = sideTo   ? _anchorOnSide(rB, sideTo)   : _anchorPoint(rB, rA)

        const path = svgEl('path', { class: 'mcd-line', d: _routePath(anchorA, anchorB) })
        svg.appendChild(path)

        // Pastilles de cardinalité
        const cardFrom = link.getAttribute('cardFrom') || link.getAttribute('cardfrom')
        const cardTo   = link.getAttribute('cardTo')   || link.getAttribute('cardto')
        if(cardFrom) svg.appendChild(_cardBadge(anchorA, cardFrom))
        if(cardTo)   svg.appendChild(_cardBadge(anchorB, cardTo))

        // Étiquette optionnelle au milieu du segment
        const label = link.getAttribute('label')
        if(label) {
          const midX = (anchorA.x + anchorB.x) / 2
          const midY = (anchorA.y + anchorB.y) / 2
          const t = svgEl('text', {
            class: 'mcd-label', x: midX, y: midY - 6, 'text-anchor': 'middle'
          })
          t.textContent = label
          svg.appendChild(t)
        }
      })
    }

    // Premier rendu : un microtask pour laisser le parser finir les enfants,
    // puis un rAF pour laisser la grille CSS calculer ses positions.
    queueMicrotask(() => {
      requestAnimationFrame(redraw)
    })

    // Redessin sur resize de l'élément lui-même (couvre les changements de
    // grille auto-fit quand le viewport change ou quand le sticky bouge).
    if(typeof ResizeObserver !== 'undefined') {
      const ro = new ResizeObserver(() => { redraw() })
      ro.observe(stage)
      // Détacher quand l'élément est retiré du DOM
      signal.addEventListener('abort', () => { ro.disconnect() })
    }

    // Redessin sur resize fenêtre (filet de sécurité) et sur load des polices
    window.addEventListener('resize', redraw, { signal })
    if(document.fonts && document.fonts.ready) {
      document.fonts.ready.then(() => { redraw() }).catch(() => {})
    }
  }
)

customHTMLElement.create('wate-table',
  '@import "/custom/wate-mcd/def.css"',
  '<div class="tbl">'
+   '<div class="tbl-title">${name}</div>'
+   '<ul class="tbl-cols"></ul>'
+ '</div>',
  null,
  function(element) {
    // Position déclarative : row/col → grid-row / grid-column sur le light DOM
    // (les attributs sont lus par le parent via la grille CSS, donc on les
    //  applique en inline-style côté custom element pour qu'ils soient
    //  honorés par .mcd-grid).
    const row = element.getAttribute('row')
    const col = element.getAttribute('col')
    if(row) element.style.gridRow    = row
    if(col) element.style.gridColumn = col

    let cols = []
    try { cols = JSON.parse(element.getAttribute('cols') || '[]') }
    catch(e) { console.error('wate-table: invalid cols JSON for', element.getAttribute('name'), e); return }

    const ul      = this.querySelector('.tbl-cols')
    const hasPk   = cols.some(c => c.pk)
    let sepDone = false

    cols.forEach(c => {
      if(hasPk && !c.pk && !sepDone) {
        const sep = document.createElement('li')
        sep.className = 'tbl-sep'
        ul.appendChild(sep)
        sepDone = true
      }
      const li = document.createElement('li')
      if(c.pk)      li.className = 'tbl-pk'
      else if(c.fk) li.className = 'tbl-fk'

      const icon = document.createElement('span')
      icon.className = 'tbl-icon'
      icon.textContent = c.pk ? '🔑' : c.fk ? '🔗' : ''

      const nameEl = document.createElement('span')
      nameEl.className = 'tbl-name'
      nameEl.textContent = c.name

      li.appendChild(icon)
      li.appendChild(nameEl)

      if(c.fk) {
        const ref = document.createElement('span')
        ref.className = 'tbl-fk-ref'
        ref.textContent = '→ ' + c.fk
        li.appendChild(ref)
      }

      ul.appendChild(li)
    })
  }
)

// <wate-link> : descripteur pur — collecté par <wate-mcd>, pas de rendu propre.
customHTMLElement.create('wate-link',
  '@import "/custom/wate-mcd/def.css"',
  ''
)

/* (WaTE) web/custom/wate-mcd/def.js v2.3.0 */
