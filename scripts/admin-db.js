/**
 * \file      (WaTE) admin-db.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      03/11/2023
 * \version   2.0.1
 * \brief     Client JS — accès aux données admin via fetch (API JSON WaTE).
 *
 * \details   Fournit adminSchema, adminGetData, adminInsert, adminUpdate, adminDelete.
 *            Compatible ESM (import) — chargé via <script type="module">.
 *            Toutes les fonctions retournent des Promises.
 *            Les erreurs HTTP sont converties en rejets avec { message }.
 *
 *            Dépend de l'API WaTE :
 *              GET    /admin/api/db/schema
 *              GET    /admin/api/db/:table?offset=&limit=
 *              POST   /admin/api/db/:table
 *              PUT    /admin/api/db/:table
 *              DELETE /admin/api/db/:table
 *
 *            v2.0.0 : init(TABLE, fkOptions) — point d'entrée page CRUD.
 *                     _buildFields(TABLE, fkOptions, row) — construit l'attribut fields
 *                     JSON pour <admin-row> (ligne existante ou ligne d'insertion).
 *                     _load(TABLE, fkOptions) — chargement paginé + rendu des lignes.
 *                     Remplace scripts/admin-row.js init() + renderRows() + load().
 *                     admin-db.ejs n'a plus de template EJS inline pour <admin-row>.
 */

'use strict'

/**
 * \fn _check
 * \brief Vérifie le statut HTTP et retourne le JSON ou rejette avec l'erreur.
 *
 * \param res  Réponse fetch
 * \return     Promise<data>
 */
// FIX v2.0.3 #107: vérifie Content-Type avant JSON (HTML = erreur serveur)
async function _check(res) {
  const ct = res.headers.get('content-type') || ''
  if(ct.indexOf('application/json') < 0) throw new Error('Erreur serveur HTTP ' + res.status)
  const data = await res.json()
  if(!res.ok) throw new Error(data.error || 'Erreur HTTP ' + res.status)
  return data
}

/**
 * \fn adminSchema
 * \brief Récupère la liste des tables accessibles pour le profil courant.
 *
 * \return Promise<{ tables: string[] }>
 */
export async function adminSchema() {
  return _check(await fetch('/admin/api/db/schema'))
}

/**
 * \fn adminGetData
 * \brief Récupère les données paginées d'une table.
 *
 * \param table   Nom de la table
 * \param offset  Index de départ (défaut 0)
 * \param limit   Nombre de lignes (défaut 50, max 200 côté serveur)
 * \return        Promise<{ columns, rows, total, offset, limit }>
 */
export async function adminGetData(table, offset, limit) {
  const url = '/admin/api/db/' + encodeURIComponent(table) +
            '?offset=' + (offset || 0) + '&limit=' + (limit || 50)
  return _check(await fetch(url))
}

/**
 * \fn _headers
 * \brief Construit les headers JSON + X-CSRF-Token pour les appels API modifiants.
 *        Le token est lu depuis <meta name="csrf-token"> (injecté par common.ejs).
 *
 * \return Object headers
 */
function _headers() {
  const meta  = document.querySelector('meta[name="csrf-token"]')
  const token = meta && meta.content ? meta.content : ''
  const h     = { 'Content-Type': 'application/json' }
  if(token) h['X-CSRF-Token'] = token
  return h
}

/**
 * \fn adminInsert
 * \brief Insère une nouvelle ligne dans une table.
 *
 * \param table  Nom de la table
 * \param body   Objet { colonne: valeur, ... }
 * \return       Promise<{ ok: true }>
 */
export async function adminInsert(table, body) {
  return _check(await fetch('/admin/api/db/' + encodeURIComponent(table), {
    method  : 'POST',
    headers : _headers(),
    body    : JSON.stringify(body)
  }))
}

/**
 * \fn adminUpdate
 * \brief Modifie une ligne dans une table.
 *        Les colonnes PK dans body servent de clause WHERE.
 *
 * \param table  Nom de la table
 * \param body   Objet { colonne: valeur, ... } (doit inclure les PK)
 * \return       Promise<{ ok: true }>
 */
