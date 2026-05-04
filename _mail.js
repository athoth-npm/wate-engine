/**
 * \file      (WaTE) _mail.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      19/04/2026
 * \version   1.1.0
 * \brief     Module engine WaTE — envoi d'emails transactionnels (nodemailer).
 *
 * \details   Dégradation gracieuse si nodemailer absent ou config incomplète.
 *            v1.0.0 : création initiale.
 *            v1.0.1 : refactoring et optimisation.
 *            v1.1.0 : harmonisation — arrow functions, logs RUN ENTER/LEAVE.
 */
'use strict'
const _core = require('./_core')

const _RE_BASE_URL = /\/+$/
const _defTTL = {verify: 604800, reset: 3600}

let _transporter = null
let _from        = ''
let _baseUrl     = ''
let _available   = false

/**
 * \brief Construit l'API mail — fermée sur l'état interne (_available, _transporter...).
 * \return Objet { isAvailable, send, ttl, baseUrl }.
 */
const _api = () => ({
  get isAvailable() { return _available },

  /**
   * \brief  Envoie un email texte. Rejette si le module est désactivé.
   * \param  to        Destinataire.
   * \param  subject   Sujet.
   * \param  text      Corps (texte brut).
   * \param  timeoutMs Timeout en ms (défaut 30000).
   * \return Promise<info>.
   */
  send(to, subject, text, timeoutMs) {
    _core.log.print(_core.log.RUN, 'ENTER _mail.send()')
    // Note : timeoutMs=0 (pas de timeout) n'a pas de cas d'usage réseau. || 30000 intentionnel.
    timeoutMs = timeoutMs || 30000
    return new Promise((resolve, reject) => {
      if(!_available || !_transporter) {
        return reject(new Error('mail module not available'))
      }
      let finished = false
      const timer = setTimeout(() => {
        if(!finished) {
          finished = true
          _core.log.print(_core.log.ERROR, '[mail] sendMail timeout after ' + timeoutMs + 'ms → ' + to)
          _core.log.print(_core.log.RUN, 'LEAVE _mail.send() (timeout)')
          reject(new Error('sendMail timeout'))
        }
      }, timeoutMs)
      _transporter.sendMail({ from: _from, to, subject, text }, (err, info) => {
        if(!finished) {
          finished = true
          clearTimeout(timer)
          if(err) {
            _core.log.print(_core.log.ERROR, '[mail] sendMail: ' + err.message)
            _core.log.print(_core.log.RUN, 'LEAVE _mail.send() (error)')
            return reject(err)
          }
          _core.log.print(_core.log.INFO, '[mail] sent → ' + to + ' : ' + subject)
          resolve(info)
          _core.log.print(_core.log.RUN, 'LEAVE _mail.send()')
        }
      })
    })
  },

  /**
   * \brief  Retourne le TTL (secondes) configuré pour un kind de token.
   * \param  kind 'verify' | 'reset'.
   * \return TTL en secondes.
   */
  ttl(kind) {
    const cfg = _core.config || {}
    const v   = parseInt(cfg['auth.' + kind + '.ttl'], 10)
    return (!isNaN(v) && v > 0) ? v : _defTTL[kind]
  },

  /**
   * \brief  Base URL pour construire les liens verify/reset.
   * \param  req Requête Express.
   * \return URL sans trailing slash.
   */
  baseUrl(req) {
    if(_baseUrl) return _baseUrl.replace(_RE_BASE_URL, '')
    return req ? req.protocol + '://' + req.get('host') : ''
  }
})

/**
 * \brief init() — charge nodemailer, crée le transporter. No-op si config absente.
 */
function init() {
  _core.log.print(_core.log.RUN, 'ENTER _mail.init()')
  const cfg = _core.config || {}
  _from    = cfg['mail.from']    || 'no-reply@localhost'
  _baseUrl = cfg['mail.baseUrl'] || ''

  if(!cfg['mail.smtp.host']) {
    _core.log.print(_core.log.INFO, '[mail] mail.smtp.host non défini — module désactivé (no-op).')
  } else {
    try {
      const nodemailer = require('nodemailer')
      const port   = parseInt(cfg['mail.smtp.port'], 10) || 587
      const secure = cfg['mail.smtp.secure'] === '1' || cfg['mail.smtp.secure'] === 1 || cfg['mail.smtp.secure'] === true
      const opts = { host: cfg['mail.smtp.host'], port, secure }
      if(cfg['mail.smtp.user']) opts.auth = { user: cfg['mail.smtp.user'], pass: cfg['mail.smtp.pass'] || '' }
      // FIX v1.0.1 #41: fermer l'ancien transporter avant double init()
if(_transporter) { try { _transporter.close() } catch(e) {} }
_transporter = nodemailer.createTransport(opts)
      _available   = true
      _core.log.print(_core.log.INFO, `[mail] transporter prêt — ${cfg['mail.smtp.host']}:${port} ${secure ? '(TLS)' : '(STARTTLS)'}, from=${_from}`)
    } catch(e) {
      if(e.code === 'MODULE_NOT_FOUND') {
        _core.log.print(_core.log.WARNING, '[mail] nodemailer absent — module désactivé : ' + e.message)
      } else {
        _core.log.print(_core.log.ERROR, '[mail] createTransport a échoué : ' + e.message)
      }
    }
  }

  _core.mail = _api()
  if(_core.app) _core.app.locals.mailAvailable = _available
  _core.log.print(_core.log.RUN, 'LEAVE _mail.init()')
}

/**
 * \brief done() — ferme le transporter SMTP.
 */
function done() {
  _core.log.print(_core.log.RUN, 'ENTER _mail.done()')
  if(_transporter && typeof _transporter.close === 'function') {
    try { _transporter.close() } catch(e) { /* ignore */ }
  }
  _transporter = null
  _available   = false
  _core.mail   = _api()
  if(_core.app) _core.app.locals.mailAvailable = false
  _core.log.print(_core.log.INFO, '[mail] done.')
  _core.log.print(_core.log.RUN, 'LEAVE _mail.done()')
}

module.exports = { init, done }

/* (WaTE) _mail.js v1.1.0 */
