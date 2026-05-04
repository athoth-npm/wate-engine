/**
 * \file      app.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   2.6.1
 * \brief     Mini application WaTE en mode bibliothèque — démarre le moteur
 *            sur la DB de test et sert les pages via Express.
 *
 * \details   v1.0.0 : création initiale.
 *            v1.1.0 : pages de test admin ajoutées (owner + admin-test).
 *                     Convention UNIX profils : owner=0, anonymous=1.
 *            v1.2.0 : routes admin mises à jour (/admin/db, /admin/api/db/...).
 *            v1.3.0 : trois instances pour tester les combinaisons de modules :
 *                       - port 3001 : auth (TTL 3600) + db
 *                       - port 3002 : auth seul (TTL 3600)
 *                       - port 3003 : aucun module
 *            v2.0.0 : mise à jour routes après refactoring auth.js/db.js v2.0.0.
 *            v2.1.0 : port 3004 — db sans auth (adminSession = anonymous profil 1).
 *                     - GET /admin/auth, /admin/me, /admin/db, /admin/db/:table
 *                       remplacés par /admin/form/auth, /admin/form/db/schema,
 *                       /admin/form/db/:table — plus aucune route sous /admin/
 *                       directement, tout passe par /admin/api/* ou /admin/form/*.
 *            v2.1.1 : Si la DB existe, on la supprime, enginejs utilise son
 *                      mécanisme de migration pour tout recréer.
 *            v2.2.0 : port 3001 — module stats ajouté (GET /admin/api/stats).
 *            v2.3.0 : port 3005 — mail stubbé (isAvailable=true, send=no-op) pour
 *                     tester le protocole verify/forgot/reset end-to-end sans SMTP.
 *                     Le stub est injecté dans ctx.app.locals.mail — lu en priorité
 *                     par _auth.js via _mail(req). Les autres instances restent en
 *                     mode dégradé (mail off → signup immédiat, forgot/reset 404).
 *            v2.3.1 : isAvailable stub passé de méthode à propriété booléenne —
 *                     cohérence avec _mail.js (getter) et _core.js v1.4.1.
 *            v2.3.2 : Route /test/mail-last déplacée en tête du router stack Express —
 *                     engine.js enregistre app.get('*') à l'init qui capturait la route
 *                     avant nous, d'où 404 et mail jamais accessible aux tests.
 *            v2.4.0 : Stub mail + route /test/mail-last extraits dans un module
 *                     applicatif test/scripts/test-mail.js, chargé via --mod=test-mail.
 *                     Les modules applicatifs sont chargés pendant init() avant
 *                     app.get('*') — la route est naturellement prioritaire, plus
 *                     besoin de manipuler le router stack.
 *            v2.5.0 : Port 3001 — ajout des modules test-api et test-routes.
 *                     - test-api   : sondes techniques de _WATE_API
 *                                    (/test/api/{log,db,render-error,app-locals}).
 *                     - test-routes: démontre les 3 styles d'écriture d'une
 *                                    appli WaTE (route+renderPage, hooks, DB-only).
 *                     Migration test/migrations/003_api.sql définit /style2 et
 *                     /style3 (profil anonymous). /style1 reste servi par une
 *                     route module via renderPage sur /home existant.
 *            v2.6.0 : Nouveaux tests — open redirect, headers CSP, rate
 *                     limiting POST, page erreur chemin profond, i18n
 *                     (?lang=en), cache LRU hits/misses.
 *
 *  Prérequis : node test/setup-db.js  (depuis CMS Engine/)
 *  Usage     : node test/app.js       (depuis CMS Engine/)
 *
 *  Pages CMS disponibles (3001/3002/3003) :
 *    http://localhost:300x/home              — page publique (profil 1, pas de cookie)
 *    http://localhost:300x/home?lang=en      — même page en anglais
 *    http://localhost:300x/admin-test        — page privée (profil 2, cookie session requis)
 *    http://localhost:300x/missing           — 404
 *
 *  API auth (JSON) — port 3001 et 3002 :
 *    POST   /admin/api/auth/signin           — connexion
 *    POST   /admin/api/auth/signout          — déconnexion
 *    GET    /admin/api/auth/me               — profil courant
 *    PUT    /admin/api/auth/me               — update-self _user
 *    DELETE /admin/api/auth/me               — delete-self _user
 *
 *  API db (JSON) — port 3001 uniquement :
 *    GET    /admin/api/db/schema             — tables accessibles
 *    GET    /admin/api/db/:table             — SELECT paginé
 *    POST   /admin/api/db/:table             — INSERT
 *    PUT    /admin/api/db/:table             — UPDATE
 *    DELETE /admin/api/db/:table             — DELETE
 *
 *  UI form auth — port 3001 et 3002 :
 *    GET    /admin/form/auth                 — login (user=null) ou profil (user≠null)
 *    POST   /admin/form/auth/signin          — connexion → redirect
 *    POST   /admin/form/auth/signout         — déconnexion → redirect
 *    POST   /admin/form/auth/me              — update-self → redirect
 *
 *  UI form db — port 3001 uniquement :
 *    GET    /admin/form/db/schema            — liste des tables → admin-db.ejs
 *    GET    /admin/form/db/:table            — CRUD table → admin-db.ejs
 *    POST   /admin/form/db/:table/:request   — INSERT/UPDATE/DELETE → redirect
 *
 *  API db sans auth — port 3004 (adminSession = anonymous/profil 1) :
 *    GET    /admin/api/db/schema             — tables profil 1 (vide par défaut)
 *    GET    /admin/api/db/_lang              — 403 (profil 1 n'a pas select sur _lang)
 *    POST   /admin/api/db/_lang             — 401 (session anonyme '0', pas insert _lang)
 *
 *  Sessions de test (Cookie: session=j:{"id":"<value>"}) :
 *    test-session-owner      — owner@test.com       (profil 0, droits système)
 *    test-session-admin      — admin@test.com       (profil 2, droits sample)
 *    test-session-expired    — admin@test.com       (expirée)
 *    test-session-p3         — p3@test.com          (profil 3)
 *    test-session-p4         — p4@test.com          (profil 4)
 *    test-session-delete-me  — delete-me@test.com   (profil 5, delete-self _user)
 */

