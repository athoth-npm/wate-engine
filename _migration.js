/**
 * \file      (WaTE) _migration.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   1.3.1
 * \brief     Module engine WaTE — migration de la DB.
 *
 * \details   v1.1.0 : upsert version WaTE dans _glossary (wate-version).
 *            v1.2.0 : filtrage des migrations moteur par scope.
 *            v1.2.1 : var → const/let.
 *            v1.2.2 : FIX WARN → WARNING + DROP TRIGGER erreurs logguées.
 *            v1.3.0 : harmonisation — arrow functions, logs RUN ENTER/LEAVE.
 *
 *                     Convention côté moteur : NNN_<scope>_<desc>.sql
 *                     Côté app : pas de filtrage, toutes exécutées dans l'ordre.
 */
'use strict'
const fs = require('fs')
const path = require('path')
const _core = require('./_core')

const _RE_SQL_EXT = /\.sql$/i

/**
 * \brief  Extrait le scope d'un fichier de migration moteur.
 * \param  filename Nom du fichier (sans chemin).
 * \return Le scope, ou 'engine' si non parsable.
 */
function parseScope(filename) {
  const base = filename.replace(_RE_SQL_EXT, '')
  const parts = base.split('_')
  if(parts.length < 3) return 'engine'
  return parts[1]
}

/**
 * \brief  Scrute un dossier, lit les .sql non appliqués, les exécute.
 * \param  db          Instance sqlite3.
 * \param  dirPath     Chemin du dossier de migrations.
 * \param  scopeFilter Fonction (filename) → bool (optionnelle).
 * \return Promise.
 */
function executeDir(db, dirPath, scopeFilter) { return new Promise((resolve, reject) => {
  _core.log.print(_core.log.RUN, 'ENTER executeDir(' + (dirPath || 'null') + ')')
  if(!dirPath || !fs.existsSync(dirPath)) {
    _core.log.print(_core.log.RUN, 'LEAVE executeDir() (no dir)')
    return resolve()
  }

  let files = fs.readdirSync(dirPath).filter(f => _RE_SQL_EXT.test(f)).sort()
  if(scopeFilter) {
    files = files.filter(f => {
      const keep = scopeFilter(f)
      if(!keep) _core.log.print(_core.log.INFO, `  -- Skipping ${f} (scope filtered out)`)
      return keep
    })
  }
  if(files.length === 0) {
    _core.log.print(_core.log.RUN, 'LEAVE executeDir() (no files)')
    return resolve()
  }

  db.all("SELECT filename FROM _migration", [], (err, rows) => {
    if(err) return reject(err)

    const applied = rows.map(r => r.filename)
    const pending = files.filter(f => applied.indexOf(f) < 0)
    if(pending.length === 0) {
      _core.log.print(_core.log.RUN, 'LEAVE executeDir() (none pending)')
      return resolve()
    }

    _core.log.print(_core.log.INFO, `Applying ${pending.length} migrations from ${dirPath}...`)

    let i = 0
    const nextMigration = () => {
      if(i >= pending.length) {
        _core.log.print(_core.log.RUN, 'LEAVE executeDir()')
        return resolve()
      }
      const file = pending[i]
      const sql = fs.readFileSync(path.join(dirPath, file), 'utf8')
      _core.log.print(_core.log.INFO, `  -> Executing ${file}`)

      db.run("BEGIN TRANSACTION", err => {
        if(err) return reject(err)
        db.exec(sql, err => {
          if(err) {
            _core.log.print(_core.log.ERROR, `Migration ${file} failed: ${err.message}`)
            return db.run("ROLLBACK", () => reject(err))
          }
          db.run("INSERT INTO _migration (filename) VALUES (?)", [file], err => {
            if(err) return db.run("ROLLBACK", () => reject(err))
            db.run("COMMIT", err => {
              if(err) return reject(err)
              i++
              nextMigration()
            })
          })
        })
      })
    }
    nextMigration()
  })
})}

/**
 * \brief  Lit package.json et met à jour wate-version dans _glossary (fr+en).
 * \param  db Instance sqlite3.
 * \return Promise.
 */
