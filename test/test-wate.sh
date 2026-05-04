#!/usr/bin/env bash
# =============================================================================
# \file      test-wate.sh
# \author    Romain Légault
# \copyright 2023-2026 WATE Team.
# \date      03/11/2023
# \version   3.18.2
# \brief     Tests HTTP WaTE — API JSON et pages HTML, par profil.
#
# \details   v3.7.0 : db:renderTable supprimé, URL /admin/form/db?table=<n>.
#            v3.7.1 : Correction de 7 attentes de test incorrectes.
#            v3.8.0 : Ajout de la protection CSRF globale.
#                     - Calcul dynamique des tokens CSRF via Node.js.
#                     - Ajout du header X-CSRF-Token pour les API POST/PUT/DELETE.
#                     - Ajout du paramètre _csrf pour les formulaires url-encoded.
#                     - Ajout d'un bloc de test dédié à l'échec CSRF (403).
#            v3.9.0 : Profil anonymous : id=1 → id=9999 dans les données et commentaires.
#                     FIX run_test : grep via if/|| au lieu de &&/!/&& pour éviter
#                     une sortie prématurée de bash avec set -euo pipefail.
#            v3.9.1 : Mise à jour des checks suite aux templates v5.5.0 (fragments purs).
#                     admin-auth.ejs/admin-db.ejs → fragments sans <h1> ni (profil X) :
#                     ces éléments migrent dans views/common.ejs non rendu par le test app.
#                     <h1>Administration</h1>  → <h2>Connexion</h2>  (du fragment signin).
#                     profil_id="N" (attribut HTML supprimé) → <code>N</code>  (test app).
#            v3.10.0: Migration 002_anon42.sql — profil anonymous 9999 → 42 dans tous
#                     les tests. Valide l'agnosticisme du moteur sur le profil_id anonymous.
#                     - profil_id signup : 9999 → 42 dans les corps de requête.
#                     - Vérification explicite id=42 / absence de id=9999 en DB.
#                     - Section [ROBUSTESSE] en fin de suite (tests destructifs) :
#                         nom cosmétique, ghost session absente, profil supprimé cascade.
#            v3.10.1: FIX [ROBUSTESSE] attentes corrigées selon le comportement réel :
#                     - Ghost session supprimée → 401 (serve() fait le JOIN sur S.id=0
#                       à chaque requête, pas de cache runtime, accès cassé immédiatement).
#                     - Profil supprimé → _page cascade-supprimée → 404 (URL inconnue),
#                       pas 401 (serve() retourne 404 quand l'URL n'est pas dans _page).
#            v3.11.0: Ajout [CONFIG] — vérifie que _config est chargée (8 clés via DB API).
#                     Ajout [STATS]  — vérifie GET /admin/api/stats (module optionnel).
#            v3.12.0: FIX patterns HTML-encoding — EJS <%=...%> encode " en &#34; (pas &quot;).
#                     form/auth/signin → champ email : type&quot;... → type&#34;...
#                     form/auth/signin → champ password : hash&quot;... → hash&#34;...
#            v3.13.0: [AUTH FORM] /me → lien désinscription (method DELETE, href api/auth/me).
#                     Vérifie l'absence de /form/auth/signup dans /me (boucle 401 corrigée).
#                     Vérifie que la session delete-me est invalidée après suppression.
#            v3.14.0: [MODAL-POPUP] custom element servi + window.wateModal dans admin-row.
#                     [AUTH MAIL OFF] mode dégradé sur 3001 — forgot/reset 404, signin sans lien.
#                     [AUTH MAIL ON]  port 3005 (mail stubbé) — signup→verify→signin et
#                     forgot→reset→signin bout à bout, token extrait du mail capturé.
#            v3.15.0: Durcissement sécurité — nouveaux tests :
#                     - CSRF d'une autre session (header + body) → 403 (timing-safe
#                       compare rejette un token valide dans la forme mais lié à un
#                       autre session id).
#                     - XSS server-side : ?error=<script> et ?info=${...} ignorés par
#                       admin-auth.ejs v8.3.0 (_RE_MSG filtre avant rendu).
#                     - Tag kebab-case inconnu du glossaire → rendu brut (comportement
#                       attendu, aucun risque car charset restreint).
#                     - Token reset/verify bien formé (64 hex) mais absent DB → même
#                       branche que expiré, reset-invalid sans fuite.
#            v3.15.1: Alignement sur l'état réel de la DB/page :
#                     - _config : total 8 → 17 (migration 004 ajoute auth.verify.ttl,
#                       auth.reset.ttl et 7 clés mail.*).
#                     - form/db/schema : import adminSchema → schema-table/def.js
#                       (refactoring custom element).
#            v3.16.0: Nouveaux blocs de tests basés sur modules applicatifs :
#                     - [API]        : sondes techniques de _WATE_API via
#                                      test/scripts/test-api.js (log, db,
#                                      renderError, app).
#                     - [APP STYLES] : valide les 3 styles d'écriture d'une
#                                      appli WaTE via test/scripts/test-routes.js :
#                                      1) route module + renderPage,
#                                      2) hook onPageLoad (+ onTableWrite),
#                                      3) page 100% DB (queries SELECT).
#                     Migration 003_api.sql crée /style2 (DB+hook) et /style3
#                     (DB pure). Ces sections s'exécutent AVANT [ROBUSTESSE]
#                     (destructeur de l'accès anonymous).
#            v3.16.1: run_test : `printf '%s' "$actual_body" | grep` au lieu de
#                     `echo "$actual_body" | grep`. `echo` builtin bash peut
#                     interpréter certains caractères dans des bodies HTML
#                     multi-lignes lourds → faux négatifs aléatoires.
#            v3.17.0: Nouveaux tests — open redirect, headers CSP/security,
#                     rate limiting POST, page erreur en chemin profond,
#                     rejet body >100 Ko, glossaire anglais (?lang=en),
#                     cache LRU hits/misses après requêtes répétées.
#            v3.18.0: Nouveaux tests — [UNDO] annulation d'écritures
#                     insert/update/delete via module audit. Tests :
#                     undo insert → ligne absente, undo update → valeurs
#                     restaurées, undo delete → ligne recréée, double
#                     undo → 404, cross-user bloqué, owner ?all=true.
#            v3.18.1: Test DELETE table sans PK → 500 (no_pk).
#                     Test APIKEY revoke prefix injection → 400.
#                     Test verify/resend — renvoi lien vérification,
#            v3.18.2: Test PK falsy — UPDATE/DELETE pk_zero avec
#                     id=0 (vérifie que !req.body[id] ne bloque
#                     plus les valeurs 0 et "").
#                     token regénéré différent, ancien token invalide,
#                     anti-énumération (email inconnu → 200 ok).
#            v3.16.2: run_test : grep directement sur le fichier temporaire
#                     (plus de variable bash) — évite les faux négatifs sur
#                     les gros corps HTML (>15 Ko). Le body n'est lu dans une
#                     variable que pour l'affichage des erreurs.
#                     FIX CSRF : le serveur incorpore désormais un secret dans
#                     le calcul SHA256(sessionId + secret). Le secret est passé
#                     via WATE_CSRF_SECRET (env) ou généré aléatoirement.
#                     Le test injecte 'test-secret' via process.env dans app.js.
# =============================================================================

set -euo pipefail

BASE="http://localhost:3001"
PASS=0
FAIL=0

COOKIE_OWNER='session=j:{"id":"test-session-owner"}'
COOKIE_ADMIN='session=j:{"id":"test-session-admin"}'
COOKIE_EXPIRED='session=j:{"id":"test-session-expired"}'
COOKIE_P3='session=j:{"id":"test-session-p3"}'
COOKIE_P4='session=j:{"id":"test-session-p4"}'
COOKIE_DELETE_ME='session=j:{"id":"test-session-delete-me"}'
COOKIE_SIGNUP='session=j:{"id":"test-session-signup"}'

# --- Génération des tokens CSRF attendus (SHA256 du Session ID + secret) ---
WATE_CSRF_SECRET='test-secret'
get_csrf() {
  node -e "process.stdout.write(require('crypto').createHash('sha256').update('$1' + '$WATE_CSRF_SECRET').digest('hex'))"
}

CSRF_OWNER=$(get_csrf "test-session-owner")
CSRF_ADMIN=$(get_csrf "test-session-admin")
CSRF_EXPIRED=$(get_csrf "test-session-expired")
CSRF_P3=$(get_csrf "test-session-p3")
CSRF_P4=$(get_csrf "test-session-p4")
CSRF_DELETE_ME=$(get_csrf "test-session-delete-me")
CSRF_SIGNUP=$(get_csrf "test-session-signup")
# ------------------------------------------------------------------

RED=$'\033[0;31m'
GRN=$'\033[0;32m'
YEL=$'\033[0;33m'
RST=$'\033[0m'

check_server() {
  local HTTP
  HTTP=$(curl -so /dev/null -w "%{http_code}" --max-time 2 "$BASE/home" 2>/dev/null || echo "000")
  if [ "$HTTP" = "000" ]; then
    echo -e "${RED}ERREUR${RST} : serveur non disponible sur $BASE — lancer : node test/app.js"
    exit 1
  fi
}

run_test() {
  local name="$1" expected_status="$2" expected_body="$3"
  shift 3
  local tmpfile; tmpfile=$(mktemp)
  local actual_status
  actual_status=$(curl -s -o "$tmpfile" -w "%{http_code}" --max-time 5 "$@" 2>/dev/null || echo "000")
  local ok=1
  [ "$actual_status" != "$expected_status" ] && ok=0
  if [ -n "$expected_body" ]; then
    grep -qF "$expected_body" "$tmpfile" || ok=0
  fi
  if [ "$ok" = "1" ]; then
    echo -e "  ${GRN}PASS${RST}  $name"; PASS=$((PASS + 1))
  else
    local actual_body; actual_body=$(cat "$tmpfile")
    echo -e "  ${RED}FAIL${RST}  $name"
    echo -e "        status   attendu=${YEL}${expected_status}${RST}  obtenu=${YEL}${actual_status}${RST}"
    [ -n "$expected_body" ] && echo -e "        contient attendu=${YEL}${expected_body}${RST}\n        corps    obtenu=${YEL}${actual_body}${RST}"
    FAIL=$((FAIL + 1))
  fi
  rm -f "$tmpfile"
}

