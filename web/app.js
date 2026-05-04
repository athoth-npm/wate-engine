/**
 * \file      (WaTE) web/app.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-26
 * \version   2.0.0
 * \brief     Site vitrine WaTE — instance dédiée servie par le moteur lui-même.
 *
 * \details   Démarre une instance WaTE autonome sur le port 3006, servant le
 *            site de présentation et de documentation technique. Le site est
 *            lui-même un site WaTE : pages en DB, layout EJS (web/views/),
 *            custom elements (web/custom/), CSS (web/css/).
 *
 *            La DB web/site.db est supprimée et recréée à chaque démarrage
 *            — toute l'info vit dans les migrations. Les tables demo_ sont
 *            créées dans site.db directement (plus d'ATTACH, plus de demo.db).
 *
 *            Prérequis : rien — le moteur crée tout via migrations.
 *            Usage     : node web/app.js (depuis CMS Engine/)
 *
 *            v1.1.0 — modules db et demo chargés ; rubrique /demo livrée.
 *            v2.0.0 — tables demo_ dans site.db (plus d'ATTACH).
 */

'use strict'

const fs   = require('fs')
const path = require('path')
const init = require('../engine').init

// FIX v2.0.0 #69: DB hors du dossier statique (sinon téléchargeable)
const dataDir = path.join(__dirname, 'data')
if(!fs.existsSync(dataDir)) fs.mkdirSync(dataDir)
const dbFile = path.join(dataDir, 'site.db')

// FIX v2.0.0 #150: nettoyer aussi WAL/SHM orphelins
if(fs.existsSync(dbFile)) {
  fs.unlinkSync(dbFile)
  try { fs.unlinkSync(dbFile + '-wal') } catch(e) {}
  try { fs.unlinkSync(dbFile + '-shm') } catch(e) {}
  console.log('🧹 Ancienne base site supprimée.')
}
fs.writeFileSync(dbFile, '')
console.log('📄 Fichier data/site.db vierge créé.')

init({
  db   : 'data/site.db',
  port : 3006,
  path : './',
  ejs  : ['site-menu'],
  mod  : ['auth=3600', 'db', 'demo', 'audit', 'search'],  // auth, db, demo, audit, search
  log  : 63  // FATAL+ERROR+WARNING+INFO ; passer à 63 pour debug verbeux (DEBUG+RUN)
}).then(function(ctx) {
  console.log('')
  console.log('Site vitrine WaTE démarré sur http://localhost:3006')
  console.log('  DB :', ctx.db.filename || ':memory:')
  console.log('')
  console.log('Pages disponibles :')
  console.log('  GET /           — Accueil')
  console.log('  GET /examples   — Apprendre WaTE par l\'exemple')
  console.log('  GET /docs       — Documentation technique')
  console.log('  GET /demo       — Démo « gestion de stock »')
  console.log('')
  console.log('Ctrl+C pour arrêter.')
}).catch(function(err) {
  console.error('Erreur de démarrage :', err.message)
  process.exit(1)
})

/* (WaTE) web/app.js v2.0.0 */
