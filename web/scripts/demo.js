/**
 * \file      (WaTE) web/scripts/demo.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-26
 * \version   2.4.0
 * \brief     Module applicatif — démo « gestion de stock » du site vitrine.
 *
 * \details   Trois responsabilités :
 *
 *            1. SCHÉMA + SEED. Le schéma (tables + trigger) est dans
 *               migrations/003_demo_schema.sql. Au boot, si les tables sont
 *               vides, le seed (scripts/demo-seed.sql) est chargé.
 *
 *            2. RESET PÉRIODIQUE. Un setInterval rejoue le seed toutes les 24h
 *               pour éviter la dérive long terme (stocks à 99 999, tables
 *               quasiment vides…). L'owner démo dispose en plus d'une route
 *               POST /demo/reset pour le déclencher à la demande.
 *
 *            3. ROUTES API (JSON) :
 *                 POST /demo/api/login/:role → { next: '/demo/stock' }
 *                 POST /demo/api/logout      → { next: '/demo' }
 *                 POST /demo/api/reset       → { next: '/demo/stock?reset=1' }
 *
 *            Convention WaTE : on n'utilise QUE l'API officielle (param, api),
 *            jamais req.app.locals ni require('./_core'). cf. _modules.js v1.x.
 *
 *            v2.0.0 — tables prefixées demo_ dans site.db (plus d'ATTACH).
 */

'use strict'

const fs   = require('fs')
const path = require('path')

// État local au module — partagé entre boot, reset périodique et route /demo/reset.
let _api         = null
let _resetTimer  = null
let _RESET_EVERY = 24 * 3600 * 1000  // 24h
let _sourceCache = null                // lu une fois au init(), relu par le hook onPageLoad


// ── Seed SQL ──────────────────────────────────────────────────────────
// Exécuté par la migration au premier boot, puis rejoué par _resetSeed
// (reset 24h ou manuel). Schéma créé par migrations/003_demo_schema.sql.
let _seedSQL = null


/**
 * \fn _seedIfEmpty
 * \brief Charge le seed initial UNIQUEMENT si demo_produit est vide.
 */
function _seedIfEmpty(done) {
  _api.db.get('SELECT COUNT(*) AS n FROM demo_produit', [], function(err, row) {
    if (err) return done(err)
    if (row && row.n > 0) return done(null)
    _seedAll(done)
  })
}


/**
 * \fn _seedAll
 * \brief Insère les 5 produits + 10 mouvements. Le trigger maintient stock à jour.
 *        Produits insérés avec stock=0, le trigger calcule depuis les mouvements.
 */
function _seedAll(done) {
  if (!_seedSQL) return done(new Error('seed SQL not loaded'))
  _api.db.exec(_seedSQL, function(err) {
    if (err) _api.log.print(_api.log.ERROR, 'demo: seed failed: ' + err.message)
    else     _api.log.print(_api.log.INFO,  'demo: seed chargé')
    done(err)
  })
}


/**
 * \fn _resetSeed
 * \brief Vide demo_mouvement et demo_produit puis recharge le seed.
 */
function _resetSeed(done) {
  done = done || function() {}
  _seedAll(function(err) {
    if (err) _api.log.print(_api.log.ERROR, 'demo: reset failed: ' + err.message)
    else     _api.log.print(_api.log.INFO,  'demo: reset effectué')
    done(err)
  })
}


/**
 * \fn init
 * \brief Hook d'initialisation — création schema + seed + timer + routes.
 */
