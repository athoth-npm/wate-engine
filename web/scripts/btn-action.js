/**
 * \file      (WaTE) web/scripts/btn-action.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-29
 * \version   4.1.2
 * \brief     Intercepte les clics sur .btn-action → fetch API, suit le next.
 *
 * \details   v4.1.1 : création initiale.
 *            v4.1.2 : harmonisation — 'use strict', arrow functions.
 */

'use strict'

document.addEventListener('click', e => {
  const link = e.target.closest('.btn-action')
  if(!link) return

  e.preventDefault()

  const csrf = document.querySelector('meta[name="csrf-token"]')?.content || ''
  const body = new URLSearchParams()
  body.append('_csrf', csrf)

  fetch(link.href, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body
  })
    .then(r  => r.json())
    .then(d  => { window.location.href = d.next })
    .catch(() => { window.location.reload() })
})

/* (WaTE) web/scripts/btn-action.js v4.1.2 */
