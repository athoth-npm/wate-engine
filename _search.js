/**
 * \file      (WaTE) _search.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/09/2025
 * \version   1.2.1
 * \brief     Module optionnel --mod search — recherche FTS5.
 *
 * \details   v1.0.0 : création initiale.
 *            v1.1.0 : FIX scope/minList priorité + FTS5 - filtré.
 *            v1.2.0 : harmonisation — arrow functions, var→const/let,
 *                     Doxygen, logs RUN ENTER/LEAVE.
 */
'use strict'
const _core = require('./_core'), _utils = require('./_utils')
const _RE_FTS = /['"*()^~\[\]{}:&|!<>-]/g
const _RE_WS  = /\s+/

/**
 * \brief  Exécute une recherche FTS5 et retourne les résultats avec URLs.
 * \param  req     Requête Express.
 * \param  res     Réponse Express.
 * \param  minList list_id minimum (0 = admin, 200 = public).
 */
function _doSearch(req, res, minList) {
  _core.log.print(_core.log.RUN, 'ENTER _doSearch()')
  const q = (req.query.q || '').trim()
  if(!q) { _core.log.print(_core.log.RUN, 'LEAVE _doSearch() (empty q)'); return res.json({ results: [] }) }
  const lang = _utils.adminLang(req)
  const scope = req.query.scope || ''
  const term = q.replace(_RE_FTS, ' ').trim()
  if(!term) { _core.log.print(_core.log.RUN, 'LEAVE _doSearch() (empty term)'); return res.json({ results: [] }) }
  const ftsQuery = term.split(_RE_WS).map(w => '"' + w + '"*').join(' ')

  let scopeSQL = ''
  if(minList > 0) scopeSQL = ' AND (list_id IS NULL OR list_id >= ' + minList + ')'
  else if(scope === 'demo') scopeSQL = ' AND (list_id IS NULL OR list_id >= 400)'
  else if(scope === 'site') scopeSQL = ' AND (list_id IS NULL OR (list_id >= 200 AND list_id < 300))'
  else scopeSQL = ' AND (list_id IS NULL OR list_id >= 200)' // defaut : contenu public uniquement

  _core.dbRequest('all', 'SELECT source, list_id, lang_id, tag, label, rank, snippet(_fts, 0, \'<mark>\', \'</mark>\', \'…\', 40) AS snippet FROM _fts WHERE _fts MATCH ? AND (lang_id = ? OR lang_id = \'\' OR lang_id IS NULL)' + scopeSQL + ' ORDER BY rank LIMIT 20', [ftsQuery, lang], (err, rows) => {
    if(err) { _core.log.print(_core.log.WARNING, '[search] FTS error: ' + err.message); return res.json({ results: [] }) }
    if(!rows || !rows.length) { _core.log.print(_core.log.RUN, 'LEAVE _doSearch()'); return res.json({ results: [] }) }

    const listIds = [], seen = {}
    rows.forEach(r => { if(r.list_id !== null && !seen[r.list_id]) { seen[r.list_id] = true; listIds.push(r.list_id) } })
    if(!listIds.length) {
      _core.log.print(_core.log.RUN, 'LEAVE _doSearch()')
      return res.json({ results: rows.map(r => ({ source: r.source, tag: r.tag, text: r.label, snippet: r.snippet, urls: [] })) })
    }

    const ph = listIds.map(() => '?').join(',')
    _core.dbRequest('all', 'SELECT DISTINCT list_id, url FROM _page WHERE list_id IN (' + ph + ')', listIds, (err, pages) => {
      const urlMap = {}
      if(pages) pages.forEach(p => { if(!urlMap[p.list_id]) urlMap[p.list_id] = []; urlMap[p.list_id].push(p.url) })
      res.json({ results: rows.map(r => ({ source: r.source, tag: r.tag, text: r.label, snippet: r.snippet, urls: urlMap[r.list_id] || [] })) })
      _core.log.print(_core.log.RUN, 'LEAVE _doSearch()')
    })
  })
}

module.exports = {
  /**
   * \brief init() — enregistre les routes de recherche.
   */
  init() {
    _core.log.print(_core.log.RUN, 'ENTER _search.init()')

    _core.app.get('/admin/api/search', (req, res) => {
      _core.log.print(_core.log.RUN, 'ENTER GET /admin/api/search')
      req.app.locals.adminSession(req, res, () => { _doSearch(req, res, 0); _core.log.print(_core.log.RUN, 'LEAVE GET /admin/api/search') })
    })

    _core.app.get('/api/search', (req, res) => {
      _core.log.print(_core.log.RUN, 'ENTER GET /api/search')
      _doSearch(req, res, 200)
      _core.log.print(_core.log.RUN, 'LEAVE GET /api/search')
    })

    _core.app.get('/admin/api/search/_status', (req, res) => {
      _core.log.print(_core.log.RUN, 'ENTER GET /admin/api/search/_status')
      _core.dbRequest('get', 'SELECT COUNT(*) AS n FROM _fts', [], (err, row) => {
        if(err) return res.json({ ok: false, error: err.message })
        res.json({ ok: true, rows: row ? row.n : 0 })
        _core.log.print(_core.log.RUN, 'LEAVE GET /admin/api/search/_status')
      })
    })

    _core.log.print(_core.log.INFO, '[search] routes registered.')
    _core.log.print(_core.log.RUN, 'LEAVE _search.init()')
  }
}

/* (WaTE) _search.js v1.2.2 */

