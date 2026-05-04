/**
 * \file      (WaTE) web/scripts/site-menu.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-05-01
 * \version   1.0.0
 * \brief     Module --ejs site-menu — construction des menus du site vitrine.
 *
 * \details   Chargé via init({ ejs: ['site-menu'] }).
 *            Expose les fonctions utilisées dans web/views/common.ejs pour
 *            construire le sélecteur de langue et le menu burger.
 */

'use strict'

/**
 * \brief  Construit la chaîne de query params préservés pour les liens de nav.
 * \param  req Requête Express.
 * \return Chaîne "?p=v&..." ou "".
 */
function queryStr(req) {
  let qs = ''
  const query = req.query
  // FIX v1.0.0 #75: encodeURIComponent anti-injection
  // FIX v1.0.0 #163: hasOwnProperty anti proto pollution
  for(var p in query) { if(Object.prototype.hasOwnProperty.call(query, p)) qs += (qs ? '&' : '?') + encodeURIComponent(p) + '=' + encodeURIComponent(query[p]) }
  return qs
}

/**
 * \brief  Construit les items du menu langue au format icon-menu.
 * \param  req    Requête Express.
 * \param  result Résultat des queries (pour glossaryItem).
 * \param  _gi    Fonction glossaryItem (closure EJS).
 * \return Chaîne "icon,label,href|..." pour l'attribut items de <icon-menu>.
 */
function langItems(req, result, _gi) {
  const allLangs = ['fr', 'en']
  return allLangs.map(l => {
    const qp = {}
    const reqQ = req.query
    // FIX v1.0.0 #163: hasOwnProperty anti proto pollution
    for(var k in reqQ) { if(Object.prototype.hasOwnProperty.call(reqQ, k)) qp[k] = encodeURIComponent(reqQ[k]) }
    qp.lang = l
    let lqs = ''
    for(var k in qp) lqs += (lqs ? '&' : '?') + encodeURIComponent(k) + '=' + encodeURIComponent(qp[k])
    return '/images/' + l + '.png,' + _gi(result, 'site-lang-' + l) + ',' + req.path + lqs
  }).join('|')
}

/**
 * \brief  Construit les items du menu burger (navigation principale).
 * \param  req    Requête Express.
 * \param  result Résultat des queries (pour glossaryItem).
 * \param  _gi    Fonction glossaryItem (closure EJS).
 * \return Chaîne "icon,label,href|..." pour l'attribut items de <icon-menu>.
 */
function navItems(req, result, _gi) {
  const qs = queryStr(req)
  return [
    '/images/nav-me.svg,'      + _gi(result, 'site-nav-home')     + ',/' + qs,
    '/images/nav-db.svg,'      + _gi(result, 'site-nav-docs')     + ',/docs' + qs,
    '/images/nav-stats.svg,'   + _gi(result, 'site-nav-examples') + ',/examples' + qs,
    '/images/nav-signin.svg,'  + _gi(result, 'site-nav-demo')     + ',/demo' + qs,
    '/images/nav-ai.svg,'      + _gi(result, 'site-nav-ai')       + ',/ai' + qs,
    '/images/nav-signup.svg,'  + _gi(result, 'site-nav-github')   + ',https://github.com/athoth-npm/wate-engine'
  ].join('|')
}

module.exports = { queryStr, langItems, navItems }

/* (WaTE) web/scripts/site-menu.js v1.0.0 */
