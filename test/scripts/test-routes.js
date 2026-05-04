/**
 * \file      test-routes.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-24
 * \version   1.0.0
 * \brief     Module applicatif de test — 3 styles d'écriture d'une appli WaTE.
 *
 * \details   Chargé via --mod=test-routes. Démontre et teste les 3 façons
 *            supportées par le moteur pour servir une page :
 *
 *            1) Route directe + api.renderPage : le module enregistre sa
 *               propre route Express et force le rendu d'une page DB en
 *               injectant des données (extraData).
 *               → GET /test/style1  (rend /home + {key:'fromRoute', value:...}).
 *
 *            2) Hook api.hooks.onPageLoad : la page /style2 est définie en DB
 *               avec l'élément HOOK=test_page_hook ; le moteur appelle le hook
 *               pendant serve() et injecte son retour dans result.
 *               → GET /style2       (page DB + hook data).
 *
 *            2b) Hook api.hooks.onTableWrite : intercepte INSERT sample
 *                et rejette les lignes dont id='blocked'.
 *                → POST /admin/form/db/sample/insert avec id=blocked → 500.
 *
 *            3) DB-only : la page /style3 est entièrement définie par la DB
 *               (queries SELECT sur _profil). Aucun code module.
 *               → GET /style3.
 *
 *            Migration : test/migrations/003_api.sql crée les pages /style2
 *            et /style3 pour le profil anonymous (id=42).
 */

'use strict'

exports.init = function(param, api) {

  // Capture de api.app au moment de l'init — voir test-api.js pour l'explication
  // détaillée (singleton _core.app réécrasé par les start() successifs).
  const myApp = api.app

  // ── Style 1 : route directe + renderPage ───────────────────────────────
  // Le module expose sa propre URL, puis délègue le rendu au moteur en
  // pointant sur une page DB existante (/home, profil anonymous).
  // extraData = { key, value } se retrouve dans result[key] à l'affichage.
  myApp.get('/test/style1', function(req, res) {
    api.renderPage(req, res, '/home', {
      key: 'fromRoute',
      value: { source: 'direct-route', at: 'test-routes.js' }
    })
  })

  // Variante : renderError depuis une route module (preuve que l'API
  // d'erreur est accessible hors _data.serve).
  myApp.get('/test/style1-error', function(req, res) {
    api.renderError(req, res, 418, 'style1-teapot')
  })

  // ── Style 2 : hook onPageLoad ──────────────────────────────────────────
  // Le hook reçoit (req, elements) et retourne { key, value } — le moteur
  // pousse result[key] = value avant le render(). Pas de route module ici,
  // la page /style2 est en DB avec elements.HOOK = 'test_page_hook'.
  api.hooks.onPageLoad('test_page_hook', function(req, elements) {
    return {
      key: 'hookPayload',
      value: {
        source: 'page-load-hook',
        path:   req.path,
        hasElements: !!elements
      }
    }
  })

  // ── Style 2b : hook onTableWrite (insert sample) ───────────────────────
  // Le hook reçoit (req, doSql) — il doit appeler doSql() pour laisser passer
  // ou doSql(err) pour bloquer. On rejette les lignes id='blocked'.
  api.hooks.onTableWrite('sample', 'insert', function(req, doSql) {
    if(req.body && req.body.id === 'blocked') {
      return doSql(new Error('blocked by test-routes hook'))
    }
    doSql()
  })

  // ── Style 3 : DB-only — aucune route, aucun hook. /style3 est en DB.
  //    Rien à faire ici, migrations/003_api.sql définit tout.

  api.log.print(api.log.INFO, '[test-routes] 3 styles d\'appli câblés')
}

/* test-routes.js v1.0.0 */
