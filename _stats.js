/**
 * \file      (WaTE) _stats.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      16/04/2026
 * \version   1.1.0
 * \brief     Module optionnel --mod stats — statistiques runtime des caches LRU.
 *
 * \details   v1.0.0 : création initiale.
 *            v1.0.1 : config retiré, init() sans paramètre, for...in → Object.keys().
 *            v1.1.0 : harmonisation — arrow functions, Doxygen, logs RUN ENTER/LEAVE.
 */
'use strict'
const _core = require('./_core')

module.exports = {

  /**
   * \brief init() — enregistre GET /admin/api/stats sur _core.app.
   */
  init() {
    _core.log.print(_core.log.RUN, '[stats] ENTER _stats.init()')

    _core.app.get('/admin/api/stats', (req, res) => {
      _core.log.print(_core.log.RUN, '[stats] ENTER GET /admin/api/stats')
      req.app.locals.adminSession(req, res, () => {
        const caches = {}
        Object.keys(_core.dbCaches).forEach(name => {
          const c = _core.dbCaches[name]
          if(typeof c.stats === 'function') try { caches[name] = c.stats() } catch(e) { caches[name] = { error: e.message } }
        })
        res.json({ caches: caches })
        _core.log.print(_core.log.RUN, '[stats] LEAVE GET /admin/api/stats')
      })
    })

    _core.log.print(_core.log.INFO, '[stats] GET /admin/api/stats registered.')
    _core.log.print(_core.log.RUN, '[stats] LEAVE _stats.init()')
  }

}

/* (WaTE) _stats.js v1.1.0 */
