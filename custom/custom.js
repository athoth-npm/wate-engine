/**
 * \file      (WaTE) custom.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/11/2024
 * \version   6.2.0
 * \brief     Création de tag HTML pour factoriser les blocs HTML composites
 *
 * \details   v3.0.0 : refactoring structurel — AbortController, signal, deux classes.
 *            v3.2.0 : attribut "persist" opt-in.
 *            v5.0.0 : _connectedCallback factorisé dans la base, _onConnect hook.
 *            v5.1.0 : _customBase séparé — chaîne incohérente, remplacé.
 *            v5.2.0 : hiérarchie linéaire —
 *                       HTMLElement
 *                         └── _customBase  (utilitaires statiques)
 *                               └── _customBase  (disconnectedCallback)
 *                                     ├── (généré par customHTMLElement.create)
 *                                     └── (généré par customFormHTMLElement.create)
 *            v6.0.0 : _escape() ajouté et intégré à parse() pour neutraliser les injections XSS
 *            v6.0.1 : la valeur "defValue" s'applique aussi aux éléments d'un tableau.
 *            v6.0.2 : setValidity exige un message non-vide si au moins un flag est true.
 *            v6.0.3 : _saveFormValues/_restoreFormValues : support des checkbox et radio
 *                     — .checked utilisé au lieu de .value pour une restauration fidèle.
 *            v6.1.0 : Ajout de ! devant le nom d'un attribut paramétrique pour éviter _escape.
 *            v6.1.1 : utilisation du regex statique et du dictionnaire pré-alloué
 *                     _attributes initialisé dans le constructeur de customFormHTMLElement
 *
 *  Deux classes publiques :
 *    customHTMLElement      — éléments display purs, pas de form machinery
 *    customFormHTMLElement  — éléments avec [bind], form-associated
 */

// Regex pré-compilées
// FIX v6.1.0 : Ajout de (!)? dans la regex pour capturer un éventuel '!'
const _RE_PARSE_VARS = /\$\{(!)?([a-zA-Z0-9_-]+)(?:\[(\d+)\])?(?:\?([^}]*))?\}/g
// FIX v6.2.1: regex statiques module-level
const _RE_ESCAPE_HTML = /[&<>"']/g
const _RE_DQUOTE_G   = /"/g

// Dictionnaire statique pour l'échappement XSS (O(1) sans création d'objet)
const _HTML_ENTITIES = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;'
}

/**
 * \class _customBase
 * \brief Classe de base unique — utilitaires statiques, _connectedCallback commun,
 *        et disconnectedCallback hérité par tous les éléments générés.
 *        Étend HTMLElement pour participer au cycle de vie des custom elements.
 */
class _customBase extends HTMLElement {

  /**
   * \fn _escape
   * \brief Échappement des caractères HTML spéciaux pour neutraliser les injections XSS.
   *        Remplace & < > " ' par leurs entités HTML équivalentes.
   *
   * \param str  Valeur à échapper (convertie en string si nécessaire)
   * \return     Chaîne échappée, ou '' si str est falsy
   */
  static _escape(str) {
    if(!str) return ''
    // FIX v6.1.1 : utilisation du regex statique et du dictionnaire pré-alloué
    return String(str).replace(_RE_ESCAPE_HTML, (m) => _HTML_ENTITIES[m])
  }