function upsertWateVersion(db) { return new Promise(resolve => {
  _core.log.print(_core.log.RUN, 'ENTER upsertWateVersion()')
  let version
  try { version = require('./package.json').version }
  catch(e) {
    _core.log.print(_core.log.WARNING, 'upsertWateVersion: package.json illisible — ' + e.message)
    _core.log.print(_core.log.RUN, 'LEAVE upsertWateVersion() (error)')
    return resolve()
  }
  if(!version) { _core.log.print(_core.log.RUN, 'LEAVE upsertWateVersion() (no version)'); return resolve() }

  const sql = "INSERT OR REPLACE INTO _glossary (lang_id, tag, label, list_id) VALUES (?, 'wate-version', ?, NULL)"
  db.run(sql, ['fr', version], err => {
    if(err) _core.log.print(_core.log.ERROR, 'upsertWateVersion(fr): ' + err.message)
    db.run(sql, ['en', version], err => {
      if(err) _core.log.print(_core.log.ERROR, 'upsertWateVersion(en): ' + err.message)
      else _core.log.print(_core.log.INFO, 'WaTE version ' + version + ' enregistrée dans _glossary.')
      _core.log.print(_core.log.RUN, 'LEAVE upsertWateVersion()')
      resolve()
    })
  })
})}

/**
 * \brief  Cycle complet des migrations : drop triggers, exécute SQL, recrée triggers.
 * \param  db        Instance sqlite3.
 * \param  argvPath  Chemin app (argv.path).
 * \param  modNames  Noms des modules chargés (filtrage scope).
 * \return Promise.
 */
function apply(db, argvPath, modNames) {
  modNames = modNames || []
  _core.log.print(_core.log.RUN, 'ENTER _migration.apply()')
  return new Promise((resolve, reject) => {
    db.run("CREATE TABLE IF NOT EXISTS _migration (filename TEXT PRIMARY KEY, applied_at DATETIME DEFAULT CURRENT_TIMESTAMP)", err => {
      if(err) return reject(new Error('Failed to create _migration table: ' + err.message))

      const engineMigrationsPath = path.join(__dirname, 'migrations')
      const appMigrationsPath = argvPath !== '' ? path.resolve(process.cwd(), argvPath, 'migrations') : null

      const engineScopeFilter = filename => {
        const scope = parseScope(filename)
        return scope === 'engine' || modNames.indexOf(scope) >= 0
      }

      const triggerActions = ['INSERT', 'UPDATE', 'DELETE']

      // 2. PHASE DE MAINTENANCE : ON BAISSE LES BOUCLIERS (Drop triggers)
      Promise.all(triggerActions.map(action => new Promise(resolve => {
        db.run('DROP TRIGGER IF EXISTS _item_no_' + action.toLowerCase(), err => {
          if(err) _core.log.print(_core.log.WARNING, '[migration] DROP TRIGGER failed: ' + err.message)
          resolve()
        })
      })))
      // 3. EXÉCUTION SÉQUENTIELLE
      .then(() => executeDir(db, engineMigrationsPath, engineScopeFilter))
      .then(() => executeDir(db, appMigrationsPath))
      .then(() => upsertWateVersion(db))
      .then(() => {
        // 4. FIN DE MAINTENANCE : ON REMONTE LES BOUCLIERS (seulement si migrations OK)
        // FIX v1.3.1 #34: return pour chaîner — apply() attend la recréation avant resolve
        return Promise.all(triggerActions.map(action => new Promise(resolve => {
          const triggerName = '_item_no_' + action.toLowerCase()
          db.run(`CREATE TRIGGER IF NOT EXISTS ${triggerName}
                  BEFORE ${action} ON _item
                  BEGIN
                    SELECT RAISE(ABORT, 'Direct ${action} on _item is not allowed via the application layer');
                  END`, err => {
            if(err) _core.log.print(_core.log.FATAL, 'Trigger ' + triggerName + ' failed: ' + err.message + ' — _item unprotected!')
            resolve() // ne pas bloquer le demarrage, les migrations SQL ont reussi
          })
        }))).then(() => {
          _core.log.print(_core.log.INFO, 'DB triggers on _ITEM active.')
          _core.log.print(_core.log.RUN, 'LEAVE _migration.apply()')
          resolve()
        })
      }).catch(err => reject(err))
    })
  })
}

module.exports = { apply, parseScope }

/* (WaTE) _migration.js v1.3.1 */
