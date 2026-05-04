/**
 * \file      (WaTE) _audit.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/09/2025
 * \version   2.0.0
 * \brief     Module optionnel --mod audit — journal d'écriture + undo.
 *
 * \details   v1.0.0 : création initiale (hooks INSERT/UPDATE/DELETE).
 *            v1.1.0 : FIX buildAuditPayload(req) + session.clause retiré.
 *            v1.2.0 : undo — POST /admin/api/db/:table/undo.
 *            v1.3.0 : SQL d'abord, audit ensuite. unregisterTableWriteHook.
 *            v2.0.0 : harmonisation — arrow functions, var→const/let,
 *                     Doxygen, logs RUN ENTER/LEAVE.
 */
'use strict'
const _core = require('./_core'), _data = require('./_data'), _utils = require('./_utils')

// --- Audit write helpers ---

/**
 * \brief  Écrit un enregistrement dans _audit.
 * \param  audit Objet { table_name, operation, record_key, old_values, new_values, user_email }.
 * \param  next  Callback appelé après écriture.
 */
function writeAuditRecord(audit, next) {
  _core.dbRequest('run', 'INSERT INTO _audit (table_name, operation, record_key, old_values, new_values, user_email) VALUES (?, ?, ?, ?, ?, ?)',
    [audit.table_name, audit.operation, audit.record_key, audit.old_values, audit.new_values, audit.user_email],
    err => { if(err) _core.log.print(_core.log.ERROR, '[audit] write failed: ' + err.message); next() })
}

/**
 * \brief  Construit le payload d'audit à partir de la requête.
 * \param  req        Requête Express.
 * \param  tableName  Nom de la table.
 * \param  reqAction  'insert' | 'update' | 'delete'.
 * \param  sessionRow Ligne _session (contient user_email).
 * \param  cols       PRAGMA table_info.
 * \return Objet audit.
 */
function buildAuditPayload(req, tableName, reqAction, sessionRow, cols) {
  const pkCols = cols.filter(c => c.pk > 0), pkv = {}
  // FIX : || null convertit "" en null (falsy). On ne garde null que si vraiment absent.
  pkCols.forEach(c => { const v = req.body && req.body[c.name]; pkv[c.name] = v !== undefined && v !== null ? v : null })
  return { table_name: tableName, operation: reqAction, user_email: sessionRow.user_email,
           record_key: Object.keys(pkv).length > 0 ? JSON.stringify(pkv) : null,
           old_values: null, new_values: null }
}

/**
 * \brief  Capture les nouvelles valeurs depuis req.body.
 * \param  req  Requête Express.
 * \param  cols PRAGMA table_info.
 * \return Objet { col: val }.
 */
function captureNewValues(req, cols) {
  const nd = {}
  cols.forEach(c => { if(req.body[c.name] !== undefined) nd[c.name] = req.body[c.name] })
  return nd
}

// --- Audit hooks (appelés par _data.modify) ---
// FIX v2.0.1 #159: writeAuditRecord dans onSuccess → après succès SQL

/**
 * \brief  Hook INSERT — capture les nouvelles valeurs.
 */
function auditInsert(req, tableName, reqAction, sessionRow, cols, next) {
  _core.log.print(_core.log.RUN, 'ENTER auditInsert(' + tableName + ')')
  const a = buildAuditPayload(req, tableName, reqAction, sessionRow, cols)
  a.old_values = null
  a.new_values = JSON.stringify(captureNewValues(req, cols))
  next(undefined, () => {
    writeAuditRecord(a, () => { _core.log.print(_core.log.RUN, 'LEAVE auditInsert(' + tableName + ')') })
  })
}

/**
 * \brief  Hook UPDATE — capture anciennes + nouvelles valeurs.
 */