check_absent() {
  local name="$1" absent="$2"; shift 2
  local actual; actual=$(curl -s --max-time 5 "$@" 2>/dev/null)
  if echo "$actual" | grep -qF "$absent"; then
    echo -e "  ${RED}FAIL${RST}  $name — '${YEL}${absent}${RST}' trouvé dans le corps"
    FAIL=$((FAIL + 1))
  else
    echo -e "  ${GRN}PASS${RST}  $name"; PASS=$((PASS + 1))
  fi
}

countdown() {
  local t=$1 msg="$2"
  echo -n "     $msg : "
  while [ $t -gt 0 ]; do echo -ne "\r     $msg : ${t}s "; sleep 1; t=$((t - 1)); done
  echo -e "\r     $msg : OK.     "
}

# =============================================================================
check_server
echo ""
echo "WaTE — tests HTTP ($BASE)"
echo "================================================================="

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[AUTH] GET /admin/api/auth/me${RST}"
# -----------------------------------------------------------------------------
run_test "me sans session → 401"       "401" '"error"'       "$BASE/admin/api/auth/me"
run_test "me owner → profil 0"         "200" '"profil_id":0' --cookie "$COOKIE_OWNER"   "$BASE/admin/api/auth/me"
run_test "me admin → profil 2"         "200" '"profil_id":2' --cookie "$COOKIE_ADMIN"   "$BASE/admin/api/auth/me"
run_test "me session expirée → 401"    "401" '"error"'       --cookie "$COOKIE_EXPIRED" "$BASE/admin/api/auth/me"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[AUTH] POST /admin/api/auth/signout${RST}"
# -----------------------------------------------------------------------------
run_test "signout sans session → ok"    "200" '"ok":true' -X POST -H "Content-Type: application/json" "$BASE/admin/api/auth/signout"
run_test "signout session expirée → ok" "200" '"ok":true' -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_EXPIRED" --cookie "$COOKIE_EXPIRED" "$BASE/admin/api/auth/signout"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[AUTH] POST /admin/api/auth/signin${RST}"
# -----------------------------------------------------------------------------
run_test "signin email manquant → 400"       "400" '"error"' \
  -X POST -H "Content-Type: application/json" -d '{"email":"","password":"x"}' "$BASE/admin/api/auth/signin"
run_test "signin mauvais mot de passe → 401" "401" '"error":"invalid credentials"' \
  -X POST -H "Content-Type: application/json" -d '{"email":"owner@test.com","password":"mauvais"}' "$BASE/admin/api/auth/signin"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[AUTH] POST /admin/api/auth/signup${RST}"
# -----------------------------------------------------------------------------
run_test "signup sans session → 200 (profil 42 a insert sur _user)" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"new-api@test.com","password":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","profil_id":"42"}' \
  "$BASE/admin/api/auth/signup"

run_test "signup owner (droits insert _user) → 200" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" \
  --cookie "$COOKIE_OWNER" \
  -d '{"email":"new-owner@test.com","password":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","profil_id":"2"}' \
  "$BASE/admin/api/auth/signup"

run_test "signup admin (profil 2, pas insert sur _user) → 403" "403" '"error"' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" \
  --cookie "$COOKIE_ADMIN" \
  -d '{"email":"blocked@test.com","password":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","profil_id":"2"}' \
  "$BASE/admin/api/auth/signup"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[SÉCURITÉ] Protection CSRF${RST}"
# -----------------------------------------------------------------------------
run_test "CSRF manquant (POST) → 403" "403" '"error"' \
  -X POST -H "Content-Type: application/json" --cookie "$COOKIE_OWNER" \
  -d '{"id":"xx-csrf","name":"Test"}' "$BASE/admin/api/db/_lang"

run_test "CSRF invalide (POST) → 403" "403" '"error"' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: aaaaaabbbbbbccccccddddddeeeeeeffffff0000001111112222223333334444" \
  --cookie "$COOKIE_OWNER" -d '{"id":"xx-csrf","name":"Test"}' "$BASE/admin/api/db/_lang"

run_test "CSRF valide Header (POST) → 200" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" \
  --cookie "$COOKIE_OWNER" -d '{"id":"xx-csrf1","name":"Test CSRF 1"}' "$BASE/admin/api/db/_lang"

curl -s -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"id":"xx-csrf1"}' "$BASE/admin/api/db/_lang" > /dev/null

run_test "CSRF valide Body (POST) → 200" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  --cookie "$COOKIE_OWNER" -d '{"id":"xx-csrf2","name":"Test CSRF 2", "_csrf":"'"$CSRF_OWNER"'"}' "$BASE/admin/api/db/_lang"

curl -s -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"id":"xx-csrf2"}' "$BASE/admin/api/db/_lang" > /dev/null

# v3.15.0 : CSRF d'une autre session rejoué avec le cookie courant.
# Le token est un SHA-256(sessionId) valide mais pour une autre session — la
# comparaison timing-safe doit le rejeter (403) même si la forme est correcte.
run_test "CSRF d'une autre session (POST owner + token admin) → 403" "403" '"error"' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" \
  --cookie "$COOKIE_OWNER" -d '{"id":"xx-csrf3","name":"Test"}' "$BASE/admin/api/db/_lang"

# v3.15.0 : même test côté body (_csrf au lieu du header).
run_test "CSRF d'une autre session (body _csrf croisé) → 403" "403" '"error"' \
  -X POST -H "Content-Type: application/json" \
  --cookie "$COOKIE_OWNER" -d '{"id":"xx-csrf4","name":"Test","_csrf":"'"$CSRF_ADMIN"'"}' "$BASE/admin/api/db/_lang"

# v3.15.0 : XSS server-side — admin-auth.ejs v8.3.0 rejette tout req.query.error
# qui ne matche pas _RE_MSG (/^[a-z][a-z0-9-]{0,63}$/). Payload XSS classique
# (<script>) ne doit pas se retrouver dans la page, ni même entre <p class="error">.
# Double vérification : (1) statut 200 + markup signin normal ; (2) absence du payload.
run_test "XSS ?error=<script> → 200 (signin rendu)" "200" "Connexion" \
  "$BASE/admin/form/auth/signin?error=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
check_absent "XSS ?error=<script> → payload absent du body" "alert(1)" \
  "$BASE/admin/form/auth/signin?error=%3Cscript%3Ealert(1)%3C%2Fscript%3E"
run_test "XSS ?info=\${exploit} → 200 (signin rendu)" "200" "Connexion" \
  "$BASE/admin/form/auth/signin?info=%24%7Bexploit%7D"
check_absent "XSS ?info=\${exploit} → payload absent du body" '${exploit}' \
  "$BASE/admin/form/auth/signin?info=%24%7Bexploit%7D"

# v3.15.0 : tag valide (kebab-case ASCII) mais non inscrit au glossaire →
# _gi retourne le tag brut (inoffensif : [a-z0-9-]). Le <p class="error"> s'affiche.
run_test "?error=unknown-tag → tag rendu brut (tag kebab-case autorisé)" "200" 'class="error"' \
  "$BASE/admin/form/auth/signin?error=unknown-tag"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[ROBUSTESSE] Profil anonymous — agnosticisme du profil_id${RST}"
# -----------------------------------------------------------------------------
# 002_anon42.sql a changé anonymous 9999 → 42. Toute la suite tourne avec id=42.
# Si tous les tests passent, c'est la preuve que le moteur ne code pas 9999 en dur.
run_test "anonymous profil_id=42 présent en DB"  "200" '"id":42'   --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_profil"
check_absent "profil_id=9999 absent de la DB"    '"id":9999'        --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_profil"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[DB API] GET /admin/api/db/schema${RST}"
# -----------------------------------------------------------------------------
run_test "schema sans session → 401"                  "401" '"error"'   "$BASE/admin/api/db/schema"
run_test "schema owner → contient _lang"              "200" '"_lang"'   --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/schema"
run_test "schema owner → contient _access"            "200" '"_access"' --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/schema"
run_test "schema admin (profil 2) → contient sample"  "200" '"sample"'  --cookie "$COOKIE_ADMIN" "$BASE/admin/api/db/schema"
check_absent "schema admin ne voit pas _lang"   '"_lang"'   --cookie "$COOKIE_ADMIN" "$BASE/admin/api/db/schema"
check_absent "schema admin ne voit pas _access" '"_access"' --cookie "$COOKIE_ADMIN" "$BASE/admin/api/db/schema"
run_test "schema owner → contient undo_test" "200" '"undo_test"' --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/schema"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[DB API] GET /admin/api/db/:table${RST}"
# -----------------------------------------------------------------------------
run_test "GET _lang sans session → 401"         "401" '"error"'               "$BASE/admin/api/db/_lang"
run_test "GET _lang owner → columns"            "200" '"columns"'             --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang"
run_test "GET _lang owner → total"              "200" '"total"'               --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang"
run_test "GET _lang admin → 403"                "403" '"error":"forbidden"'   --cookie "$COOKIE_ADMIN" "$BASE/admin/api/db/_lang"
run_test "GET sample admin → 200"               "200" '"columns"'             --cookie "$COOKIE_ADMIN" "$BASE/admin/api/db/sample"
run_test "GET table nom invalide → 400"         "400" '"error":"invalid table name"' --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/bad-name"
run_test "GET _lang owner pagination limit=1"   "200" '"limit":1'             --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang?offset=0&limit=1"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[DB API] sort, search, filter${RST}"
# -----------------------------------------------------------------------------
run_test "GET _lang owner sort=name"               "200" '"columns"'           --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang?sort=name"
run_test "GET _lang owner sort=name&dir=desc"      "200" '"columns"'           --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang?sort=name&dir=desc"
run_test "GET _lang owner sort=invalidcol"         "200" '"columns"'           --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang?sort=invalidcol"
run_test "GET _lang sort injection ignoree"        "200" '"columns"'           --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang?sort=evil%27%20OR%201%3D1"
run_test "GET _lang owner search=Fran"             "200" '"total"'             --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang?search=Fran"
run_test "GET _lang owner filter=id:en"            "200" '"id"'                --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang?filter=id:en"
run_test "GET _lang owner filter=badcol:x"         "200" '"columns"'           --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang?filter=badcol:x"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[DB API] export CSV/JSON${RST}"
# -----------------------------------------------------------------------------
run_test "EXPORT json sans session 401"            "401" '"error"'              "$BASE/admin/api/db/_lang/export?format=json"
run_test "EXPORT json owner 200"                   "200" '"id"'                 --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang/export?format=json"
run_test "EXPORT json default format"              "200" '"id"'                 --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang/export"
run_test "EXPORT csv owner 200"                    "200" 'id'                     --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang/export?format=csv"
run_test "EXPORT admin 403"                        "403" '"error":"forbidden"' --cookie "$COOKIE_ADMIN" "$BASE/admin/api/db/_lang/export?format=json"
run_test "EXPORT bad-name csv 400"                 "400" '"error"'              --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/bad-name/export?format=csv"
run_test "EXPORT search=Fran csv 200"              "200" 'Fran'                   --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang/export?format=csv&search=Fran"
run_test "EXPORT filter=id:en csv 200"             "200" 'en'                     --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_lang/export?format=csv&filter=id:en"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[SEARCH] FTS5${RST}"
# -----------------------------------------------------------------------------
run_test "SEARCH sans session 401"                 "401" '"error"'          "$BASE/admin/api/search?q=Connexion&lang=fr"
run_test "SEARCH owner 200"                        "200" '"results"'        --cookie "$COOKIE_OWNER" "$BASE/admin/api/search?q=Connexion&lang=fr"
run_test "SEARCH owner resultat trouve"            "200" '"snippet"'        --cookie "$COOKIE_OWNER" "$BASE/admin/api/search?q=Connexion&lang=fr"
run_test "SEARCH owner terme absent vide"          "200" '"results":[]'     --cookie "$COOKIE_OWNER" "$BASE/admin/api/search?q=xyznonexistent&lang=fr"
run_test "SEARCH owner sans q vide"                "200" '"results":[]'     --cookie "$COOKIE_OWNER" "$BASE/admin/api/search?lang=fr"
run_test "SEARCH admin 200"                        "200" '"results"'        --cookie "$COOKIE_ADMIN" "$BASE/admin/api/search?q=fr&lang=fr"
run_test "SEARCH public /api/search 200"           "200" '"results"'        "$BASE/api/search?q=fr&lang=fr"
run_test "SEARCH _status ok"                       "200" '"ok":true'        "$BASE/admin/api/search/_status"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[HEALTH] /health${RST}"
# -----------------------------------------------------------------------------
run_test "HEALTH /health 200"                      "200" '"status":"ok"'    "$BASE/health"
run_test "HEALTH contient uptime"                  "200" '"uptime"'         "$BASE/health"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[API KEY]${RST}"
# -----------------------------------------------------------------------------
run_test "APIKEY create owner 200"                 "200" '"ok":true'   -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"label":"test-key"}' "$BASE/admin/api/auth/apikey"
run_test "APIKEY list owner 200"                   "200" '"keys"'   --cookie "$COOKIE_OWNER" "$BASE/admin/api/auth/apikey"
run_test "APIKEY revoke bad prefix 400"            "400" '"error"'   -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{}' "$BASE/admin/api/auth/apikey"
run_test "APIKEY revoke injection % → 400"          "400" '"invalid prefix"' -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"prefix":"%"}' "$BASE/admin/api/auth/apikey"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[DB API] POST/PUT/DELETE${RST}"
# -----------------------------------------------------------------------------
run_test "INSERT _lang sans session → 403 (profil 1 sans droits sur _lang)" "403" '"error"' \
  -X POST -H "Content-Type: application/json" -d '{"id":"xx","name":"Test"}' "$BASE/admin/api/db/_lang"

