/**
 * \file      (WaTE) _log.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      06/03/2024
 * \version   2.2.3
 * \brief     Mise en forme des messages de trace et gestion du niveau de trace.
 *
 * \details   v2.1.1 : levelRank puissance de 2.
 *            v2.1.2 : Singleton au lieu de classe statique.
 *            v2.1.3 : (31 - Math.clz32(x)) remplace parseInt(Math.log2(x)).
 *            v2.1.4 : Garde-fou pour msgLevel = 0.
 *            v2.2.0 : Optimisations _getTimestamp() et Log.print().
 *            v2.2.1 : Harmonisation — arrow functions.
 *            v2.2.2 : FIX codes ANSI conditionnés à process.stdout.isTTY
 *                     — pas de bruit dans les logs redirigés vers fichier.
 *            v2.2.3 : Cache _isTTY au niveau module — évite un accès propriété
 *                     à chaque print().
 */
'use strict'

const _levelCodes = ['???', 'FTL', 'ERR', 'WRN', 'INF', 'DBG', 'RUN']
const _levelColors = ['5', '41', '31', '33', '39', '36', '7']

// FIX v2.2.3: isTTY caché au niveau module — évite un accès propriété à chaque print()
const _isTTY = process.stdout.isTTY
let _level = 0

/**
 * \brief   Donne la date/heure courante au format YYYY/MM/DD hh:mm:ss.ms.
 * \return  Chaîne timestamp formatée.
 */
const _getTimestamp = () => {
  const now = new Date()
  const m = now.getMonth() + 1
  const d = now.getDate()
  const h = now.getHours()
  const min = now.getMinutes()
  const s = now.getSeconds()
  const ms = now.getMilliseconds()

  return now.getFullYear() + (m < 10 ? '/0' : '/') + m + (d < 10 ? '/0' : '/') + d +
         (h < 10 ? ' 0' : ' ') + h + (min < 10 ? ':0' : ':') + min + (s < 10 ? ':0' : ':') + s +
         (ms < 10 ? '.00' : (ms < 100 ? '.0' : '.')) + ms
}

const Log = {

  FATAL: 1,
  ERROR: 2,
  WARNING: 4,
  INFO: 8,
  DEBUG: 16,
  RUN: 32,

  get level() {return _level},
  set level(level) {_level = level & 63},

  /**
   * \brief Affiche un message de log si le niveau est activé.
   * \param msgLevel Niveau du message (FATAL, ERROR, WARNING, INFO, DEBUG, RUN).
   * \note  Utilise `arguments` — doit rester function().
   */
  print(msgLevel) {
    let rank = 0
    const raw = msgLevel | 0
    if (raw > 0 && raw < 64) {
      rank = 32 - Math.clz32(raw & _level)
      if(rank == 0) return
    }
    const color = _isTTY
    let msg = _getTimestamp() + ' |' + (color ? '\x1b[' + _levelColors[rank] + ';1m' : '') + _levelCodes[rank] + (color ? '\x1b[0m| \x1b[' + _levelColors[rank] + 'm' : '| ')

    for(let i = 1; i < arguments.length; ++i) {
      const val = arguments[i]
      msg += typeof val === 'string' ? val : JSON.stringify(val)
    }
    // NOTE: pas de try-catch — crash stdout = arrêt propre. Accepté ANALYSIS v5 #11.
    process.stdout.write(msg + (color ? '\x1b[0m\n' : '\n'))
  }

}

module.exports = Log

/* (WaTE) _log.js v2.2.3 */
