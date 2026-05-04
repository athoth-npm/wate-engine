/**
 * \file      (WaTE: show-image) def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/09/2025
 * \version   1.2.6
 * \brief     Détection shadow DOM via rootNode.host au lieu de instanceof ShadowRoot —
 *            instanceof échoue en cross-frame (iframe vs window.top).
 *
 * \details  Contrainte d'usage : une seule instance de <show-image> par page
 *            (window.top.imageContainer partagé). Accepté ANALYSIS v10 #161.
 *
 *            V1.2.3 : - Guard pour l'appel de la fonction soundStart
 *           V1.2.4 : - FIX imagePrev/imageNext : const curr réassigné
 *                     dans while → TypeError en mode strict.
 *                     const → let (2 occurrences).
 *                    - lastIndexOf pour trouver le fichier image '-mini'
 *           V1.2.5 : FIX imageArea vérifié via isConnected — recréé
 *                    si l'élément a été retiré du DOM.
 */

import { customHTMLElement } from '/custom/custom.js'

customHTMLElement.create('show-image',
  '@import "/custom/show-image/def.css"',
  '<div id="showImage">\
    <p id="closeArrow" role="button" tabindex="0" aria-label="Fermer"></p>\
    <p id="prevArrow" role="button" tabindex="0" aria-label="Précédent"></p>\
    <img id="theImage" alt="">\
    <p id="nextArrow" role="button" tabindex="0" aria-label="Suivant"></p>\
  </div>',
  null,
  function(element, signal) {
    const shadowRoot = this
    const closeArrow = shadowRoot.querySelector('#closeArrow')
    const prevArrow  = shadowRoot.querySelector('#prevArrow')
    const nextArrow  = shadowRoot.querySelector('#nextArrow')
    const theImage   = shadowRoot.querySelector('#theImage')

    // FIX v1.0.0 #94: flèches focusables + clavier
    closeArrow.setAttribute('tabindex', '0'); closeArrow.setAttribute('role', 'button')
    prevArrow.setAttribute('tabindex', '0');  prevArrow.setAttribute('role', 'button')
    nextArrow.setAttribute('tabindex', '0');  nextArrow.setAttribute('role', 'button')
    const _click = function(fn) { return function(e) { if(e.type === 'keydown' && e.key !== 'Enter' && e.key !== ' ') return; e.preventDefault(); fn() } }
    closeArrow.addEventListener('click', function() { window.top.imageHide(closeArrow) }, { signal })
    closeArrow.addEventListener('keydown', _click(function() { window.top.imageHide(closeArrow) }), { signal })
    prevArrow.addEventListener('click',  function() { window.top.imageInit(window.top.imagePrev()) }, { signal })
    prevArrow.addEventListener('keydown',  _click(function() { window.top.imageInit(window.top.imagePrev()) }), { signal })
    nextArrow.addEventListener('click',  function() { window.top.imageInit(window.top.imageNext()) }, { signal })
    nextArrow.addEventListener('keydown',  _click(function() { window.top.imageInit(window.top.imageNext()) }), { signal })
    theImage.addEventListener('click',   function() { window.top.imageHide(theImage) }, { signal })
    theImage.addEventListener('load',    function() { window.top.imageShow(theImage) }, { signal })
  }
)

// NOTE: API publique partagée entre <show-image> instances. Accepté ANALYSIS v5 #28.
window.top.imageInit = function(container) {
  if(!container) return

  // FIX v1.0.0 #133: guard — deux clics rapides ne bloquent pas le premier
  if(window.top.imageContainer && window.top.imageContainer !== container) {
    window.top.imageContainer.style.cursor = ''
  }
  container.style.cursor = 'wait'
  window.top.imageContainer = container

  const shadow  = window.top.imageArea.shadowRoot
  const prevBtn = shadow.querySelector('#prevArrow')
  const nextBtn = shadow.querySelector('#nextArrow')
  const theImg  = shadow.querySelector('#theImage')

  prevBtn.style.visibility = window.top.imagePrev() ? 'visible' : 'hidden'
  nextBtn.style.visibility = window.top.imageNext() ? 'visible' : 'hidden'

  // src direct si pas de '-mini' (images pleine page), sinon strip le suffixe
  // FIX v1.2.3 Si le path contient plusieurs '-mini' on garantit de prendre celui du fichier !
  const idx = container.src.lastIndexOf('-mini')
  theImg.src = (container.src.substring(0, 5) === 'data:') ? container.src
             : (idx >= 0) ? container.src.substring(0, idx)
             : container.src
}

window.top.imageShow = function(ele) {
  window.top.imageContainer.style.cursor = ''
  // Son uniquement si le container est dans un shadow DOM (custom element avec attribut sound)
  const rootNode = window.top.imageContainer.getRootNode()
  if(!!rootNode.host) {
    const soundFile = rootNode.host.getAttribute('sound')
    // FIX v1.2.3 guard d'existance de la fonction window.top.soundStart
    if(soundFile) setTimeout(function() { if(typeof window.top.soundStart === 'function') window.top.soundStart('store/' + soundFile) }, 50)
  }
  ele.parentElement.style.display = 'flex'
  ele.parentElement.focus()
}

window.top.imageHide = function(ele) {
  if(typeof window.top.soundStop === 'function') window.top.soundStop()
  ele.parentElement.style.display = 'none'
}

window.top.imagePrev = function() {
  if(!window.top.imageContainer) return null
  const rootNode = window.top.imageContainer.getRootNode()
  if(!!rootNode.host) {
    // Contexte shadow DOM — navigation entre custom elements frères du même type
    // FIX v1.2.4 : let (réassigné dans while)
    let curr        = rootNode.host
    const tagName   = curr.nodeName
    while(curr.previousElementSibling && curr.previousElementSibling.nodeName !== tagName) {
      curr = curr.previousElementSibling
    }
    if(curr.previousElementSibling && curr.previousElementSibling.shadowRoot) {
      return curr.previousElementSibling.shadowRoot.querySelector('img')
    }
  } else {
    // Contexte DOM standard — navigation entre <img> frères
    let prev = window.top.imageContainer.previousElementSibling
    while(prev && prev.nodeName !== 'IMG') prev = prev.previousElementSibling
    return prev || null
  }
  return null
}

window.top.imageNext = function() {
  if(!window.top.imageContainer) return null
  const rootNode = window.top.imageContainer.getRootNode()
  if(!!rootNode.host) {
    // Contexte shadow DOM — navigation entre custom elements frères du même type
    // FIX v1.2.4 : let (réassigné dans while)
    let curr        = rootNode.host
    const tagName   = curr.nodeName
    while(curr.nextElementSibling && curr.nextElementSibling.nodeName !== tagName) {
      curr = curr.nextElementSibling
    }
    if(curr.nextElementSibling && curr.nextElementSibling.shadowRoot) {
      return curr.nextElementSibling.shadowRoot.querySelector('img')
    }
  } else {
    // Contexte DOM standard — navigation entre <img> frères
    let next = window.top.imageContainer.nextElementSibling
    while(next && next.nodeName !== 'IMG') next = next.nextElementSibling
    return next || null
  }
  return null
}

if(!window.top.imageArea || !window.top.imageArea.isConnected) {
  window.top.imageContainer = null
  window.top.imageArea = window.top.document.createElement('show-image')
  window.top.document.body.appendChild(window.top.imageArea)
}

/* (WaTE: show-image) def.js v1.2.7 */