function auditUpdate(req, tableName, reqAction, sessionRow, cols, next) {
  _core.log.print(_core.log.RUN, 'ENTER auditUpdate(' + tableName + ')')
  const isSelf = reqAction.indexOf('-self') >= 0
  const pkCols = cols.filter(c => c.pk > 0)
  const emailCols = cols.filter(c => c.name === 'email')
  const whereCols = (isSelf && emailCols.length > 0) ? emailCols : pkCols

  if(!whereCols.length) {
    const a2 = buildAuditPayload(req, tableName, reqAction, sessionRow, cols)
    a2.new_values = JSON.stringify(captureNewValues(req, cols))
    return next(undefined, () => {
      writeAuditRecord(a2, () => { _core.log.print(_core.log.RUN, 'LEAVE auditUpdate(' + tableName + ')') })
    })
  }

  const wc = whereCols.map(c => '"' + c.name + '" = ?').join(' AND ')
  const wp = whereCols.map(c => req.body[c.name])
  _core.dbRequest('get', 'SELECT * FROM "' + tableName + '" WHERE ' + wc, wp, (err, oldRow) => {
    const a = buildAuditPayload(req, tableName, reqAction, sessionRow, cols)
    a.old_values = (err || !oldRow) ? null : JSON.stringify(oldRow)
    a.new_values = JSON.stringify(captureNewValues(req, cols))
    next(undefined, () => {
      writeAuditRecord(a, () => { _core.log.print(_core.log.RUN, 'LEAVE auditUpdate(' + tableName + ')') })
    })
  })
}

/**
 * \brief  Hook DELETE — capture les anciennes valeurs.
 */
function auditDelete(req, tableName, reqAction, sessionRow, cols, next) {
  _core.log.print(_core.log.RUN, 'ENTER auditDelete(' + tableName + ')')
  const isSelf = reqAction.indexOf('-self') >= 0
  const pkCols = cols.filter(c => c.pk > 0)
  const emailCols = cols.filter(c => c.name === 'email')
  const whereCols = (isSelf && emailCols.length > 0) ? emailCols : pkCols

  if(!whereCols.length) {
    const a2 = buildAuditPayload(req, tableName, reqAction, sessionRow, cols)
    a2.new_values = null
    return next(undefined, () => {
      writeAuditRecord(a2, () => { _core.log.print(_core.log.RUN, 'LEAVE auditDelete(' + tableName + ')') })
    })
  }

  const wc = whereCols.map(c => '"' + c.name + '" = ?').join(' AND ')
  const wp = whereCols.map(c => req.body[c.name])
  _core.dbRequest('get', 'SELECT * FROM "' + tableName + '" WHERE ' + wc, wp, (err, oldRow) => {
    const a = buildAuditPayload(req, tableName, reqAction, sessionRow, cols)
    a.old_values = (err || !oldRow) ? null : JSON.stringify(oldRow)
    a.new_values = null
    next(undefined, () => {
      writeAuditRecord(a, () => { _core.log.print(_core.log.RUN, 'LEAVE auditDelete(' + tableName + ')') })
    })
  })
}

/**
 * \brief  Factory de hook — vérifie auditEnabled, session, puis appelle le bon hook.
 */
function makeAuditThenNext(tableName, reqAction, req, next) { return function(err) {
  if(err) return next(err)
  if(!req.app || !req.app.locals || !req.app.locals.auditEnabled) return next()
  const session = _utils.getSession(req)
  if(session.id === '0') return next()
  _core.dbRequest('get', 'SELECT user_email FROM _session WHERE id = ?', [session.id], (err, sessionRow) => {
    if(err || !sessionRow) return next()
    _core.dbRequestCache(_core.dbCaches.tableInfo, tableName, 'all', 'PRAGMA table_info(' + tableName + ')', [], (err, cols) => {
      if(err || !cols) return next()
      // NOTE: tableName validé par _RE_TABLE en amont. Accepté ANALYSIS v5 #13.
      if(reqAction === 'insert') auditInsert(req, tableName, reqAction, sessionRow, cols, next)
      else if(reqAction.indexOf('update') === 0) auditUpdate(req, tableName, reqAction, sessionRow, cols, next)
      else if(reqAction.indexOf('delete') === 0) auditDelete(req, tableName, reqAction, sessionRow, cols, next)
      else next()
    })
  })
}}

// --- Undo ---

/**
 * \brief  Annule un INSERT (supprime la ligne).
 */
