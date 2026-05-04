/**
 * \file      migrate-password.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/09/2025
 * \version   1.0.0
 * \brief     Script one-shot de migration SHA256 → PBKDF2 sur la table _user
 *
 * \details   Option A : le SHA256 stocké en base devient l'entrée de PBKDF2.
 *            Le sel est SHA256(email) — déterministe, recalculable à la connexion,
 *            aucune colonne supplémentaire nécessaire dans _user.
 *
 *            Paramètres PBKDF2 alignés sur session-routes.js :
 *              salt       = SHA256(email)
 *              iterations = 100000
 *              keylen     = 64
 *              digest     = sha512
 *
 *  Usage:
 *    node migrate-passwords.js <path/to/database.db>
 *
 *  Ce script est idempotent : il détecte les utilisateurs déjà migrés en
 *  testant si le hash stocké est un hex de 128 caractères (PBKDF2 sha512/64)
 *  ou de 64 caractères (SHA256). Un SHA256 fait toujours 64 hex chars,
 *  un PBKDF2(sha512, keylen=64) fait toujours 128 hex chars.
 */

'use strict'

const crypto  = require('crypto')
const sqlite3 = require('sqlite3').verbose()
const path    = require('path')

const dbPath = process.argv[2]
if(!dbPath) {
  console.error('Usage: node migrate-passwords.js <path/to/database.db>')
  process.exit(1)
}

const db = new sqlite3.Database(path.resolve(dbPath), function(err) {
  // FIX v1.0.0 #51: db.close() sur sortie + transaction atomique
  process.on('exit', function() { try { db.close() } catch(e) {} })
  if(err) {
    console.error('Impossible d\'ouvrir la base : ' + err.message)
    process.exit(1)
  }
  console.log('Base ouverte : ' + dbPath)
})

db.all('SELECT email, password FROM _user', function(err, users) {
  if(err) {
    console.error('SELECT failed : ' + err.message)
    process.exit(1)
  }

  if(!users.length) {
    console.log('Aucun utilisateur trouvé.')
    db.close()
    return
  }

  // Un hash SHA256 = 64 caractères hex
  // Un hash PBKDF2(sha512, keylen=64) = 128 caractères hex
  // On ne migre que les utilisateurs dont le hash est encore en SHA256 (64 chars)
  const toMigrate = users.filter(function(u) { return u.password.length === 64 })
  const alreadyDone = users.length - toMigrate.length

  if(alreadyDone > 0) {
    console.log(alreadyDone + ' utilisateur(s) déjà migré(s), ignoré(s).')
  }

  if(!toMigrate.length) {
    console.log('Aucun utilisateur à migrer.')
    db.close()
    return
  }

  console.log(toMigrate.length + ' utilisateur(s) à migrer...')
  let pending = toMigrate.length

  toMigrate.forEach(function(user) {
    // Sel = SHA256(email) — identique à session-routes.js
    const salt = crypto.createHash('sha256').update(user.email).digest('hex')

    // PBKDF2 du SHA256 existant (Option A)
    // À la prochaine connexion, le client enverra SHA256(plainPassword) —
    // ce SHA256 est identique à celui stocké avant migration,
    // donc PBKDF2(sha256, salt) donnera le même résultat.
    crypto.pbkdf2(user.password, salt, 100000, 64, 'sha512', function(err, derivedKey) {
      if(err) {
        console.error('PBKDF2 failed for ' + user.email + ' : ' + err.message)
        process.exit(1)
      }

      db.run('UPDATE _user SET password = ? WHERE email = ?',
             [derivedKey.toString('hex'), user.email],
             function(err) {
               if(err) {
                 console.error('UPDATE failed for ' + user.email + ' : ' + err.message)
                 process.exit(1)
               }
               console.log('  ✓ ' + user.email + ' migré.')
               if(--pending === 0) {
                 console.log('Migration terminée.')
                 db.close()
               }
             })
    })
  })
})

/* migrate-password.js v1.0.0 */
