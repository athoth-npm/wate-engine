/**
 * \file      (WaTE) _apikey.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/09/2025
 * \version   1.4.2
 * \brief     Module optionnel --mod apikey — clés API Bearer + gestion admin.
 *
 * \details   v1.0.0 : création initiale.
 *            v1.1.0 : FIX key.length < 70 → !== 69.
 *            v1.2.0 : FIX LIKE injection prefix → validation regex.
 *            v1.3.0 : harmonisation — arrow functions, var→const/let,
 *                     Doxygen, logs RUN ENTER/LEAVE.
 *            v1.4.0 : FIX révocation — double bug hash/clair.
 *                     Stocke le prefix clair en DB. GET affiche le
 *                     prefix DB (pas le hash). DELETE utilise
 *                     WHERE prefix = ? (exact) au lieu de LIKE.
 *                     Migration 008_apikey_prefix.sql.
 *            v1.4.1 : FIX colonne prefix absente du SELECT GET → affichait
 *                     le hash au lieu du préfixe clair.
 *            v1.4.2 : FIX mutation req.cookies — ne remplace pas un cookie
 *                     de session navigateur existant (garde-fou).
 */
'use strict'
const crypto = require('crypto'), _core = require('./_core'), _utils = require('./_utils')
const _RE_PREFIX = /^wate_[0-9a-f]{7}$/

module.exports = {
  /**
   * \brief init() — enregistre le middleware Bearer et les routes admin CRUD.
   */
  init() {
    _core.log.print(_core.log.RUN, 'ENTER _apikey.init()')

    // --- Middleware Bearer ---
    _core.app.use((req, res, next) => {
      const auth = req.headers && req.headers.authorization
      if(!auth || auth.substring(0, 7) !== 'Bearer ') return next()
      const key = auth.substring(7).trim()
      // FIX v1.1.0 : clé = 'wate_' (5) + 64 hex = 69
      if(key.length !== 69 || key.substring(0, 5) !== 'wate_') return next()
      const hash = crypto.createHash('sha256').update(key).digest('hex')
      _core.dbRequest('get', 'SELECT user_email FROM _api_key WHERE key = ?', [hash], (err, row) => {
        if(err || !row) return next()
        _core.dbRequest('run', 'UPDATE _api_key SET last_used = strftime(\'%s\',\'now\') WHERE key = ?', [hash], () => {})
        // Filtre TTL : ne pas réutiliser une session expirée
        const ttl = _core.app && _core.app.locals && _core.app.locals.SESSION_TTL_S
        const minIssued = ttl ? Math.floor(Date.now() / 1000) - ttl : 0
        _core.dbRequest('get', 'SELECT id FROM _session WHERE user_email = ? AND issued > ? ORDER BY issued DESC LIMIT 1', [row.user_email, minIssued], (err, sess) => {
          // Note : cookie non propagé au navigateur — le Bearer token est le credential
          if(sess) { if(!req.cookies) req.cookies = {}; if(!req.cookies.session) req.cookies.session = { id: sess.id }; return next() }
          const sid = crypto.randomBytes(32).toString('hex')
          const now = Math.floor(Date.now() / 1000)
          _core.dbRequest('run', 'INSERT INTO _session (id, user_email, issued) VALUES (?, ?, ?)', [sid, row.user_email, now], err => {
            if(err) return next()
            if(!req.cookies) req.cookies = {}
            if(!req.cookies.session) req.cookies.session = { id: sid }; next()
          })
        })
      })
    })

    // --- GET /admin/api/auth/apikey : liste les clés ---
    _core.app.get('/admin/api/auth/apikey', (req, res) => {
      _core.log.print(_core.log.RUN, 'ENTER GET /admin/api/auth/apikey')
      req.app.locals.adminSession(req, res, user => {
        _core.dbRequest('all', 'SELECT key, prefix, label, created_at, last_used FROM _api_key WHERE user_email = ? ORDER BY created_at DESC', [user.email], (err, rows) => {
          if(err) return res.status(500).json({ error: err.message })
          res.json({ keys: (rows || []).map(r => ({ prefix: (r.prefix || r.key.substring(0, 12)) + String.fromCharCode(8230), label: r.label, created_at: r.created_at, last_used: r.last_used })) })
          _core.log.print(_core.log.RUN, 'LEAVE GET /admin/api/auth/apikey')
        })
      })
    })

    // --- POST /admin/api/auth/apikey : crée une clé ---
    _core.app.post('/admin/api/auth/apikey', (req, res) => {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/api/auth/apikey')
      req.app.locals.adminSession(req, res, user => {
        const clear = 'wate_' + crypto.randomBytes(32).toString('hex')
        const hash = crypto.createHash('sha256').update(clear).digest('hex')
        const label = (req.body && req.body.label) || ''
        _core.dbRequest('run', 'INSERT INTO _api_key (key, user_email, label, prefix) VALUES (?, ?, ?, ?)', [hash, user.email, label, clear.substring(0, 12)], err => {
          if(err) return res.status(500).json({ error: err.message })
          res.json({ ok: true, key: clear, prefix: clear.substring(0, 12) + String.fromCharCode(8230), label: label })
          _core.log.print(_core.log.RUN, 'LEAVE POST /admin/api/auth/apikey')
        })
      })
    })

    // --- DELETE /admin/api/auth/apikey : révoque une clé ---
    _core.app.delete('/admin/api/auth/apikey', (req, res) => {
      _core.log.print(_core.log.RUN, 'ENTER DELETE /admin/api/auth/apikey')
      req.app.locals.adminSession(req, res, user => {
        let prefix = req.body && req.body.prefix
        if(!prefix) return res.status(400).json({ error: 'prefix required' })
        prefix = prefix.replace(String.fromCharCode(8230), '')
        if(!_RE_PREFIX.test(prefix)) return res.status(400).json({ error: 'invalid prefix' })
        _core.dbRequest('run', 'DELETE FROM _api_key WHERE user_email = ? AND prefix = ?', [user.email, prefix], err => {
          if(err) return res.status(500).json({ error: err.message })
          res.json({ ok: true })
          _core.log.print(_core.log.RUN, 'LEAVE DELETE /admin/api/auth/apikey')
        })
      })
    })

    _core.log.print(_core.log.INFO, '[apikey] middleware + routes registered.')
    _core.log.print(_core.log.RUN, 'LEAVE _apikey.init()')
  }
}

/* (WaTE) _apikey.js v1.4.2 */