function undoInsert(tableName, recordKey, newValues, callback) {
  let whereObj = null
  if(recordKey) {
    const rkKeys = Object.keys(recordKey)
    let allNull = true
    for(let i = 0; i < rkKeys.length; i++) { if(recordKey[rkKeys[i]] !== null) { allNull = false; break } }
    if(!allNull && rkKeys.length > 0) whereObj = recordKey
  }
  // FIX v2.0.1 #37: fallback newValues (table sans PK) — risque si non-unique. Accepté.
  if(!whereObj) whereObj = newValues
  if(!whereObj) return callback(new Error('No key to identify row'))
  const cols = Object.keys(whereObj)
  const where = cols.map(c => '"' + c + '" = ?').join(' AND ')
  const values = cols.map(c => whereObj[c])
  // Note : pas de LIMIT 1 (non supporté par SQLite < 3.33 / Node 4.6.1).
  // Le record_key identifie normalement une ligne unique.
  _core.dbRequest('run', 'DELETE FROM "' + tableName + '" WHERE ' + where, values, callback)
}

/**
 * \brief  Annule un UPDATE (restaure les anciennes valeurs).
 */
function undoUpdate(tableName, recordKey, oldValues, callback) {
  if(!recordKey || !oldValues) return callback(new Error('Missing record_key or old_values'))
  const setCols = Object.keys(oldValues)
  const setClause = setCols.map(c => '"' + c + '" = ?').join(', ')
  const setValues = setCols.map(c => oldValues[c])
  const whereCols = Object.keys(recordKey)
  const whereClause = whereCols.map(c => '"' + c + '" = ?').join(' AND ')
  const whereValues = whereCols.map(c => recordKey[c])
  _core.dbRequest('run', 'UPDATE "' + tableName + '" SET ' + setClause + ' WHERE ' + whereClause, setValues.concat(whereValues), callback)
}

/**
 * \brief  Annule un DELETE (réinsère la ligne).
 */
function undoDelete(tableName, oldValues, callback) {
  if(!oldValues) return callback(new Error('Missing old_values'))
  const cols = Object.keys(oldValues)
  const placeholders = cols.map(() => '?').join(', ')
  const values = cols.map(c => oldValues[c])
  _core.dbRequest('run', 'INSERT INTO "' + tableName + '" ("' + cols.join('", "') + '") VALUES (' + placeholders + ')', values, callback)
}

/**
 * \brief  Supprime l'enregistrement _audit après undo réussi.
 */
function deleteAuditRecord(id, res) {
  _core.dbRequest('run', 'DELETE FROM _audit WHERE id = ?', [id], err => {
    if(err) _core.log.print(_core.log.ERROR, '[audit] undo audit delete failed: ' + err.message)
    res.json({ ok: true })
  })
}

/**
 * \brief  Route POST /admin/api/db/:table/undo.
 */
