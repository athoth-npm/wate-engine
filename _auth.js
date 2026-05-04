/**
 * \file      (WaTE) _auth.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   2.11.2
 * \brief     Module engine WaTE — gestion des sessions admin.
 *            Enregistre les routes /admin/api/auth/* et /admin/form/auth/*.
 *
 * \details   Chargé via init({ mod: ['auth=TTL'] }) ou --mod auth=TTL.
 *            TTL : durée de vie des sessions en secondes (optionnel).
 *
 *            Classe statique non-instantiable (comme Log).
 *            Propriétés injectées par engine.js avant register() :
 *              Auth.argv = argv
 *              Auth.EJSs = EJSs
 *
 *            Utilise les globals : dbRequest, httpError, tableHooks, app, _core.log.
 *            Exporte SESSION_TTL_S et adminSession pour db.js.
 *
 *            v1.0.0 : création initiale — API JSON /admin/api/auth/*.
 *            v1.1.0 : symétrie form/API — PUT/DELETE /admin/api/auth/me,
 *                     POST /admin/form/auth/*, _utils.adminNext.
 *            v2.0.0 : _userModify, signup, split GET routes, require('./db').
 *            v2.1.0 : _helpers.js, res dans _userSignin, GET /signin + /me.
 *            v2.2.0 : mode='me' dans admin-auth.ejs, fin d'admin-me.ejs.
 *            v2.3.0 : _helpers.js → _utils.js (+ boundedCache, setCookie, jsonResponder).
 *            v2.3.1 : FIX _userSignin : email/password bare → req.body.email/password.
 *                     FIX _userSignout : _core.hasSession → _utils.hasSession.
 *                     FIX _userSignup : _data.modifyTable → _data.modify.
 *            v2.4.0 : Renommage auth.js → _auth.js (convention module interne WaTE).
 *                     init(param) exporté — injecte SESSION_TTL_S, adminSession,
 *                     tableHooks['_user'] dans _core et enregistre toutes les routes
 *                     sur _core.app courant (appelé à chaque loadModules, pas au
 *                     require() — contourne le cache Node.js pour instances multiples).
 *                     done() exporté — réinitialise les injections à l'arrêt.
 *                     adminSession retiré de module.exports — accessible via _core.
 *                     FIX _core.hasSession → _utils.hasSession dans GET /signup.
 *                     _userSignup() factorise POST /admin/api/auth/signup et
 *                     POST /admin/form/auth/signup — diffèrent uniquement par le responder.
 *                     setCookie importé depuis _utils — supprime la fonction locale.
 *            v2.5.0 : adminSession, tableHooks['_user'], SESSION_TTL_S déplacés dans
 *                     app.locals (per-instance) — plus dans _core (singleton).
 *                     done() simplifié : app.locals détruits avec l'instance Express.
 *            v2.6.0 : _renderAuth charge langOptions depuis _lang et les passe à la vue.
 *                     hookHashPassword : delete password_confirm (champ UI, pas colonne DB).
 *            v2.7.0 : _renderAuth → res.render('common') au lieu de res.render('admin-auth').
 *                     GET routes simplifiées : appellent _data.serve(req, res).
 *                     jsHandlers enregistrés dans init() : auth:renderSignin/Signup/Me.
 *            v2.8.0 : _renderAuth supprimé — serve() fournit elements/result complets.
 *                     auth:renderMe supprimé — serve() rend directement (list 101 = query _user).
 *                     auth:renderSignin/Signup simplifiés : profil_id !== PROFIL_ANONYMOUS → redirect.
 *                     Routes GET /admin/form/auth/* supprimées — catch-all engine.js suffit.
 *            v2.8.1 : on utilise le CSRF token
 *            v2.8.2 : init() — SESSION_TTL_S : priorité param CLI, fallback _core.config['session.ttl'].
 *            v2.9.0 : Validation de compte par token + récupération par token.
 *                     - Table _user_token (kind='verify'|'reset') + _user.verified.
 *                     - Helpers : _makeToken (random + hash + insert), _consumeToken
 *                       (get + timing-safe compare + delete), _sendTokenMail.
 *                     - Signup : si _core.mail.isAvailable → verified=0, token verify
 *                       envoyé par email. Sinon verified=1 immédiat (comportement actuel).
 *                     - Signin : refuse si verified=0 (message account-not-verified).
 *                     - Routes ajoutées :
 *                         GET  /admin/form/auth/verify?token=…  — active le compte + redirect signin.
 *                         POST /admin/form/auth/forgot          — si mail dispo, crée un token reset.
 *                         POST /admin/api/auth/forgot           — idem version JSON.
 *                         POST /admin/form/auth/reset?token=…   — applique le nouveau mot de passe.
 *                         POST /admin/api/auth/reset            — idem version JSON.
 *                     - Dégradation sans nodemailer : forgot/reset répondent 404.
 *            v2.9.1 : Override per-instance — les handlers lisent mail via _mail(req),
 *                     qui préfère req.app.locals.mail si défini (stub de test) sinon
 *                     _core.mail. Permet d'avoir mail désactivé sur une instance et
 *                     activé sur une autre dans le même processus Node (utile pour
 *                     tester le protocole verify/forgot/reset sans SMTP réel).
 *            v2.9.2 : migration var → const/let.
 *            v2.10.0 : ajout POST /admin/api/auth/verify/resend —
 *                     renvoi du lien de vérification si le premier
 *                     email n'est pas arrivé. Anti-énumération
 *                     (toujours {ok:true}).
 *            v2.11.0 : rate limiting signin 10/min/IP, verified===0→!user.verified,
 *                     INSERT _session named columns, _makeToken/_consumeToken en
 *                     transactions, null password guard, done() unregisters _user hooks.
 *            v2.11.1 : FIX code d'erreur reset-invalid→verify-invalid sur GET /verify.
 *            v2.11.2 : FIX var→const sur email/lang, hash dummy adaptatif
 *                     (hash.length au lieu de 128), LEAVE déplacé dans
 *                     callback GET /verify, function(err)→(err)=> signin.
 */