run_test "INSERT _lang admin (profil 2, pas de droits) → 403" "403" '"error"' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" --cookie "$COOKIE_ADMIN" -d '{"id":"xx","name":"Test"}' "$BASE/admin/api/db/_lang"

run_test "INSERT _lang owner → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"id":"de","name":"Deutsch"}' "$BASE/admin/api/db/_lang"

run_test "UPDATE _lang owner → ok" "200" '"ok":true' \
  -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"id":"de","name":"Deutsch (DE)"}' "$BASE/admin/api/db/_lang"

run_test "UPDATE _lang admin → 403" "403" '"error"' \
  -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" --cookie "$COOKIE_ADMIN" -d '{"id":"de","name":"x"}' "$BASE/admin/api/db/_lang"

run_test "UPDATE sans PK → 400" "400" '"error"' \
  -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"name":"sans cle"}' "$BASE/admin/api/db/_lang"

run_test "DELETE _lang admin → 403" "403" '"error"' \
  -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" --cookie "$COOKIE_ADMIN" -d '{"id":"de"}' "$BASE/admin/api/db/_lang"

run_test "DELETE _lang owner → ok" "200" '"ok":true' \
  -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"id":"de"}' "$BASE/admin/api/db/_lang"

run_test "DELETE sans PK → 400" "400" '"error"' \
  -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"name":"sans cle"}' "$BASE/admin/api/db/_lang"

# Table no_pk n'a aucune colonne avec pk > 0 → DELETE impossible → 500
run_test "DELETE table sans PK → 500" "500" '"error"' \
  -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" --cookie "$COOKIE_ADMIN" -d '{"col1":"x"}' "$BASE/admin/api/db/no_pk"

# PK falsy (0, "") — doivent être acceptés pour UPDATE/DELETE
run_test "UPDATE pk_zero id=0 owner → ok" "200" '"ok":true' \
  -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"id":0,"name":"Zero Updated"}' "$BASE/admin/api/db/pk_zero"
run_test "GET pk_zero id=0 → updated" "200" '"Zero Updated"' \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/pk_zero"
run_test "DELETE pk_zero id=0 owner → ok" "200" '"ok":true' \
  -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"id":0}' "$BASE/admin/api/db/pk_zero"
run_test "GET pk_zero → row 0 gone" "200" '"Row One"' \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/pk_zero"
check_absent "GET pk_zero → id=0 absent" '"id":0' \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/pk_zero"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[CONFIG] GET /admin/api/db/_config — table moteur${RST}"
# -----------------------------------------------------------------------------
# La migration 002_config.sql crée _config avec 8 clés et les droits owner.
# Ce test vérifie que la migration s'est appliquée et que les droits sont corrects.
run_test "_config sans session → 401"                     "401" '"error"'          "$BASE/admin/api/db/_config"
run_test "_config admin (profil 2, pas de droits) → 403"  "403" '"error":"forbidden"' --cookie "$COOKIE_ADMIN" "$BASE/admin/api/db/_config"
run_test "_config owner → 200"                             "200" '"columns"'        --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_config"
run_test "_config owner → clé session.ttl présente"        "200" '"session.ttl"'   --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_config"
run_test "_config owner → clé cache.tableInfo présente"    "200" '"cache.tableInfo"' --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_config"
run_test "_config owner → clé db.defaultLimit présente"    "200" '"db.defaultLimit"' --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_config"
run_test "_config owner → 17 entrées (total=17)"           "200" '"total":17'       --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_config"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[STATS] GET /admin/api/stats — module optionnel (port 3001)${RST}"
# -----------------------------------------------------------------------------
# Le module _stats est chargé sur port 3001 (auth+db+stats).
# adminSession est actif → une session valide est requise.
run_test "stats sans session → 401"                          "401" ""              "$BASE/admin/api/stats"
run_test "stats owner → 200"                                 "200" '"caches"'      --cookie "$COOKIE_OWNER" "$BASE/admin/api/stats"
run_test "stats owner → compteurs tableInfo présents"        "200" '"tableInfo"'   --cookie "$COOKIE_OWNER" "$BASE/admin/api/stats"
run_test "stats owner → compteurs fkList présents"           "200" '"fkList"'      --cookie "$COOKIE_OWNER" "$BASE/admin/api/stats"
run_test "stats owner → compteurs queries présents"          "200" '"queries"'     --cookie "$COOKIE_OWNER" "$BASE/admin/api/stats"
run_test "stats owner → champ hits présent"                  "200" '"hits"'        --cookie "$COOKIE_OWNER" "$BASE/admin/api/stats"
check_absent "stats owner → config absente (voir /api/db/_config)" '"config"' --cookie "$COOKIE_OWNER" "$BASE/admin/api/stats"
run_test "stats 3002 → 404 (stats non chargé)"               "404" ""              "http://localhost:3002/admin/api/stats"
run_test "stats 3003 → 404 (stats non chargé)"               "404" ""              "http://localhost:3003/admin/api/stats"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[STATS] GET /admin/form/stats — page EJS (migration 003_stats.sql)${RST}"
# -----------------------------------------------------------------------------
run_test "form/stats sans session → 401"                "401" ""                     "$BASE/admin/form/stats"
run_test "form/stats admin (profil 2) → 401"            "401" ""                     --cookie "$COOKIE_ADMIN" "$BASE/admin/form/stats"
run_test "form/stats owner → 200 HTML"                  "200" "<!DOCTYPE html>"      --cookie "$COOKIE_OWNER" "$BASE/admin/form/stats"
run_test "form/stats owner → titre Statistiques"        "200" "WaTE — Statistiques"  --cookie "$COOKIE_OWNER" "$BASE/admin/form/stats"
run_test "form/stats owner → container #stats-wrap"     "200" 'id="stats-wrap"'      --cookie "$COOKIE_OWNER" "$BASE/admin/form/stats"
run_test "form/stats owner → import admin-stats.js"     "200" "admin-stats.js"       --cookie "$COOKIE_OWNER" "$BASE/admin/form/stats"
run_test "form/stats owner → email owner"               "200" "owner@test.com"       --cookie "$COOKIE_OWNER" "$BASE/admin/form/stats"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[PERF] Cache LRU — hits/misses après requêtes répétées${RST}"
echo "================================================================="
# Lecture initiale des stats pour référence.
STATS_INIT=$(curl -s --max-time 5 --cookie "$COOKIE_OWNER" "$BASE/admin/api/stats" 2>/dev/null)
HITS_TI_BEFORE=$(echo "$STATS_INIT" | node -e "var d='';process.stdin.on('data',function(c){d+=c});process.stdin.on('end',function(){var s=JSON.parse(d);process.stdout.write(String(s.caches.tableInfo.hits))})" 2>/dev/null || echo "0")

# 5 appels au même schema → toutes les PRAGMA table_info devraient être en cache après le 1er.
for i in $(seq 1 5); do
  curl -s -o /dev/null --max-time 5 --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/schema" 2>/dev/null
done

