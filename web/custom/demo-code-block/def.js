/**
 * \file      (WaTE) web/custom/demo-code-block/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-29
 * \version   1.0.0
 * \brief     Custom element <demo-code-block> — bloc <details> avec label et code source.
 *
 * \details   Évite la répétition du pattern :
 *              <details class="demo-code-block">
 *                <summary class="demo-code-summary">...</summary>
 *                <pre><code class="LANG">...</code></pre>
 *              </details>
 *
 *            Attributs :
 *              label   — texte du <summary> (requis).
 *              lang    — classe CSS pour le <code> (ex: js, sql, css, ejs).
 *              content — code HTML brut inséré via ${!content} (requis).
 *
 *            Utilise ${!content} pour ne pas échapper le HTML (blocs de code
 *            déjà échappés côté serveur).
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'

customHTMLElement.create('demo-code-block',
  '@import "/custom/demo-code-block/def.css"',
  '<details class="demo-code-block">'
+   '<summary class="demo-code-summary"><span>${label}</span><button class="copy-btn" title="${copylabel?Copier}"></button></summary>'
+   '<pre><code class="${lang}">${content}</code></pre>'
+ '</details>',
  null,
  function(element) {
    const btn  = this.querySelector('.copy-btn')
    const code = this.querySelector('code')
    if(btn && code) {
      btn.addEventListener('click', e => {
        e.preventDefault()
        // FIX v1.0.1 #154: .catch() clipboard
        navigator.clipboard.writeText(code.textContent).then(() => {
          btn.classList.add('copied')
          setTimeout(() => { btn.classList.remove('copied') }, 1500)
        }).catch(() => {})
      })
    }
  }
)

/* (WaTE) web/custom/demo-code-block/def.js v1.0.1 */
