/**
 * \file      (WaTE) custom/modal-popup/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      18/04/2026
 * \version   1.3.3
 * \brief     Custom element <modal-popup> + API globale window.wateModal.
 *
 * \details   Remplace alert() / confirm() natifs par une boîte stylée à la charte WaTE.
 *            Trois modes pilotés par l'attribut `mode` :
 *              - "info"    : un seul bouton OK (alert).
 *              - "confirm" : OK + Annuler (window.confirm). Icône « ? » sur le logo.
 *              - "about"   : un seul bouton OK, contenu libre (À propos).
 *
 *            Attributs :
 *              mode         — "info" | "confirm" | "about" (défaut "info").
 *              title        — Titre affiché dans le modal.
 *              ok-label     — Libellé du bouton OK     (défaut "OK").
 *              cancel-label — Libellé du bouton Annuler (défaut "Annuler").
 *
 *            API globale (attachée à window au chargement du module) :
 *              wateModal.info({text|html, title?, okLabel?})      → Promise<true>
 *              wateModal.confirm({text|html, title?, okLabel?, cancelLabel?}) → Promise<boolean>
 *              wateModal.about({html, title?, okLabel?})           → Promise<true>
 *
 *            Sécurité :
 *              `text`  — injecté en textContent (safe).
 *              `html`  — injecté en innerHTML  — l'appelant doit garantir que
 *                        le contenu est trusté (jamais du texte utilisateur).
 *
 *            Thème :
 *              Toute la charte (couleurs, radius, padding, ombres, boutons)
 *              est exposée en CSS custom properties --mp-*. Voir le contrat
 *              complet et la liste des variables dans
 *              custom/modal-popup/def.css (header).
 *
 *            Fermeture :
 *              - Clic OK         → resolve(true),  suppression de l'élément.
 *              - Clic Annuler    → resolve(false), suppression (mode confirm uniquement).
 *              - Clic backdrop   → équivalent Annuler en confirm, OK en info/about.
 *              - Touche Échap    → équivalent Annuler en confirm, OK en info/about.
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'

// Règles critiques de positionnement en ligne — évitent le FOUC (modal affiché
// en bas avant que l'@import ne soit appliqué). L'@import apporte le reste du
// style (couleurs, typo, boutons).
customHTMLElement.create('modal-popup',
  '@import "/custom/modal-popup/def.css";' +
  ':host{position:fixed;inset:0;z-index:1000;display:block}' +
  '.backdrop{position:absolute;inset:0;display:flex;align-items:center;justify-content:center}' +
  '.icon{width:48px;height:48px;display:var(--mp-icon-display,block);background-image:var(--mp-icon-src,url("/images/WaTE-Logo-White.png"));background-position:center;background-size:contain;background-repeat:no-repeat}',
  '<div class="backdrop" part="backdrop">' +
    '<div class="popup" role="dialog" aria-modal="true" aria-labelledby="modal-title">' +
      '<div class="header">' +
        '<div class="icon"></div>' +
        '<h2 class="title" id="modal-title">${title?}</h2>' +
      '</div>' +
      '<div class="body"><slot></slot></div>' +
      '<div class="actions">' +
        '<button type="button" class="btn-cancel">${cancel-label?Annuler}</button>' +
        '<button type="button" class="btn-ok">${ok-label?OK}</button>' +
      '</div>' +
    '</div>' +
  '</div>',
  null,
  function(element, signal) {
    const root     = this  // shadowRoot
    const popup    = root.querySelector('.popup')
    const btnOk    = root.querySelector('.btn-ok')
    const btnCan   = root.querySelector('.btn-cancel')
    const backdrop = root.querySelector('.backdrop')
    const mode     = element.getAttribute('mode') || 'info'
    const isConfirm = (mode === 'confirm')

    // FIX v1.3.3 #117: restaurer le focus après fermeture
    const _prevFocus = document.activeElement
    function _close(ok) {
      element.dispatchEvent(new CustomEvent(ok ? 'modal:ok' : 'modal:cancel'))
      element.remove()
      if(_prevFocus && _prevFocus.focus) _prevFocus.focus()
    }

    btnOk.addEventListener('click', function() { _close(true) }, {signal})
    btnCan.addEventListener('click', function() { _close(false) }, {signal})
    backdrop.addEventListener('click', function(e) {
      if(e.target === backdrop) _close(!isConfirm)
    }, {signal})
    // FIX v1.3.3 #93: focus trapping — Tab/Shift+Tab cyclent dans la modale
    const _firstFocus = btnOk
    const _lastFocus  = isConfirm ? btnCan : btnOk
    popup.addEventListener('keydown', function(e) {
      if(e.key === 'Escape')      { _close(!isConfirm); return }
      if(e.key === 'Enter')       { _close(true); return }
      if(e.key === 'Tab') {
        if(e.shiftKey && document.activeElement === _firstFocus) { e.preventDefault(); _lastFocus.focus() }
        else if(!e.shiftKey && document.activeElement === _lastFocus) { e.preventDefault(); _firstFocus.focus() }
      }
    }, {signal})
    document.addEventListener('keydown', function(e) {
      if(e.key === 'Escape')      _close(!isConfirm)
      else if(e.key === 'Enter')  _close(true)
    }, {signal})

    // FIX v1.3.3 #137: setTimeout stocké pour cleanup si modale retirée avant le tick
    const _focusTimer = setTimeout(function() { btnOk.focus() }, 0)
    signal.addEventListener('abort', function() { clearTimeout(_focusTimer) })
  }
)

/**
 * \fn _open
 * \brief Crée un <modal-popup>, le connecte au DOM et retourne une Promise.
 *
 * \param opts Options : { mode, title?, okLabel?, cancelLabel?, text? | html? }
 * \return     Promise<boolean> — true si OK, false si Annuler.
 */
function _open(opts) {
  return new Promise(function(resolve) {
    const m = document.createElement('modal-popup')
    m.setAttribute('mode', opts.mode || 'info')
    if(opts.title)       m.setAttribute('title',        opts.title)
    if(opts.okLabel)     m.setAttribute('ok-label',     opts.okLabel)
    if(opts.cancelLabel) m.setAttribute('cancel-label', opts.cancelLabel)
    if(opts.html)      m.innerHTML   = opts.html
    else if(opts.text) m.textContent = opts.text
    m.addEventListener('modal:ok',     function() { resolve(true) })
    m.addEventListener('modal:cancel', function() { resolve(false) })
    document.body.appendChild(m)
  })
}

window.wateModal = {
  info:    function(opts) { return _open(Object.assign({}, opts, {mode: 'info'})) },
  confirm: function(opts) { return _open(Object.assign({}, opts, {mode: 'confirm'})) },
  about:   function(opts) { return _open(Object.assign({}, opts, {mode: 'about'})) }
}

/* (WaTE) custom/modal-popup/def.js v1.3.3 */
