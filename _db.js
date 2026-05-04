/**
 * \file      (WaTE) _db.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   3.4.1
 * \brief     Module engine WaTE — CRUD admin + export + formulaires.
 *
 * \details   v3.0.0 : CRUD API + formulaires admin.
 *            v3.1.0 : export CSV/JSON.
 *            v3.2.0 : sort/filter/search.
 *            v3.3.0 : csvEscape + _RE_FORMULA anti-injection.
 *            v3.4.0 : harmonisation — arrow functions, var→const/let,
 *                     Doxygen, logs RUN ENTER/LEAVE.
 */
'use strict'
const jimp    = require('jimp')
const fs      = require('fs')
const _core   = require('./_core')
const _utils  = require('./_utils')
const _data   = require('./_data')

let upload = null

const _RE_DQUOTE  = /"/g
const _RE_FORMULA = /^[=+\-@]/

/**
 * \brief  Vérifie les droits d'accès DB pour un profil/table/action.
 */
function _adminCheckAccess(profilId, tableName, requestName, cb) {
  _core.dbRequest('get',
    'SELECT 1 FROM _access WHERE profil_id = ? AND tablename = ? AND request_name = ?',
    [profilId, tableName, requestName],
    (err, row) => { if(err) return cb(false, err); cb(!!row, null) }
  )
}

/**
 * \brief  Échappe une valeur pour CSV (RFC 4180 + anti-injection formules).
 */
function csvEscape(val) {
  if(val === null || val === undefined) return ''
  let str = String(val)
  if(_RE_FORMULA.test(str)) str = '\'' + str
  if(str.indexOf(',') >= 0 || str.indexOf('"') >= 0 || str.indexOf('\n') >= 0 || str.indexOf('\r') >= 0) {
    return '"' + str.replace(_RE_DQUOTE, '""') + '"'
  }
  return str
}

/**
 * \brief  Redimensionne une image uploadée (max 150px).
 */
function _reduceImageSize(path, mime) {
  _core.log.print(_core.log.RUN, 'ENTER _reduceImageSize(' + path + ', ' + mime + ')')
  return jimp.read(path).then(image => {
    const w = image.bitmap.width, h = image.bitmap.height
    if(!w || !h || w < 1 || h < 1 || w > 10000 || h > 10000)
      return Promise.reject(new Error('Dimensions image invalides : ' + w + 'x' + h))
    const dim = (w > h) ? { width: 150, height: Math.floor(150 * (h / w)) }
      : { width: Math.floor(150 * (w / h)), height: 150 }
    return new Promise((resolve, reject) => {
      image.resize(dim.width, dim.height).write(path + '-mini.png', err => {
        if(err) return reject(err)
        fs.rename(path + '-mini.png', path + '-mini', err => {
          if(err) { fs.unlink(path + '-mini.png', () => {}); return reject(err) }
          _core.log.print(_core.log.INFO, 'Resized image saved to ' + path + '-mini')
          _core.log.print(_core.log.RUN, 'LEAVE _reduceImageSize()')
          resolve({ name: path })
        })
      })
    })
  }).catch(e => {
    // Note : ne pas supprimer l'original — le resize a échoué, pas l'upload.
    // La mini (-mini.png) peut rester orpheline si créée, nettoyée au prochain cycle.
    _core.log.print(_core.log.ERROR, 'Error resizing image: ' + e.message)
    _core.log.print(_core.log.RUN, 'LEAVE _reduceImageSize()')
    return Promise.reject({ error: e })
  })
}

/**
 * \brief init() — enregistre les routes API et formulaires CRUD.
 */