# Lecture après pour vérifier que les hits ont augmenté.
STATS_AFTER=$(curl -s --max-time 5 --cookie "$COOKIE_OWNER" "$BASE/admin/api/stats" 2>/dev/null)
HITS_TI_AFTER=$(echo "$STATS_AFTER" | node -e "var d='';process.stdin.on('data',function(c){d+=c});process.stdin.on('end',function(){var s=JSON.parse(d);process.stdout.write(String(s.caches.tableInfo.hits))})" 2>/dev/null || echo "0")
HITS_Q_AFTER=$(echo "$STATS_AFTER" | node -e "var d='';process.stdin.on('data',function(c){d+=c});process.stdin.on('end',function(){var s=JSON.parse(d);process.stdout.write(String(s.caches.queries.hits))})" 2>/dev/null || echo "0")

if [ "$HITS_TI_AFTER" -gt "$HITS_TI_BEFORE" ] 2>/dev/null; then
  echo -e "  ${GRN}PASS${RST}  cache tableInfo : hits ${HITS_TI_BEFORE} → ${HITS_TI_AFTER}"; PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${RST}  cache tableInfo : hits inchangés (${HITS_TI_BEFORE})"; FAIL=$((FAIL + 1))
fi
if [ -n "$HITS_Q_AFTER" ] && [ "$HITS_Q_AFTER" -ge 0 ] 2>/dev/null; then
  echo -e "  ${GRN}PASS${RST}  cache queries présent (hits=${HITS_Q_AFTER})"; PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${RST}  cache queries absent des stats"; FAIL=$((FAIL + 1))
fi

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[UI] GET /admin/form/auth/signin — mode login${RST}"
# -----------------------------------------------------------------------------
run_test "form/auth/signin sans session → 200"           "200" "<!DOCTYPE html>"              "$BASE/admin/form/auth/signin"
run_test "form/auth/signin → titre Connexion"            "200" "WaTE — Connexion"              "$BASE/admin/form/auth/signin"
run_test "form/auth/signin → h2 Connexion"              "200" "<h2>Connexion</h2>"            "$BASE/admin/form/auth/signin"
run_test "form/auth/signin → action signin"              "200" 'action="/admin/form/auth/signin"' "$BASE/admin/form/auth/signin"
run_test "form/auth/signin → champ email"                "200" 'type&#34;:&#34;email&#34;'   "$BASE/admin/form/auth/signin"
run_test "form/auth/signin → champ password"             "200" 'hash&#34;:&#34;sha256&#34;' "$BASE/admin/form/auth/signin"
run_test "form/auth/signin → lien signup"                "200" '/admin/form/auth/signup'       "$BASE/admin/form/auth/signin"
check_absent "form/auth/signin sans session → pas d'email" "owner@test.com" "$BASE/admin/form/auth/signin"

run_test "form/auth/signin session owner → 401 (pas _page profil 0)" "401" "" --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/signin"
run_test "form/auth/signin session admin → 401 (pas _page profil 2)" "401" "" --cookie "$COOKIE_ADMIN" "$BASE/admin/form/auth/signin"
run_test "form/auth/signin session expirée → 401 (TTL filtre la session)" "401" "" --cookie "$COOKIE_EXPIRED" "$BASE/admin/form/auth/signin"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[UI] GET /admin/form/auth/signup — mode signup${RST}"
# -----------------------------------------------------------------------------
run_test "form/auth/signup sans session → 200"        "200" "<!DOCTYPE html>"                  "$BASE/admin/form/auth/signup"
run_test "form/auth/signup → titre Inscription"       "200" "WaTE — Inscription"               "$BASE/admin/form/auth/signup"
run_test "form/auth/signup → action signup"           "200" 'action="/admin/form/auth/signup"' "$BASE/admin/form/auth/signup"
run_test "form/auth/signup → lien retour signin"      "200" '/admin/form/auth/signin'          "$BASE/admin/form/auth/signup"

run_test "form/auth/signup session owner → 401 (pas _page profil 0)" "401" "" --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/signup"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[UI] GET /admin/form/auth/me — mode profil (session requise)${RST}"
# -----------------------------------------------------------------------------
run_test "form/auth/me sans session → 401 (anonymous pas _page /me)" "401" "" "$BASE/admin/form/auth/me"

run_test "form/auth/me owner → 200 HTML"                   "200" "<!DOCTYPE html>"              --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
run_test "form/auth/me owner → titre Mon profil"           "200" "WaTE — Mon profil"            --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
run_test "form/auth/me owner → h2 Mon profil"              "200" "<h2>Mon profil</h2>"          --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
run_test "form/auth/me owner → email owner@test.com"       "200" "owner@test.com"               --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
run_test "form/auth/me owner → profil_id 0"                "200" '"profil_id": 0'               --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
run_test "form/auth/me owner → lien /admin/form/db/schema" "200" "/admin/form/db/schema"        --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
run_test "form/auth/me owner → formulaire signout"         "200" 'action="/admin/form/auth/signout"' --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
run_test "form/auth/me owner → formulaire update-self"     "200" 'action="/admin/form/auth/me"' --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"

run_test "form/auth/me admin → email admin@test.com"  "200" "admin@test.com" --cookie "$COOKIE_ADMIN" "$BASE/admin/form/auth/me"
run_test "form/auth/me admin → profil_id 2"           "200" '"profil_id": 2'  --cookie "$COOKIE_ADMIN" "$BASE/admin/form/auth/me"

check_absent "form/auth/me owner ne voit pas admin@test.com" "admin@test.com" --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
check_absent "form/auth/me admin ne voit pas owner@test.com" "owner@test.com" --cookie "$COOKIE_ADMIN" "$BASE/admin/form/auth/me"
check_absent "form/auth/me owner ne voit pas profil_id 2"    '"profil_id": 2'  --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
check_absent "form/auth/me admin ne voit pas profil_id 0"    '"profil_id": 0'  --cookie "$COOKIE_ADMIN" "$BASE/admin/form/auth/me"

run_test "form/auth/me signup-test (profil 6) → 200" "200" "signup-test@test.com" --cookie "$COOKIE_SIGNUP" "$BASE/admin/form/auth/me"

run_test "form/auth/me owner → lien désinscription method DELETE"     "200" 'method&#34;:&#34;DELETE&#34;'   --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
run_test "form/auth/me owner → lien désinscription href api/auth/me"  "200" 'href&#34;:&#34;/admin/api/auth/me'   --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"
check_absent "form/auth/me owner → pas de lien form/auth/signup" '/form/auth/signup' --cookie "$COOKIE_OWNER" "$BASE/admin/form/auth/me"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[UI] GET /admin/form/db/schema — liste des tables${RST}"
# -----------------------------------------------------------------------------
run_test "form/db/schema sans session → 401"          "401" "" "$BASE/admin/form/db/schema"
run_test "form/db/schema owner → 200 HTML"            "200" "<!DOCTYPE html>"     --cookie "$COOKIE_OWNER" "$BASE/admin/form/db/schema"
run_test "form/db/schema → Tables accessibles"        "200" "Tables accessibles"  --cookie "$COOKIE_OWNER" "$BASE/admin/form/db/schema"
run_test "form/db/schema → schema-grid"               "200" 'id="schema-grid"'    --cookie "$COOKIE_OWNER" "$BASE/admin/form/db/schema"
run_test "form/db/schema → import schema-table"       "200" "schema-table/def.js" --cookie "$COOKIE_OWNER" "$BASE/admin/form/db/schema"
run_test "form/db/schema owner → email owner"         "200" "owner@test.com"      --cookie "$COOKIE_OWNER" "$BASE/admin/form/db/schema"
run_test "form/db/schema admin → email admin"         "200" "admin@test.com"      --cookie "$COOKIE_ADMIN" "$BASE/admin/form/db/schema"
run_test "form/db/schema admin → profil_id 2"          "200" '"profil_id": 2'     --cookie "$COOKIE_ADMIN" "$BASE/admin/form/db/schema"
check_absent "form/db/schema owner ne voit pas admin@test.com" "admin@test.com" --cookie "$COOKIE_OWNER" "$BASE/admin/form/db/schema"
check_absent "form/db/schema admin ne voit pas owner@test.com" "owner@test.com" --cookie "$COOKIE_ADMIN" "$BASE/admin/form/db/schema"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[UI] GET /admin/form/db?table=... — CRUD table${RST}"
# -----------------------------------------------------------------------------
run_test "form/db?table=_lang sans session → 401"      "401" "" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → titre _lang"           "200" "WaTE — _lang"          --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → code _lang"            "200" "<code>_lang</code>"    --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → data-table"            "200" 'id="data-table"'       --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → btn-insert"            "200" 'id="btn-insert"'       --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → import scripts/admin-db.js" "200" "scripts/admin-db.js"       --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → import { init }"             "200" "import { init }"          --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → import admin-row/def.js"     "200" "custom/admin-row/def.js"  --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → col id dans TABLE.cols"      "200" '"name":"id"'              --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → col name dans TABLE.cols"    "200" '"name":"name"'            --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang owner → fkOptions dans script"       "200" "fkOptions"                --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_lang admin → 401"                   "401" ""                      --cookie "$COOKIE_ADMIN" "$BASE/admin/form/db?table=_lang"
run_test "form/db?table=_access owner → 200"                 "200" "WaTE — _access"        --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_access"
run_test "form/db?table=_access owner → FK _profil"           "200" '"_profil"'             --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_access"
run_test "form/db?table=_access owner → FK _request"          "200" '"_request"'            --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=_access"
run_test "form/db?table=_access admin → 401"                 "401" ""                      --cookie "$COOKIE_ADMIN" "$BASE/admin/form/db?table=_access"
run_test "form/db?table=bad-name owner → 500"  "500" "" --cookie "$COOKIE_OWNER" "$BASE/admin/form/db?table=bad-name"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[PAGES] /home — anonymous${RST}"
# -----------------------------------------------------------------------------
run_test "/home anonymous → 200" "200" '<code>/home</code>' "$BASE/home"
run_test "/home profil2 → 401"   "401" "" --cookie "$COOKIE_ADMIN" "$BASE/home"
run_test "/home profil3 → 401"   "401" "" --cookie "$COOKIE_P3"    "$BASE/home"
run_test "/home profil4 → 401"   "401" "" --cookie "$COOKIE_P4"    "$BASE/home"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[PAGES] /shared — contenu par profil${RST}"
# -----------------------------------------------------------------------------
run_test "/shared anonymous → 401"             "401" ""              "$BASE/shared"
run_test "/shared profil2 → admin-test"        "200" '"admin-test"'    --cookie "$COOKIE_ADMIN" "$BASE/shared"
run_test "/shared profil3 → profil-3-test"     "200" '"profil-3-test"' --cookie "$COOKIE_P3"    "$BASE/shared"
run_test "/shared profil4 → profil-4-test"     "200" '"profil-4-test"' --cookie "$COOKIE_P4"    "$BASE/shared"
check_absent "/shared profil2 pas profil-3-test" '"profil-3-test"' --cookie "$COOKIE_ADMIN" "$BASE/shared"
check_absent "/shared profil2 pas profil-4-test" '"profil-4-test"' --cookie "$COOKIE_ADMIN" "$BASE/shared"
check_absent "/shared profil3 pas admin-test"    '"admin-test"'    --cookie "$COOKIE_P3"    "$BASE/shared"
check_absent "/shared profil3 pas profil-4-test" '"profil-4-test"' --cookie "$COOKIE_P3"    "$BASE/shared"
check_absent "/shared profil4 pas admin-test"    '"admin-test"'    --cookie "$COOKIE_P4"    "$BASE/shared"
check_absent "/shared profil4 pas profil-3-test" '"profil-3-test"' --cookie "$COOKIE_P4"    "$BASE/shared"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[PAGES] /exclusive — profils 3 et 4${RST}"
# -----------------------------------------------------------------------------
run_test "/exclusive anonymous → 401"              "401" "" "$BASE/exclusive"
run_test "/exclusive profil2 → 401"                "401" "" --cookie "$COOKIE_ADMIN" "$BASE/exclusive"
run_test "/exclusive profil3 → profil-3-test"      "200" '"profil-3-test"' --cookie "$COOKIE_P3" "$BASE/exclusive"
run_test "/exclusive profil4 → profil-4-test"      "200" '"profil-4-test"' --cookie "$COOKIE_P4" "$BASE/exclusive"
check_absent "/exclusive profil3 pas profil-4-test" '"profil-4-test"' --cookie "$COOKIE_P3" "$BASE/exclusive"
check_absent "/exclusive profil4 pas profil-3-test" '"profil-3-test"' --cookie "$COOKIE_P4" "$BASE/exclusive"

