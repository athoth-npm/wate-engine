/**
 * \file      (WaTE) web/custom/wate-example/def.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-29
 * \version   2.0.0
 * \brief     Custom element <wate-example> — contenu via attributs, pas de slots.
 *
 * \details   Les blocs de code et l'aperçu sont passés comme attributs HTML
 *            (code-blocks, preview). L'EJS les construit côté serveur avec <%=.
 *            Le navigateur décode les entités, ${!attr} insère le HTML brut.
 */

'use strict'

import { customHTMLElement } from '/custom/custom.js'

customHTMLElement.create('wate-example',
  '@import "/custom/wate-example/def.css"',

  '<article class="example" id="${id}">'
+   '<header class="example-head">'
+     '<span class="example-num">${num}</span>'
+     '<h2 class="example-title">${title}</h2>'
+     '<p class="example-lead">${lead}</p>'
+   '</header>'
+   '<figure class="example-path"><slot name="path"></slot></figure>'
+   '<div class="example-split">'
+     '<section class="example-code">${!code-blocks}</section>'
+     '<section class="example-preview">'
+       '<div class="pane-label">${preview-label}</div>'
+       '<div class="preview-frame">'
+         '<div class="preview-bar">'
+           '<span class="preview-dot r"></span><span class="preview-dot y"></span><span class="preview-dot g"></span>'
+           '<span class="preview-url">${route}</span>'
+         '</div>'
+         '<div class="preview-body">'
+           '<div class="preview-meta">'
+             '<span><strong>${preview-route-label} :</strong> <code>${route}</code></span>'
+             '<span class="status-ok"><strong>${preview-status-label} :</strong> 200 OK</span>'
+           '</div>'
+           '<section class="preview-content">${!preview}</section>'
+         '</div>'
+       '</div>'
+     '</section>'
+   '</div>'
+   '<footer class="example-explain">'
+     '<div class="pane-label">${explain-label}</div>'
+     '<p>${explain}</p>'
+   '</footer>'
+ '</article>'
)

/* (WaTE) web/custom/wate-example/def.js v2.0.0 */
