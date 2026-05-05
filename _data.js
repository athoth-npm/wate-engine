/**
 * \file      (WaTE) _data.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   2.4.4
 * \brief     Fonctions d'accès aux données : pageData (lecture) et modify (écriture).
 *
 * \details   v2.4.4 : Doxygen aligné sur signatures réelles — serve(req,res,data,urlOverride)
 *                     et modify(req,res,responder). req.cookies.sid → req.cookies.session.
 *                     Préfixe '_' : module interne moteur, non destiné aux modules applicatifs.
 *            Importé via require('./_data') depuis _auth.js, _db.js, et engine.js.
 *
 *            ── FORMAT DES QUERIES EN DB (tables _item, list_id applicatif) ──
 *
 *            Chaque _item d'une page peut définir une clé "queries" contenant un
 *            template JSON. Exemple :
 *
 *              {"maQuery": {
 *                "request": "SELECT * FROM t WHERE col IN (${req.query.filter:text})",
 *                "values":  ["${lang}", ${req.query.limit:number}]
 *              }}
 *
 *            Les placeholders ${expr} ou ${expr:type} sont résolus AVANT JSON.parse().
 *            Le résultat est un objet dont chaque clé devient une requête exécutée
 *            via db.all(request, values, callback).
 *
 *            SYNTAXE DE SUBSTITUTION :
 *              ${expr}            — évalue expr dans le sandbox VM, injecte le résultat
 *              ${expr:type}       — évalue + contraint le type (number|identifier|text)
 *
 *            CONTEXTES D'INJECTION (deux niveaux distincts) :
 *              1. Contexte JSON : les valeurs substituées sont injectées dans une
 *                 chaîne JSON avant parsing. Les caractères " et \ sont échappés.
 *                 Les objets et fonctions sont rejetés (barrière de sécurité).
 *              2. Contexte SQL   : après JSON.parse(), "request" est exécutée par
 *                 db.all(). Les "values" sont passées en paramètres bindés (?) —
 *                 donc protégées contre l'injection SQL classique.
 *
 *            RÈGLES DE SÉCURITÉ POUR LES DÉVELOPPEURS :
 *              - TOUJOURS utiliser un type (:number, :identifier, :text) pour les
 *                valeurs issues de req.query ou req.body. Le type force une
 *                conversion stricte avant injection.
 *              - JAMAIS concaténer une ${...} directement dans "request" sans type
 *                :identifier si c'est un nom de table/colonne. Utiliser :identifier
 *                qui valide contre /^[a-zA-Z0-9_]+$/.
 *              - Les "values" sont bindées (?) : une string contenant "'; DROP--"
 *                est inoffensive. Ne PAS contourner ce mécanisme en concaténant
 *                des valeurs directement dans "request".
 *              - Une expression sans type retournant un objet ou une fonction est
 *                rejetée (log ERROR, valeur remplacée par "null").
 *              - Longueur max d'une expression : 500 caractères (anti-DoS sandbox).
 *
 *            EXEMPLES VALIDES :
 *              ${req.query.id:number}     → force un nombre (NaN → erreur)
 *              ${req.query.table:identifier} → valide nom de table (regex)
 *              ${req.query.name:text}     → force String, échappe " et \
 *              ${lang}                    → valeur interne (langue courante), sûr
 *
 *            EXEMPLE INVAlide (rejeté) :
 *              ${req.query.raw}           → pas de type, objet/fonction rejeté
 *
 *            ─────────────────────────────────────────────────────────────────
 *
 *            v1.0.1 : FIX références _adminLang, httpError, _core.getSession.
 *            v1.0.2 : FIX requête droits — IN(request, baseRight).
 *            v1.0.3 : _core.tableHooks → req.app.locals.tableHooks (per-instance).
 *                     FIX hook : cherche tableHooks[access.request_name] puis baseRight.
 *            v2.0.0 : pageData() déplacé depuis engine.js — _data.js regroupe toutes
 *                     les opérations DB métier (lecture + écriture).
 *                     buildSelectSQL() et _queriesCache migrés depuis engine.js.
 *                     pageData accepte urlOverride pour les routes dynamiques.
 *                     JS escape : si elements.JS existe, appelle _core.jsHandlers[value]
 *                     au lieu de res.render('common').
 *                     pageData exposé dans _core.pageData pour les modules.
 *            v2.0.1 : Utilise jsHandler pour exécuter un JS plutôt qu'un EJS.
 *            v2.1.0 : - Pour HTTP GET, on utilise les données en DB => plus de jsHandler.
 *                     - title_param : si elements.title_param est défini, le titre est
 *                       pris dans req.query[elements.title_param] avant res.render().
 *            v2.1.1 : SQLite n'accepte pas '?' comme paramètre de PRAGMA. On utilise
 *                     ${x} dans la string "request" en DB et on évalue x par la sandbox.
 *            v2.1.2 : - La fonction resolveParams sort de serve() évitant la conso mémoire.
 *                     - tableInfoCache est placée dans _core pour être partagé avec _db.js.
 *            v2.1.3 : _core.dbRequestCache() qui fait une vérification dans le cache avant le SQL.
 *                     const des regex statiques évaluées une seule fois.
 *            v2.1.4 : on indique un type à la valeur pour garantir son format
 *            v2.1.5 : on ajoute le CSRF token dans les données de render()
 *            v2.1.6 : resolveParams — garde longueur max 500 chars sur les expressions
 *                     VM pour limiter la surface d'attaque DoS sur le sandbox.
 *            v2.1.7 : _queriesCache local supprimé — remplacé par _core.dbCaches.queries
 *                     (partagé avec _core, exposé aux stats par _stats.js).
 *            v2.2.0 : Glossaire chargé directement par serve() via LEFT JOIN _page —
 *                     même hiérarchie que _item/_page. list_id NULL = toujours chargé,
 *                     list_id N = chargé si la page courante a ce list_id dans _page.
 *                     Plus de requête _glossary dans les _item (list 103 allégé).
 *            v2.3.0 : Gestion des hooks avant render() et avant INSERT/UPDATE/DELETE.
 *            v2.3.1 : migration var → const/let.
 *            v2.3.2 : FIX DELETE/UPDATE sans PK — si aucune colonne
 *                     pk > 0, where reste vide → DELETE FROM table
 *                     sans WHERE efface tout. Bloque avec 400.
 *            v2.3.3 : PK falsy (0,"",false) détecté via ===undefined||===null,
 *                     _SQLS module-level, resolveParams coercion documentée.
 *            v2.3.4 : done() try-catch sur close(), baseRight shadow documenté.
 *            v2.3.5 : FIX skip email dans boucle d'extraction au lieu de
 *                     delete req.body.email — évite la mutation du caller.
 *            v2.4.0 : FIX injection SQL via ${...} — valeurs JSON-échappées
 *                     (["\\]), objets/fonctions rejetés (anti-sandbox-escape
 *                     Node < 10). resolveParams barrière objets non-Array.
 *            v2.4.1 : FIX #20 cache key — substring(0,50) sur req.query.table.
 *                     Harmonisation arrow functions + module.exports.
 *            v2.4.2 : FIX __proto__/constructor filtrés dans result[q] et
 *                     elements[item.key] (anti prototype pollution).
 *                     FIX hasOwnProperty.call sur req.body[colName].
 *                     FIX log RUN LEAVE dans modify() (10+ chemins d'erreur)
 *                     et serve() (déplacé dans le callback asynchrone).
 *                     FIX message d'erreur générique (pas de fuite SQL).
 *            v2.4.3 : Documentation — JSDoc complet sur serve() et modify()
 *                     (pipeline, paramètres, codes d'erreur, opérations -self).
 *                     Description du format des queries ${expr:type} et des
 *                     règles de sécurité pour les développeurs.
 */