'use strict'

const crypto  = require('crypto')
const _core   = require('./_core')
const _utils  = require('./_utils')

const _RE_HEX  = /^[0-9a-f]+$/
const _RE_BSN  = /\\n/g
const _data   = require('./_data')  // require au niveau module — modifyTable accédé dans
                                    // les handlers uniquement, après db.register(). Pas de
                                    // dépendance circulaire : db.js ne require pas auth.js.

// Rate limiting signin — anti-bruteforce (5 tentatives/min/IP)
const _signinAttempts = {}

// =============================================================================
// Helpers internes
// =============================================================================

// v2.9.1 — résolution mail per-instance : priorité à req.app.locals.mail (stub de
// test injecté par instance), fallback sur _core.mail (module singleton global).
function _mail(req) {
  // FIX v2.11.3 #31: garde-fou si mail non chargé — retourne objet inerte au lieu de undefined
  return (req && req.app && req.app.locals && req.app.locals.mail) || _core.mail || { isAvailable: false }
}

/**
 * \fn _userSignin
 * \brief Logique commune signin — vérification PBKDF2 + création session.
 *        Partagée entre POST /admin/api/auth/signin et POST /admin/form/auth/signin.
 *
 * \param req       Requête Express (pour req.secure)
 * \param res       Réponse Express (pour _utils.setCookie)
 * \param onOk      function(user) — appelée si authentification réussie
 * \param onFail    function(code, msg) — appelée en cas d'échec
 */
function _userSignin(req, res, onOk, onFail) {
  // FIX v2.11.3 #42: limite longueur password anti-DoS PBKDF2
  if(!req.body.email || !req.body.password) return onFail(400, 'email and password required')
  if(req.body.password.length > 1024) return onFail(400, 'password too long')

  // Rate limiting anti-bruteforce : 5 tentatives/min par IP
  const now = Date.now()
  const ip  = req.ip || (req.socket && req.socket.remoteAddress) || 'unknown'
  // Garde-fou mémoire : max 10000 IPs trackées (le cleanup évacue en 120s)
  if(!_signinAttempts[ip] && Object.keys(_signinAttempts).length > 10000) return onFail(429, 'too many requests')
  const b   = _signinAttempts[ip] || (_signinAttempts[ip] = { tokens: 10, last: now })
  const elapsed = (now - b.last) / 1000
  b.tokens = Math.min(10, b.tokens + elapsed * (10 / 60))
  b.last = now
  if(b.tokens < 1) {
    _core.log.print(_core.log.WARNING, 'Signin rate limit exceeded for IP ' + ip)
    return onFail(429, 'too many signin attempts')
  }
  b.tokens -= 1

  _core.dbRequest('get', 'SELECT password, lang_id, verified FROM _user WHERE email = ?', [req.body.email], (err, user) => {
    if(err) return onFail(500, err.message)

    _utils.adminHashPassword(req.body.password, req.body.email, (err, hash) => {
      if(err) return onFail(500, err.message)

      // Comparaison en temps constant — même durée si user inexistant
      // Guard : user.password peut être null (DB corrompue ou migration)
      if(!_utils.adminTimingSafeEqual(hash, (user && user.password) || '0'.repeat(hash.length))) {
        _core.log.print(_core.log.WARNING, 'Admin signin failed for \'' + req.body.email + '\'')
        return onFail(401, 'invalid credentials')
      }

      // v2.9.0 : compte non validé → refus. verified est 1 par défaut (migration),
      // 0 uniquement si le signup a pu envoyer un email de validation.
      // Note : retour 403 pour orienter l'utilisateur légitime vers verify/resend.
      // Un attaquant peut distinguer "email existe non vérifié" vs "email inexistant".
      if(user && !user.verified) {
        _core.log.print(_core.log.WARNING, 'Admin signin refused — account not verified: \'' + req.body.email + '\'')
        return onFail(403, 'account-not-verified')
      }

      const id     = crypto.randomBytes(32).toString('hex')
      const issued = Math.floor(Date.now() / 1000)
      _core.dbRequest('run', 'INSERT INTO _session (id, user_email, issued) VALUES(?,?,?)', [id, req.body.email, issued], (err) => {
        if(err) return onFail(500, err.message)
        _utils.setCookie(res, id, req.app.locals.SESSION_TTL_S, req.secure)
        _core.log.print(_core.log.INFO, 'Admin signin: \'' + req.body.email + '\'')
        user.sessionId = id  // On retient l'ID du cookie
        onOk(user)
      })
    })
  })
}