  /**
   * \fn parse
   * \brief Substitue les ${attr}, ${attr[N]}, ${attr?default} par les attributs de l'élément.
   *        Les valeurs substituées sont automatiquement échappées (v6.0.0).
   *
   * \param element  Élément custom dont les attributs sont lus
   * \param inStr    Chaîne template à traiter (peut être null/undefined)
   * \return         Chaîne avec les substitutions appliquées, ou '' si inStr est falsy
   *
   * \details Syntaxe supportée :
   *   ${attr}         → valeur de l'attribut attr, échappée
   *   ${attr[N]}      → élément N d'un tableau JSON stocké dans attr, échappé
   *   ${attr?default} → valeur de l'attribut attr ou default si absent, échappés
   *   FIX v6.0.1 : si la valeur extraite du JSON est null/undefined, on applique defValue.
   */
  static parse(element, inStr) {
    if(!inStr) return ''
    // FIX v6.1.1 : utilisation du regex statique
    return inStr.replace(_RE_PARSE_VARS, (match, rawFlag, attrName, index, defValue) => {
      let attr = element.getAttribute(attrName)
      if(attr) {
        if(index !== undefined) {
          try { attr = JSON.parse(attr)[parseInt(index, 10)] }
          catch(e) { console.error('_customBase.parse: JSON.parse error on:', attrName) }
        }
        if(attr !== null && attr !== undefined) {
          // Si rawFlag ('!') est présent, on ne passe PAS par _escape()
          return rawFlag ? attr : _customBase._escape(attr)
        }
      }
      return defValue === undefined ? '' : rawFlag ? defValue : _customBase._escape(defValue)
    })
  }

  /**
   * \fn _runScript
   * \brief Appelle script.call(shadowRoot, element, signal) si script est une fonction.
   *
   * \param script   Fonction à appeler (ou null/undefined — ignoré silencieusement)
   * \param element  Élément custom passé en second argument au script
   * \param signal   AbortSignal du contrôleur courant, passé en troisième argument
   */
  static _runScript(script, element, signal) {
    if(typeof script === 'function') {
      script.call(element.shadowRoot, element, signal)
    }
  }

  /**
   * \fn _saveFormValues
   * \brief Sauvegarde les valeurs du <form> dans le shadowRoot dans un objet plat.
   *        Appelée uniquement si l'attribut "persist" est présent — coût nul sinon.
   *        FIX v6.0.3 : les checkbox et radio sont sauvegardés via .checked (pas .value).
   *
   * \param shadowRoot  Racine shadow de l'élément custom
   * \return            Objet { name: value|checked } pour chaque champ nommé trouvé
   */
  static _saveFormValues(shadowRoot) {
    const saved = {}
    const form = shadowRoot && shadowRoot.querySelector('form')
    if(!form) return saved
    for(let i = 0; i < form.elements.length; i++) {
      const el = form.elements[i]
      if(!el.name) continue
      if(el.type === 'checkbox' || el.type === 'radio') {
        saved[el.name] = el.checked
      } else {
        saved[el.name] = el.value
      }
    }
    // FIX v6.2.0 #100: persist <admin-list> (custom element, absent de form.elements)
    const _lists = form.querySelectorAll('admin-list')
    for(let j = 0; j < _lists.length; j++) {
      const _s = _lists[j].shadowRoot && _lists[j].shadowRoot.querySelector('select')
      if(_s && _lists[j].getAttribute('name')) saved[_lists[j].getAttribute('name')] = _s.value
    }
    return saved
  }

  /**
   * \fn _restoreFormValues
   * \brief Restitue les valeurs sauvegardées dans le <form> du shadowRoot.
   *        FIX v6.0.3 : les checkbox et radio sont restaurés via .checked (pas .value).
   *
   * \param shadowRoot  Racine shadow de l'élément custom
   * \param saved       Objet { name: value|checked } produit par _saveFormValues
   */
  static _restoreFormValues(shadowRoot, saved) {
    const form = shadowRoot && shadowRoot.querySelector('form')
    if(!form) return
    // FIX v6.2.1 #162: hasOwnProperty + skip __proto__
    for(var name in saved) {
      if(!Object.prototype.hasOwnProperty.call(saved, name) || name === '__proto__') continue
      const field = form.elements[name]
      if(field) {
        if(field.type === 'checkbox' || field.type === 'radio') field.checked = saved[name]
        else field.value = saved[name]
      } else {
        // FIX v6.2.1 #164: escape " dans le sélecteur
        const _safeName = name.replace(_RE_DQUOTE_G, '\\"')
        const _list = form.querySelector('admin-list[name="' + _safeName + '"]')
        if(_list) _list.setAttribute('value', saved[name])
      }
    }
  }

