/**
 * \file      test-mail.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-24
 * \version   1.0.0
 * \brief     Module applicatif de test — stub mail + endpoint d'inspection.
 *
 * \details   Chargé via --mod=test-mail par test/app.js (port 3005 uniquement).
 *            - Injecte un stub mail dans app.locals.mail (isAvailable=true,
 *              send() capture chaque envoi dans _mailBox).
 *            - Enregistre GET /test/mail-last[?to=email] pour que test-wate.sh
 *              récupère l'URL avec le token sans accéder à la DB.
 *
 *            Passer par un module applicatif garantit que la route est
 *            enregistrée AVANT app.get('*') de engine.js — sinon le catch-all
 *            la masque et renvoie une page HTML 404 au lieu du JSON.
 */

'use strict'

const _mailBox = []

const mailStub = {
  isAvailable: true,
  send: function(to, subject, text) {
    _mailBox.push({ to: to, subject: subject, text: text })
    console.log('[test-mail] → ' + to + ' : ' + subject)
    return Promise.resolve({ stub: true })
  },
  ttl: function(kind) { return kind === 'verify' ? 604800 : 3600 },
  baseUrl: function(req) { return req ? (req.protocol + '://' + req.get('host')) : '' }
}

exports.init = function(param, api) {
  // Capture de api.app au moment de l'init — _core.app est un singleton
  // réécrasé à chaque start() en mode multi-instance (test/app.js).
  const myApp = api.app
  myApp.locals.mail = mailStub

  myApp.get('/test/mail-last', function(req, res) {
    let box = _mailBox
    if(req.query.to) box = box.filter(function(m) { return m.to === req.query.to })
    const last = box[box.length - 1]
    if(!last) return res.status(404).json({ error: 'no mail' })
    res.json(last)
  })

  api.log.print(api.log.INFO, '[test-mail] stub mail actif + GET /test/mail-last')
}

/* test-mail.js v1.0.0 */