exports.init = function(param, api) {
  _api = api
  _api.log.print(_api.log.INFO, 'demo: initialisation')

  // Le schéma est créé par migrations/003_demo_schema.sql (avant init).
  // Le seed est dans scripts/demo-seed.sql.
  _seedIfEmpty(function(err) {
    if (err) _api.log.print(_api.log.ERROR, 'demo: seedIfEmpty failed: ' + err.message)
  })

  // Hook : injecte le code source pour la section "Code source" sur /demo.
  // Les fichiers sont lus une fois au boot et mis en cache dans _sourceCache.
  let dir = path.join(__dirname, '..')
  _sourceCache = {
    app:      fs.readFileSync(path.join(dir, 'app.js'),                                     'utf8').trim(),
    site:     fs.readFileSync(path.join(dir, 'migrations', '001_site.sql'),                 'utf8').trim(),
    access:   fs.readFileSync(path.join(dir, 'migrations', '002_demo_access.sql'),          'utf8').trim(),
    schema:   fs.readFileSync(path.join(dir, 'migrations', '003_demo_schema.sql'),          'utf8').trim(),
    seed:     fs.readFileSync(path.join(dir, 'migrations', '004_demo_seed.sql'),            'utf8').trim(),
    ai:       fs.readFileSync(path.join(dir, 'migrations', '005_ai.sql'),                   'utf8').trim(),
    demo:     fs.readFileSync(path.join(dir, 'scripts', 'demo.js'),                         'utf8').trim(),
    stockjs:  fs.readFileSync(path.join(dir, 'scripts', 'demo-stock.js'),                   'utf8').trim(),
    btnaction:fs.readFileSync(path.join(dir, 'scripts', 'btn-action.js'),                   'utf8').trim(),
    common:   fs.readFileSync(path.join(dir, 'views', 'common.ejs'),                        'utf8').trim(),
    home:     fs.readFileSync(path.join(dir, 'views', 'demo-home.ejs'),                     'utf8').trim(),
    stock:    fs.readFileSync(path.join(dir, 'views', 'demo-stock.ejs'),                    'utf8').trim(),
    csscommon:fs.readFileSync(path.join(dir, 'css', 'common.css'),                          'utf8').trim(),
    admindb:  fs.readFileSync(path.join(dir, 'css', 'admin-db.css'),                        'utf8').trim(),
    democss:  fs.readFileSync(path.join(dir, 'css', 'demo.css'),                            'utf8').trim()
  }
  api.hooks.onPageLoad('demo-code', function(req, elements) {
    return { key: 'demoCode', value: _sourceCache }
  })

  // Seed SQL — lu une fois au boot, rejoué au reset
  _seedSQL = fs.readFileSync(path.join(dir, 'migrations', '004_demo_seed.sql'), 'utf8')

  // Reset périodique (24h)
  _resetTimer = setInterval(function() { _resetSeed() }, _RESET_EVERY)

  // Routes API (JSON) — pour les <a class="btn-action">
  // FIX v1.0.0 #70-72: sessions random, CSRF validé, cookie secure conditionnel
  const _csrfDemo = require('../../_utils')

  _api.app.post('/demo/api/login/:role', function(req, res) {
    // CSRF check
    const session = _csrfDemo.getSession(req)
    const expected = _csrfDemo.generateCSRFToken(session.id)
    const provided = req.headers['x-csrf-token'] || (req.body && req.body._csrf)
    if(session.id !== '0' && (!provided || provided.length !== 64 || !_csrfDemo.adminTimingSafeEqual(expected, provided))) {
      return res.status(403).json({ error: 'CSRF token invalid' })
    }

    // FIX v1.0.1 #156: cookie + réponse dans le callback DB (pas avant)
    const crypto = require('crypto')
    const sessionId = crypto.randomBytes(50).toString('hex')
    let email, role
    if(req.params.role === 'owner') {
      email = 'demo-owner@wate.fr'; role = 'owner'
    } else if(req.params.role === 'mgr') {
      email = 'demo-mgr@wate.fr'; role = 'mgr'
    } else {
      return res.status(400).json({ error: 'invalid role' })
    }
    _api.db.run('INSERT INTO _session (id, user_email, issued) VALUES (?, ?, ?)',
      [sessionId, email, Math.floor(Date.now() / 1000)], function(err) {
      if(err) return res.status(500).json({ error: 'session creation failed' })
      res.cookie('session', { id: sessionId }, { httpOnly: true, sameSite: 'lax', secure: !!req.secure, path: '/' })
      res.json({ next: '/demo/stock' })
    })
  })

  _api.app.post('/demo/api/logout', function(req, res) {
    res.clearCookie('session')
    res.json({ next: '/demo' })
  })

  _api.app.post('/demo/api/reset', function(req, res) {
    if (!req.cookies || !req.cookies.session || !req.cookies.session.id) {
      return res.status(401).json({ error: 'unauthorized' })
    }
    _api.db.get('SELECT u.profil_id FROM _user u, _session s WHERE u.email = s.user_email AND s.id = ?',
                [req.cookies.session.id], function(err, row) {
      if (err)  return res.status(500).json({ error: err.message })
      if (!row) return res.status(401).json({ error: 'unauthorized' })
      if (row.profil_id !== 10) return res.status(403).json({ error: 'forbidden' })
      _resetSeed(function(resetErr) {
        if (resetErr) return res.status(500).json({ error: resetErr.message })
        res.json({ next: '/demo/stock?reset=1' })
      })
    })
  })

}


/**
 * \fn done
 * \brief Hook de fermeture — annule le timer.
 */
exports.done = function() {
  if (_resetTimer) clearInterval(_resetTimer)
  _resetTimer = null
  _api = null
}

/* (WaTE) web/scripts/demo.js v2.4.0 */
