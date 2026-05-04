/**
 * \file      (WaTE) _core.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   1.4.4
 * \brief     Registre central du moteur WaTE (State Manager).
 *
 * \details   v1.0.1 : FIX httpError : arrow function → function ordinaire (this était undefined) ;
 *                     module.exports = Core (était manquant — objet littéral non référençable par son nom) ;
 *                     toutes les références this.* → Core.*.
 *            v1.0.2 : adminSession, tableHooks, SESSION_TTL_S retirés du singleton —
 *                     état per-instance déplacé dans app.locals (Express).
 *            v1.1.0 : jsHandlers — registre des fonctions JS appelables depuis _item key='JS'.
 *                     Peuplé par les modules dans leur init(), consulté par pageData.
 *            v1.2.0 : Caches commun pour _data.ejs et _db.js + fonction dbRequestCache().
 *                     const du regex statique évaluée une seule fois.
 *            v1.2.1 : Sanitisation de msg dans httpError — longueur max 120 chars,
 *                     filtre les caractères non imprimables pour éviter les fuites
 *                     d'informations SQLite côté client (chemins, schéma, etc.).
 *            v1.3.0 : dbCaches.queries ajouté — cache LRU des queries JSON (_data.js),
 *                     remplace la variable locale _queriesCache de _data.js.
 *                     config: {} ajouté — hydraté par engine.js depuis _config (DB)
 *                     après migration et avant chargement des modules.
 *            v1.4.0 : dbRequest est définie ici et _db est initialisée par injection de engine.js via setter.
 *            v1.4.1 : mail.isAvailable exposé comme propriété booléenne (état statique)
 *                     et non plus méthode — cohérent avec le getter de _mail.js.
 *            v1.4.2 : var → const/let. _RE_LANG retiré → _utils.adminLang(req).
 *            v1.4.3 : dbRequest callback wrappé try-catch —
 *                     évite crash si un callback lance une exception.
 *            v1.4.4 : FIX dbRequest — LEAVE déplacé dans le callback
 *                     asynchrone (était synchrone avant l'exécution SQL).
 *
 * \note      Remplace l'utilisation de l'objet `global` de Node.js.
 *            Ce fichier contient l'état de l'application pendant son exécution.
 *            Les dépendances lourdes (app, dbRequest, etc.) sont injectées par engine.js.
 *            Les autres modules (auth.js, _data.js) importent _core.js pour y accéder.
 */

'use strict'

const _utils = require('./_utils')

  /** \brief Map statique des erreurs HTTP */
const _HTTP_ERRORS = {
  400: { tag: 'error-bad-request',        image: 'stop.png',      redirect: 'back' },
  401: { tag: 'error-unauthorized',       image: 'forbidden.png', redirect: 'root' },
  403: { tag: 'error-forbidden',          image: 'forbidden.png', redirect: 'back' },
  404: { tag: 'error-not-found',          image: 'danger.png',    redirect: 'back' },
  405: { tag: 'error-method-not-allowed', image: 'stop.png',      redirect: 'back' },
  410: { tag: 'error-gone',               image: 'danger.png',    redirect: 'root' },
  413: { tag: 'error-too-large',          image: 'stop.png',      redirect: 'back' },
  429: { tag: 'error-too-many-requests',  image: 'stop.png',      redirect: 'none' },
  500: { tag: 'error-internal',           image: 'noway.png',     redirect: 'none' },
  502: { tag: 'error-bad-gateway',        image: 'noway.png',     redirect: 'none' },
  503: { tag: 'error-unavailable',        image: 'noway.png',     redirect: 'none' },
  504: { tag: 'error-timeout',            image: 'noway.png',     redirect: 'none' }
}