'use strict'

const fs = require('fs');
const path = require('path')

// Secret CSRF fixé pour les tests — permet de pré-calculer les tokens
// dans test-wate.sh via SHA256(sessionId + secret).
process.env.WATE_CSRF_SECRET = 'test-secret'

const init = require('../engine').init

// FIX v2.1.1 : On supprime la DB existante
const dbFile = path.join(__dirname, 'test.db');

// 1. SUPPRESSION : Si on relance les tests, on détruit l'ancienne base.
// Cela garantit que les tests repartent toujours de zéro et ne plantent pas.
if (fs.existsSync(dbFile)) {
  fs.unlinkSync(dbFile)
  console.log('🧹 Ancienne base de test supprimée.')
}

// 2. CRÉATION : On crée un fichier vide.
// Cela satisfait la sécurité stricte de engine.js (qui refuse de démarrer sans fichier).
fs.writeFileSync(dbFile, '')
console.log('📄 Fichier test.db vierge créé. Prêt pour les migrations.')

// 3. MIGRATION : on recrée la DB et ses données de test grâce au mécanisme de migration.
function start(port, mod, label) {
  return init({
    db   : 'test.db',
    port : port,
    path : 'test/',
    mod  : mod,
    log  : 63
  }).then(function(ctx) {
    console.log(label + ' démarrée sur http://localhost:' + port)
    console.log('  DB :', ctx.db.filename || ':memory:')
    return ctx
  })
}