/**
 * \fn _userSignout
 * \brief Logique commune signout — suppression session + clearCookie.
 *        Idempotent : onDone() est appelé même si pas de session active.
 *        Partagée entre POST /admin/api/auth/signout et POST /admin/form/auth/signout.
 *
 * \param req    Requête Express
 * \param res    Réponse Express
 * \param onDone function() — appelée quand terminé
 */
function _userSignout(req, res, onDone) {
  if(!_utils.hasSession(req)) return onDone()

  _core.dbRequest('run', 'DELETE FROM _session WHERE id = ?', [req.cookies.session.id], function(err) {
    if(err) _core.log.print(_core.log.WARNING, 'signout delete session: ' + err.message)
    res.clearCookie('session')
    onDone()
  })
}

/**
 * \fn _userSignup
 * \brief Logique commune signup — INSERT dans _user via modifyTable.
 *        Factorise POST /admin/api/auth/signup et POST /admin/form/auth/signup —
 *        les deux routes ne diffèrent que par leur responder (JSON vs redirect).
 *        Le hook tableHooks['_user'].insert hashe le mot de passe avant l'INSERT.
 *        Droits contrôlés par _access (profil 1 = anonymous doit avoir insert/_user
 *        pour un signup public — non activé par défaut dans engine.sql).
 *
 *        v2.9.0 — si le module mail est disponible, force verified=0 avant INSERT,
 *        puis crée un token 'verify' et envoie l'email. Sinon, verified=1 par défaut
 *        de colonne, signin immédiatement possible.
 *
 * \param req       Requête Express (req.body doit contenir email, password, ...)
 * \param res       Réponse Express
 * \param responder { success(), error(code, msg) }
 */
function _userSignup(req, res, responder) {
  req.params.table   = '_user'
  req.params.request = 'insert'

  // FIX v2.11.3: whitelist colonnes signup — empêche mass assignment de profil_id, verified…
  req.body = { email: req.body.email, password: req.body.password, lang_id: req.body.lang_id }

  const mail       = _mail(req)
  const sendVerify = mail && mail.isAvailable
  if(sendVerify) req.body.verified = 0

  _data.modify(req, res, {
    success: function() {
      if(!sendVerify) return responder.success()
      // INSERT _user OK — on crée le token verify et on envoie l'email.
      // Un échec d'envoi ne casse pas le signup : le compte existe,
      // l'utilisateur pourra redemander un lien plus tard (feature possible).
      _sendTokenMail(req, req.body.email, 'verify', function(err) {
        if(err) _core.log.print(_core.log.ERROR, 'signup: envoi verify échoué pour ' + req.body.email + ': ' + err.message)
        responder.success()
      })
    },
    error: responder.error
  })
}

// =============================================================================
// Tokens verify / reset
// =============================================================================

/**
 * \fn _hashToken
 * \brief Retourne SHA-256(token) en hex — stocké en DB pour que la fuite de la
 *        base ne permette pas de rejouer les liens encore actifs.
 */
function _hashToken(t) { return crypto.createHash('sha256').update(t).digest('hex') }

