/**
 * \file      (WaTE) csrf.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      01/09/2025
 * \version   1.0.0
 * \brief     Injection automatique du jeton CSRF dans les formulaires HTML.
 *
 * \details   Lit le jeton depuis la balise <meta name="csrf-token"> et crée
 *            silencieusement un <input type="hidden" name="_csrf"> dans tous
 *            les formulaires de type POST de la page au chargement du DOM.
 *            Permet au développeur applicatif d'omettre la gestion du CSRF
 *            dans ses vues EJS.
 */

'use strict';

document.addEventListener('DOMContentLoaded', () => {
  const csrfMeta = document.querySelector('meta[name="csrf-token"]');
  
  if (csrfMeta && csrfMeta.content) {
    // FIX : [method="POST" i] non supporté par Safari. On filtre en JS.
    const forms = document.querySelectorAll('form[method="POST"], form[method="post"]');
    
    forms.forEach(form => {
      // Sécurité : on n'injecte pas si le champ existe déjà (ajouté manuellement par le dev)
      if (!form.querySelector('input[name="_csrf"]')) {
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = '_csrf';
        input.value = csrfMeta.content;
        form.appendChild(input);
      }
    });
  }
});

/* (WaTE) csrf.js v1.0.0 */