'use strict'

const vm     = require('vm')
const _core  = require('./_core')
const _utils = require('./_utils')

// REGEX statiques
// On ajoute une capture optionnelle pour le type : ${expression:type}
// Groupe 1 : l'expression JS
// Groupe 2 : le type (optionnel)
const _RE_EXPR      = /\${(.*?)(?::(number|identifier|text))?\}/g
const _SQLS          = { insert: 'INSERT INTO ', update: 'UPDATE ', delete: 'DELETE FROM ' }
const _RE_NEXT_PAGE = /^[a-zA-Z0-9_-]+$/
const _RE_SELF      = /-self$/

/**
 * \const _pageLoadHooks
 * \brief Hook pour la récupération de données hors DB.
 */
const _pageLoadHooks = {}

/**
 * \const _tableWriteHooks
 * \brief Hook pour l'exécution applicative avant modification de la DB.
 */
const _tableWriteHooks = {}

// =============================================================================
// Helpers internes
// =============================================================================

/**
 * \fn buildSelectSQL
 * \brief Construit la requête SELECT dynamique à partir de la définition JSON d'une query.
 *
 * \param q       Clé de la query (nom de la table source)
 * \param queries Objet queries complet issu du JSON de la page en DB
 * \return        Chaîne SQL SELECT
 */