/**
 * \fn _makeToken
 * \brief Génère un token aléatoire (32 octets hex), l'insère dans _user_token
 *        (hashé) pour l'email et le kind donnés, et retourne le clair au callback.
 *        Supprime d'abord les tokens existants du même kind pour cet utilisateur
 *        (un seul token actif à la fois par kind).
 *
 * \param req      Requête Express (pour résoudre le mail per-instance).
 * \param email    Utilisateur concerné.
 * \param kind     'verify' | 'reset'.
 * \param cb       function(err, clearToken, ttlSeconds)
 */
function _makeToken(req, email, kind, cb) {
  const clear = crypto.randomBytes(32).toString('hex')
  const hash  = _hashToken(clear)
  const ttl   = _mail(req).ttl(kind)
  const exp   = Math.floor(Date.now() / 1000) + ttl

  // Transaction : DELETE + INSERT atomique — évite orphelin si INSERT échoue
  _core.dbRequest('run', 'BEGIN', [], function(err) {
    if(err) return cb(err)
    _core.dbRequest('run', 'DELETE FROM _user_token WHERE user_email = ? AND kind = ?', [email, kind], function(err) {
      if(err) return _core.dbRequest('run', 'ROLLBACK', [], function() { cb(err) })
      _core.dbRequest('run',
        'INSERT INTO _user_token (token, user_email, kind, expires_at) VALUES (?, ?, ?, ?)',
        [hash, email, kind, exp],
        function(err) {
          if(err) return _core.dbRequest('run', 'ROLLBACK', [], function() { cb(err) })
          _core.dbRequest('run', 'COMMIT', [], function(err) {
            if(err) return cb(err)
            cb(null, clear, ttl)
          })
        }
      )
    })
  })
}

/**
 * \fn _consumeToken
 * \brief Vérifie un token soumis par l'utilisateur : récupère l'entrée par hash,
 *        vérifie le kind et l'expiration. Supprime l'entrée si valide.
 *        La comparaison utilise timing-safe sur le hash pour uniformiser la
 *        durée avec un token inexistant.
 *
 * \param clear  Token en clair (?token=… de l'URL ou du body).
 * \param kind   'verify' | 'reset'.
 * \param cb     function(err, email) — err non-null si invalide/expiré.
 */
// FIX v2.11.3 #160: consume=false → valide sans supprimer (pour TX atomique caller)
function _consumeToken(clear, kind, consume, cb) {
  // Backward compat: appel 3 args → (clear, kind, cb)
  if(typeof consume === 'function') { cb = consume; consume = true }
  if(typeof clear !== 'string' || clear.length !== 64 || !_RE_HEX.test(clear)) {
    return cb(new Error('invalid token'))
  }
  const hash = _hashToken(clear)
  const now  = Math.floor(Date.now() / 1000)
  _core.dbRequest('get', 'SELECT user_email, kind, expires_at FROM _user_token WHERE token = ?', [hash], (err, row) => {
    if(err) return cb(err)
    if(!row || row.kind !== kind || row.expires_at < now) return cb(new Error('invalid or expired'))
    if(!consume) return cb(null, row.user_email)
    _core.dbRequest('run', 'DELETE FROM _user_token WHERE token = ?', [hash], function(err) {
      if(err) return cb(err)
      cb(null, row.user_email)
    })
  })
}

/**
 * \fn _sendTokenMail
 * \brief Génère un token (via _makeToken), construit le lien verify/reset, récupère
 *        sujet+corps du glossaire selon la langue du user, et envoie l'email.
 *        Silencieux sur l'identité de l'utilisateur — _userForgot doit toujours
 *        répondre « ok » que l'email existe ou non (anti-enumeration).
 *
 * \param req    Requête Express (pour construire la base URL et lire la langue).
 * \param email  Destinataire.
 * \param kind   'verify' | 'reset'.
 * \param cb     function(err) — err si création token ou envoi échoue.
 */
function _sendTokenMail(req, email, kind, cb) {
  _makeToken(req, email, kind, (err, clear, ttl) => {
    if(err) return cb(err)

    const mail   = _mail(req)
    const lang   = _utils.adminLang(req)
    const base   = mail.baseUrl(req)
    const path   = (kind === 'verify') ? '/admin/form/auth/verify' : '/admin/form/auth/reset'
    const url    = base + path + '?token=' + clear + '&lang=' + lang
    const ttl_h  = Math.max(1, Math.floor(ttl / 3600))

    // Lookup des templates dans _glossary pour la langue courante.
    // Fallback sur 'fr' puis sur un template minimal si rien en DB.
    _core.dbRequest('all',
      'SELECT tag, label FROM _glossary WHERE lang_id = ? AND tag IN (?, ?)',
      [lang, 'mail-' + kind + '-subject', 'mail-' + kind + '-body'],
      (err, rows) => {
        if(err) return cb(err)
        const map = {}
        ;(rows || []).forEach(r => { map[r.tag] = r.label })
        const subject = map['mail-' + kind + '-subject'] || ('WaTE — ' + kind)
        let body    = map['mail-' + kind + '-body']    || ('{url}')
        // Le glossaire stocke '\n' littéraux — on les convertit en vrais sauts de ligne.
        body = body.replace(_RE_BSN, '\n').replace('{url}', url).replace('{ttl_h}', String(ttl_h))
        mail.send(email, subject, body).then(function() { cb(null) }).catch(cb)
      }
    )
  })
}

