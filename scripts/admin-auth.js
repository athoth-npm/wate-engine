/**
 * \file      (WaTE) admin-auth.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   2.0.3
 * \brief     Client JS — authentification admin via fetch (API JSON WaTE).
 *
 * \details   Fournit adminSignin, adminSignout et adminMe.
 *            Le mot de passe est haché en SHA256 côté client avant envoi —
 *            le serveur recalcule PBKDF2(sha256pwd, SHA256(email)).
 *            Compatible ESM (import) — chargé via <script type="module">.
 *
 *            Dépend de l'API WaTE :
 *              POST /admin/api/auth/signin
 *              POST /admin/api/auth/signout
 *              GET  /admin/api/auth/me
 *
 *            v1.0.1 : var → const et fonction fléchée dans map().
 *            v1.0.2 : mise en place d'un CSRF token.
 *            v1.1.0 : initialisation auto du formulaire auth (signin/signup/me).
 *                     sha256 : fallback pure JS (_sha256) pour HTTP réseau local
 *                     (SubtleCrypto indisponible hors contexte sécurisé).
 *                     Hash via event formdata — sans effet visuel sur les inputs.
 *            v1.2.0 : formdata — suppression de tous les champs vides avant envoi
 *                     (next et lang exclus) : _data.modify n'écrase pas les colonnes
 *                     non modifiées (absent de req.body = absent du SET).
 *                     submit disabled si champ readonly présent (mode édition) —
 *                     activé dès qu'un input ou select est modifié.
 *            v1.3.0 : la logique dirty-detection et suppression des champs vides est
 *                     déplacée dans adminFormBind (admin-row.js) — partagée avec admin-db.
 *                     Le formulaire est maintenant dans le shadow DOM de <admin-row> :
 *                     accès via _row.shadowRoot (shadow mode open).
 *                     admin-auth.js ne conserve que les traitements auth-spécifiques :
 *                       - SHA256 hashing dans l'event formdata.
 *                       - Validation password === password_confirm dans l'event submit.
 *            v2.0.0 : suppression du bloc customElements.whenDefined — SHA256 hashing
 *                     (hash:"sha256" sur le champ) et validation confirm (confirm:"field")
 *                     sont désormais gérés directement par custom/admin-row/def.js.
 *                     admin-auth.js ne fournit plus que les exports API.
 *            v2.0.1 : _sha256 remplacé par import { sha256 } from '/scripts/sha256.js'.
 *            v2.0.2 : FIX récursion infinie — la fonction locale sha256() masquait
 *                     l'import. Renommé l'import en sha256js pour le fallback.
 *                     Code mort _sha256() supprimé (~40 lignes).
 */

'use strict'

// FIX v1.0.2 : Variable locale stockant le token courant
let _csrfToken = ''

import { sha256 as sha256js } from '/scripts/sha256.js'

export function getCsrfToken() {
  if (_csrfToken) return _csrfToken
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta ? meta.content : ''
}

/**
 * \fn sha256
 * \brief Calcule le SHA256 d'une chaîne.
 *        Utilise SubtleCrypto (contexte sécurisé HTTPS/localhost),
 *        fallback pure JS via /scripts/sha256.js pour HTTP sur réseau local.
 *
 * \param message  Chaîne à hacher
 * \return         Promise<string> hexadécimale
 */
async function sha256(message) {
  if (globalThis.crypto?.subtle) {
    const enc = new TextEncoder()
    const buf = await crypto.subtle.digest('SHA-256', enc.encode(message))
    return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('')
  }
  return sha256js(message)
}

/**
 * \fn adminSignin
 * \brief Authentifie un utilisateur auprès de l'API admin WaTE.
 *
 * \param email     Email de l'utilisateur
 * \param password  Mot de passe en clair (haché SHA256 avant envoi)
 * \return          Promise<{ ok, lang }> ou rejet avec { message }
 */
export async function adminSignin(email, password) {
  const sha256pwd = await sha256(password)
  const res = await fetch('/admin/api/auth/signin', {
    method  : 'POST',
    headers : { 'Content-Type': 'application/json' },
    body    : JSON.stringify({ email, password: sha256pwd })
  })
  const data = await res.json()
  if(!res.ok) throw new Error(data.error || 'Erreur de connexion')

  // Stockage du token à la connexion
  if(data.csrf) _csrfToken = data.csrf
  return data
}

/**
 * \fn adminSignout
 * \brief Déconnecte la session courante.
 *
 * \return Promise<{ ok }> ou rejet avec { message }
 */
export async function adminSignout() {
  const csrf = getCsrfToken()
  const res = await fetch('/admin/api/auth/signout', {
    method  : 'POST',
    headers : { 'Content-Type': 'application/json', 'X-CSRF-Token': csrf }
  })
  const data = await res.json()
  if(!res.ok) throw new Error(data.error || 'Erreur de déconnexion')

  _csrfToken = ''
  return data
}

/**
 * \fn adminMe
 * \brief Récupère le profil de la session courante.
 *
 * \return Promise<{ email, profil_id, lang }> ou rejet avec { message }
 */
export async function adminMe() {
  const res  = await fetch('/admin/api/auth/me')
  const data = await res.json()
  if(!res.ok) throw new Error(data.error || 'Non authentifié')

  // Restauration du token si on recharge la page (F5)
  if(data.csrf) _csrfToken = data.csrf
  return data
}

/* (WaTE) admin-auth.js v2.0.3 */