// REGEX statiques — _RE_LANG retiré, utilise _utils.adminLang(req)
// Note : \p{L} non supporté avant Node 10 — on garde \w qui couvre l'ASCII étendu.
const _RE_MSG_SAFE = /[^\w\s.,:;!\-'()_]/g

/**
 * \const _glossaryCache
 * \brief Cache des labels de glossaire par code langue (LRU borné à 20 entrées).
 *        Clé = code langue ('fr', 'en'...). Invalidé au redémarrage uniquement.
 *        FIX v2.11.0 : évite un SELECT _glossary à chaque appel httpError.
 *        FIX v2.14.0 : borné via _boundedCache.
 */
const _glossaryCache = _utils.boundedCache(20)

// propriété privée seulement initialisée une fois par engine.js
let _db = null

const Core = {
  
  // ===========================================================================
  // 1. DÉPENDANCES DIRECTES (Stateless)
  // ===========================================================================
  
  /** \brief Instance du logger (disponible immédiatement) */
  log: require('./_log'),

  // ===========================================================================
  // 2. INJECTIONS (Peuplées par engine.js au démarrage)
  // ===========================================================================

  /** \brief Instance Express globale */
  app: null,

  /** \brief Arguments de la ligne de commande parsés */
  path: '',

  /** \brief Arguments de la ligne de commande parsés */
  root: undefined,

  /** \brief Modules EJS chargés */
  EJSs: null,

  /**
   * \brief API du module mail (remplacée par _mail.js à son init()).
   *        Valeur par défaut = module désactivé — permet aux autres modules
   *        de l'appeler sans check d'existence.
   */
  mail: {
    isAvailable: false,
    send:        function() { return Promise.reject(new Error('mail module not loaded')) },
    ttl:         function(kind) { return kind === 'verify' ? 604800 : 3600 },
    baseUrl:     function(req) { return req ? (req.protocol + '://' + req.get('host')) : '' }
  },

  /**
   * \brief Paramètres moteur lus depuis la table _config après migration.
   *        Hydraté par engine.js avant loadModules — accessible dans init() des modules.
   *        Clés : 'session.ttl', 'cache.tableInfo', 'cache.fkList', 'cache.queries',
   *               'upload.maxFileSize', 'upload.maxFiles', 'db.defaultLimit', 'db.maxLimit'.
   */
  config: {},

  dbCaches: {
    tableInfo: _utils.boundedCache(100),
    fkList:    _utils.boundedCache(100),
    /** \brief Cache LRU des queries JSON par clé url:profil_id — partagé avec _data.js. */
    queries:   _utils.boundedCache(200)
  },

  // L'accesseur "Write-Only" (écriture seule). Le handle DB n'est jamais remplacé
  // — évite qu'une seconde instance écrase le handle partagé entre instances.
  set db(db) {if(!_db) _db = db},

  /**
   * \fn dbRequest
   * \brief Envoie un ordre à la base de données SQLite.
   *
   * \param call      Méthode sqlite3 à appeler ('run', 'get', 'all')
   * \param request   Chaîne SQL paramétrée
   * \param values    Tableau des valeurs de substitution
   * \param callback  Fonction de rappel(err, result)
   */
  // NOTE : niveau RUN = debug — les valeurs (mots de passe, tokens, emails)
  // sont visibles dans les logs. À utiliser uniquement en développement.
  // NOTE : err.message SQLite est parfois renvoyé au client (contient noms
  // de tables/colonnes). Accepté en usage interne, à masquer en prod publique.
  dbRequest: function(call, request, values, callback) {
    if (!_db) return callback(new Error("Database not initialized"))
    // FIX v1.4.4: LEAVE déplacé dans le callback asynchrone — était synchrone avant exécution SQL
    Core.log.print(Core.log.RUN, 'ENTER dbRequest(db.' + call + '(\'' + request + '\', ' + JSON.stringify(values) + ')')
    _db[call](request, values, (err, result) => {
      Core.log.print(Core.log.RUN, 'LEAVE dbRequest()')
      try { callback(err, result) } catch(e) { Core.log.print(Core.log.ERROR, 'dbRequest callback exception: ' + e.message) }
    })
  },

  /**
   * \fn dbRequestCache
   * \brief Exécute une requête DB ou retourne le résultat depuis le cache fourni.
   *
   * \param cacheObj L'objet cache (ex: _utils.boundedCache)
   * \param cacheKey La clé unique pour cette requête
   * \param call     Méthode sqlite3 ('run', 'get', 'all')
   * \param request  Chaîne SQL
   * \param values   Tableau des valeurs
   * \param callback Fonction de rappel (err, result)
   */
  dbRequestCache: function(cacheObj, cacheKey, call, request, values, callback) {
    const cached = cacheObj.get(cacheKey)
    if (cached !== undefined) {
      return callback(null, cached)
    }
    
    Core.dbRequest(call, request, values, (err, result) => {
      if (!err && result !== undefined) {
        cacheObj.set(cacheKey, result)
      }
      callback(err, result)
    })
  },

  /**
   * \brief Registre des handlers JS appelables via _item key='JS', value='module:fonction'.
   *        Peuplé par chaque module dans son init() :
   *          _core.jsHandlers['auth:renderSignin'] = function(req, res, elements, result) {...}
   *        Consulté par pageData après chargement des _item.
   *        Vérifié au démarrage — une clé manquante lève une erreur à l'init, pas à runtime.
   */
  jsHandlers: {},

  // ===========================================================================
  // 3. FONCTIONS MÉTIERS (Qui dépendent de l'état du Core)
  // ===========================================================================

  /**
   * \fn httpError
   * \brief Rendu direct de la page d'erreur.
   *        Déplacé depuis engine.js pour l'alléger. 
   *        Utilise Core.argv, Core.dbRequest, etc.
   */
  httpError: function(req, res, code, msg, next) {
    // Guard : si une réponse est déjà en cours, on annule.
    if(res.headersSent) {
      Core.log.print(Core.log.ERROR, 'httpError(' + code + ') — headers already sent, aborting render')
      return
    }

    Core.log.print(Core.log.ERROR, 'HTTP ' + code + (msg ? ' — ' + msg : ''))

    const lang      = _utils.adminLang(req)
    const entry = _HTTP_ERRORS[code] || { tag: 'error-unknown', image: 'noway.png', redirect: 'none' }
    const errorNext = (next !== undefined) ? next : entry.redirect

    // Sanitisation : filtre les caractères non imprimables et limite la longueur
    // pour éviter d'exposer les détails internes SQLite (chemins, contraintes FK, etc.).
    const safeMsg = msg ? String(msg).replace(_RE_MSG_SAFE, '').substring(0, 120) : ''

    function render(result) {
      res.status(code).render('error', {
        req,
        path: Core.path,
        EJSs: Core.EJSs,
        lang,
        elements  : {},
        result    : result,
        errorCode : code,
        errorMsg  : safeMsg,
        errorImage: entry.image,
        errorTag  : entry.tag,
        errorNext : errorNext,
        rootRoute : Core.root
      })
    }

    // 1. On cherche d'abord dans le cache du Core
    const cached = _glossaryCache.get(lang)
    if(cached) return render({ _glossary: { rows: cached } })

    // 2. Sinon on interroge la DB
    Core.dbRequest('all', 'SELECT tag, label FROM _glossary WHERE lang_id = ? AND tag LIKE \'error-%\'', [lang], (err, rows) => {
      if(!err && rows && rows.length > 0) {
        _glossaryCache.set(lang, rows);
      }
      render(err ? {} : { _glossary: { rows: rows || [] } })
    })
  }

}

module.exports = Core

/* (WaTE) _core.js v1.4.4 */