/**
 * \fn _userForgot
 * \brief Demande de récupération : si l'email existe en DB et que le module mail
 *        est dispo, génère un token 'reset' et l'envoie. Répond toujours « ok »
 *        à l'appelant (pas d'enumeration).
 *
 * \param req       Requête Express (req.body.email requis).
 * \param res       Réponse Express.
 * \param onDone    function() — toujours appelée (succès ou erreur silencieuse).
 */
function _userForgot(req, res, onDone) {
  if(!_mail(req).isAvailable) return onDone(new Error('mail module not loaded'))
  const email = req.body && req.body.email
  if(!email) return onDone()
  _core.dbRequest('get', 'SELECT email FROM _user WHERE email = ?', [email], (err, row) => {
    // On ignore les erreurs DB pour ne pas révéler de détails — on logge seulement.
    if(err) _core.log.print(_core.log.ERROR, 'forgot: DB error — ' + err.message)
    if(!row) { _core.log.print(_core.log.INFO, 'forgot: email inconnu (silencieux) — ' + email); return onDone() }
    _sendTokenMail(req, email, 'reset', function(err) {
      if(err) _core.log.print(_core.log.ERROR, 'forgot: envoi reset échoué — ' + err.message)
      onDone()
    })
  })
}

/**
 * \fn _userReset
 * \brief Applique un nouveau mot de passe après validation du token 'reset'.
 *
 * \param req       Requête Express (req.body.password + req.query.token | req.body.token).
 * \param res       Réponse Express.
 * \param onOk      function() — succès.
 * \param onFail    function(code, msg)
 */
// FIX v2.11.3 #160: DELETE token + UPDATE password dans la même TX
function _userReset(req, res, onOk, onFail) {
  if(!_mail(req).isAvailable) return onFail(404, 'not found')
  const token = (req.query && req.query.token) || (req.body && req.body.token)
  const pwd   = req.body && req.body.password
  if(!pwd)   return onFail(400, 'password required')
  if(!token) return onFail(400, 'token required')
  // Valider le token sans le supprimer (consume=false)
  _consumeToken(token, 'reset', false, (err, email) => {
    if(err) return onFail(400, 'reset-invalid')
    _utils.adminHashPassword(pwd, email, (err, hash) => {
      if(err) return onFail(500, err.message)
      // TX atomique : DELETE token + UPDATE password
      _core.dbRequest('run', 'BEGIN', [], function(err) {
        if(err) return onFail(500, err.message)
        _core.dbRequest('run', 'DELETE FROM _user_token WHERE token = ?', [_hashToken(token)], function(err) {
          if(err) return _core.dbRequest('run', 'ROLLBACK', [], function() { onFail(500, err.message) })
          _core.dbRequest('run', 'UPDATE _user SET password = ? WHERE email = ?', [hash, email], function(err) {
            if(err) return _core.dbRequest('run', 'ROLLBACK', [], function() { onFail(500, err.message) })
            _core.dbRequest('run', 'COMMIT', [], function(err) {
              if(err) return onFail(500, err.message)
              _core.log.print(_core.log.INFO, 'Password reset OK for ' + email)
              onOk()
            })
          })
        })
      })
    })
  })
}

/**
 * \fn _userModify
 * \brief Logique commune pour les opérations update-self/delete-self sur _user.
 *        Factorise PUT/DELETE /admin/api/auth/me et POST /admin/form/auth/me —
 *        les routes ne diffèrent que par leur responder et le flag redirect.
 *        L'email est toujours injecté depuis la SESSION — jamais du body client.
 *
 * \param request    'update-self' ou 'delete-self'
 * \param req        Requête Express
 * \param res        Réponse Express
 * \param responder  { success(), error(code, msg) }
 * \param redirect   true → redirect /admin/form/auth/signin si session absente
 */
function _userModify(request, req, res, responder, redirect) {
  _adminSession(req, res, function(user) {
    req.params.table   = '_user'
    req.params.request = request
    req.body.email     = user.email   // email de SESSION — jamais du body client
    _data.modify(req, res, responder)
  }, redirect)
}