  /**
   * \fn _connectedCallback
   * \brief Logique commune de connectedCallback — appelée depuis les deux class bodies.
   *        Séquence : persist-save → abort controller → innerHTML rebuild → persist-restore → _onConnect hook.
   *
   * \param element          Élément custom en cours de connexion
   * \param tagStyle         Chaîne CSS template (peut être null)
   * \param tagHTML          Chaîne HTML template
   * \param tagBeforeScript  Fonction à appeler avant le rebuild innerHTML (peut être null)
   * \param tagAfterScript   Fonction à appeler après le rebuild innerHTML (peut être null)
   * \param _onConnect       Hook appelé après le rebuild, reçoit (signal) en contexte this=element
   */
  // FIX v6.2.1 #110: try-catch global — évite shadow DOM partiel si parse/script lève
  static _connectedCallback(element, tagStyle, tagHTML, tagBeforeScript, tagAfterScript, _onConnect) {
    try {
    if(element._controller) element._controller.abort()
    element._controller = new AbortController()
    const signal = element._controller.signal

    const saved = element.hasAttribute('persist') ? _customBase._saveFormValues(element.shadowRoot) : null
    _customBase._runScript(tagBeforeScript, element, signal)
    element.shadowRoot.innerHTML = (tagStyle ? '<style>' + _customBase.parse(element, tagStyle) + '</style>' : '')
                                 + _customBase.parse(element, tagHTML)
    _customBase._runScript(tagAfterScript, element, signal)
    if(saved) _customBase._restoreFormValues(element.shadowRoot, saved)

    if(_onConnect) _onConnect.call(element, signal)
    } catch(e) { console.error('_connectedCallback error:', e) }
  }

  /**
   * \fn disconnectedCallback
   * \brief Annule le contrôleur AbortController au retrait de l'élément du DOM.
   *        Déclenche automatiquement l'arrêt de tous les event listeners liés au signal.
   */
  disconnectedCallback() {
    if(this._controller) this._controller.abort()
  }
}

/**
 * \class customHTMLElement
 * \brief Éléments display purs — pas de form machinery.
 *        Utilisé pour les custom elements qui n'ont pas besoin d'interagir
 *        avec les formulaires HTML natifs (validation, valeur...).
 */
class customHTMLElement extends _customBase {

  /**
   * \fn create
   * \brief Définit et enregistre un nouveau custom element display-only.
   *
   * \param tagName         Nom du tag HTML à définir (ex: 'icon-menu')
   * \param tagStyle        Chaîne CSS template parsée à chaque connexion (peut être null)
   * \param tagHTML         Chaîne HTML template parsée à chaque connexion (peut être null)
   * \param tagBeforeScript Fonction appelée avant le rebuild innerHTML (peut être null)
   * \param tagAfterScript  Fonction appelée après le rebuild innerHTML (peut être null)
   */
  static create(tagName, tagStyle = null, tagHTML = null, tagBeforeScript = null, tagAfterScript = null) {
    window.customElements.define(tagName, class extends _customBase {

      constructor() {
        super()
        this.attachShadow({mode: 'open', delegatesFocus: true})
      }

      connectedCallback() {
        _customBase._connectedCallback(this, tagStyle, tagHTML, tagBeforeScript, tagAfterScript, null)
      }
    })
  }
}

/**
 * \class customFormHTMLElement
 * \brief Variante form-associated pour les éléments contenant un [bind].
 *        Gère disabled, readonly, required, value et remonte la valeur au formulaire parent.
 *        Permet au custom element de participer à la validation et à la soumission native HTML.
 */
class customFormHTMLElement extends _customBase {

