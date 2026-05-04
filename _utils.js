/**
 * \file      (WaTE) _utils.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   1.2.2
 * \brief     Utilitaires partagés entre les modules internes du moteur WaTE.
 *
 * \details   Préfixe '_' : module interne moteur, non destiné aux modules applicatifs.
 *            Importé via require('./_utils') depuis auth.js, db.js, et engine.js.
 *
 *            Principe : fonctions pures ou quasi-pures (crypto, Express res/req uniquement)
 *            sans dépendance aux globals engine (dbRequest, httpError, app, log,
 *            tableHooks). Ces globals restent dans les modules qui les consomment.
 *
 *            Remplace _helpers.js (v1.0.0) — renommé et étendu en v1.0.0 :
 *              + boundedCache  — déplacé depuis global._boundedCache (engine.js)
 *              + setCookie     — déplacé depuis auth.js
 *              + jsonResponder — déplacé depuis db.js
 *              + glossatyItem  — déplacé depuis engine.js
 *
 *            v1.0.3 : const des regex statiques évaluées une seule fois.
 *            v1.0.4 : generateCSRFToken contre les attaques Cross-Site Request Forgery.
 *            v1.0.5 : boundedCache — compteurs hits/misses/evictions + méthode stats().
 *            v1.1.0 : migration var → const/let + export _RE_TABLE.
 *            v1.2.0 : CSRF_SECRET + setCSRFSecret() — le token CSRF incorpore
 *                     un secret serveur (SHA256(sessionId + secret)). Le secret
 *                     est injecté par engine.js (WATE_CSRF_SECRET ou aléatoire).
 *                     Sans le secret, un attaquant ne peut pas forger de token.
 */

'use strict'

const crypto  = require('crypto')

const _RE_LANG = /[^a-z]/g
const _RE_NEXT = /^\/[a-zA-Z0-9/_-]*$/

/**
 * \var CSRF_SECRET
 * \brief Secret serveur pour le hachage CSRF — configuré via setCSRFSecret().
 *        Tant qu'il n'est pas initialisé, generateCSRFToken retourne '' (sécurité).
 */
let CSRF_SECRET = ''

/**
 * \fn setCSRFSecret
 * \brief Initialise le secret CSRF (appelé par engine.js après chargement config).
 * \param secret  Secret (lu depuis _config ou généré aléatoirement)
 */
function setCSRFSecret(secret) {
  CSRF_SECRET = secret || ''
}

/**
 * \fn generateCSRFToken
 * \brief Dérive un token CSRF unique et déterministe à partir de l'ID de session
 *        et du secret serveur. SHA-256(sessionId + secret).
 *        Sans le secret, un attaquant connaissant le sessionId ne peut pas
 *        forger un token valide.
 *
 * \param sessionId  Identifiant de session (issu du cookie)
 * \return           Chaîne hexadécimale de 64 caractères, ou '' si absent
 */
function generateCSRFToken(sessionId) {
  // Note : CSRF_SECRET toujours initialisé par engine.js avant les routes. Défense en profondeur.
  if(!sessionId || sessionId === '0' || !CSRF_SECRET) return ''
  return crypto.createHash('sha256').update(String(sessionId) + CSRF_SECRET).digest('hex')
}

/**
 * \fn hasSession
 * \brief Vérifie si une session est active.
 *
 * \param req       Requête Express
 */
function hasSession(req) {
  return !!(req.cookies && req.cookies.session && typeof req.cookies.session === 'object' && req.cookies.session.id)
}

/**
 * \fn getSession
 * \brief Donne l'id et la classe d'expiratioin d'une session.
 *
 * \param req       Requête Express
 */
function getSession(req) {
  // FIX : id = '0' (string) cohérent avec _session.id TEXT
  const session = {id: '0', clause: ''}
  if(hasSession(req)) {
    session.id = req.cookies.session.id
    const ttl = req.app && req.app.locals.SESSION_TTL_S
    // Note : ttl est toujours un nombre (parseFloat) → clause = entier, pas d'injection SQL possible
    if(ttl !== undefined) { session.clause = ' AND S.issued > ' + (Math.floor(Date.now() / 1000) - ttl) }
  }
  return session
}