function buildSelectSQL(q, queries) {
  const cols = Object.keys(queries[q].columns).join(', ')
  let sql  = 'SELECT ' + cols + ' FROM ' + q
  if(queries[q].join)  sql += ' ' + queries[q].join.clause
  if(queries[q].where) sql += ' WHERE ' + queries[q].where.clause
  if(queries[q].order) sql += ' ORDER BY ' + queries[q].order
  return sql
}

/**
 * \fn resolveParams
 * \brief Évalue une expression JS dans un contexte sécurisé (sandbox).
 *        Applique une sanitisation stricte si un type est spécifié (${expr:type}).
 *
 * \param expr    L'expression JavaScript sous forme de chaîne
 * \param type    Le type attendu ('number', 'identifier', 'text' ou undefined)
 * \param sandbox Le contexte VM instancié pour la requête courante
 * \return        Un tableau de valeurs (ou un tableau vide en cas d'erreur)
 */
function resolveParams(expr, type, sandbox) {
  if(!expr) return []
  if(Array.isArray(expr)) return expr
  if(expr.length > 500) {
    _core.log.print(_core.log.WARNING, 'resolveParams: expression trop longue (' + expr.length + ' chars) — rejetée')
    return []
  }
  try {
    const r = vm.runInContext('(' + expr + ')', sandbox, { timeout: 50 })

    // Barriere anti-sandbox-escape : rejeter objets et fonctions
    if(r !== null && typeof r === 'object' && !Array.isArray(r)) {
      _core.log.print(_core.log.ERROR, 'resolveParams: objet interdit — ' + expr)
      return []
    }
    if(typeof r === 'function') {
      _core.log.print(_core.log.ERROR, 'resolveParams: fonction interdite — ' + expr)
      return []
    }

    // Si la valeur est un tableau, on applique la sanitisation a chaque element
    const values = Array.isArray(r) ? r : [r]

    if (type) {
      for (let i = 0; i < values.length; i++) {
        const v = values[i]

        if (type === 'number') {
          const n = parseFloat(v)
          if (isNaN(n) || !isFinite(n)) throw new Error('Type mismatch: expected number for ' + expr)
          values[i] = n

        } else if (type === 'identifier') {
          // Uniquement lettres, chiffres et underscores (ex: nom de table ou de colonne)
          if (typeof v !== 'string' || !_utils._RE_TABLE.test(v)) {
            throw new Error('Type mismatch: expected valid identifier for ' + expr)
          }
          values[i] = v

        } else if (type === 'text') {
          // Forcer la conversion en chaîne de caractères
          if (v === null || v === undefined) {
            values[i] = ''
          } else {
            values[i] = String(v)
          }
        }
      }
    }

    return values
  } catch(e) {
    _core.log.print(_core.log.ERROR, 'resolveParams: ' + e.message + ' — ' + expr + (type ? ':' + type : ''))
    return []
  }
}



// =============================================================================
// serve — lecture
// =============================================================================