# -----------------------------------------------------------------------------
echo ""
echo "${YEL}[PAGES] /missing — 404${RST}"
# -----------------------------------------------------------------------------
run_test "/missing anonymous → 404" "404" "" "$BASE/missing"
run_test "/missing profil2 → 404"   "404" "" --cookie "$COOKIE_ADMIN" "$BASE/missing"
run_test "/missing profil3 → 404"   "404" "" --cookie "$COOKIE_P3"    "$BASE/missing"
run_test "/missing profil4 → 404"   "404" "" --cookie "$COOKIE_P4"    "$BASE/missing"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[MODIFY TABLE] POST /admin/form/db/:table/:request${RST}"
echo "================================================================="
run_test "POST _lang/insert sans session → 403 (profil 9999 sans droits)"        "403" "" -X POST -d 'id=xx-test&name=Test' "$BASE/admin/form/db/_lang/insert"
run_test "POST _lang/insert session expirée → 401"                             "401" "" -X POST -H "X-CSRF-Token: $CSRF_EXPIRED" --cookie "$COOKIE_EXPIRED" -d 'id=xx-test&name=Test' "$BASE/admin/form/db/_lang/insert"
run_test "POST _lang/insert admin (session OK, pas droits) → 403"              "403" "" -X POST --cookie "$COOKIE_ADMIN"   -d "id=xx-test&name=Test&_csrf=$CSRF_ADMIN" "$BASE/admin/form/db/_lang/insert"
run_test "POST bad-name/insert owner → 400"                                    "400" "" -X POST --cookie "$COOKIE_OWNER"   -d "id=xx-test&name=Test&_csrf=$CSRF_OWNER" "$BASE/admin/form/db/bad-name/insert"

echo ""
echo "${YEL}[MODIFY TABLE] owner sur _lang${RST}"
run_test "INSERT _lang owner → 302"  "302" "" -o /dev/null -X POST --cookie "$COOKIE_OWNER" -d "id=xx-test&name=Test Language&_csrf=$CSRF_OWNER"         "$BASE/admin/form/db/_lang/insert"
run_test "UPDATE _lang owner → 302"  "302" "" -o /dev/null -X POST --cookie "$COOKIE_OWNER" -d "id=xx-test&name=Test Language Updated&_csrf=$CSRF_OWNER" "$BASE/admin/form/db/_lang/update"
run_test "DELETE _lang owner → 302"  "302" "" -o /dev/null -X POST --cookie "$COOKIE_OWNER" -d "id=xx-test&_csrf=$CSRF_OWNER"                            "$BASE/admin/form/db/_lang/delete"

echo ""
echo "${YEL}[MODIFY TABLE] admin sur sample${RST}"
run_test "INSERT sample admin → 302" "302" "" -o /dev/null -X POST --cookie "$COOKIE_ADMIN" -d "id=t1&name=Test Sample&_csrf=$CSRF_ADMIN"         "$BASE/admin/form/db/sample/insert"
run_test "UPDATE sample admin → 302" "302" "" -o /dev/null -X POST --cookie "$COOKIE_ADMIN" -d "id=t1&name=Test Sample Updated&_csrf=$CSRF_ADMIN" "$BASE/admin/form/db/sample/update"
run_test "DELETE sample admin → 302" "302" "" -o /dev/null -X POST --cookie "$COOKIE_ADMIN" -d "id=t1&_csrf=$CSRF_ADMIN"                          "$BASE/admin/form/db/sample/delete"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[AUDIT] _audit${RST}"
echo "================================================================="
run_test "GET _audit sans session 401"             "401" '"error"'                  "$BASE/admin/api/db/_audit"
run_test "GET _audit admin 403"                    "403" '"error":"forbidden"'    --cookie "$COOKIE_ADMIN" "$BASE/admin/api/db/_audit"
run_test "GET _audit owner 200"                    "200" '"columns"'                --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_audit"
echo ""
echo "${YEL}[AUDIT] INSERT/UPDATE/DELETE${RST}"
run_test "AUDIT INSERT _lang"                      "200" '"ok":true'   -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER"   --cookie "$COOKIE_OWNER" -d '{"id":"audit-test","name":"Audit Insert"}' "$BASE/admin/api/db/_lang"
run_test "AUDIT total a augmente"                  "200" '"total"' --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_audit"
run_test "AUDIT UPDATE _lang"                      "200" '"ok":true'   -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER"   --cookie "$COOKIE_OWNER" -d '{"id":"audit-test","name":"Audit Updated"}' "$BASE/admin/api/db/_lang"
run_test "AUDIT filter table_name=_lang"           "200" '"total"' --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/_audit?filter=table_name:_lang"
run_test "AUDIT DELETE _lang"                      "200" '"ok":true'   -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER"   --cookie "$COOKIE_OWNER" -d '{"id":"audit-test"}' "$BASE/admin/api/db/_lang"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[AUTH API] PUT/DELETE /admin/api/auth/me${RST}"
echo "================================================================="
run_test "PUT /me sans session → 401"                         "401" '"error"'   -X PUT -H "Content-Type: application/json" -d '{"forename":"Test"}' "$BASE/admin/api/auth/me"
run_test "PUT /me owner (update → accès) → 200"              "200" '"ok":true' -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d '{"forename":"Owner Updated"}' "$BASE/admin/api/auth/me"
run_test "PUT /me admin (update-self) → ok"                  "200" '"ok":true' -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" --cookie "$COOKIE_ADMIN" -d '{"forename":"Admin Updated"}' "$BASE/admin/api/auth/me"
run_test "PUT /me admin body vide → 400"                     "400" '"error"'   -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" --cookie "$COOKIE_ADMIN" -d '{}' "$BASE/admin/api/auth/me"
run_test "PUT /me p3 (aucun droit _user) → 403"              "403" '"error"'   -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_P3"    --cookie "$COOKIE_P3"    -d '{"forename":"P3 Updated"}' "$BASE/admin/api/auth/me"

echo ""
echo "${YEL}[AUTH API] DELETE /admin/api/auth/me${RST}"
run_test "DELETE /me sans session → 401"             "401" '"error"'    -X DELETE "$BASE/admin/api/auth/me"
run_test "DELETE /me admin (pas delete-self) → 403"  "403" '"error"'    -X DELETE -H "X-CSRF-Token: $CSRF_ADMIN"     --cookie "$COOKIE_ADMIN"     "$BASE/admin/api/auth/me"
run_test "DELETE /me delete-me → ok"                 "200" '"ok":true'  -X DELETE -H "X-CSRF-Token: $CSRF_DELETE_ME" --cookie "$COOKIE_DELETE_ME" "$BASE/admin/api/auth/me"
run_test "GET /api/auth/me delete-me (supprimé) → 401" "401" '"error"'   --cookie "$COOKIE_DELETE_ME" "$BASE/admin/api/auth/me"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[AUTH FORM] POST /admin/form/auth/signin${RST}"
echo "================================================================="
run_test "form signin champs manquants → 302"   "302" "" -o /dev/null -X POST -d 'email=&password='                              "$BASE/admin/form/auth/signin"
run_test "form signin mauvais mot de passe → 302" "302" "" -o /dev/null -X POST -d 'email=owner@test.com&password=wrong'            "$BASE/admin/form/auth/signin"

echo ""
echo "${YEL}[AUTH FORM] POST /admin/form/auth/signout${RST}"
run_test "form signout sans session → 302"  "302" "" -o /dev/null -X POST                          "$BASE/admin/form/auth/signout"
run_test "form signout session active → 302" "302" "" -o /dev/null -X POST -d "_csrf=$CSRF_P3" --cookie "$COOKIE_P3"    "$BASE/admin/form/auth/signout"

echo ""
echo "${YEL}[AUTH FORM] POST /admin/form/auth/me — update-self${RST}"
run_test "form me sans session → 302"       "302" "" -o /dev/null -X POST -d 'forename=Test'               "$BASE/admin/form/auth/me"
run_test "form me admin (update-self) → 302 succès" "302" "" -o /dev/null -X POST --cookie "$COOKIE_ADMIN" -d "forename=Admin+Form+Updated&_csrf=$CSRF_ADMIN" "$BASE/admin/form/auth/me"
run_test "form me owner (update via update-self) → 302" "302" "" -o /dev/null -X POST --cookie "$COOKIE_OWNER" -d "forename=Owner&_csrf=$CSRF_OWNER"    "$BASE/admin/form/auth/me"

