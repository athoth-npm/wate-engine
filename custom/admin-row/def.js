/**
 * \file      (WaTE) custom/admin-row/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      17/04/2026
 * \version   1.2.4
 * \brief     Définition du custom element <admin-row> — ligne CRUD ou formulaire standalone.
 *
 * \details   Remplace les appels customHTMLElement.create('admin-row', ...) inline dans
 *            admin-db.ejs et admin-auth.ejs. Le rendu complet est piloté par l'attribut
 *            fields (JSON Array de FieldDef).
 *
 *            Importe custom/admin-list/def.js — composition : chaque colonne FK est
 *            rendue par une instance <admin-list> indépendante dans le shadow DOM.
 *            Plusieurs <admin-list> peuvent coexister dans un même <admin-row>
 *            (ex : profil_id + lang_id dans _user).
 *
 *            Attributs de <admin-row> :
 *              fields         — JSON Array<FieldDef>.
 *              mode           — "form" → formulaire standalone (panel) ; absent → ligne table.
 *              action         — URL POST → submit natif (admin-auth) ; absent → CRUD AJAX.
 *              table          — Nom de la table SQLite pour les appels CRUD.
 *              confirm-delete — Texte du confirm() avant suppression.
 *
 *            FieldDef :
 *              { name, type, label?, value?, pk?, auto?, readonly?, required?,
 *                hash?, confirm?, hint?, placeholder?, autofocus?,
 *                items?, disabled?,
 *                action?, title?, href?, id? }
 *            Types spéciaux  : "hidden", "select", "button", "submit", "link".
 *            Types HTML       : "text", "email", "password", …
 *            hash:"sha256"   → hachage synchrone dans formdata (champs password).
 *            confirm:"field" → validation croisée dans submit (ex: password_confirm).
 *            Pour type "link" : si method est défini, le click déclenche fetch(href, {method})
 *            avec confirmation window.confirm(confirm) et redirection vers next après succès.
 *
 *            v1.2.1 : _sha256 → import { sha256 } from '/scripts/sha256.js'.
 *
 *            Événements émis (bubbles, mode CRUD) :
 *              admin-row:done  — CRUD réussi → la page appelle load().
 *              admin-row:error — CRUD échoué, detail.message = message d'erreur.
 *
 *            v1.2.0 : window.confirm / alert natifs remplacés par window.wateModal
 *                     (dépendance implicite sur common.ejs qui charge modal-popup/def.js)
 *                     (custom/modal-popup/def.js) — style cohérent avec la charte.
 *                     Les handlers link click et form submit deviennent async.
 *            v1.2.1 : _sha256 → import { sha256 } from '/scripts/sha256.js'.
 *            v1.2.2 : code mort _removed_sha256() supprimé (~40 lignes).
 *            v1.2.3 : FIX _collectBody supporte textarea, checkbox, radio.
 *                     FIX largeurs colonnes réévaluées au resize fenêtre.
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'
import '/custom/admin-list/def.js'
import { adminUpdate, adminDelete, adminInsert } from '/scripts/admin-db.js'
import { sha256 } from '/scripts/sha256.js'

// ── Collecte du corps CRUD depuis le shadow DOM ───────────────────────────────
// PK update/delete : valeur d'origine depuis fields (non modifiable).
// PK non-auto insert : valeur depuis le DOM.
// Champs vides exclus en insert. hidden / button / submit / link ignorés.
/**
 * \brief  Collecte les données du formulaire shadow DOM pour CRUD.
 * \param  form       Élément <form> dans le shadowRoot.
 * \param  fields     Array<FieldDef> issu de l'attribut JSON.
 * \param  forInsert  true → exclut les champs vides ; false → PK depuis fields.
 * \return Objet { name: value } prêt pour adminInsert/Update/Delete.
 */