/**
 * @brief Résout et renvoie les données d'une page au client.
 *
 *        Vérifie la session, charge les _item de la page, exécute les queries, puis :
 *          - si elements.JS : appelle _core.jsHandlers[elements.JS](req, res, elements, result)
 *          - sinon          : res.render('common', ...)
 *
 * Lit la route dans _page, charge les _item associés, exécute les requêtes
 * SQL définies dans _item.queries via un sandbox VM, fusionne les résultats
 * et rend le template EJS correspondant.
 *
 * Les expressions ${expr:type} dans les requêtes sont résolues depuis req.query
 * et req.body. Les valeurs non typées ou dépassant 500 caractères sont rejetées.
 *
 * @param {import('express').Request}  req - Requête Express. Doit contenir :
 *   req.cookies.session : cookie de session (ou absent pour anonyme),
 *   req.query.lang      : langue courante (ex: 'fr', 'en'),
 *   req.path            : URL de la page à servir.
 * @param {import('express').Response} res - Réponse Express.
 *   En cas d'erreur : res.status(401|403|404|500).
 *   En cas de succès : res.render() avec les données fusionnées.
 * @param {Object} [data]     - Données additionnelles injectées (clé/valeur).
 * @param {string} [urlOverride] - URL à servir à la place de req.path.
 *
 * @returns {void} Répond directement via @p res. Ne retourne pas de valeur.
 *
 * @note Les erreurs SQL ne sont pas propagées au client (message générique).
 *       Le détail est loggué en interne via _core.log.
 *
 * @see modify() pour les opérations d'écriture.
 * @see _item.queries pour le format des requêtes dynamiques.
 *
 * @details  Migré depuis engine.js (pageData) v3.7.0 — renommé serve.
 *           v1.5.0 : vérification d'expiration de session.
 *           v2.11.0 : cache _queriesCache, vm.createContext factorisé par requête.
 *           v2.12.0 : 401 si session expirée, 404 si page absente.
 *           v2.13.0 : UNION pour distinguer page inexistante / mauvais profil.
 *           v2.13.1 : clé cache page + profil.
 *           v2.14.0 : logique UNION corrigée ; lang sanitisé ; Object.keys() Promise.all.
 *           v3.1.2  : FIX items.length === 0 — Part 2 redessinée.
 *           v3.7.0  : urlOverride + JS escape via _core.jsHandlers.
 *           v2.0.1  : jsHandler reçoit (req, res, elements, result, lang, profil_id).
 *                     nonce injecté dans res.render('common').
 *           v2.1.0  : title_param : si elements.title_param est défini, le titre est
 *                     pris dans req.query[elements.title_param] avant res.render().
 */

