/**
 * \file      (WaTE) _cron.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/09/2025
 * \version   1.1.1
 * \brief     Module optionnel --mod cron — purges périodiques (sessions, tokens, audit).
 *
 * \details   v1.0.0 : création initiale.
 *            v1.0.1 : double init() safe — done() appelé en début d'init().
 *            v1.1.0 : harmonisation — arrow functions, var→const/let,
 *                     Doxygen, logs RUN ENTER/LEAVE.
 *            v1.1.1 : FIX constante nommée PURGE_TOKENS_S (3600) au lieu
 *                     de l'intervalle hardcodé.
 */
'use strict'
const _core = require('./_core')

module.exports = {
  /**
   * \brief init() — planifie les purges périodiques.
   * \details Nettoie les timers existants (double init safe) puis lance
   *          les 3 purges immédiatement et les planifie.
   */
  init() {
    _core.log.print(_core.log.RUN, 'ENTER _cron.init()')
    if(this._timers) { this._timers.forEach(t => clearInterval(t)); this._timers = null }

    const purgeInterval = parseInt(_core.config['cron.purgeInterval'], 10) || 300

    /**
     * \brief Supprime les sessions expirées (hors session fantôme id='0').
     */
    const purgeSessions = () => {
      _core.log.print(_core.log.RUN, 'ENTER _cron.purgeSessions()')
      // Note : undefined si cron chargé avant auth. Le guard !ttl ci-dessous protège.
      const ttl = _core.app.locals.SESSION_TTL_S
      if(!ttl) return _core.log.print(_core.log.RUN, 'LEAVE _cron.purgeSessions() (no TTL)')
      const cutoff = Math.floor(Date.now() / 1000) - ttl
      _core.dbRequest('run', "DELETE FROM _session WHERE id != '0' AND issued < ?", [cutoff], err => {
        if(err) _core.log.print(_core.log.WARNING, '[cron] purge sessions: ' + err.message)
        else _core.log.print(_core.log.INFO, '[cron] purge sessions OK')
        _core.log.print(_core.log.RUN, 'LEAVE _cron.purgeSessions()')
      })
    }

    /**
     * \brief Supprime les tokens verify/reset expirés.
     */
    const purgeTokens = () => {
      _core.log.print(_core.log.RUN, 'ENTER _cron.purgeTokens()')
      const now = Math.floor(Date.now() / 1000)
      _core.dbRequest('run', 'DELETE FROM _user_token WHERE expires_at < ?', [now], err => {
        if(err) _core.log.print(_core.log.WARNING, '[cron] purge tokens: ' + err.message)
        else _core.log.print(_core.log.INFO, '[cron] purge tokens OK')
        _core.log.print(_core.log.RUN, 'LEAVE _cron.purgeTokens()')
      })
    }

    /**
     * \brief Supprime les enregistrements d'audit au-delà de la rétention.
     */
    const purgeAudit = () => {
      _core.log.print(_core.log.RUN, 'ENTER _cron.purgeAudit()')
      // Note : changed_at (DEFAULT strftime('%s')) et cutoff (Date.now()/1000)
      // sont tous les deux en secondes Unix. La comparaison est correcte.
      const retention = parseInt(_core.config['cron.auditRetention'], 10) || (90 * 24 * 3600)
      const cutoff = Math.floor(Date.now() / 1000) - retention
      _core.dbRequest('run', 'DELETE FROM _audit WHERE changed_at < ?', [cutoff], err => {
        if(err) _core.log.print(_core.log.WARNING, '[cron] purge audit: ' + err.message)
        else _core.log.print(_core.log.INFO, '[cron] purge audit OK')
        _core.log.print(_core.log.RUN, 'LEAVE _cron.purgeAudit()')
      })
    }

    const PURGE_TOKENS_S = 3600
    const timers = []
    timers.push(setInterval(purgeSessions, purgeInterval * 1000))
    timers.push(setInterval(purgeTokens, PURGE_TOKENS_S * 1000))
    timers.push(setInterval(purgeAudit, 24 * 3600 * 1000))
    purgeSessions(); purgeTokens(); purgeAudit()
    this._timers = timers
    _core.log.print(_core.log.INFO, '[cron] tasks scheduled')
    _core.log.print(_core.log.RUN, 'LEAVE _cron.init()')
  },

  /**
   * \brief done() — stoppe les timers et désactive les purges.
   */
  done() {
    _core.log.print(_core.log.RUN, 'ENTER _cron.done()')
    if(this._timers) { this._timers.forEach(t => clearInterval(t)); this._timers = null }
    _core.log.print(_core.log.INFO, '[cron] done.')
    _core.log.print(_core.log.RUN, 'LEAVE _cron.done()')
  }
}

/* (WaTE) _cron.js v1.1.1 */