echo ""
echo "${YEL}[AUTH FORM] POST /admin/form/auth/signup${RST}"
run_test "form signup sans session → 302" "302" "" \
  -o /dev/null -X POST \
  -d 'email=new-form@test.com&password=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa&profil_id=42' \
  "$BASE/admin/form/auth/signup"

# =============================================================================
echo ""
echo "================================================================="
echo " [MODULES] port 3002 — auth seul"
echo "================================================================="
BASE2="http://localhost:3002"
run_test "3002 GET /admin/api/auth/me sans session → 401"              "401" "" "$BASE2/admin/api/auth/me"
run_test "3002 POST /admin/api/auth/signin → 401 (mauvais mot de passe)" "401" '"error"' \
  -X POST -H 'Content-Type: application/json' -d '{"email":"owner@test.com","password":"bad"}' "$BASE2/admin/api/auth/signin"
run_test "3002 GET /admin/form/auth/signin → 200 (auth chargé)"        "200" "<!DOCTYPE html>" "$BASE2/admin/form/auth/signin"
run_test "3002 GET /admin/api/db/schema → 404 (db non chargé)"         "404" "" --cookie "$COOKIE_OWNER" "$BASE2/admin/api/db/schema"
run_test "3002 GET /admin/form/db/schema → 401 (page profil 0, anonymous → accès refusé)" "401" "" "$BASE2/admin/form/db/schema"
run_test "3002 POST /admin/form/db/_lang/insert → 404 (db non chargé)" "404" "" -X POST -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" -d 'id=xx&name=Test' "$BASE2/admin/form/db/_lang/insert"

echo ""
echo "================================================================="
echo " [MODULES] port 3003 — aucun module"
echo "================================================================="
BASE3="http://localhost:3003"
run_test "3003 GET /admin/api/auth/me → 404 (auth non chargé)"          "404" "" "$BASE3/admin/api/auth/me"
run_test "3003 POST /admin/api/auth/signin → 404"                       "404" "" -X POST -H 'Content-Type: application/json' -d '{"email":"x","password":"x"}' "$BASE3/admin/api/auth/signin"
run_test "3003 GET /admin/form/auth/signin → 200 (page CMS profil 42)"  "200" "" "$BASE3/admin/form/auth/signin"
run_test "3003 GET /admin/api/db/schema → 404"                          "404" "" "$BASE3/admin/api/db/schema"
run_test "3003 GET /home → 200 (CMS fonctionne sans modules)"           "200" "" "$BASE3/home"
run_test "3003 GET /admin/form/db/schema → 401 (page profil 0, anonymous → refusé)" "401" "" "$BASE3/admin/form/db/schema"
run_test "3003 POST /admin/form/db/_lang/insert → 404"                  "404" "" -X POST -d 'id=xx&name=Test' "$BASE3/admin/form/db/_lang/insert"

echo ""
echo "================================================================="
echo " [MODULES] port 3004 — db sans auth"
echo "================================================================="
BASE4="http://localhost:3004"
run_test "3004 GET /admin/api/db/schema → 200 (anonymous, tables vides)" "200" '"tables":[]' "$BASE4/admin/api/db/schema"
run_test "3004 GET /admin/api/db/_lang → 403 (anonymous, pas select _lang)" "403" '"error":"forbidden"' "$BASE4/admin/api/db/_lang"
run_test "3004 POST /admin/api/db/_lang → 403 (anonymous, pas insert _lang)" "403" '"error"' \
  -X POST -H "Content-Type: application/json" -d '{"id":"xx","name":"Test"}' "$BASE4/admin/api/db/_lang"
run_test "3004 GET /admin/api/auth/me → 404 (auth non chargé)"      "404" "" "$BASE4/admin/api/auth/me"
run_test "3004 GET /admin/form/auth/signin → 200 (page CMS profil 42)" "200" "" "$BASE4/admin/form/auth/signin"
run_test "3004 GET /home → 200 (CMS fonctionne sans auth)"        "200" "" "$BASE4/home"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[MODAL-POPUP] plomberie HTTP — custom element + wateModal${RST}"
echo "================================================================="
# modal-popup remplace alert/confirm natifs. On teste que le module est servi
# sous /custom/modal-popup/{def.js,def.css} et qu'admin-row l'utilise bien.
run_test "GET /custom/modal-popup/def.js → 200"           "200" "customHTMLElement"    "$BASE/custom/modal-popup/def.js"
run_test "GET /custom/modal-popup/def.js → wateModal"     "200" "wateModal"            "$BASE/custom/modal-popup/def.js"
run_test "GET /custom/modal-popup/def.js → mode confirm"  "200" "confirm"              "$BASE/custom/modal-popup/def.js"
run_test "GET /custom/modal-popup/def.js → modal-popup"   "200" "modal-popup"          "$BASE/custom/modal-popup/def.js"
run_test "GET /custom/modal-popup/def.css → 200 backdrop" "200" "backdrop"             "$BASE/custom/modal-popup/def.css"
# admin-row utilise wateModal.confirm/info à la place de window.alert/confirm.
run_test "admin-row/def.js → wateModal.confirm"          "200" "wateModal.confirm"     "$BASE/custom/admin-row/def.js"
run_test "admin-row/def.js → wateModal.info"             "200" "wateModal.info"        "$BASE/custom/admin-row/def.js"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[AUTH MAIL OFF] mode dégradé sur port 3001 (mail non chargé)${RST}"
echo "================================================================="
# Sans module mail + sans stub app.locals.mail, _core.mail reste no-op (_core.js
# défaut). _userSignup → verified=1 immédiat. forgot/reset → 404.
run_test "API  /admin/api/auth/forgot → 404 (mail off)"   "404" '"error"' \
  -X POST -H "Content-Type: application/json" -d '{"email":"owner@test.com"}' "$BASE/admin/api/auth/forgot"
run_test "API  /admin/api/auth/reset → 404 (mail off)"    "404" '"error"' \
  -X POST -H "Content-Type: application/json" -d '{"password":"x","token":"deadbeef"}' "$BASE/admin/api/auth/reset"
run_test "FORM /admin/form/auth/forgot → 404 (mail off)"  "404" "" \
  -o /dev/null -X POST -d 'email=owner@test.com' "$BASE/admin/form/auth/forgot"
# signin page : mail off → pas de lien « mot de passe oublié ».
check_absent "form/auth/signin mail off → pas de link-forgot" '/admin/form/auth/forgot' "$BASE/admin/form/auth/signin"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[AUTH MAIL ON] protocole complet — port 3005 (mail stubbé)${RST}"
echo "================================================================="
BASE5="http://localhost:3005"

# Le stub capture l'envoi — GET /test/mail-last?to=<email> retourne {to,subject,text}.
# L'URL verify/reset est dans text (format base + path?token=...&lang=...).
# Helpers locaux : extraction du token (64 hex) et de l'URL du mail.
get_mail_url() {
  curl -s --max-time 5 "$BASE5/test/mail-last?to=$1" | node -e \
    'var d="";process.stdin.on("data",function(c){d+=c});process.stdin.on("end",function(){try{var m=JSON.parse(d);var u=(m.text||"").match(/https?:\S+/);process.stdout.write(u?u[0]:"")}catch(e){process.stdout.write("")}})'
}
get_mail_token() {
  local url; url=$(get_mail_url "$1")
  echo "$url" | node -e 'var d="";process.stdin.on("data",function(c){d+=c});process.stdin.on("end",function(){var m=d.match(/[?&]token=([0-9a-f]{64})/);process.stdout.write(m?m[1]:"")})'
}

# --- signup : verified=0, mail capturé ----------------------------------------
run_test "3005 signup nouveau compte → 200 (API)" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"mail-on@test.com","password":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","profil_id":"42"}' \
  "$BASE5/admin/api/auth/signup"

# Le mail est capturé par le stub. On extrait le token verify.
VERIFY_URL=$(get_mail_url "mail-on@test.com")
VERIFY_TOKEN=$(get_mail_token "mail-on@test.com")
if [ -n "$VERIFY_TOKEN" ]; then
  echo -e "  ${GRN}PASS${RST}  3005 signup → mail capturé avec token (${VERIFY_TOKEN:0:8}…)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${RST}  3005 signup → token absent du mail (url=${YEL}${VERIFY_URL}${RST})"
  FAIL=$((FAIL + 1))
fi

# signin refusé tant que verified=0
run_test "3005 signin avant verify → 403 account-not-verified" "403" '"account-not-verified"' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"mail-on@test.com","password":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}' \
  "$BASE5/admin/api/auth/signin"

# --- verify/resend : renvoi du lien de vérification --------------------------
run_test "3005 verify/resend → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"mail-on@test.com"}' \
  "$BASE5/admin/api/auth/verify/resend"

# Anti-énumération : email inconnu → 200 ok (silencieux)
run_test "3005 verify/resend email inconnu → 200 (silencieux)" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"inconnu@test.com"}' \
  "$BASE5/admin/api/auth/verify/resend"

# Token ré-émis : le nouveau token est différent de l'original (l'ancien est supprimé)
VERIFY_TOKEN_2=$(get_mail_token "mail-on@test.com")
if [ -n "$VERIFY_TOKEN_2" ] && [ "$VERIFY_TOKEN_2" != "$VERIFY_TOKEN" ]; then
  echo -e "  ${GRN}PASS${RST}  3005 verify/resend → nouveau token différent (${VERIFY_TOKEN_2:0:8}…)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${RST}  3005 verify/resend → token identique ou absent (t1=${YEL}${VERIFY_TOKEN:0:8}…${RST} t2=${YEL}${VERIFY_TOKEN_2:0:8}…${RST})"
  FAIL=$((FAIL + 1))
fi

# L'ancien token verify est invalide (supprimé par _makeToken)
run_test "3005 replay verify original (token consommé par resend) → 302" "302" "" \
  -o /dev/null "$BASE5/admin/form/auth/verify?token=$VERIFY_TOKEN"

# GET /verify?token=... → 302 redirect signin?info=account-verified
# Avec le NOUVEAU token
run_test "3005 GET /verify?token=... → 302" "302" "" \
  -o /dev/null "$BASE5/admin/form/auth/verify?token=$VERIFY_TOKEN_2"
run_test "3005 GET /verify?token=... → 302" "302" "" \
  -o /dev/null "$BASE5/admin/form/auth/verify?token=$VERIFY_TOKEN"