export async function adminUpdate(table, body) {
  return _check(await fetch('/admin/api/db/' + encodeURIComponent(table), {
    method  : 'PUT',
    headers : _headers(),
    body    : JSON.stringify(body)
  }))
}

/**
 * \fn adminDelete
 * \brief Supprime une ligne dans une table.
 *
 * \param table  Nom de la table
 * \param body   Objet { colPK: valeur, ... } (clés primaires uniquement)
 * \return       Promise<{ ok: true }>
 */
export async function adminDelete(table, body) {
  return _check(await fetch('/admin/api/db/' + encodeURIComponent(table), {
    method  : 'DELETE',
    headers : _headers(),
    body    : JSON.stringify(body)
  }))
}

/**
 * \fn _showError
 * \brief Affiche ou masque le message d'erreur dans #data-error.
 */
function _showError(msg) {
  const el = document.getElementById('data-error')
  if(!el) return
  el.textContent  = msg || ''
  el.style.display = msg ? 'inline' : 'none'
}

/**
 * \fn _buildFields
 * \brief Construit le tableau fields JSON pour un <admin-row>.
 *        row = null → mode insert (ligne vide).
 *        row = {}   → mode edit  (ligne existante).
 *
 *        Règles :
 *          - PK auto  : {pk:true, auto:true, readonly:true} → span .pk-val dans def.js.
 *                       readonly:true sert de signal hasExisting pour le dirty check.
 *          - PK+FK    : {type:'select', pk:true, disabled:true, readonly:true} → dropdown désactivée.
 *          - PK texte : {type:'text',  pk:true, readonly:true} → input readonly.
 *          - FK       : {type:'select', items:[…]} → <admin-list>.
 *          - Texte    : {type:'text'} → input.
 *          Boutons :
 *          - Ligne existante : update (disabled) + delete.
 *          - Ligne insert    : insert (disabled, activé dès toutes les PK renseignées).
 *
 * \param TABLE      {name, cols, confirmDelete, titleEdit?, titleDelete?, titleInsert?}
 * \param fkOptions  { '_table': { pkValue: label, … }, … }
 * \param row        Objet ligne (null pour insert)
 * \return           Array<FieldDef>
 */
// FIX v2.0.2 #98: cache partagé entre tous les appels _buildFields
const _fkCacheGlobal = {}
function _buildFields(TABLE, fkOptions, row) {
  const fields     = []
  const isExisting = row !== null

  function _items(fkTable) {
    if(_fkCacheGlobal[fkTable]) return _fkCacheGlobal[fkTable]
    const opts  = fkOptions[fkTable] || {}
    const items = [{label: '---', value: ''}]
    Object.keys(opts).forEach(k => { items.push({label: opts[k], value: k}) })
    _fkCacheGlobal[fkTable] = items
    return items
  }

  TABLE.cols.forEach(c => {
    const value = (isExisting && row[c.name] != null) ? String(row[c.name]) : ''

    if(c.pk && c.auto) {
      // PK AUTOINCREMENT : span grisé — readonly signale hasExisting pour dirty check
      fields.push({name: c.name, type: 'text', pk: true, auto: true, value: value,
                   readonly: isExisting || undefined})
    } else if(c.fk) {
      // FK (PK+FK possible) : dropdown <admin-list>
      const fld = {name: c.name, type: 'select', pk: c.pk || false,
                 items: _items(c.fk.table), value: value}
      if(isExisting && c.pk) { fld.readonly = true; fld.disabled = true }
      fields.push(fld)
    } else {
      // Colonne ordinaire ou PK texte
      const fld = {name: c.name, type: 'text', pk: c.pk || false, value: value}
      if(isExisting && c.pk) fld.readonly = true
      fields.push(fld)
    }
  })

  // Boutons d'action
  if(isExisting) {
    fields.push({type: 'button', action: 'update', label: '\u270F',
                 title: TABLE.titleEdit   || 'Modifier',   disabled: true})
    fields.push({type: 'button', action: 'delete', label: '\u2715',
                 title: TABLE.titleDelete || 'Supprimer'})
  } else {
    fields.push({type: 'button', action: 'insert', label: '\u2713 Valider',
                 title: TABLE.titleInsert || 'Insérer', disabled: true})
  }

  return fields
}