// Démarrage séquentiel — chaque init() crée une instance Express indépendante via _core.app.
// Un démarrage parallèle (Promise.all) provoquerait une course sur _core.app.
// Port 3005 : le module applicatif test-mail (test/scripts/test-mail.js) injecte
// le stub mail dans app.locals.mail et enregistre GET /test/mail-last avant
// le catch-all app.get('*') de engine.js.
start(3001, ['auth=3600', 'db', 'stats', 'test-api', 'test-routes', 'audit', 'search', 'apikey', 'cron'], 'Instance full (3001)')
.then(function() { return start(3002, ['auth=3600'],  'Instance auth seul (3002)') })
.then(function() { return start(3003, [],              'Instance sans mod  (3003)') })
.then(function() { return start(3004, ['db'],          'Instance db seul   (3004)') })
.then(function() { return start(3005, ['auth=3600', 'db', 'test-mail'], 'Instance auth+db mail-stub (3005)') })
.then(function() {
  console.log('')
  console.log('Pages CMS de test (3001/3002/3003) :')
  console.log('  GET /home                                  — publique (200)')
  console.log('  GET /home?lang=en                          — publique EN (200)')
  console.log('  GET /admin-test                            — privée sans session (401)')
  console.log('  GET /missing                               — inexistante (404)')
  console.log('')
  console.log('API auth (3001 et 3002) :')
  console.log('  POST   /admin/api/auth/signin              — connexion')
  console.log('  POST   /admin/api/auth/signout             — déconnexion')
  console.log('  GET    /admin/api/auth/me                  — profil courant')
  console.log('  PUT    /admin/api/auth/me                  — update-self _user')
  console.log('  DELETE /admin/api/auth/me                  — delete-self _user')
  console.log('')
  console.log('API db (3001 uniquement) :')
  console.log('  GET    /admin/api/db/schema                — tables accessibles')
  console.log('  GET    /admin/api/db/_lang                 — données _lang (owner)')
  console.log('  GET    /admin/api/db/:table/export         — export CSV/JSON')
  console.log('')
  console.log('UI form auth (3001 et 3002) :')
  console.log('  GET    /admin/form/auth                    — login ou profil')
  console.log('  POST   /admin/form/auth/signin             — connexion → redirect')
  console.log('  POST   /admin/form/auth/signout            — déconnexion → redirect')
  console.log('  POST   /admin/form/auth/me                 — update-self → redirect')
  console.log('')
  console.log('UI form db (3001 uniquement) :')
  console.log('  GET    /admin/form/db/schema               — liste des tables')
  console.log('  GET    /admin/form/db/_lang                — CRUD _lang (owner)')
  console.log('  POST   /admin/form/db/_lang/insert         — INSERT _lang')
  console.log('')
  console.log('API db sans auth (3004) :')
  console.log('  GET /admin/api/db/schema  — profil 1, vide par défaut')
  console.log('  GET /admin/api/db/_lang   — 403 (profil 1 pas select _lang)')
  console.log('')
  console.log('Sondes _WATE_API (3001, module test-api) :')
  console.log('  GET /test/api/log                          — api.log fonctionnel')
  console.log('  GET /test/api/db                           — api.db.all(_profil)')
  console.log('  GET /test/api/render-error[?code=N]        — api.renderError (418 défaut)')
  console.log('  GET /test/api/app-locals                   — api.app === req.app')
  console.log('')
  console.log('3 styles d\'appli WaTE (3001, module test-routes) :')
  console.log('  GET /test/style1                           — style 1 : route+renderPage(/home)')
  console.log('  GET /test/style1-error                     — style 1 : route+renderError(418)')
  console.log('  GET /style2                                — style 2 : page DB + hook onPageLoad')
  console.log('  GET /style3                                — style 3 : page 100% DB (queries)')
  console.log('  POST /admin/form/db/sample/insert id=blocked — hook onTableWrite → 500')
  console.log('')
  console.log('Audit + undo (3001, module audit) :')
  console.log('  GET    /admin/api/db/_audit                — journal d\'audit')
  console.log('  POST   /admin/api/db/:table/undo           — annule dernière écriture')
  console.log('  POST   /admin/api/db/:table/undo?all=true  — owner annule n\'importe qui')
  console.log('')
  console.log('Recherche FTS5 (3001, module search) :')
  console.log('  GET    /admin/api/search?q=terme           — recherche admin')
  console.log('  GET    /api/search?q=terme                 — recherche publique')
  console.log('')
  console.log('API Keys (3001, module apikey) :')
  console.log('  GET    /admin/api/auth/apikey              — liste des clés')
  console.log('  POST   /admin/api/auth/apikey              — création')
  console.log('  DELETE /admin/api/auth/apikey              — révocation')
  console.log('')
  console.log('Health + mail verify/resend :')
  console.log('  GET    /health                             — statut serveur')
  console.log('  POST   /admin/api/auth/verify/resend       — renvoi lien vérification')
  console.log('')
  console.log('Stub mail (3005, module test-mail) :')
  console.log('  GET /test/mail-last[?to=email]             — dernier mail capturé')
  console.log('')
  console.log('Sécurité & robustesse (3001, tests bash) :')
  console.log('  GET /admin/form/auth/signin?next=https://evil.com  — open redirect bloqué')
  console.log('  GET /admin/form/auth/signin -I                     — headers CSP/X-Frame')
  console.log('  POST ×31 /admin/api/auth/forgot                    — rate limit → 429')
  console.log('  GET /a/b/c                                         — erreur 404 chemin profond')
  console.log('')
  console.log('I18n & performance (3001, tests bash) :')
  console.log('  GET /admin/form/auth/signin?lang=en                — glossaire anglais')
  console.log('  GET /admin/api/db/schema ×5 → /admin/api/stats     — cache LRU hits')
  console.log('')
  console.log('Script de test : bash test/test-wate.sh')
  console.log('Ctrl+C pour arrêter.')
}).catch(function(err) {
  console.error('Erreur de démarrage :', err.message)
  process.exit(1)
})

// app.js v2.6.1