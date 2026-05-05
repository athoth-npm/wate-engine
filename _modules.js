/**
 * \file      (WaTE) _modules.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   1.3.5
 * \brief     Module engine WaTE — chargement des modules externes.
 *
 * \details   v1.3.5 : @typedef _WATE_API aligné sur l'objet réel (renderPage, renderError,
 *                     db, hooks). Retrait des propriétés inexistantes. load() Doxygen corrigé.
 *            Syntaxe unifiée (--mod et --ejs) : name[:alias][=param].
 *            v1.0.1 : injection _core pour variables globales.
 *            v1.1.0 : _WATE_API (façade pour modules applicatifs).
 *            v1.2.0 : parseNames() — extraction noms sans chargement.
 *            v1.2.1 : var → const/let.
 *            v1.2.2 : API restreinte pour --ejs.
 *            v1.3.0 : harmonisation — arrow functions, logs RUN ENTER/LEAVE.
 *            v1.3.1 : FIX _REGEX_PARAM — [\s\S]*? → [^,]* élimine le risque
 *                     de backtracking catastrophique sur entrée malveillante.
 *            v1.3.3 : FIX .catch() sur Promise.race — évite que load() pende
 *                     si un init() asynchrone rejette (timeout 10 s).
 *            v1.3.4 : Documentation — JSDoc complet sur _WATE_API (@typedef
 *                     avec les 9 propriétés) et load() (paramètres, validation,
 *                     cycle de vie, timeout, path traversal).
 */
'use strict'
const _core = require('./_core')
const _data = require('./_data')

const _REGEX_PARAM = /(?:^|,)\s*([\w.\-/@]+)(?::([\w.\-/@]+))?(?:=([^,]*))?(?=\s*(?:,|$))/g

/**
 * \const _ENGINE_MODS
 * \brief Noms des modules engine intégrés.
 */
const _ENGINE_MODS = ['auth', 'db', 'stats', 'log', 'utils', 'mail', 'audit', 'search', 'apikey', 'cron']



/**
 * @typedef {Object} _WATE_API
 * @brief API interne exposée à chaque module lors de son initialisation.
 *
 * Passée en argument à module.init(api). Donne accès aux primitives du moteur
 * sans exposer les internals (_core, db brut).
 *
 * @property {import('express').Application} app
 *   Instance Express partagée. Permet d'enregistrer des routes supplémentaires.
 *   app.locals.tableHooks  : registre des hooks d'écriture.
 *   app.locals.jsHandlers  : handlers JS côté client.
 *   app.locals.SESSION_TTL_S : TTL de session en secondes.
 *
 * @property {Object} hooks
 *   Registre des hooks.
 *   @property {Function} hooks.onPageLoad(name, callback)
 *     Injecte des données avant le rendu EJS d'une page.
 *     @param {string}   name     - Nom du hook.
 *     @param {Function} callback - function(req, elements).
 *   @property {Function} hooks.onTableWrite(tableName, action, callback)
 *     Intercepte INSERT/UPDATE/DELETE sur une table.
 *     @param {string}   tableName - Nom de la table.
 *     @param {string}   action    - 'insert' | 'update' | 'delete'.
 *     @param {Function} callback  - function(req, next) appelée avant l'écriture.
 *
 * @property {Function} renderPage(req, res, targetUrl?, extraData?)
 *   Force le rendu d'une page DB via _data.serve().
 *
 * @property {Function} renderError(req, res, code, msg, nextUrl?)
 *   Force le rendu d'une page d'erreur.
 *
 * @property {Object} db
 *   Accès direct à la base de données (read-only).
 *   @property {Function} db.run(sql, params, callback)
 *   @property {Function} db.all(sql, params, callback)
 *   @property {Function} db.get(sql, params, callback)
 *
 * @property {Object} log
 *   Logger interne. Méthodes : log.INFO(msg), log.WARN(msg), log.ERROR(msg).
 */
const _WATE_API = {
  log: _core.log,

  get app() { return _core.app },

  /**
   * \brief  Force le rendu d'une page DB.
   * \param  req       Requête Express.
   * \param  res       Réponse Express.
   * \param  targetUrl URL de la page (défaut req.path).
   * \param  extraData { key, value } optionnel.
   */
  renderPage(req, res, targetUrl, extraData) {
    if(!targetUrl) targetUrl = req.path
    _data.serve(req, res, extraData, targetUrl)
  },

  /**
   * \brief  Force le rendu d'une page d'erreur.
   * \param  req     Requête Express.
   * \param  res     Réponse Express.
   * \param  code    Code HTTP.
   * \param  msg     Message.
   * \param  nextUrl URL de redirection.
   */
  renderError(req, res, code, msg, nextUrl) {
    _core.httpError(req, res, code, msg, nextUrl)
  },

  db: {
    run: _core.dbRequest.bind(null, 'run'),
    all: _core.dbRequest.bind(null, 'all'),
    get: _core.dbRequest.bind(null, 'get')
  },

  hooks: {
    /**
     * \brief  Enregistre un hook onPageLoad.
     * \param  name     Nom du hook.
     * \param  callback Fonction à appeler.
     */
    onPageLoad(name, callback) {
      if(typeof callback !== 'function') throw new Error("Hook doit être une fonction")
      _data.registerPageLoadHook(name, callback)
    },
    /**
     * \brief  Enregistre un hook onTableWrite.
     * \param  tableName Table cible.
     * \param  action    'insert' | 'update' | 'delete'.
     * \param  callback  Fonction à appeler.
     */
    onTableWrite(tableName, action, callback) {
      if(typeof callback !== 'function') throw new Error("Hook doit être une fonction")
      _data.registerTableWriteHook(tableName, action, callback)
    }
  }
}



