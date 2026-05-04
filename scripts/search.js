/**
 * \file      (WaTE) scripts/search.js
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-05-02
 * \version   1.0.1
 * \brief     Script client — recherche FTS5 header admin et page site.
 *
 * \details   Chargé via _item list 200/201/202/400/401/500.
 *            Cible #global-search ou #site-search-input selon contexte.
 */
;(() => {'use strict'
	// FIX v1.0.2: regex statiques — pas de re-création à chaque appel
	const _RE_AMP=/&/g, _RE_LT=/</g, _RE_GT=/>/g, _RE_DQ=/"/g, _RE_SQ=/'/g, _RE_SAFE_URL=/^\/(?!\/)|^https?:\/\//
	function esc(s){return String(s||'').replace(_RE_AMP,'&amp;').replace(_RE_LT,'&lt;').replace(_RE_GT,'&gt;').replace(_RE_DQ,'&quot;').replace(_RE_SQ,'&#39;')}
	function safeUrl(u){const s=String(u||'');return _RE_SAFE_URL.test(s)?s:'#'}
	function init(){
	const i=document.getElementById('global-search')||document.getElementById('site-search-input')
	const r=document.getElementById('search-results')||document.getElementById('site-search-results')
	if(!i||!r)return
	const isSite=!!document.getElementById('site-search-input')
	const cls=isSite?'site-search-item':'header-search-result'
	const api=isSite?'/api/search':'/admin/api/search'
	// FIX v1.0.1 #103: AbortController annule la requête précédente
	let t=null,_ctrl=null;const l=(document.documentElement.lang||'fr').substring(0,2);let scope=''
	if(location.pathname.indexOf('/demo')===0)scope='demo'
	i.addEventListener('input',() => {clearTimeout(t)
	const q=i.value.trim();if(!q){r.innerHTML='';r.style.display='';return}
	t=setTimeout(() => {if(_ctrl)_ctrl.abort();_ctrl=new AbortController();let u=api+'?q='+encodeURIComponent(q)+'&lang='+l;if(scope)u+='&scope='+scope
	fetch(u,{credentials:'same-origin',signal:_ctrl.signal}).then(x => x.ok?x.json():Promise.reject(x.status)).then(d => {
	if(!d.results||!d.results.length){r.innerHTML='<span class="'+cls+'" style="opacity:0.5;font-style:italic">'+(l==='en'?'No results':'Aucun résultat')+'</span>';r.style.display='block';return}
	r.innerHTML=d.results.map(x => {const u2=x.urls&&x.urls[0]?' href="'+esc(safeUrl(x.urls[0]))+'"':'';return'<a'+u2+' class="'+cls+'"><span>'+esc(x.snippet)+'</span><span class="src">'+esc(x.text||x.tag||'')+'</span></a>'}).join('');r.style.display='block'}).catch(() => {r.innerHTML='';r.style.display=''})},300)})
	// FIX v1.0.2 #106: !r.contains(e.target) — le clic sur <a> enfant ne ferme pas les résultats
document.addEventListener('click',e => {if(e.target!==i&&!r.contains(e.target)){r.innerHTML='';r.style.display=''}})}
	if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init()})()

/* (WaTE) scripts/search.js v1.0.2 */