/**
 * \fn _adminSession
 * \brief Middleware interne admin — vérifie la session et retourne le profil.
 *        Exporté pour être utilisé par db.js (via authMod.adminSession).
 *
 * \param req       Requête Express
 * \param res       Réponse Express
 * \param cb        function({ email, profil_id, lang_id })
 * \param redirect  true → redirect /admin/form/auth/signin ; false → 401 JSON
 */
function _adminSession(req, res, cb, redirect) {
  const session = _utils.getSession(req)
  if(session.id === '0') {
    if(redirect) return res.redirect('/admin/form/auth/signin?next=' + encodeURIComponent(req.path) + '&lang=' + _utils.adminLang(req))
    return res.status(401).json({ error: 'not authenticated' })
  }

  _core.dbRequest('get',
    'SELECT U.email, U.profil_id, U.lang_id FROM _session S INNER JOIN _user U ON S.user_email = U.email WHERE S.id = ?' + session.clause,
    [session.id],
    (err, user) => {
      if(err) {
        if(redirect) return _core.httpError(req, res, 500, err.message)
        return res.status(500).json({ error: err.message })
      }
      if(!user) {
        res.clearCookie('session')
        if(redirect) return res.redirect('/admin/form/auth/signin?next=' + encodeURIComponent(req.path) + '&lang=' + _utils.adminLang(req))
        return res.status(401).json({ error: 'session expired' })
      }
      cb(user)
  })
}