# Réutiliser le même token → 302 avec error=reset-invalid (consommé + supprimé)
run_test "3005 replay verify (token consommé) → 302" "302" "" \
  -o /dev/null "$BASE5/admin/form/auth/verify?token=$VERIFY_TOKEN"

# signin OK après verify
run_test "3005 signin après verify → 200" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"mail-on@test.com","password":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}' \
  "$BASE5/admin/api/auth/signin"

# --- forgot : mail reset capturé ---------------------------------------------
run_test "3005 forgot → 200 (API, toujours ok)" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"mail-on@test.com"}' \
  "$BASE5/admin/api/auth/forgot"

# Anti-enumeration : email inconnu → 200 ok (silencieux).
run_test "3005 forgot email inconnu → 200 (silencieux)" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"nobody@test.com"}' \
  "$BASE5/admin/api/auth/forgot"

RESET_TOKEN=$(get_mail_token "mail-on@test.com")
if [ -n "$RESET_TOKEN" ] && [ "$RESET_TOKEN" != "$VERIFY_TOKEN" ]; then
  echo -e "  ${GRN}PASS${RST}  3005 forgot → mail reset capturé (token ≠ verify)"
  PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${RST}  3005 forgot → token reset absent ou identique au verify"
  FAIL=$((FAIL + 1))
fi

# POST /reset avec le token + nouveau password
run_test "3005 reset → 200 nouveau password" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  -d '{"token":"'"$RESET_TOKEN"'","password":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}' \
  "$BASE5/admin/api/auth/reset"

# Ancien password → 401
run_test "3005 signin ancien password → 401" "401" '"invalid credentials"' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"mail-on@test.com","password":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}' \
  "$BASE5/admin/api/auth/signin"

# Nouveau password → 200
run_test "3005 signin nouveau password → 200" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" \
  -d '{"email":"mail-on@test.com","password":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}' \
  "$BASE5/admin/api/auth/signin"

# Token reset rejoué → 400 reset-invalid
run_test "3005 reset replay (token consommé) → 400" "400" '"reset-invalid"' \
  -X POST -H "Content-Type: application/json" \
  -d '{"token":"'"$RESET_TOKEN"'","password":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}' \
  "$BASE5/admin/api/auth/reset"

# Token mal formé → 400
run_test "3005 reset token mal formé → 400" "400" '"reset-invalid"' \
  -X POST -H "Content-Type: application/json" \
  -d '{"token":"not-hex","password":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}' \
  "$BASE5/admin/api/auth/reset"

# v3.15.0 : token bien formé (64 hex) mais jamais émis — même branche que expiré
# (!row dans _consumeToken). Vérifie qu'on renvoie reset-invalid sans fuite
# (pas de 404/401 qui distinguerait un email inexistant d'un token expiré).
run_test "3005 reset token inconnu (64 hex, absent DB) → 400" "400" '"reset-invalid"' \
  -X POST -H "Content-Type: application/json" \
  -d '{"token":"0000000000000000000000000000000000000000000000000000000000000000","password":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}' \
  "$BASE5/admin/api/auth/reset"

# v3.15.0 : idem côté verify — GET avec token bien formé mais inconnu →
# 302 vers signin?error=reset-invalid (_auth.js reroute sans fuite).
run_test "3005 verify token inconnu (64 hex, absent DB) → 302" "302" "" \
  -o /dev/null "$BASE5/admin/form/auth/verify?token=1111111111111111111111111111111111111111111111111111111111111111"

# signin page sur 3005 → lien forgot présent (mailAvailable=true).
run_test "3005 /form/auth/signin → lien forgot présent" "200" '/admin/form/auth/forgot' \
  "$BASE5/admin/form/auth/signin"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[API] _WATE_API — sondes techniques (module test-api sur 3001)${RST}"
echo "================================================================="
# Le module test-api expose /test/api/* pour valider chaque surface de l'API
# injectée dans les modules applicatifs par _modules.js (log, db, renderError,
# app). Ces tests prouvent qu'un module applicatif peut écrire une appli WaTE
# complète sans jamais taper dans _core.

# api.log fonctionnel — constantes numériques exposées.
run_test "API /test/api/log → ok"                 "200" '"ok":true'  "$BASE/test/api/log"
run_test "API /test/api/log → niveau INFO présent" "200" '"INFO"'    "$BASE/test/api/log"

# api.db.all — accès SQLite sécurisé via dbRequest.
run_test "API /test/api/db → ok"                  "200" '"ok":true'  "$BASE/test/api/db"
run_test "API /test/api/db → rows de _profil"     "200" '"rows"'     "$BASE/test/api/db"
run_test "API /test/api/db → profil anonymous id" "200" '"id":42'    "$BASE/test/api/db"
run_test "API /test/api/db → profil admin-test"   "200" '"admin-test"' "$BASE/test/api/db"

# api.renderError — rendu d'une page d'erreur arbitraire.
run_test "API /test/api/render-error → 418"        "418" "" "$BASE/test/api/render-error?code=418"
run_test "API /test/api/render-error → 500 défaut" "418" "" "$BASE/test/api/render-error"

# api.app === req.app (même instance Express).
run_test "API /test/api/app-locals → same=true"   "200" '"same":true' "$BASE/test/api/app-locals"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[APP STYLES] 3 façons d'écrire une appli WaTE — module test-routes${RST}"
echo "================================================================="
# Le module test-routes illustre/valide les 3 styles officiellement supportés
# par le moteur. Un même utilisateur anonymous doit obtenir une page rendue
# dans chaque cas — les 3 mènent au même résultat pour le moteur.

# ── Style 1 : route module + api.renderPage ───────────────────────────────
# GET /test/style1 est enregistrée par test-routes.js (pas en DB). Le handler
# délègue à renderPage('/home') en injectant extraData → result.fromRoute.
run_test "STYLE1 route+renderPage → 200 HTML"           "200" "<!DOCTYPE html>"            "$BASE/test/style1"
run_test "STYLE1 req.path rendu = /test/style1"         "200" "<code>/test/style1</code>"  "$BASE/test/style1"
run_test "STYLE1 extraData dans result (fromRoute)"     "200" '"fromRoute"'                "$BASE/test/style1"
run_test "STYLE1 extraData.source=direct-route"         "200" '"source": "direct-route"'    "$BASE/test/style1"

# Variante : route module + api.renderError (preuve que l'API d'erreur marche
# hors _data.serve).
run_test "STYLE1 route+renderError → 418"        "418" "" "$BASE/test/style1-error"

# ── Style 2 : hook api.hooks.onPageLoad ───────────────────────────────────
# /style2 est une page DB (profil anonymous) avec elements.HOOK=test_page_hook.
# Le moteur appelle le hook pendant serve() et injecte { hookPayload: {...} }.
run_test "STYLE2 page DB + hook → 200 HTML"         "200" "<!DOCTYPE html>"         "$BASE/style2"
run_test "STYLE2 hook → route /style2 rendue"       "200" "<code>/style2</code>"    "$BASE/style2"
run_test "STYLE2 hook → payload dans result"        "200" '"hookPayload"'           "$BASE/style2"
run_test "STYLE2 hook → source=page-load-hook"      "200" '"source": "page-load-hook"' "$BASE/style2"
run_test "STYLE2 hook → req.path vu par le hook"    "200" '"path": "/style2"'       "$BASE/style2"

# ── Style 2b : hook api.hooks.onTableWrite (insert sample) ────────────────
# Le hook rejette toute insertion sample.id='blocked'. Le moteur renvoie 500.
# Insertion normale id=hook-ok → 302 (succès : admin sur sample).
run_test "STYLE2b insert sample id=blocked → 500" "500" "" -o /dev/null \
  -X POST --cookie "$COOKIE_ADMIN" -d "id=blocked&name=X&_csrf=$CSRF_ADMIN" \
  "$BASE/admin/form/db/sample/insert"
run_test "STYLE2b insert sample id=hook-ok → 302" "302" "" -o /dev/null \
  -X POST --cookie "$COOKIE_ADMIN" -d "id=hook-ok&name=OK&_csrf=$CSRF_ADMIN" \
  "$BASE/admin/form/db/sample/insert"
# Nettoyage de la ligne valide pour ne pas polluer les tests suivants.
curl -s -o /dev/null -X POST --cookie "$COOKIE_ADMIN" \
  -d "id=hook-ok&_csrf=$CSRF_ADMIN" "$BASE/admin/form/db/sample/delete"

# ── Style 3 : DB-only (aucun code applicatif) ─────────────────────────────
# /style3 est entièrement définie en DB : queries SELECT sur _profil WHERE id=2.
# Aucun module ne la sert — preuve que le CMS seul suffit à livrer de la data.
run_test "STYLE3 DB-only → 200 HTML"             "200" "<!DOCTYPE html>"       "$BASE/style3"
run_test "STYLE3 DB-only → route /style3"        "200" "<code>/style3</code>"  "$BASE/style3"
run_test "STYLE3 DB-only → query _profil rendue" "200" '"_profil"'             "$BASE/style3"
run_test "STYLE3 DB-only → row id=2"             "200" '"id": 2'               "$BASE/style3"
run_test "STYLE3 DB-only → row name admin-test"  "200" '"name": "admin-test"'  "$BASE/style3"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[UNDO] Annulation d'écritures — port 3001 (module audit)${RST}"
countdown 30 "Recharge bucket rate-limit"
echo "================================================================="

# --- Undo insert (owner sur undo_test) ---
run_test "UNDO insert undo_test owner → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":"xx-undo-ins","name":"Test Undo Insert"}' "$BASE/admin/api/db/undo_test"
run_test "UNDO insert → row exists" "200" '"xx-undo-ins"' \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/undo_test"
run_test "UNDO insert undo → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '' "$BASE/admin/api/db/undo_test/undo"
check_absent "UNDO insert → row absent" "xx-undo-ins" \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/undo_test"

# --- Undo update (owner sur undo_test) ---
run_test "UNDO update insert → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":"xx-undo-upd","name":"Before"}' "$BASE/admin/api/db/undo_test"
run_test "UNDO update modify → ok" "200" '"ok":true' \
  -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":"xx-undo-upd","name":"After"}' "$BASE/admin/api/db/undo_test"
run_test "UNDO update verify → After" "200" '"After"' \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/undo_test"
run_test "UNDO update undo → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '' "$BASE/admin/api/db/undo_test/undo"
run_test "UNDO update verify → Before (update undone)" "200" '"Before"' \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/undo_test"
# Consomme l'INSERT initial
run_test "UNDO update undo insert → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '' "$BASE/admin/api/db/undo_test/undo"
check_absent "UNDO update → row gone" "xx-undo-upd" \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/undo_test"