function _collectBody(form, fields, forInsert) {
  const body = {}
  fields.forEach(function(f) {
    if(!f.name) return
    const t = f.type
    if(t === 'hidden' || t === 'button' || t === 'submit' || t === 'link') return
    if(f.pk && f.auto) return

    if(f.pk && !forInsert) {
      body[f.name] = f.value != null ? String(f.value) : ''
      return
    }

    if(t === 'select') {
      const listEl = form.querySelector('[name="' + f.name + '"]')
      const sel    = listEl && listEl.shadowRoot && listEl.shadowRoot.querySelector('select')
      if(sel && sel.value !== '') body[f.name] = sel.value
    } else if(t === 'checkbox' || t === 'radio') {
      // FIX v1.2.4 #99: checkbox non cochée ignorée en insert (préserve DB default)
      const el = form.querySelector('input[name="' + f.name + '"]' + (t === 'radio' ? ':checked' : ''))
      if(el && t === 'checkbox' && !el.checked && forInsert) return
      if(el) body[f.name] = t === 'checkbox' ? el.checked : el.value
    } else {
      // input text/password/date/number/email... + textarea
      const el = form.querySelector('input[name="' + f.name + '"], textarea[name="' + f.name + '"]')
      if(el && (!forInsert || el.value !== '')) body[f.name] = el.value
    }
  })
  return body
}

