/**
 * \file      (WaTE) scripts/admin-stats.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      16/04/2026
 * \version   2.2.3
 * \brief     Script client — peuplement des données stats LRU (admin-stats.ejs).
 *
 * \details   Chargé via elements.scripts (type=module, différé).
 *            Fetch GET /admin/api/stats → peuple <tbody id="stats-body">.
 *            Toute la structure HTML (thead, note, bouton, états) est rendue
 *            par admin-stats.ejs — ce module ne construit aucun HTML statique.
 *            Show/hide via l'attribut hidden sur les éléments pré-rendus.
 *
 *            v2.0.0 : rôle limité à l'échange client/serveur + peuplement tbody.
 *                     Suppression de toute construction HTML statique côté JS.
 *            v2.1.0 : bouton Rafraîchir rappelle loadStats() — pas de location.reload().
 *            v2.2.0 : barres ratio miss, direction right-to-left, esc() XSS.
 *            v2.2.1 : FIX esc() ajout échappement single quote ' → &#39;.
 */

'use strict'

// FIX v2.2.3: regex statiques module-level
const _RE_AMP=/&/g,_RE_LT=/</g,_RE_GT=/>/g,_RE_DQ=/"/g,_RE_SQ=/'/g
function esc(s) { return String(s||'').replace(_RE_AMP,'&amp;').replace(_RE_LT,'&lt;').replace(_RE_GT,'&gt;').replace(_RE_DQ,'&quot;').replace(_RE_SQ,'&#39;') }

/**
 * \brief  Peuple le tableau des stats (cache LRU) et affiche les blocs masqués.
 * \param  data  Objet { caches: { name: { hits, misses, evictions, size, max } } }.
 */
function renderStats(data) {
  const caches = data.caches || {}
  const names  = Object.keys(caches)

  let el
  if(el = document.getElementById('stats-loading')) el.hidden = true
  if(el = document.getElementById('stats-error'))   el.hidden = true
  if(el = document.getElementById('stats-empty'))   el.hidden = true
  if(el = document.getElementById('stats-table'))   el.hidden = true
  if(el = document.getElementById('stats-note'))    el.hidden = true

  if (names.length === 0) {
    if(el = document.getElementById('stats-empty')) el.hidden = false
    return
  }

  if(el = document.getElementById('stats-body')) el.innerHTML = names.map(function(name) {
    const c     = caches[name]
    const hits  = Number(c.hits)   || 0
    const misses= Number(c.misses) || 0
    const total = hits + misses
    const ratio  = total > 0 ? Math.round(hits / total * 100) : 0
    const missesDominate = misses > hits
    // La barre montre le ratio majoritaire : depuis la droite si misses > hits, depuis la gauche sinon
    const barPct   = missesDominate ? Math.round(misses / total * 100) : ratio
    const barColor = ratio >= 80 ? '#4caf50' : ratio >= 50 ? '#f0a500' : '#e05050'
    const barStyle = 'width:' + barPct + '%;background:' + barColor + (missesDominate ? ';margin-left:auto' : '')
    return '<tr>' +
      '<td class="cache-name">' + esc(name) + '</td>' +
      '<td class="num">'        + hits        + '</td>' +
      '<td class="num">'        + misses      + '</td>' +
      '<td class="ratio-cell">' +
        '<div class="ratio-bar">' +
          '<div class="ratio-fill" style="' + barStyle + '"></div>' +
        '</div>' +
        '<span class="ratio-pct">' + ratio + '%</span>' +
      '</td>' +
      '<td class="num">' + Number(c.evictions || 0) + '</td>' +
      '<td class="num">' + Number(c.size || 0) + ' / ' + Number(c.max || 0) + '</td>' +
    '</tr>'
  }).join('')

  const statsTable = document.getElementById('stats-table')
  const statsNote  = document.getElementById('stats-note')
  const btnRefresh = document.getElementById('btn-refresh')
  if(statsTable) statsTable.hidden = false
  if(statsNote)  statsNote.hidden  = false
  if(btnRefresh) btnRefresh.hidden = false
}

/**
 * \brief  Charge les stats via GET /admin/api/stats, appelle renderStats en cas de succès.
 */
// FIX v2.2.3 #102: AbortController annule la requête précédente
let _statsCtrl = null
function loadStats() {
  if(_statsCtrl) _statsCtrl.abort()
  _statsCtrl = new AbortController()
  fetch('/admin/api/stats', { signal: _statsCtrl.signal })
    .then(function(r) {
      if (!r.ok) throw new Error('HTTP ' + r.status)
      return r.json()
    })
    .then(renderStats)
    .catch(function(err) {
      // FIX v2.2.3 #144: AbortError = annulation normale (pas d'erreur visible)
      if(err && err.name === 'AbortError') return
      const loading = document.getElementById('stats-loading')
      const errMsg  = document.getElementById('stats-error-msg')
      const errEl   = document.getElementById('stats-error')
      if(loading) loading.hidden = true
      if(errMsg)  errMsg.textContent  = err.message
      if(errEl)   errEl.hidden = false
    })
}

const btnRefresh = document.getElementById('btn-refresh')
if(btnRefresh) btnRefresh.addEventListener('click', loadStats)
loadStats()

/* (WaTE) scripts/admin-stats.js v2.2.3 */