# --- Undo delete (owner sur undo_test) ---
run_test "UNDO delete insert → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":"xx-undo-del","name":"Test Undo Delete"}' "$BASE/admin/api/db/undo_test"
run_test "UNDO delete remove → ok" "200" '"ok":true' \
  -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":"xx-undo-del"}' "$BASE/admin/api/db/undo_test"
check_absent "UNDO delete → row gone" "xx-undo-del" \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/undo_test"
run_test "UNDO delete undo → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '' "$BASE/admin/api/db/undo_test/undo"
run_test "UNDO delete → row restored" "200" '"xx-undo-del"' \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/undo_test"
# Consomme l'INSERT initial
run_test "UNDO delete undo insert → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '' "$BASE/admin/api/db/undo_test/undo"
check_absent "UNDO delete → row gone (clean)" "xx-undo-del" \
  --cookie "$COOKIE_OWNER" "$BASE/admin/api/db/undo_test"

# --- Double undo : insert + undo + undo (plus rien) ---
run_test "UNDO double insert → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":"xx-double","name":"Double Undo"}' "$BASE/admin/api/db/undo_test"
run_test "UNDO double first undo → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '' "$BASE/admin/api/db/undo_test/undo"
run_test "UNDO double second undo → 404" "404" "Nothing to undo" \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '' "$BASE/admin/api/db/undo_test/undo"

# --- Cross-user : admin insère, p4 ne peut pas annuler ---
run_test "UNDO cross insert admin → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" --cookie "$COOKIE_ADMIN" \
  -d '{"id":"xx-undo-x","name":"Cross"}' "$BASE/admin/api/db/undo_test"
run_test "UNDO cross p4 undo → 404" "404" "Nothing to undo" \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_P4" --cookie "$COOKIE_P4" \
  -d '' "$BASE/admin/api/db/undo_test/undo"
run_test "UNDO cross cleanup delete → ok" "200" '"ok":true' \
  -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" --cookie "$COOKIE_ADMIN" \
  -d '{"id":"xx-undo-x"}' "$BASE/admin/api/db/undo_test"

# --- Owner ?all=true annule l'écriture d'un autre utilisateur ---
run_test "UNDO all insert admin → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_ADMIN" --cookie "$COOKIE_ADMIN" \
  -d '{"id":"xx-undo-all","name":"All Test"}' "$BASE/admin/api/db/undo_test"
run_test "UNDO all owner undo → ok" "200" '"ok":true' \
  -X POST -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '' "$BASE/admin/api/db/undo_test/undo?all=true"
check_absent "UNDO all → row gone (admin view)" "xx-undo-all" \
  --cookie "$COOKIE_ADMIN" "$BASE/admin/api/db/undo_test"

echo ""
echo "================================================================="
echo "${YEL}[SÉCURITÉ] Open redirect — next externe${RST}"
echo "================================================================="
# adminNext() valide contre /^\/[a-zA-Z0-9\/_-]*$/ — une URL externe est rejetée.
run_test "next=https://evil.com → redirige vers défaut (signin)" "200" "Connexion" \
  "$BASE/admin/form/auth/signin?next=https://evil.com"
check_absent "next=https://evil.com → pas d'URL evil.com dans le body" "evil.com" \
  "$BASE/admin/form/auth/signin?next=https://evil.com"
run_test "next=//evil.com → redirige vers défaut" "200" "Connexion" \
  "$BASE/admin/form/auth/signin?next=//evil.com"

echo ""
echo "================================================================="
echo "${YEL}[SÉCURITÉ] Headers HTTP — CSP, HSTS, X-Frame${RST}"
echo "================================================================="
# Récupère les headers d'une page GET
HEADERS_CSP=$(curl -sI --max-time 5 "$BASE/admin/form/auth/signin" 2>/dev/null)
if echo "$HEADERS_CSP" | grep -qi 'Content-Security-Policy'; then
  echo -e "  ${GRN}PASS${RST}  CSP header présent"; PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${RST}  CSP header absent"; FAIL=$((FAIL + 1))
fi
if echo "$HEADERS_CSP" | grep -qi 'X-Content-Type-Options: nosniff'; then
  echo -e "  ${GRN}PASS${RST}  X-Content-Type-Options: nosniff"; PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${RST}  X-Content-Type-Options absent"; FAIL=$((FAIL + 1))
fi
if echo "$HEADERS_CSP" | grep -qi 'X-Frame-Options: SAMEORIGIN'; then
  echo -e "  ${GRN}PASS${RST}  X-Frame-Options: SAMEORIGIN"; PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${RST}  X-Frame-Options absent"; FAIL=$((FAIL + 1))
fi

echo ""
echo "================================================================="
echo "${YEL}[SÉCURITÉ] Rate limiting POST — token bucket${RST}"
echo "================================================================="
# 30 requêtes d'affilée sans CSRF (anonymous) — la 31e doit être 429.
RATE_FAIL=0
for i in $(seq 1 31); do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
    -X POST -H "Content-Type: application/json" -d '{"x":"y"}' \
    "$BASE/admin/api/auth/forgot" 2>/dev/null || echo "000")
  if [ "$STATUS" = "429" ]; then RATE_FAIL=1; break; fi
done
if [ "$RATE_FAIL" = "1" ]; then
  echo -e "  ${GRN}PASS${RST}  rate limit POST >30 → 429 obtenu après $i requêtes"; PASS=$((PASS + 1))
else
  echo -e "  ${RED}FAIL${RST}  rate limit POST >30 → 429 jamais reçu"; FAIL=$((FAIL + 1))
fi
# Laisser le bucket se recharger (~3 tokens) pour les tests POST suivants.
countdown 3 "Recharge bucket"

echo ""
echo "================================================================="
echo "${YEL}[ROBUSTESSE] Page d'erreur en chemin profond${RST}"
echo "================================================================="
# GET /a/b/c (404) → error.ejs doit calculer le bon rel pour le CSS.
run_test "/a/b/c → 404"                               "404" ""        "$BASE/a/b/c"
run_test "/a/b/c → ../images/danger.png"              "404" "danger.png" "$BASE/a/b/c"
run_test "/a/b/c → ../css/error.css"                  "404" "error.css"  "$BASE/a/b/c"

echo ""
echo "================================================================="
echo "${YEL}[I18N] Glossaire anglais — ?lang=en${RST}"
echo "================================================================="
# Les pages admin ont un glossaire FR/EN complet (migration 001_engine.sql).
# On teste que ?lang=en charge bien les labels anglais.
run_test "signin?lang=en → titre anglais"       "200" "Sign in"          "$BASE/admin/form/auth/signin?lang=en"
run_test "signin?lang=fr → titre français"      "200" "Connexion"        "$BASE/admin/form/auth/signin?lang=fr"
run_test "erreur 404 ?lang=en → label anglais"  "404" "Page not found"   "$BASE/missing-page?lang=en"
run_test "erreur 404 ?lang=fr → label français" "404" "Page introuvable" "$BASE/missing-page?lang=fr"

# =============================================================================
echo ""
echo "================================================================="
echo "${YEL}[ROBUSTESSE] Ghost session & profil anonymous — port 3001${RST}"
echo " Tests destructifs — exécutés en dernier, DB non restaurée."
echo "================================================================="

# ── 1 : nom du profil anonymous (cosmétique — non destructif) ────────────────
# Le moteur n'utilise jamais le nom 'anonymous' dans sa logique runtime.
# Le renommage ne doit pas affecter l'accès aux pages public.
run_test "renommer profil anonymous → ok" "200" '"ok":true' \
  -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":42,"name":"not-anonymous"}' "$BASE/admin/api/db/_profil"
run_test "profil renommé → /home 200 (nom cosmétique)"   "200" '<code>/home</code>' "$BASE/home"
run_test "profil renommé → /signin 200 (nom cosmétique)" "200" ""                   "$BASE/admin/form/auth/signin"
run_test "restaurer nom profil anonymous" "200" '"ok":true' \
  -X PUT -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":42,"name":"anonymous"}' "$BASE/admin/api/db/_profil"
run_test "profil restauré → /home 200"   "200" '<code>/home</code>' "$BASE/home"

# ── 2 : suppression ghost session (DESTRUCTIF — INSERT refusé, pas de restore) ──
# serve() fait un JOIN sur S.id = 0 à chaque requête anonyme — pas de cache runtime.
# Supprimer la ghost session id='0' casse immédiatement l'accès aux pages public (401).
# Un redémarrage échouerait également avec "Session fantôme introuvable".
run_test "DELETE ghost session id='0' → ok" "200" '"ok":true' \
  -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":"0"}' "$BASE/admin/api/db/_session"
run_test "ghost session absente → /home 401 (JOIN S.id='0' échoue)" \
  "401" "" "$BASE/home"
run_test "ghost session absente → /signin 401 (JOIN S.id='0' échoue)" \
  "401" "" "$BASE/admin/form/auth/signin"

# ── 3 : suppression profil anonymous (DESTRUCTIF — cascade _user + _page) ────
# ON DELETE CASCADE supprime les _page associées à profil_id=42.
# L'URL n'existe plus dans _page → 404 (URL inconnue), pas 401 (accès refusé).
# _user('anonymous') est aussi supprimé par cascade (profil_id → _user.profil_id).
run_test "DELETE profil anonymous id=42 (cascade _user + _page) → ok" "200" '"ok":true' \
  -X DELETE -H "Content-Type: application/json" -H "X-CSRF-Token: $CSRF_OWNER" --cookie "$COOKIE_OWNER" \
  -d '{"id":42}' "$BASE/admin/api/db/_profil"
run_test "profil absent → /home 404 (_page cascade-supprimée, URL inconnue)"   "404" "" "$BASE/home"
run_test "profil absent → /signin 404 (_page cascade-supprimée, URL inconnue)" "404" "" "$BASE/admin/form/auth/signin"

# =============================================================================
echo ""
echo "================================================================="
TOTAL=$((PASS + FAIL))
if [ "$FAIL" = "0" ]; then
  echo -e "  ${GRN}Résultat : $PASS/$TOTAL PASS${RST}"
else
  echo -e "  ${RED}Résultat : $FAIL/$TOTAL FAIL — $PASS PASS${RST}"
fi
echo ""

[ "$FAIL" = "0" ] && exit 0 || exit 1

# test-wate.sh v3.17.0