function undoRoute(req, res) {
  _core.log.print(_core.log.RUN, 'ENTER POST /admin/api/db/' + req.params.table + '/undo')
  const session = _utils.getSession(req)
  if(session.id === '0') return res.status(401).json({ error: 'Unauthorized' })

  const tableName = req.params.table
  if(!_utils._RE_TABLE.test(tableName)) return res.status(400).json({ error: 'Invalid table name' })

  _core.dbRequest('get', 'SELECT user_email FROM _session WHERE id = ?', [session.id], (err, sessionRow) => {
    if(err || !sessionRow) return res.status(401).json({ error: 'Invalid session' })

    const whereClause = 'table_name = ? AND user_email = ?'
    const params = [tableName, sessionRow.user_email]

    if(req.query.all === 'true') {
      _core.dbRequest('get', 'SELECT profil_id FROM _user WHERE email = ?', [sessionRow.user_email], (err2, userRow) => {
        if(err2 || !userRow || userRow.profil_id !== 0) return res.status(403).json({ error: 'Forbidden' })
        performUndo('table_name = ?', [tableName])
      })
      return
    }

    performUndo(whereClause, params)

    function performUndo(whereClause, params) {
      _core.dbRequest('get', 'SELECT * FROM _audit WHERE ' + whereClause + ' ORDER BY id DESC LIMIT 1', params, (err, auditRow) => {
        if(err) { _core.log.print(_core.log.ERROR, '[audit] undo query failed: ' + err.message); return res.status(500).json({ error: 'Database error' }) }
        if(!auditRow) { _core.log.print(_core.log.RUN, 'LEAVE undo (nothing to undo)'); return res.status(404).json({ error: 'Nothing to undo' }) }

        const op = auditRow.operation
        const recordKey = auditRow.record_key ? JSON.parse(auditRow.record_key) : null
        const oldValues = auditRow.old_values ? JSON.parse(auditRow.old_values) : null
        const newValues = auditRow.new_values ? JSON.parse(auditRow.new_values) : null

        try {
          if(op === 'insert') {
            undoInsert(tableName, recordKey, newValues, err => {
              if(err) return res.status(500).json({ error: err.message })
              deleteAuditRecord(auditRow.id, res)
            })
          } else if(op === 'update') {
            undoUpdate(tableName, recordKey, oldValues, err => {
              if(err) return res.status(500).json({ error: err.message })
              deleteAuditRecord(auditRow.id, res)
            })
          } else if(op === 'delete') {
            undoDelete(tableName, oldValues, err => {
              if(err) return res.status(500).json({ error: err.message })
              deleteAuditRecord(auditRow.id, res)
            })
          } else {
            res.status(400).json({ error: 'Unknown operation: ' + op })
          }
        } catch(e) {
          _core.log.print(_core.log.ERROR, '[audit] undo failed: ' + e.message)
          res.status(500).json({ error: 'Undo failed: ' + e.message })
        }
      })
    }
  })
}

module.exports = {
  _app: null,
  _hooks: null,

  /**
   * \brief init() — enregistre les hooks d'audit + route undo.
   */
  // Note : si _auth est chargé après _audit, le hook _user n'est pas wrappé par l'audit.
  // L'ordre dans --mod garantit le chargement correct : auth avant audit.
  init() {
    _core.log.print(_core.log.RUN, 'ENTER _audit.init()')
    const app = _core.app; this._app = app
    const self = this
    self._hooks = []

    app.post('/admin/api/db/:table/undo', undoRoute)

    _core.dbRequest('all', "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE '\\_%' ESCAPE '\\' AND name != 'sqlite_sequence'", [], (err, tables) => {
      if(err) { _core.log.print(_core.log.ERROR, '[audit] Failed to list tables: ' + err.message); _core.log.print(_core.log.RUN, 'LEAVE _audit.init()'); return }
      if(!tables || !tables.length) {
        app.locals.auditEnabled = true
        _core.log.print(_core.log.INFO, '[audit] No application tables found.')
        _core.log.print(_core.log.RUN, 'LEAVE _audit.init()')
        return
      }
      tables.forEach(t => {
        const tn = t.name
        ;['insert', 'update', 'delete'].forEach(action => {
          const existingHook = _data.getTableWriteHook(tn, action)
          _data.registerTableWriteHook(tn, action, (req, next) => {
            const reqAction = req.params.request || action
            const ath = makeAuditThenNext(tn, reqAction, req, next)
            if(existingHook) existingHook(req, ath); else ath()
          })
          self._hooks.push({ table: tn, action, prev: existingHook })
        })
      })
      app.locals.auditEnabled = true
      _core.log.print(_core.log.INFO, '[audit] hooks registered for ' + tables.length + ' tables.')
      _core.log.print(_core.log.RUN, 'LEAVE _audit.init()')
    })
  },

  /**
   * \brief done() — désactive l'audit + nettoie les hooks.
   */
  done() {
    _core.log.print(_core.log.RUN, 'ENTER _audit.done()')
    if(this._app) this._app.locals.auditEnabled = false
    // Restaure les hooks externes (ne pas les perdre en supprimant le wrapper audit)
    if(this._hooks) { this._hooks.forEach(h => { if(h.prev) _data.registerTableWriteHook(h.table, h.action, h.prev); else _data.unregisterTableWriteHook(h.table, h.action) }); this._hooks = null }
    _core.log.print(_core.log.INFO, '[audit] done.')
    _core.log.print(_core.log.RUN, 'LEAVE _audit.done()')
  }
}

/* (WaTE) _audit.js v2.0.1 */