/**
 * \fn _load
 * \brief Charge la page courante (offset/limit) et met à jour le tbody + la pagination.
 *        Appelée par init() et à chaque admin-row:done.
 *
 * \param TABLE      {name, cols, confirmDelete, …}
 * \param fkOptions  { '_table': { pkValue: label } }
 */
// FIX v2.0.3 #168: offset/limit par instance (scopé à init, pas module-level)
function _load(TABLE, fkOptions, state) {
  _showError('')
  // FIX v2.0.3 #142: indicateur chargement
  const tbody = document.getElementById('data-body')
  if(tbody) tbody.innerHTML = '<tr><td colspan="99" style="text-align:center;color:var(--wate-text-muted);padding:2em">Chargement…</td></tr>'
  adminGetData(TABLE.name, state.offset, state.limit).then(data => {
    if(!tbody) return
    tbody.innerHTML = ''
    data.rows.forEach(row => {
      const el = document.createElement('admin-row')
      el.setAttribute('table',          TABLE.name)
      el.setAttribute('confirm-delete', TABLE.confirmDelete || 'Supprimer ?')
      el.setAttribute('fields',         JSON.stringify(_buildFields(TABLE, fkOptions, row)))
      tbody.appendChild(el)
    })

    const btnInsert = document.getElementById('btn-insert')
    if(btnInsert) btnInsert.disabled = false

    const total = data.total
    const pag   = document.getElementById('pagination')
    if(!pag) return
    pag.innerHTML = ''
    if(state.offset > 0) {
      const prev = document.createElement('button')
      prev.textContent = '\u25C4'
      prev.addEventListener('click', () => {
        state.offset = Math.max(0, state.offset - state.limit)
        _load(TABLE, fkOptions, state)
      })
      pag.appendChild(prev)
    }
    const info = document.createElement('span')
    info.textContent = ' ' + (state.offset + 1) + '\u2013' +
                       Math.min(state.offset + state.limit, total) + ' / ' + total + ' '
    pag.appendChild(info)
    if(state.offset + state.limit < total) {
      const nxt = document.createElement('button')
      nxt.textContent = '\u25BA'
      nxt.addEventListener('click', () => { state.offset += state.limit; _load(TABLE, fkOptions, state) })
      pag.appendChild(nxt)
    }
  }).catch(e => { state.offset = Math.max(0, state.offset - state.limit); _showError(e.message || 'Erreur de chargement') })
}

/**
 * \fn init
 * \brief Point d'entrée CRUD — câble le bouton "+ Insérer", écoute les événements
 *        admin-row:done / admin-row:error, déclenche le premier chargement.
 *
 * \param TABLE      {name, cols, confirmDelete, titleEdit?, titleDelete?, titleInsert?}
 * \param fkOptions  { '_table': { pkValue: label } }
 */
// FIX v2.0.3 #168: état par instance (plus de module-level _offset)
export function init(TABLE, fkOptions) {
  const _state = { offset: 0, limit: 50 }
  document.addEventListener('admin-row:done',  () => { _load(TABLE, fkOptions, _state) })
  document.addEventListener('admin-row:error', e => { _showError(e.detail && e.detail.message) })

  const btnInsert = document.getElementById('btn-insert')
  if(btnInsert) {
    btnInsert.addEventListener('click', () => {
      if(document.getElementById('insert-row')) return
      const el = document.createElement('admin-row')
      el.id  = 'insert-row'
      el.setAttribute('table',          TABLE.name)
      el.setAttribute('confirm-delete', TABLE.confirmDelete || 'Supprimer ?')
      el.setAttribute('fields',         JSON.stringify(_buildFields(TABLE, fkOptions, null)))
      const tbody = document.getElementById('data-body')
      if(tbody) tbody.insertBefore(el, tbody.firstChild)
      btnInsert.disabled = true
    })
  }

  _load(TABLE, fkOptions, _state)
}

/* (WaTE) admin-db.js v2.0.3 */