function serve(req, res, data, urlOverride) {
  _core.log.print(_core.log.RUN, 'ENTER serve()')
  _core.log.print(_core.log.DEBUG, 'req.cookies = ', req.cookies)
  _core.log.print(_core.log.DEBUG, 'req.path = \'' + req.path + '\'')
  _core.log.print(_core.log.DEBUG, 'req.query = ', req.query)

  const session = _utils.getSession(req)
  const pageUrl = urlOverride || req.path

  // UNION ALL — Part 1 : items pour ce profil. Part 2 : discriminant accès.
  _core.dbRequest('all',
                  'SELECT I.key, I.value FROM _item I, _page P, _user U, _session S WHERE P.url = ? AND P.profil_id = U.profil_id AND U.email = S.user_email AND S.id = ?' + session.clause + ' AND P.list_id = I.list_id \
                  UNION ALL \
                  SELECT DISTINCT \'__\' || P.url, MAX((P.profil_id = (SELECT U2.profil_id FROM _user U2, _session S2 WHERE U2.email = S2.user_email AND S2.id = ?)) * (1 + P.profil_id)) FROM _page P GROUP BY P.url',
                  [pageUrl, session.id, session.id],
                  (err, items) => {
    if(err) return _core.httpError(req, res, 500, err.message)

    const urls = items.filter(r => r.key.startsWith('__/'))
    const pageRow = urls.find(r => r.key === '__' + pageUrl)
    if(!pageRow) return _core.httpError(req, res, 404)

    if(items.length === urls.length) {
      // La page existe, mais l'utilisateur n'a pas les droits pour CE profil
      // pageRow.value > 0 signifie qu'on a trouvé au moins un profil valide
      // S'il avait une session active (session.id !== 0) mais pas les droits, on la supprime
      if(pageRow.value !== 0 && session.id !== '0') {
        res.clearCookie('session')
      }
      return _core.httpError(req, res, 401, null, '/admin/form/auth/signin')
    }

    const profil_id = pageRow.value - 1
    // FIX v2.4.1: substring(0,50) limite la longueur de la clé cache (req.query.table validé par _RE_TABLE)
    const cacheKey  = pageUrl + ':' + profil_id + (req.query.table ? ':' + String(req.query.table).substring(0, 50) : '')

    const elements = {}
    // NOTE: var obligatoire (Node 4.6.1). Accepté ANALYSIS v5 #8.
    for(var item of items) {
      // FIX v2.4.2 #61: __proto__ et constructor protégés contre la pollution
      if(!item.key.startsWith('__/') && item.key !== '__proto__' && item.key !== 'constructor')
        elements[item.key] = (elements[item.key] ? elements[item.key] + ',' : '') + item.value
    }
    _core.log.print(_core.log.DEBUG, 'ELEMENTS: ', elements)

    const lang = _utils.adminLang(req)

    // NOTE : Node < 10 ignore contextCodeGeneration. eval/Function=undefined
    // ne bloquent pas constructor.constructor(). La validation dans resolveParams
    // (rejet des objets/fonctions) est la vraie barrière de sécurité.
    const sandbox = vm.createContext({
      req:       { query: req.query, body: req.body, params: req.params, cookies: req.cookies },
      lang:      lang,
      EJSs:      _core.EJSs,
      Date:      Date,  Math: Math,  JSON: JSON,
      eval:      undefined,  Function: undefined,
      parseInt:  parseInt,   parseFloat: parseFloat,
      isNaN:     isNaN,      isFinite:   isFinite,
      String:    String,     Number:     Number,
      Boolean:   Boolean,    Array:      Array,
      Object:    Object
    }, { contextCodeGeneration: { strings: false, wasm: false } })

    let queries
    const cached = _core.dbCaches.queries.get(cacheKey)
    if(cached) {
      queries = cached
    } else {
      try {
        // FIX v2.1.1 : Pour palier '?' invalide dans une requête PRAGMA, on utilise ${x}
        const tmpQueries = (elements['queries'] || '').replace(_RE_EXPR, (match, expr, type) => {
          // FIX v3.18.2 : resolveParams retourne un Array. On JSON-encode chaque
          // valeur individuellement pour neutraliser l'injection de " dans le JSON.
          // Sans type, on refuse les objets/fonctions issus de vm.runInContext
          // (barrière anti-sandbox-escape Node < 10).
          const vals = resolveParams(expr, type, sandbox)
          return Array.isArray(vals) ? vals.map(v => {
            if(v !== null && typeof v === 'object') {
              _core.log.print(_core.log.ERROR, 'resolveParams: objet interdit — ' + expr)
              return 'null'
            }
            if(typeof v === 'function') {
              _core.log.print(_core.log.ERROR, 'resolveParams: fonction interdite — ' + expr)
              return 'null'
            }
            return typeof v === 'string' ? v.replace(/["\\]/g, '\\$&') : String(v)
          }).join(',') : String(vals)
        })
        queries = JSON.parse('{' + tmpQueries + '}')
        _core.dbCaches.queries.set(cacheKey, queries)
      } catch(e) {
        _core.log.print(_core.log.ERROR, 'Erreur JSON queries: ' + e.message)
        return _core.httpError(req, res, 500, 'Configuration error')
      }
    }

    const queryKeys = Object.keys(queries)
    const requests  = queryKeys.map(q => {
      return new Promise((resolve, reject) => {
        let dbReq, dbArg
        if(queries[q].hasOwnProperty('request')) {
          dbReq = queries[q].request
          dbArg = resolveParams(queries[q].values, undefined, sandbox)
        } else {
          dbReq = buildSelectSQL(q, queries)
          dbArg = queries[q].join  ? resolveParams(queries[q].join.values, undefined, sandbox)  : []
          if(queries[q].where) dbArg = dbArg.concat(resolveParams(queries[q].where.values, undefined, sandbox))
        }
        _core.dbRequest('all', dbReq, dbArg, (err, rows) => {
          if(err) reject(err)
          else { _core.log.print(_core.log.DEBUG, 'ROWS: ', rows); resolve(rows) }
        })
      })
    })

    // Glossaire scopé par page — même hiérarchie que _item/_page (v2.2.0).
    // list_id NULL = toujours chargé ; list_id N = chargé si la page a ce list_id dans _page.
    requests.push(new Promise((resolve, reject) => {
      _core.dbRequest('all',
        'SELECT DISTINCT g.tag, g.label FROM _glossary g \
         LEFT JOIN _page p ON g.list_id = p.list_id AND p.url = ? AND p.profil_id = ? \
         WHERE (g.lang_id = ? OR g.lang_id IS NULL) AND (g.list_id IS NULL OR p.list_id IS NOT NULL)',
        [pageUrl, profil_id, lang],
        (err, rows) => {
          if(err) reject(err)
          else resolve(rows)
        })
    }))

    if (elements.HOOK) {
      // On pousse la Promise du Hook dans le tableau
      requests.push(new Promise((resolve, reject) => {
        const hookFn = _pageLoadHooks[elements.HOOK]
        if (!hookFn) return reject(new Error('Provider manquant: ' + elements.HOOK))

        // Le hook est attendu pour retourner { key: '...', value: ... }
        // On enveloppe avec Promise.resolve() au cas où le développeur ait oublié de rendre sa fonction async
        Promise.resolve(hookFn(req, elements))
               .then(resolve)
               .catch(reject)
      }))
    }

    // FIX v2.4.2 #35: erreur générique (pas de fuite SQL vers le client)
    Promise.all(requests).then(rows => {
      const result = {}
      // 1. On peuple les résultats SQL normaux
      // FIX v2.4.2 #39: __proto__ et constructor protégés contre la pollution
      queryKeys.forEach((q, i) => {
        if(q === '__proto__' || q === 'constructor') { _core.log.print(_core.log.ERROR, 'serve: query name protégé — ' + q); return }
        result[q] = { columns: queries[q].columns, rows: rows[i] }
      })
      // 2. Le glossaire est toujours juste après les queryKeys
      const _glossaryIdx = queryKeys.length
      result['_glossary'] = { columns: { tag: {}, label: {} }, rows: rows[_glossaryIdx] }
      // 3. Le résultat du Hook (juste après le glossaire, s'il existe)
      if (elements.HOOK) {
        const hookData = rows[_glossaryIdx + 1]
        if (hookData && hookData.key) {
          result[hookData.key] = hookData.value
        }
      }
      // 4. Les données forcées depuis renderPage(req, res, extraData)
      if(data) result[data.key] = data.value

      // Rendu EJS standard.
      // title_param : titre dynamique depuis req.query si configuré.
      let renderElements = elements
      if(elements.title_param && req.query[elements.title_param]) {
        renderElements = Object.assign({}, elements, { title: req.query[elements.title_param] })
      }
      res.render('common', {
        req, path: _core.path,
        CSRFToken: _utils.generateCSRFToken(session.id),  // FIX v2.1.5 : CSRF token
        EJSs: _core.EJSs, lang,
        elements: renderElements,
        result,
        profil_id,
        nonce: res.locals.nonce
      }, (err, html) => {
        if(err) { _core.log.print(_core.log.FATAL, err.name + ':', err.message); _core.httpError(req, res, 500, 'res.render()') }
        else { res.send(html); _core.log.print(_core.log.RUN, 'LEAVE serve()') }
      })
    }).catch(err => {
      _core.log.print(_core.log.ERROR, 'serve() Promise.all: ' + err.message)
      _core.log.print(_core.log.RUN, 'LEAVE serve()')
      _core.httpError(req, res, 500, 'Data query error')
    })
  })
}

// =============================================================================
// modify — écriture
// =============================================================================

/**
 * @brief Exécute une opération d'écriture (INSERT, UPDATE, DELETE) sur une table.
 *
 * Vérifie dans l'ordre :
 *  1. Validité du nom de table (_RE_TABLE).
 *  2. Session active (sinon 401).
 *  3. Droit ACL dans _access pour le profil courant (sinon 403).
 *  4. Présence des colonnes PK pour UPDATE/DELETE (sinon 400).
 *  5. Exécution du tableHook enregistré (si présent).
 *  6. Écriture en base (INSERT/UPDATE/DELETE).
 *
 * Les opérations '-self' (update-self, delete-self) filtrent automatiquement
 * sur la colonne 'email' de la session courante.
 *
 * @param {import('express').Request}  req - Requête Express. Doit contenir :
 *   req.body            : données à écrire (colonnes → valeurs),
 *   req.cookies.session : cookie de session,
 *   req.params.table    : nom de la table cible,
 *   req.params.request  : 'insert' | 'update' | 'update-self' | 'delete' | 'delete-self'.
 * @param {import('express').Response} res - Réponse Express.
 * @param {Object} [responder] - Optionnel. { success(), error(code, msg) }.
 *   Défaut : redirige vers ../data-<table>?lang=<lang>.
 *
 * @returns {void} Répond directement via @p res.
 *
 * @note La vérification CSRF est effectuée en amont par le middleware Express,
 *       pas dans cette fonction.
 * @note req.body ne doit pas être muté avant l'appel — modify() en fait une copie.
 *
 * @see registerTableWriteHook() pour intercepter les écritures.
 * @see serve() pour les opérations de lecture.
 */
function modify(req, res, responder) {
  // Note : toutes les validations (table, session, droits) sont faites ici.
  // Les routes appelantes n'ont pas besoin de dupliquer ces checks.
  _core.log.print(_core.log.RUN, 'ENTER _data.modify()')

  const r = responder || {
    success: () => {
      const lang     = _utils.adminLang(req)
      const nextPage = (req.query.next && _RE_NEXT_PAGE.test(req.query.next))
                  ? req.query.next : 'data-' + req.params.table
      res.redirect('../' + nextPage + '?lang=' + lang)
    },
    error: (code, msg) => { _core.httpError(req, res, code, msg) }
  }

  if(!_utils._RE_TABLE.test(req.params.table)) {
    _core.log.print(_core.log.WARNING, 'Invalid table name: ' + req.params.table)
    _core.log.print(_core.log.RUN, 'LEAVE _data.modify()')
    return r.error(400, 'Invalid table name')
  }

  const session = _utils.getSession(req)

  // ── Étape 1 : vérification de la session ─────────────────────────────────
  _core.dbRequest('get',
    'SELECT U.email, U.lang_id, U.profil_id FROM _session S INNER JOIN _user U ON S.user_email = U.email WHERE S.id = ?' + session.clause,
    [session.id],
    (err, user) => {
      if(err)   { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(500, err.message) }
      if(!user) { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(401, 'not authenticated') }

      // ── Étape 2 : vérification des droits ──────────────────────────────
      const baseRight = req.params.request.replace(_RE_SELF, '')
      _core.dbRequest('get',
        'SELECT request_name FROM _access WHERE profil_id = ? AND tablename = ? AND request_name IN (?, ?) LIMIT 1',
        [user.profil_id, req.params.table, req.params.request, baseRight],
        (err, access) => {
          if(err)    { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(500, err.message) }
          if(!access) { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(403, 'forbidden') }

          const accessRow = { email: user.email, lang_id: user.lang_id, request_name: access.request_name }

          // Note : baseRight redéfini ici (shadow intentionnel — utilisé pour le hook lookup)
          _core.dbRequestCache(_core.dbCaches.tableInfo, req.params.table, 'all', 'PRAGMA table_info(' + req.params.table + ')', [], (err, cols) => {
            if(err) { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(500, err.message) }
            doTableWork(accessRow, cols)
          })

          function doTableWork(access, cols) {
            const baseRight = req.params.request.replace(_RE_SELF, '')
            const hook      = _tableWriteHooks[req.params.table] &&
                           (_tableWriteHooks[req.params.table][access.request_name] ||
                            _tableWriteHooks[req.params.table][baseRight])

            // FIX v2.4.2 #159: onSuccess appelé APRÈS succès SQL (audit fiable)
            function doSql(err, onSuccess) {
              if(err) { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(500, err.message) }

              let targets = '', where = '', values = [], keys = []
              const requestType = access.request_name
              const tableName   = req.params.table

              // 1. PKs & WHERE (pour Update et Delete)
              if(requestType !== 'insert') {
                if(requestType === 'update-self' || requestType === 'delete-self') {
                  // Vérification ultra-rapide de l'existence de la colonne 'email'
                  if(!cols.find(c => c.name === 'email')) {
                    _core.log.print(_core.log.RUN, 'LEAVE _data.modify()')
                    return r.error(400, 'Access denied: table has no email column for -self operation')
                  }
                  where = ' WHERE email = ?'
                  keys.push(access.email)
                }

                for(let j = 0; j < cols.length; j++) {
                  if(cols[j].pk > 0) {
                    // FIX : !val rejette 0, "" et false — PK légitimes. Seul undefined/null = absent.
                    if(req.body[cols[j].name] === undefined || req.body[cols[j].name] === null) { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(400, 'PK column ' + cols[j].name + ' missed') }
                    where += (where ? ' AND ' : ' WHERE ') + cols[j].name + ' = ?'
                    keys.push(req.body[cols[j].name])
                  }
                }

                // FIX : pas de PK → DELETE sans WHERE viderait la table entière
                if(!where && requestType.indexOf('-self') < 0) { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(500, 'No PK column found for ' + requestType) }
              }

              // 2. Boucle unique sur COLS pour extraire les données (Insert et Update)
              if(requestType !== 'delete' && requestType !== 'delete-self') {
                for(let i = 0; i < cols.length; i++) {
                  const colName = cols[i].name
                  // FIX v2.4.2 #54: hasOwnProperty évite de lire Object.prototype (constructor, toString…)
                  const colVal  = Object.prototype.hasOwnProperty.call(req.body, colName) ? req.body[colName] : undefined

                  // Si le champ est présent dans la requête (même si c'est "" ou null)
                  if(colVal !== undefined) {
                    // email est utilisé uniquement pour le WHERE des -self, jamais en SET
                    if(colName === 'email' && requestType !== 'insert') continue
                    if(requestType === 'insert') {
                      targets += (targets ? ', ' : '') + colName
                      values.push(colVal)
                    } else if(requestType.indexOf('update') === 0 && cols[i].pk === 0) {
                      targets += (targets ? ', ' : ' SET ') + colName + '= ?'
                      values.push(colVal)
                    }
                  }
                }

                // Messages d'erreur spécifiques restaurés
                const reqMsg = requestType === 'insert' ? 'INSERT' : 'UPDATE'
                if(values.length === 0) { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(400, 'No value to ' + reqMsg) }
                
                if(requestType === 'insert') {
                  targets = '(' + targets + ') VALUES (?' + ', ?'.repeat(values.length - 1) + ')'
                }
              }

              // 3. Exécution SQL
              const sql  = requestType === 'insert'            ? _SQLS.insert + tableName + targets
                       : requestType.indexOf('update') === 0 ? _SQLS.update + tableName + targets + where
                       :                                        _SQLS.delete + tableName + where
              const vals = requestType.indexOf('update') === 0 ? values.concat(keys)
                       : requestType === 'insert'             ? values : keys

              _core.dbRequest('run', sql, vals, (err) => {
                if(err) { _core.log.print(_core.log.RUN, 'LEAVE _data.modify()'); return r.error(500, err.message) }
                if(onSuccess) { try { onSuccess() } catch(e) { _core.log.print(_core.log.ERROR, 'doSql onSuccess: ' + e.message) } }
                _core.log.print(_core.log.RUN, 'LEAVE modify()')
                r.success()
              })
            }

            // FIX v2.4.2 #159: next(err, onSuccess) — onSuccess appelé après SQL
            if(hook) { hook(req, (err, onSuccess) => { doSql(err, onSuccess) }) } else { doSql() }
          }
        }
      )
    }
  )
}

module.exports = {
  serve,
  modify,
  // Setters de hooks (Exposés à _modules.js uniquement)
  registerPageLoadHook: (name, fn) => {
    _pageLoadHooks[name] = fn
  },
  unregisterPageLoadHook: (name) => {
    // FIX v2.4.2 #68: cleanup hooks entre init() multiples (tests)
    delete _pageLoadHooks[name]
  },
  registerTableWriteHook: (tableName, action, fn) => {
    if (!_tableWriteHooks[tableName]) _tableWriteHooks[tableName] = {}
    _tableWriteHooks[tableName][action] = fn
  },
  unregisterTableWriteHook: (tableName, action) => {
    if (_tableWriteHooks[tableName]) delete _tableWriteHooks[tableName][action]
  },
  getTableWriteHook: (tableName, action) => {
    return _tableWriteHooks[tableName] && _tableWriteHooks[tableName][action]
  }
}

/* (WaTE) _data.js v2.4.3 */