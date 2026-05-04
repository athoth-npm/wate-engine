/**
 * \file      test-api.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-24
 * \version   1.0.0
 * \brief     Module applicatif de test — sonde technique de _WATE_API.
 *
 * \details   Chargé via --mod=test-api. Expose 4 endpoints sous /test/api/*
 *            qui exercent chacun une facette de l'API exposée aux modules
 *            applicatifs (api.log, api.db, api.renderError, api.app).
 *            Les tests HTTP (test-wate.sh) vérifient que chaque surface
 *            fonctionne — preuve que les modules peuvent écrire une appli
 *            WaTE sans taper dans _core.
 */

'use strict'

exports.init = function(param, api) {

  // Capture de api.app au moment de l'init — indispensable : _core.app est un
  // singleton réécrasé à chaque start() (instances 3001/3002/…). Le getter lazy
  // d'api.app pointerait sinon sur la DERNIÈRE instance au runtime. Le module
  // doit verrouiller sa référence ici, à l'init de SON instance.
  const myApp = api.app

  // api.log — doit être fonctionnel (les niveaux sont des constantes numériques).
  myApp.get('/test/api/log', function(req, res) {
    api.log.print(api.log.INFO, '[test-api] /test/api/log hit')
    res.json({
      ok: true,
      levels: { RUN: api.log.RUN, INFO: api.log.INFO, FATAL: api.log.FATAL }
    })
  })

  // api.db.get/all/run — accès sécurisé à SQLite, même moteur que dbRequest.
  myApp.get('/test/api/db', function(req, res) {
    api.db.all('SELECT id, name FROM _profil ORDER BY id', [], function(err, rows) {
      if(err) return res.status(500).json({ error: err.message })
      res.json({ ok: true, count: rows.length, rows: rows })
    })
  })

  // api.renderError — rendu d'une page d'erreur via le moteur (code arbitraire).
  myApp.get('/test/api/render-error', function(req, res) {
    const code = parseInt(req.query.code, 10) || 418
    api.renderError(req, res, code, 'test-api-error')
  })

  // api.app (capturé à l'init) — doit être la même instance Express que req.app.
  // Note : api.app est un getter lazy qui pointe sur _core.app, lequel est
  // réassigné à chaque start() d'une nouvelle instance. Le contrat stable est
  // donc : la valeur CAPTURÉE à l'init doit correspondre au req.app des
  // handlers enregistrés par ce module.
  myApp.get('/test/api/app-locals', function(req, res) {
    res.json({ ok: true, same: myApp === req.app })
  })

  api.log.print(api.log.INFO, '[test-api] endpoints /test/api/{log,db,render-error,app-locals} actifs')
}

/* test-api.js v1.0.0 */