/**
 * \fn adminLang
 * \brief Extrait et sanitise le code langue depuis req.query.lang.
 *        Supprime tout caractère non-[a-z], tronque à 2 caractères.
 *        Retourne 'fr' si absent ou invalide.
 *
 * \param req  Requête Express
 * \return     Code langue 2 lettres (ex : 'fr', 'en')
 */
function adminLang(req) {
  // String() protège contre req.query.lang = ['fr','en'] (Express/qs array)
  return (String(req.query.lang || 'fr').replace(_RE_LANG, '').substring(0, 2)) || 'fr'
}

/**
 * \fn adminNext
 * \brief Extrait et valide l'URL de redirection depuis req.query.next ou req.body.next.
 *        Accepte uniquement les chemins relatifs (/alphanum/_/-) — évite l'open redirect.
 *
 * \param req          Requête Express
 * \param defaultPath  Chemin par défaut si next absent ou invalide
 * \return             Chemin validé ou defaultPath
 */
function adminNext(req, defaultPath) {
  const next = req.query.next || (req.body && req.body.next)
  if(next && _RE_NEXT.test(next)) return next
  return defaultPath || '/admin/form/auth/signin'
}

/**
 * \fn adminHashPassword
 * \brief Dérive un hash PBKDF2 du mot de passe SHA256 reçu du client.
 *        100 000 itérations, 64 octets, sha512.
 *        Sel déterministe = SHA256(email) — pas de stockage de sel séparé.
 *
 * \param sha256Password  SHA256 hex du mot de passe brut (calculé côté client)
 * \param email           Email de l'utilisateur (sert de sel)
 * \param callback        function(err, hashHex)
 */
function adminHashPassword(sha256Password, email, callback) {
  const salt = crypto.createHash('sha256').update(email).digest('hex')
  crypto.pbkdf2(sha256Password, salt, 100000, 64, 'sha512', (err, key) => {
    if(err) return callback(err)
    callback(null, key.toString('hex'))
  })
}

/**
 * \fn adminTimingSafeEqual
 * \brief Comparaison de chaînes en temps constant via XOR bit-à-bit.
 *        Protège contre les timing attacks sur la vérification de mot de passe.
 *        Les deux chaînes doivent avoir la même longueur — retourne false sinon.
 *
 * \param a  Première chaîne
 * \param b  Deuxième chaîne
 * \return   true si égales en temps constant, false sinon
 */
function adminTimingSafeEqual(a, b) {
  if(a.length !== b.length) return false
  let r = 0
  for(let i = 0; i < a.length; i++) r |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return r === 0
}

/**
 * \fn _boundedCache
 * \brief Factory d'un cache LRU à capacité bornée.
 *        Évite la croissance illimitée des caches en mémoire sur des applications
 *        à nombreuses pages ou tables.
 *
 * \param max  Nombre maximum d'entrées simultanées dans le cache
 * \return     Objet exposant get(key) et set(key, value)
 *
 * \details FIX v2.15.0 Implémentation via Map ES6 — l'ordre d'insertion est garanti par la spec.
 *          La politique d'éviction est LRU : l'entrée la moins récemment accédée
 *          ou modifiée est évincée en premier.
 *          get() et set() sont tous les deux O(1) : delete+set déplace la clé
 *          en fin de Map, map.keys().next() lit la clé de tête sans parcours.
 *          Map est disponible dès Node 4 — pas de risque de compatibilité.
 */