// ── Définition du custom element ──────────────────────────────────────────────
customHTMLElement.create('admin-row',
  '@import "/custom/admin-row/def.css"',
  '<form></form>',
  null,
  function(element, signal) {
    const shadowRoot = this
    const form       = shadowRoot.querySelector('form')
    // FIX v1.2.4 #108: try-catch protège contre JSON corrompu
    let fields; try { fields = JSON.parse(element.getAttribute('fields') || '[]') } catch(e) { console.error('admin-row: invalid fields JSON', e); return }
    const isForm     = element.getAttribute('mode')                     === 'form'
    const formAction = element.getAttribute('action')                   || null
    const tableName  = element.getAttribute('table')                    || null
    const confirmDel = element.getAttribute('confirm-delete')           || 'Supprimer ?'

    if(formAction) { form.method = 'POST'; form.action = formAction }

    const insertMode  = fields.some(function(f) { return f.type === 'button' && f.action === 'insert' })
    const hasExisting = fields.some(function(f) { return f.readonly === true })

    // ── Paragraphe d'erreur (mode form uniquement) ─────────────────────────
    let errEl = null
    if(isForm) {
      errEl           = document.createElement('p')
      errEl.id        = 'form-error'
      errEl.className = 'error'
      form.appendChild(errEl)
    }

    // ── Rendu des champs ───────────────────────────────────────────────────
    let updateBtn  = null  // bouton update / insert / submit — dirty check et allPkFilled
    let btnWrapper = null  // .admin-col-btn (table) ou .form-actions (form)

    fields.forEach(function(f) {

      // ── Champ caché ──────────────────────────────────────────────────────
      if(f.type === 'hidden') {
        const inp   = document.createElement('input')
        inp.type  = 'hidden'
        inp.name  = f.name
        inp.value = f.value != null ? String(f.value) : ''
        form.appendChild(inp)
        return
      }

      // ── Boutons et liens ─────────────────────────────────────────────────
      if(f.type === 'button' || f.type === 'submit' || f.type === 'link') {
        if(!btnWrapper) {
          btnWrapper           = document.createElement('div')
          btnWrapper.className = isForm ? 'form-actions' : 'admin-col-btn'
          form.appendChild(btnWrapper)
        }

        if(f.type === 'link') {
          const a         = document.createElement('a')
          a.textContent = f.label || ''
          if(f.method) {
            a.href = '#'
            a.addEventListener('click', async function(e) {
              e.preventDefault()
              // FIX v1.2.5 #167: désactiver le lien pendant l'opération async
              if(a.disabled) return
              if(f.confirm && window.wateModal && !(await window.wateModal.confirm({text: f.confirm, title: f.label || ''}))) return
              a.disabled = true
              const csrfMeta = document.querySelector('meta[name="csrf-token"]')
              const headers  = {}
              if(csrfMeta && csrfMeta.content) headers['X-CSRF-Token'] = csrfMeta.content
              fetch(f.href, {method: f.method, headers: headers})
                .then(function(r) {
                  if(r.ok) {
                    if(f.next) window.location.href = f.next
                  } else {
                    a.disabled = false
                    r.json().then(function(d) {
                      const msg = d.error || 'Erreur'
                      if(errEl) errEl.textContent = msg
                      else      window.wateModal.info({text: msg, title: 'Erreur'})
                    }).catch(function() {
                      if(errEl) errEl.textContent = 'Erreur'
                      else      window.wateModal.info({text: 'Erreur', title: 'Erreur'})
                    })
                  }
                })
                .catch(function(err) {
                  a.disabled = false
                  if(errEl) errEl.textContent = err.message
                  else      window.wateModal.info({text: err.message, title: 'Erreur'})
                })
            }, {signal})
          } else {
            a.href = f.href || '#'
          }
          btnWrapper.appendChild(a)
          return
        }

        if(f.type === 'submit') {
          const sub   = document.createElement('input')
          sub.type  = 'submit'
          sub.value = f.label || ''
          if(f.id)       sub.id       = f.id
          if(f.disabled) sub.disabled = true
          updateBtn = sub
          btnWrapper.appendChild(sub)
          return
        }

        // type === 'button' → <button type="submit" name="__action">
        const btn         = document.createElement('button')
        btn.type        = 'submit'
        btn.name        = '__action'
        btn.value       = f.action || ''
        btn.textContent = f.label  || ''
        if(f.title)    btn.title    = f.title
        if(f.disabled) btn.disabled = true
        if(f.action === 'update' || f.action === 'insert') updateBtn = btn
        btnWrapper.appendChild(btn)
        return
      }

      // ── Wrapper (table: .admin-col / form: .form-row) ────────────────────
      const wrapper       = document.createElement('div')
      wrapper.className = isForm ? 'form-row' : 'admin-col'

      if(isForm && f.label) {
        const label = document.createElement('label')
        label.setAttribute('for', f.name || '')
        label.textContent = f.label
        if(f.hint) {
          label.appendChild(document.createElement('br'))
          const small         = document.createElement('small')
          small.textContent = f.hint
          label.appendChild(small)
        }
        wrapper.appendChild(label)
      }

      // PK auto → span grisé (insert : placeholder, existant : valeur)
      if(f.pk && f.auto) {
        const span         = document.createElement('span')
        span.className   = 'pk-val'
        span.textContent = (f.value != null && f.value !== '') ? String(f.value) : '(auto)'
        wrapper.appendChild(span)
        form.appendChild(wrapper)
        return
      }

      // FK → <admin-list>
      if(f.type === 'select') {
        const list = document.createElement('admin-list')
        list.setAttribute('name',  f.name)
        list.setAttribute('items', JSON.stringify(f.items || []))
        if(f.value != null && f.value !== '') list.setAttribute('value', String(f.value))
        if(f.disabled || f.readonly)          list.setAttribute('disabled', '')
        if(f.pk)                               list.className = 'pk-fk'
        wrapper.appendChild(list)
        form.appendChild(wrapper)
        return
      }

      // Input standard ou textarea
      const isTA  = f.type === 'textarea'
      const inp   = document.createElement(isTA ? 'textarea' : 'input')
      if(!isTA) inp.type = f.type || 'text'
      // FIX v1.2.4 #65: autocomplete pour password managers dans le shadow DOM
      inp.name  = f.name || ''
      if(f.type === 'password') inp.autocomplete = f.autocomplete || 'current-password'
      if(f.type !== 'password' && f.value != null) inp.value = String(f.value)
      if(isTA) { inp.rows = f.rows || 3 }
      if(f.readonly)    inp.readOnly  = true
      if(f.required)    inp.required  = true
      if(f.placeholder) inp.placeholder = f.placeholder
      if(f.autofocus)   inp.autofocus   = true
      if(f.pk && !f.auto) inp.className = 'pk-input'
      wrapper.appendChild(inp)
      form.appendChild(wrapper)
    })

    // ── Synchronisation largeurs avec <th> (mode table) ───────────────────
    const _syncWidths = function() {
      if(isForm) return
      const _ths   = Array.from(document.querySelectorAll('#data-head th'))
      const _cells = Array.from(shadowRoot.querySelectorAll('.admin-col, .admin-col-btn'))
      _ths.forEach(function(th, i) {
        if(_cells[i]) _cells[i].style.width = th.offsetWidth + 'px'
      })
    }
    _syncWidths()
    window.addEventListener('resize', _syncWidths, {signal})

    // ── Dirty check — réactive updateBtn sur toute modification ───────────
    if(hasExisting && !insertMode && updateBtn) {
      const _df = fields.filter(function(f) {
        return f.name && f.type !== 'hidden' && f.type !== 'button' &&
               f.type !== 'submit' && f.type !== 'link' && !(f.pk && f.auto)
      })
      function _vals() {
        return _df.map(function(f) {
          if(f.type === 'select') {
            const l = form.querySelector('[name="' + f.name + '"]')
            const s = l && l.shadowRoot && l.shadowRoot.querySelector('select')
            return s ? s.value : ''
          }
          const i = form.querySelector('input[name="' + f.name + '"]')
          return i ? i.value : ''
        }).join('\x00')
      }
      const _snap = _vals()
      function _dirty() { updateBtn.disabled = (_vals() === _snap) }
      form.addEventListener('input',  _dirty, {signal})
      form.addEventListener('change', _dirty, {signal})
    }

    // ── allPkFilled — active updateBtn en insert quand les PK sont saisies ─
    if(insertMode && updateBtn) {
      const _pk = fields.filter(function(f) { return f.pk && !f.auto })
      function _allPk() {
        return _pk.every(function(f) {
          if(f.type === 'select') {
            const l = form.querySelector('[name="' + f.name + '"]')
            const s = l && l.shadowRoot && l.shadowRoot.querySelector('select')
            return s && s.value !== ''
          }
          const i = form.querySelector('input[name="' + f.name + '"]')
          return i && i.value !== ''
        })
      }
      form.addEventListener('input',  function() { updateBtn.disabled = !_allPk() }, {signal})
      form.addEventListener('change', function() { updateBtn.disabled = !_allPk() }, {signal})
    }

    // ── formdata : SHA256 + CSRF + suppression des champs vides (mode POST natif) ─
    // (Non déclenché en mode CRUD — e.preventDefault() empêche la soumission.)
    form.addEventListener('formdata', function(e) {
      // Injection CSRF token depuis <meta name="csrf-token"> si absent du formData
      const csrfMeta = document.querySelector('meta[name="csrf-token"]')
      if(csrfMeta && csrfMeta.content && !e.formData.has('_csrf')) {
        e.formData.set('_csrf', csrfMeta.content)
      }
      fields.forEach(function(f) {
        if(f.hash !== 'sha256') return
        const v = e.formData.get(f.name)
        if(v) e.formData.set(f.name, sha256(v))
      })
      for(var _p of [...e.formData.entries()]) {
        if(_p[0] !== 'next' && _p[0] !== 'lang' && _p[0] !== '_csrf' && _p[1] === '') e.formData.delete(_p[0])
      }
    }, {signal})

    // ── submit ─────────────────────────────────────────────────────────────
    form.addEventListener('submit', async function(e) {

      // Mode POST natif (action URL présent) — validation puis submit naturel
      if(formAction) {
        if(errEl) errEl.textContent = ''
        const cf = fields.find(function(f) { return f.confirm })
        if(cf) {
          const p1 = form.querySelector('[name="' + cf.confirm + '"]')
          const p2 = form.querySelector('[name="' + cf.name   + '"]')
          if(p1 && p2 && p1.value && p1.value !== p2.value) {
            e.preventDefault()
            if(errEl) errEl.textContent = 'Les mots de passe ne correspondent pas.'
          }
        }
        return
      }

      // Mode CRUD — intercept, appel API, événement résultat
      e.preventDefault()
      const act = (e.submitter && e.submitter.name === '__action')
                ? e.submitter.value
                : (insertMode ? 'insert' : 'update')

      // FIX v1.2.4 #139: composed:true — traverse le shadow DOM
      function _ok()     { element.dispatchEvent(new CustomEvent('admin-row:done',  {bubbles: true, composed: true})) }
      function _err(err) { element.dispatchEvent(new CustomEvent('admin-row:error', {bubbles: true, composed: true, detail: {message: typeof err === 'string' ? err : (err && err.message) || 'Unknown error'}})) }

      if(act === 'delete') {
        if(!(await window.wateModal.confirm({text: confirmDel, title: '\u2715 Supprimer'}))) return
        adminDelete(tableName, _collectBody(form, fields, false)).then(_ok).catch(_err)
      } else if(act === 'insert') {
        adminInsert(tableName, _collectBody(form, fields, true)).then(_ok).catch(_err)
      } else {
        adminUpdate(tableName, _collectBody(form, fields, false)).then(_ok).catch(_err)
      }
    }, {signal})
  }
)

/* (WaTE) custom/admin-row/def.js v1.2.5 */