  /**
   * \fn create
   * \brief Définit et enregistre un nouveau custom element form-associated.
   *
   * \param tagName         Nom du tag HTML à définir
   * \param tagStyle        Chaîne CSS template parsée à chaque connexion (peut être null)
   * \param tagHTML         Chaîne HTML template parsée à chaque connexion (peut être null)
   * \param tagBeforeScript Fonction appelée avant le rebuild innerHTML (peut être null)
   * \param tagAfterScript  Fonction appelée après le rebuild innerHTML (peut être null)
   */
  static create(tagName, tagStyle = null, tagHTML = null, tagBeforeScript = null, tagAfterScript = null) {
    window.customElements.define(tagName, class extends _customBase {

      /** \brief Indique au navigateur que cet élément est form-associated. */
      static get formAssociated()     { return true }

      /** \brief Liste des attributs dont les changements déclenchent attributeChangedCallback. */
      static get observedAttributes() { return ['disabled', 'readonly', 'required', 'value'] }

      constructor() {
        super()
      /**
       * \var _attributes
       * \brief Cache des attributs observés reçus avant que _bind ne soit disponible.
       *        Appliqués rétroactivement lors de la connexion.
       * \details Initialisé ici, 100% compatible avec tous les navigateurs supportant les classes ES6
       */
        this._attributes = {} 
        this._internals = this.attachInternals()
        this.attachShadow({mode: 'open', delegatesFocus: true})
      }

      /**
       * \fn attributeChangedCallback
       * \brief Appelé par le navigateur à chaque changement d'un attribut observé.
       *        Délègue à updateAttribute si _bind est disponible, sinon met en cache.
       *
       * \param name  Nom de l'attribut modifié
       * \param prev  Ancienne valeur (non utilisée)
       * \param next  Nouvelle valeur
       */
      attributeChangedCallback(name, prev, next) {
        if(this._bind) this.updateAttribute(name, next)
        else           this._attributes[name] = next
      }

      connectedCallback() {
        _customBase._connectedCallback(this, tagStyle, tagHTML, tagBeforeScript, tagAfterScript,
          function(signal) {
            this._bind = this.shadowRoot.querySelector('[bind]')
            if(this._bind) {
              for(var attr in this._attributes) this.updateAttribute(attr, this._attributes[attr])
              this.handleInput()
              this._bind.addEventListener('input', () => this.handleInput(), {signal})
            }
          }
        )
      }

      /**
       * \fn updateAttribute
       * \brief Applique un attribut observé sur l'élément [bind] interne.
       *        readonly est converti en disabled (même effet visuel et comportemental).
       *
       * \param name   Nom de l'attribut ('value', 'readonly', 'disabled', 'required')
       * \param value  Nouvelle valeur (null = attribut absent)
       */
      updateAttribute(name, value) {
        switch(name) {
          case 'value':
            this._bind.value = value
            break
          case 'readonly':
            name = 'disabled'
            /* falls through */
          case 'disabled':
          case 'required':
            this._bind.toggleAttribute(name, value !== null && (value === true || value === ''))
            break
        }
      }

      /**
       * \fn handleInput
       * \brief Synchronise la validité et la valeur de l'élément [bind] avec les internals.
       *        Appelée à la connexion et à chaque événement 'input' sur [bind].
       *
       * \details FIX v6.0.2 : setValidity exige un message non-vide si au moins un flag est true.
       *          ValidityState est un objet live — snapshot avant toute opération pour éviter
       *          les états transitoires (ex: disabled appliqué entre la lecture des flags et
       *          celle du message de validation).
       *          Zero-width space (\u200B) utilisé si le message natif est vide mais invalide.
       */
      handleInput() {
        const validity  = this._bind.validity
        const message   = this._bind.validationMessage
        const isInvalid = !validity.valid
        this._internals.setValidity(
          validity,
          isInvalid && !message ? '\u200B' : message,
          this._bind
        )
        this._internals.setFormValue(
          this._bind.getAttribute('type') === 'file'
            ? this._bind.files[0]
            : this._bind.value
        )
      }

    })
  }
}

export { customHTMLElement, customFormHTMLElement }

/* (WaTE) custom.js v6.2.1 */