function init() {
  _core.log.print(_core.log.RUN, 'ENTER _db.init()')
  const _maxFileSize = parseInt(_core.config['upload.maxFileSize'], 10) || (10 * 1024 * 1024)
  const _maxFiles    = parseInt(_core.config['upload.maxFiles'],    10) || 5
  const _defLimit    = parseInt(_core.config['db.defaultLimit'],    10) || 50
  const _maxLimit    = parseInt(_core.config['db.maxLimit'],        10) || 200

  upload = require('multer')({ dest: _core.path + 'store', limits: { fileSize: _maxFileSize, files: _maxFiles } })

  // === API JSON ===

  _core.app.get('/admin/api/db/schema', (req, res) => {
    req.app.locals.adminSession(req, res, user => {
      _core.dbRequest('all',
        'SELECT DISTINCT tablename FROM _access WHERE profil_id = ? AND request_name = ? ORDER BY tablename',
        [user.profil_id, 'select'],
        (err, rows) => {
          if(err) return res.status(500).json({ error: err.message })
          const tableNames = rows.map(r => r.tablename)
          if(tableNames.length === 0) return res.json({ tables: [] })
          const tables = []; let pending = tableNames.length
          tableNames.forEach(tableName => {
            _core.dbRequestCache(_core.dbCaches.tableInfo, tableName, 'all', 'PRAGMA table_info(' + tableName + ')', [], (err, cols) => {
              _core.dbRequestCache(_core.dbCaches.fkList, tableName, 'all', 'PRAGMA foreign_key_list(' + tableName + ')', [], (err2, fkList) => {
                const fks = {}
                if(!err2 && fkList) fkList.forEach(fk => { fks[fk.from] = fk.table })
                tables.push({ name: tableName, columns: (!err && cols) ? cols.map(c => ({ name: c.name, pk: c.pk, fk: fks[c.name] || null })) : [] })
                if(--pending === 0) { tables.sort((a, b) => a.name < b.name ? -1 : 1); res.json({ tables }) }
              })
            })
          })
        }
      )
    })
  })

  // --- Export CSV/JSON ---
  _core.app.get('/admin/api/db/:table/export', (req, res) => {
    if(!_utils._RE_TABLE.test(req.params.table)) return res.status(400).json({ error: 'invalid table name' })
    req.app.locals.adminSession(req, res, user => {
      _adminCheckAccess(user.profil_id, req.params.table, 'select', (allowed, err) => {
        if(err) return res.status(500).json({ error: err.message })
        if(!allowed) return res.status(403).json({ error: 'forbidden' })
        _core.dbRequestCache(_core.dbCaches.tableInfo, req.params.table, 'all', 'PRAGMA table_info(' + req.params.table + ')', [], (err, cols) => {
          if(err || !cols || cols.length === 0) return res.status(404).json({ error: 'table not found' })
          const columnNames = cols.map(c => c.name)
          let orderClause = ''; const sortCol = req.query.sort
          if(sortCol && columnNames.indexOf(sortCol) >= 0) { const dir = (req.query.dir === 'desc') ? 'DESC' : 'ASC'; orderClause = ' ORDER BY "' + sortCol + '" ' + dir }
          const whereClauses = [], whereParams = []; const filterRaw = req.query.filter
          if(filterRaw) { const pairs = filterRaw.split(','); for(let fi = 0; fi < pairs.length; fi++) { const ci = pairs[fi].indexOf(':'); if(ci > 0) { const col = pairs[fi].substring(0, ci), val = pairs[fi].substring(ci + 1); if(columnNames.indexOf(col) >= 0) { whereClauses.push('"' + col + '" = ?'); whereParams.push(val) } } } }
          const searchTerm = req.query.search
          if(searchTerm) { const likeCols = cols.filter(c => { const t = (c.type || '').toUpperCase(); return t.indexOf('CHAR') >= 0 || t.indexOf('TEXT') >= 0 || t.indexOf('CLOB') >= 0 || t === '' }).map(c => c.name); if(likeCols.length > 0) { const likes = likeCols.map(c => '"' + c + '" LIKE ?'); whereClauses.push('(' + likes.join(' OR ') + ')'); for(let si = 0; si < likeCols.length; si++) whereParams.push('%' + searchTerm + '%') } }
          const whereSQL = whereClauses.length > 0 ? ' WHERE ' + whereClauses.join(' AND ') : ''
          const maxExport = parseInt(_core.config['db.maxExport'], 10) || 10000
          _core.dbRequest('all', 'SELECT * FROM ' + req.params.table + whereSQL + orderClause + ' LIMIT ?', whereParams.concat([maxExport]), (err, rows) => {
            if(err) return res.status(500).json({ error: err.message })
            const format = req.query.format === 'csv' ? 'csv' : 'json'
            if(format === 'csv') { res.setHeader('Content-Type', 'text/csv; charset=utf-8'); res.setHeader('Content-Disposition', 'attachment; filename="' + req.params.table + '.csv"'); const header = cols.map(c => csvEscape(c.name)).join(','); const lines = rows.map(row => cols.map(c => csvEscape(row[c.name] !== undefined ? String(row[c.name]) : '')).join(',')); res.write('﻿'); res.end(header + '\r\n' + lines.join('\r\n') + '\r\n') }
            else { res.setHeader('Content-Disposition', 'attachment; filename="' + req.params.table + '.json"'); res.json(rows) }
          })
        })
      })
    })
  })

  _core.app.get('/admin/api/db/:table', (req, res) => {
    if(!_utils._RE_TABLE.test(req.params.table)) return res.status(400).json({ error: 'invalid table name' })
    req.app.locals.adminSession(req, res, user => {
      _adminCheckAccess(user.profil_id, req.params.table, 'select', (allowed, err) => {
        if(err) return res.status(500).json({ error: err.message })
        if(!allowed) return res.status(403).json({ error: 'forbidden' })
        const offset = Math.max(0, parseInt(req.query.offset, 10) || 0)
        const limit  = Math.min(_maxLimit, Math.max(1, parseInt(req.query.limit, 10) || _defLimit))
        _core.dbRequestCache(_core.dbCaches.tableInfo, req.params.table, 'all', 'PRAGMA table_info(' + req.params.table + ')', [], (err, cols) => {
          if(err || !cols || cols.length === 0) return res.status(404).json({ error: 'table not found' })
          const columnNames = cols.map(c => c.name)
          let orderClause = ''; const sortCol = req.query.sort
          if(sortCol && columnNames.indexOf(sortCol) >= 0) { const dir = (req.query.dir === 'desc') ? 'DESC' : 'ASC'; orderClause = ' ORDER BY "' + sortCol + '" ' + dir }
          const whereClauses = [], whereParams = []; const filterRaw = req.query.filter
          if(filterRaw) { const pairs = filterRaw.split(','); for(let fi = 0; fi < pairs.length; fi++) { const ci = pairs[fi].indexOf(':'); if(ci > 0) { const col = pairs[fi].substring(0, ci), val = pairs[fi].substring(ci + 1); if(columnNames.indexOf(col) >= 0) { whereClauses.push('"' + col + '" = ?'); whereParams.push(val) } } } }
          const searchTerm = req.query.search
          if(searchTerm) { const likeCols = cols.filter(c => { const t = (c.type || '').toUpperCase(); return t.indexOf('CHAR') >= 0 || t.indexOf('TEXT') >= 0 || t.indexOf('CLOB') >= 0 || t === '' }).map(c => c.name); if(likeCols.length > 0) { const likes = likeCols.map(c => '"' + c + '" LIKE ?'); whereClauses.push('(' + likes.join(' OR ') + ')'); for(let si = 0; si < likeCols.length; si++) whereParams.push('%' + searchTerm + '%') } }
          const whereSQL = whereClauses.length > 0 ? ' WHERE ' + whereClauses.join(' AND ') : ''
          _core.dbRequestCache(_core.dbCaches.fkList, req.params.table, 'all', 'PRAGMA foreign_key_list(' + req.params.table + ')', [], (err, fkList) => {
            const fks = {}
            if(!err && fkList) fkList.forEach(fk => { fks[fk.from] = { table: fk.table } })
            _core.dbRequest('get', "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", [req.params.table], (_err, row) => {
              const _sql = (row && row.sql) || ''
              _core.dbRequest('get', 'SELECT COUNT(*) AS total FROM ' + req.params.table + whereSQL, whereParams, (err, count) => {
                if(err) return res.status(500).json({ error: err.message })
                _core.dbRequest('all', 'SELECT * FROM ' + req.params.table + whereSQL + orderClause + ' LIMIT ? OFFSET ?', whereParams.concat([limit, offset]), (err, rows) => {
                  if(err) return res.status(500).json({ error: err.message })
                  res.json({ columns: cols.map(c => { const autoRe = new RegExp('\\b' + c.name + '\\b[^,)]*\\bAUTOINCREMENT\\b', 'i'); return { name: c.name, type: c.type, pk: c.pk, auto: autoRe.test(_sql), notnull: c.notnull, fk: fks[c.name] || null } }), rows, total: count.total, offset, limit })
                })
              })
            })
          })
        })
      })
    })
  })

  _core.app.post('/admin/api/db/:table', (req, res) => {
    if(!_utils._RE_TABLE.test(req.params.table)) return res.status(400).json({ error: 'invalid table name' })
    req.params.request = 'insert'; _data.modify(req, res, _utils.jsonResponder(res))
  })
  _core.app.put('/admin/api/db/:table', (req, res) => {
    if(!_utils._RE_TABLE.test(req.params.table)) return res.status(400).json({ error: 'invalid table name' })
    req.params.request = 'update'; _data.modify(req, res, _utils.jsonResponder(res))
  })
  _core.app.delete('/admin/api/db/:table', (req, res) => {
    if(!_utils._RE_TABLE.test(req.params.table)) return res.status(400).json({ error: 'invalid table name' })
    req.params.request = 'delete'; _data.modify(req, res, _utils.jsonResponder(res))
  })

  // === FORM ===
  _core.app.post('/admin/form/db/:table/:request', upload.any(), (req, res) => {
    // FIX v3.4.2 #36: validation _RE_TABLE cohérente avec les routes API
    if(!_utils._RE_TABLE.test(req.params.table)) return _core.httpError(req, res, 400, 'Invalid table name')
    _core.log.print(_core.log.RUN, 'ENTER POST /admin/form/db/' + req.params.table + '/' + req.params.request)
    if(req.files && req.files.length > 0) {
      const reduces = []
      req.files.forEach(file => { if(file.mimetype.indexOf('image') >= 0) reduces.push(_reduceImageSize(file.path, file.mimetype)); if(!Object.prototype.hasOwnProperty.call(req.body, file.fieldname)) req.body[file.fieldname] = file.filename })
      // Note : si Promise.all échoue partiellement, les miniatures déjà créées restent sur disque.
      Promise.all(reduces).then(() => { _data.modify(req, res, null) }).catch(e => { _core.log.print(_core.log.ERROR, e.message || e.error); _core.httpError(req, res, 500, 'Image processing failed') })
    } else { _data.modify(req, res, null) }
    _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/db/' + req.params.table + '/' + req.params.request)
  })

  _core.log.print(_core.log.INFO, '[db] routes registered.')
  _core.log.print(_core.log.RUN, 'LEAVE _db.init()')
}

module.exports = { init }

/* (WaTE) _db.js v3.4.2 */