module.exports = {

  /**
   * \brief init(param) — appelé par loadModules après require().
   *        param : TTL des sessions en secondes (string, ex: '3600').
   *        Injecte SESSION_TTL_S, adminSession et tableHooks['_user'] dans _core.
   */
  init: function(param) {
    // Garde-fou double init : nettoie avant de réenregistrer
    if(this._signinCleanup) { clearInterval(this._signinCleanup); this._signinCleanup = null }
    // Priorité : param CLI (--mod auth=TTL) > _core.config['session.ttl'] (DB) > undefined.
    let ttl = parseFloat(param)
    if(isNaN(ttl) || ttl <= 0) ttl = parseFloat(_core.config['session.ttl'])
    _core.app.locals.SESSION_TTL_S = (!isNaN(ttl) && ttl > 0) ? ttl : undefined
    _core.log.print(_core.log.INFO, '[auth] SESSION_TTL_S = ' + (_core.app.locals.SESSION_TTL_S !== undefined ? _core.app.locals.SESSION_TTL_S + 's' : 'undefined'))
    _core.app.locals.adminSession = _adminSession
    _data.registerTableWriteHook('_user', 'insert', module.exports.hookHashPassword)
    _data.registerTableWriteHook('_user', 'update', module.exports.hookHashPassword)
    _core.log.print(_core.log.INFO, '[auth] tableHooks[\'_user\'] registered.')

    // Nettoyage périodique du bucket anti-bruteforce signin (toutes les 60s)
    this._signinCleanup = setInterval(() => {
      const cutoff = Date.now() - 120000
      Object.keys(_signinAttempts).forEach(ip => { if(_signinAttempts[ip].last < cutoff) delete _signinAttempts[ip] })
    }, 60000)

    // === API JSON ===

    _core.app.post('/admin/api/auth/signin', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/api/auth/signin')
      _userSignin(req, res,
        // FIX v2.8.1 : CSRF token
        user => { res.json({ ok: true, lang: user.lang_id || 'fr', csrf: _utils.generateCSRFToken(user.sessionId) }) },
        (code, msg) => { res.status(code).json({ error: msg }) }
      )
      _core.log.print(_core.log.RUN, 'LEAVE POST /admin/api/auth/signin')
    })

    _core.app.post('/admin/api/auth/signout', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/api/auth/signout')
      _userSignout(req, res, () => { res.json({ ok: true }) })
      _core.log.print(_core.log.RUN, 'LEAVE POST /admin/api/auth/signout')
    })

    _core.app.get('/admin/api/auth/me', function(req, res) {
      _adminSession(req, res, function(user) {
        const session = _utils.getSession(req) // <--- FIX v2.8.1 : Récupère la session courante pour le CSRF token
        res.json({ email: user.email, profil_id: user.profil_id, lang: user.lang_id || 'fr', csrf: _utils.generateCSRFToken(session.id) })
      })
    })

    _core.app.put('/admin/api/auth/me', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER PUT /admin/api/auth/me')
      _userModify('update-self', req, res, {
        success: () => { res.json({ ok: true }) },
        error:   (code, msg) => { res.status(code).json({ error: msg || 'error' }) }
      }, false)
      _core.log.print(_core.log.RUN, 'LEAVE PUT /admin/api/auth/me')
    })

    _core.app.delete('/admin/api/auth/me', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER DELETE /admin/api/auth/me')
      _userModify('delete-self', req, res, {
        success: function() { res.clearCookie('session'); res.json({ ok: true }) },
        error:   (code, msg) => { res.status(code).json({ error: msg || 'error' }) }
      }, false)
      _core.log.print(_core.log.RUN, 'LEAVE DELETE /admin/api/auth/me')
    })

    _core.app.post('/admin/api/auth/signup', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/api/auth/signup')
      _userSignup(req, res, {
        success: () => { res.json({ ok: true }) },
        error:   (code, msg) => { res.status(code).json({ error: msg || 'error' }) }
      })
      _core.log.print(_core.log.RUN, 'LEAVE POST /admin/api/auth/signup')
    })

    _core.app.post('/admin/api/auth/forgot', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/api/auth/forgot')
      if(!_mail(req).isAvailable) {
        res.status(404).json({ error: 'not found' })
        return _core.log.print(_core.log.RUN, 'LEAVE POST /admin/api/auth/forgot (mail disabled)')
      }
      _userForgot(req, res, function() {
        res.json({ ok: true })
        _core.log.print(_core.log.RUN, 'LEAVE POST /admin/api/auth/forgot')
      })
    })

    // Renvoi du lien de vérification — débloque un compte créé avec
    // verified=0 dont l'email de vérification initial n'est jamais arrivé.
    _core.app.post('/admin/api/auth/verify/resend', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/api/auth/verify/resend')
      if(!_mail(req).isAvailable) {
        res.status(404).json({ error: 'not found' })
        return _core.log.print(_core.log.RUN, 'LEAVE POST /admin/api/auth/verify/resend (mail disabled)')
      }
      const email = req.body && req.body.email
      if(!email) { res.status(400).json({ error: 'email required' }); return }
      _core.dbRequest('get', 'SELECT email, verified FROM _user WHERE email = ?', [email], (err, row) => {
        // Silencieux : ne révèle pas l'existence du compte (anti-énumération)
        if(err || !row || row.verified != 0) { res.json({ ok: true }); return }
        _sendTokenMail(req, email, 'verify', function(err2) {
          if(err2) _core.log.print(_core.log.ERROR, 'verify/resend: envoi échoué pour ' + email + ': ' + err2.message)
          res.json({ ok: true })
          _core.log.print(_core.log.RUN, 'LEAVE POST /admin/api/auth/verify/resend')
        })
      })
    })

    _core.app.post('/admin/api/auth/reset', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/api/auth/reset')
      _userReset(req, res,
        () => { res.json({ ok: true }) },
        (code, msg) => { res.status(code).json({ error: msg }) }
      )
      _core.log.print(_core.log.RUN, 'LEAVE POST /admin/api/auth/reset')
    })

    // === FORM ===

    _core.app.post('/admin/form/auth/signin', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/form/auth/signin')
      const lang = _utils.adminLang(req)
      const next = _utils.adminNext(req, '/admin/form/auth/me')
      _userSignin(req, res,
        function(user) { res.redirect(next + '?lang=' + (user.lang_id || lang)) },
        function(code, msg) {
          res.redirect('/admin/form/auth/signin?error=' + encodeURIComponent(msg) +
                        '&next=' + encodeURIComponent(next) + '&lang=' + lang)
        }
      )
      _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/auth/signin')
    })

    _core.app.post('/admin/form/auth/signout', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/form/auth/signout')
      _userSignout(req, res, function() {
        res.redirect('/admin/form/auth/signin?lang=' + _utils.adminLang(req))
      })
      _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/auth/signout')
    })

    _core.app.post('/admin/form/auth/me', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/form/auth/me')
      _userModify('update-self', req, res, {
        success: function() { res.redirect(_utils.adminNext(req, '/admin/form/auth/me') + '?lang=' + _utils.adminLang(req)) },
        error:   function(code, msg) { _core.httpError(req, res, code, msg) }
      }, true)
      _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/auth/me')
    })

    _core.app.post('/admin/form/auth/signup', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/form/auth/signup')
      const lang = _utils.adminLang(req)
      _userSignup(req, res, {
        success: function() { res.redirect(_utils.adminNext(req, '/admin/form/auth/signin') + '?lang=' + lang) },
        error:   function(code, msg) {
          res.redirect('/admin/form/auth/signup?error=' + encodeURIComponent(msg || 'error') + '&lang=' + lang)
        }
      })
      _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/auth/signup')
    })

    // GET /admin/form/auth/verify?token=… — active le compte et redirige vers signin.
    _core.app.get('/admin/form/auth/verify', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER GET /admin/form/auth/verify')
      const lang = _utils.adminLang(req)
      const tok = req.query && req.query.token
      _consumeToken(tok, 'verify', (err, email) => {
        if(err) {
          _core.log.print(_core.log.WARNING, 'verify: token invalide — ' + (tok || '(absent)'))
          return res.redirect('/admin/form/auth/signin?error=verify-invalid&lang=' + lang)
        }
        _core.dbRequest('run', 'UPDATE _user SET verified = 1 WHERE email = ?', [email], function(err) {
          if(err) return _core.httpError(req, res, 500, err.message)
          _core.log.print(_core.log.INFO, 'Account verified: ' + email)
          _core.log.print(_core.log.RUN, 'LEAVE GET /admin/form/auth/verify')
          res.redirect('/admin/form/auth/signin?info=account-verified&lang=' + lang)
        })
      })
    })

    // POST /admin/form/auth/verify/resend — renvoi lien vérification.
    _core.app.post('/admin/form/auth/verify/resend', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/form/auth/verify/resend')
      const lang = _utils.adminLang(req)
      if(!_mail(req).isAvailable) {
        _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/auth/verify/resend (mail disabled)')
        return _core.httpError(req, res, 404, 'not found')
      }
      const email = req.body && req.body.email
      if(!email) {
        return res.redirect('/admin/form/auth/signin?error=verify-resend-email-required&lang=' + lang)
      }
      _core.dbRequest('get', 'SELECT email, verified FROM _user WHERE email = ?', [email], (err, row) => {
        if(err || !row || row.verified != 0) {
          // Silencieux : toujours rediriger vers signin (anti-énumération)
          return res.redirect('/admin/form/auth/signin?info=verify-resend-ok&lang=' + lang)
        }
        _sendTokenMail(req, email, 'verify', function(err2) {
          if(err2) _core.log.print(_core.log.ERROR, 'verify/resend form: envoi échoué pour ' + email + ': ' + err2.message)
          _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/auth/verify/resend')
          res.redirect('/admin/form/auth/signin?info=verify-resend-ok&lang=' + lang)
        })
      })
    })

    // POST /admin/form/auth/forgot — demande de récupération (silencieuse).
    _core.app.post('/admin/form/auth/forgot', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/form/auth/forgot')
      const lang = _utils.adminLang(req)
      if(!_mail(req).isAvailable) {
        _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/auth/forgot (mail disabled)')
        return _core.httpError(req, res, 404, 'not found')
      }
      _userForgot(req, res, function() {
        res.redirect('/admin/form/auth/signin?info=forgot-sent&lang=' + lang)
        _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/auth/forgot')
      })
    })

    // POST /admin/form/auth/reset?token=… — applique le nouveau mot de passe.
    _core.app.post('/admin/form/auth/reset', function(req, res) {
      _core.log.print(_core.log.RUN, 'ENTER POST /admin/form/auth/reset')
      const lang = _utils.adminLang(req)
      _userReset(req, res,
        function() { res.redirect('/admin/form/auth/signin?info=reset-done&lang=' + lang) },
        function(code, msg) { res.redirect('/admin/form/auth/reset?error=' + encodeURIComponent(msg) + '&lang=' + lang) }
      )
      _core.log.print(_core.log.RUN, 'LEAVE POST /admin/form/auth/reset')
    })

    _core.log.print(_core.log.INFO, '[auth] routes registered.')
  },

  /**
   * \brief done() — appelé par _shutdown/_close à l'arrêt.
   *        Réinitialise les injections dans _core.
   */
  done: function() {
    if(this._signinCleanup) { clearInterval(this._signinCleanup); this._signinCleanup = null }
    _data.unregisterTableWriteHook('_user', 'insert')
    _data.unregisterTableWriteHook('_user', 'update')
    _core.log.print(_core.log.INFO, '[auth] done.')
  },

  /**
   * \brief hookHashPassword — hook tableHooks['_user'].insert/update.
   *        Hash PBKDF2 du mot de passe avant écriture en DB.
   *        email obligatoire dans req.body — utilisé comme sel.
   */
  hookHashPassword: function(req, next) {
    delete req.body.password_confirm  // champ de confirmation — pas une colonne _user
    if(!req.body.password || !req.body.email) return next()
    _utils.adminHashPassword(req.body.password, req.body.email, (err, hash) => {
      if(err) return next(err)
      req.body.password = hash
      next()
    })
  }

}

/* (WaTE) _auth.js v2.11.3 */