function boundedCache(max) {
  const map       = new Map()
  let hits      = 0
  let misses    = 0
  let evictions = 0
  return {
    /**
     * \fn get
     * \brief Retourne la valeur associée à la clé et la marque comme récemment utilisée.
     *        Incrémente hits si trouvée, misses sinon.
     *        Retourne undefined si la clé est absente.
     * \param k  Clé de recherche
     * \return   Valeur stockée ou undefined
     */
    get(k) {
      const v = map.get(k)
      if(v === undefined) { misses++; return undefined }
      hits++
      // Remonte en fin — delete + re-set préserve l'ordre d'insertion de Map.
      map.delete(k)
      map.set(k, v)
      return v
    },

    /**
     * \fn set
     * \brief Stocke une valeur et la marque comme récemment utilisée.
     *        Si la clé existe déjà, elle est réinsérée en fin (mise à jour LRU).
     *        Si le cache est plein et la clé est nouvelle, l'entrée la moins
     *        récemment utilisée (tête de Map) est évincée avant insertion.
     *        Incrémente evictions en cas d'éviction.
     * \param k  Clé
     * \param v  Valeur à stocker
     */
    set(k, v) {
      if(map.has(k)) {
        // Réinsertion en fin — met à jour l'ordre LRU sans changer la taille.
        map.delete(k)
      } else if(map.size >= max) {
        // map.keys().next().value : tête de Map = entrée la plus ancienne — O(1).
        map.delete(map.keys().next().value)
        evictions++
      }
      map.set(k, v)
    },

    /**
     * \fn stats
     * \brief Retourne les statistiques courantes du cache.
     * \return { hits, misses, evictions, size, max }
     */
    stats() {
      return { hits: hits, misses: misses, evictions: evictions, size: map.size, max: max }
    }
  }
}



/**
 * \fn glossaryItem
 * \brief Récupère un label traduit depuis le résultat d'une requête glossaire.
 *
 * \param result  Objet résultat contenant optionnellement _glossary.rows (tableau { tag, label })
 * \param tag     Identifiant du label à rechercher
 * \return        Label traduit si trouvé, sinon le tag brut
 */
function glossaryItem (result, tag) {
  // NOTE: hasOwnProperty sur objet interne (pas d'entrée externe). Accepté ANALYSIS v5 #24.
  const row = result.hasOwnProperty("_glossary") && result["_glossary"].rows.find(r => r.tag === tag)
  const _core = require('./_core')
  _core.log.print(_core.log.RUN, "glossaryItem(" + tag + ") = \"" + (row ? row.label : tag) + "\"")
  return row ? row.label : tag
}



/**
 * \fn setCookie
 * \brief Pose le cookie de session sur la réponse Express.
 *        Factorisé depuis auth.js — utilisé par _doSignin et les routes signin/form.
 *
 * \param res     Réponse Express
 * \param id      Identifiant de session (32 octets hex)
 * \param ttl     Durée de vie en secondes (défaut 3600 si undefined)
 * \param secure  true si la connexion est HTTPS (req.secure)
 */
function setCookie(res, id, ttl, secure) {
  res.cookie('session', {id}, {
    // Note : ttl=0 n'a pas de cas d'usage (session expirée immédiatement).
    // Le fallback || 3600 est intentionnel : undefined → 3600, 0 → 3600.
    maxAge   : (ttl || 3600) * 1000,
    httpOnly : true,
    secure   : secure,
    sameSite : 'lax'
  })
}

/**
 * \fn jsonResponder
 * \brief Construit un responder JSON standard pour les routes /admin/api/*.
 *        success()        → { ok: true }
 *        error(code, msg) → res.status(code).json({ error: msg })
 *        Factorisé depuis db.js — utilisé par toutes les routes API JSON CRUD.
 *
 * \param res  Réponse Express
 * \return     Objet { success, error }
 */
function jsonResponder(res) {
  return {
    success()          { res.json({ ok: true }) },
    error(code, msg) { res.status(code).json({ error: msg || 'error' }) }
  }
}

module.exports = {
  setCSRFSecret,
  generateCSRFToken,
  hasSession,
  getSession,
  adminLang,
  adminNext,
  adminHashPassword,
  adminTimingSafeEqual,
  boundedCache,
  glossaryItem,
  setCookie,
  jsonResponder,
  _RE_TABLE: /^[a-zA-Z0-9_]+$/
}

/* (WaTE) _utils.js v1.2.2 */