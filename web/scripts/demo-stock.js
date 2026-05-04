/**
 * \file      (WaTE) web/scripts/demo-stock.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-30
 * \version   1.1.0
 * \brief     Tri et filtrage client-side pour /demo/stock.
 *            Attache les écouteurs via data-sort / data-filter (CSP-compatible).
 *
 * \details   v1.0.0 : création initiale.
 *            v1.1.0 : harmonisation — var→const/let, arrow functions.
 */

;(function() {
  'use strict'

  const _sortState = {}

  // ── Tri ──────────────────────────────────────────────────────────────
  function sortTable(tableId, colIdx, th) {
    const table = document.getElementById(tableId)
    if(!table) return
    const tbody = table.querySelector('tbody')
    if(!tbody) return
    const rows = Array.from(tbody.querySelectorAll('tr'))

    const key = tableId + ':' + colIdx
    const dir = _sortState[key] === 'asc' ? 'desc' : 'asc'
    _sortState[key] = dir

    // Réinitialise toutes les flèches de cette table
    table.querySelectorAll('th.sortable .sort-arrow').forEach(s => {
      s.textContent = '↕'
      s.classList.remove('asc', 'desc')
    })
    // Flèche de la colonne active
    const arrow = th.querySelector('.sort-arrow')
    if(arrow) {
      arrow.textContent = dir === 'asc' ? '▲' : '▼'
      arrow.classList.add(dir)
    }

    const isNum = th.classList.contains('num')
    rows.sort((a, b) => {
      let va = a.cells[colIdx].textContent.trim()
      let vb = b.cells[colIdx].textContent.trim()
      if(isNum) {
        va = parseFloat(va) || 0
        vb = parseFloat(vb) || 0
      }
      return (va < vb ? -1 : (va > vb ? 1 : 0)) * (dir === 'asc' ? 1 : -1)
    })
    rows.forEach(r => { tbody.appendChild(r) })
  }

  // ── Filtre ───────────────────────────────────────────────────────────
  function filterTable(tableId, term) {
    const table = document.getElementById(tableId)
    if(!table) return
    const rows = table.querySelectorAll('tbody tr')
    const t = term.toLowerCase()
    rows.forEach(r => {
      r.style.display = t ? (r.textContent.toLowerCase().indexOf(t) >= 0 ? '' : 'none') : ''
    })
  }

  // ── Attachement des écouteurs ────────────────────────────────────────
  function init() {
    // Colonnes triables
    const sortableHeaders = document.querySelectorAll('th.sortable[data-sort][data-col]')
    sortableHeaders.forEach(th => {
      th.addEventListener('click', () => {
        const tableId = th.getAttribute('data-sort')
        const colIdx  = parseInt(th.getAttribute('data-col'), 10)
        sortTable(tableId, colIdx, th)
      })
    })

    // Champs de recherche
    const filterInputs = document.querySelectorAll('input[data-filter]')
    filterInputs.forEach(input => {
      input.addEventListener('input', () => {
        const tableId = input.getAttribute('data-filter')
        filterTable(tableId, input.value)
      })
    })
  }

  // Démarrage au DOM ready
  if(document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init)
  } else {
    init()
  }

})()

/* (WaTE) web/scripts/demo-stock.js v1.1.0 */