/**
 * @brief Charge un module WaTE et lui injecte l'API du moteur.
 *
 * Résout le module depuis son nom, appelle module.init(api) de façon asynchrone
 * avec un timeout de 5 secondes. Enregistre module.done() pour le shutdown propre.
 * Les noms de module sont validés contre /^[a-zA-Z0-9_-]+$/ (anti path-traversal).
 *
 * @param {string}   flag     - Type de module : 'mod' | 'ejs'.
 * @param {string}  [rawInput] - Entrée brute (ex: 'auth=3600' ou 'auth,db').
 * @param {string}   appPath  - Chemin racine de l'application (pour résoudre les modules locaux).
 *
 * @returns {Promise<Object>} Objet { alias: module } contenant les modules chargés.
 * @throws {Error} Si un nom contient '..', le module est introuvable,
 *                 ou si init() dépasse le timeout de 10 secondes.
 */
function load(flag, rawInput, appPath) { return new Promise((resolve, reject) => {
  _core.log.print(_core.log.RUN, 'ENTER _modules.load(' + flag + ')')
  try {
    const mods = {}
    const _initPromises = []
    if(rawInput === undefined) {
      _core.log.print(_core.log.RUN, 'LEAVE _modules.load() (no input)')
      return resolve(mods)
    }

    let input = ''
    if(Array.isArray(rawInput)) {
      input = rawInput.join(',')
    } else if(typeof rawInput === 'string') {
      input = rawInput
    } else {
      _core.log.print(_core.log.FATAL, 'Invalid modules list after --' + flag + ' !')
      throw new Error('Invalid modules list after --' + flag + ' !')
    }

    _REGEX_PARAM.lastIndex = 0  // reset (regex /g global, lastIndex persiste entre appels)
    let match
    while((match = _REGEX_PARAM.exec(input)) !== null) {
      const name = match[1]
      // Garde-fou : pas de path traversal via --mod
      if(name.indexOf('/') >= 0 || name.indexOf('\\') >= 0 || name === '..' || name.indexOf('../') >= 0) {
        _core.log.print(_core.log.FATAL, '[' + flag + '] Invalid module name (path traversal): "' + name + '"')
        continue
      }
      const alias = match[2] || name

      let param
      try { param = JSON.parse(match[3]) } catch(e) { param = match[3] }

      if(Object.prototype.hasOwnProperty.call(mods, alias)) {
        _core.log.print(_core.log.WARNING, '[' + flag + '] "' + alias + '" already loaded !')
        continue
      }

      const logParam = match[3] !== undefined ? ' (param=' + match[3] + ')' : ''
      const logAlias = alias !== name ? ' as "' + alias + '"' : ''
      _core.log.print(_core.log.INFO, '[' + flag + '] Loading "' + name + '"' + logAlias + logParam + '...')

      const modPath = (_ENGINE_MODS.indexOf(name) >= 0)
              ? (__dirname + '/_' + name)
              : (process.cwd() + '/' + appPath + 'scripts/' + name)

      const loaded = require(modPath)
      mods[alias] = loaded

      if(typeof loaded.init === 'function') {
        _core.log.print(_core.log.INFO, '[' + flag + '] "' + alias + '" init(...)')
        const ret = loaded.init(param, flag === 'ejs' ? { log: _WATE_API.log, get app() { return _WATE_API.app } } : _WATE_API)
        if(ret && typeof ret.then === 'function') _initPromises.push(ret.catch(err => { _core.log.print(_core.log.ERROR, '[' + flag + '] "' + alias + '" init() async failed: ' + err.message); throw err }))
      }
    }

    const doneLoading = () => {
      _core.log.print(_core.log.RUN, 'LEAVE _modules.load()')
      resolve(mods)
    }
    // FIX v1.3.3 #29: .catch() évite que load() pende si un init() async rejette
    if(_initPromises.length) { Promise.race([Promise.all(_initPromises), new Promise(r => setTimeout(r, 10000))]).then(doneLoading).catch(err => { _core.log.print(_core.log.ERROR, '[' + flag + '] load() async failed: ' + err.message); reject(err) }) }
    else doneLoading()
  } catch(err) {
    _core.log.print(_core.log.FATAL, '[' + flag + '] Failed to load module : ' + err.message)
    reject(err)
  }
})}

/**
 * \brief  Parse rawInput et retourne juste les noms (sans charger).
 * \param  rawInput Valeur brute.
 * \return Array de noms.
 */
function parseNames(rawInput) {
  const names = []
  if(rawInput === undefined || rawInput === null) return names
  const input = Array.isArray(rawInput) ? rawInput.join(',') : String(rawInput)
  let match
  _REGEX_PARAM.lastIndex = 0
  while((match = _REGEX_PARAM.exec(input)) !== null) {
    names.push(match[1])
  }
  return names
}

module.exports = { load, parseNames }

/* (WaTE) _modules.js v1.3.4 */