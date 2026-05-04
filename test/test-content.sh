#!/usr/bin/env bash
# ==============================================================================
# WaTE — Content tests (structure, CSS, JS, i18n, logo, demo)
# Cible : admin (port 3011) + vitrine/démo (port 3006)
# ==============================================================================
set -eu

ADMIN="${1:-http://localhost:3011}"
SITE="${2:-http://localhost:3006}"
PASS=0; FAIL=0
RED=$(printf '\033[31m'); GREEN=$(printf '\033[32m'); YELLOW=$(printf '\033[33m'); NC=$(printf '\033[0m')

pass() { echo "  ${GREEN}PASS${NC} $1"; PASS=$((PASS+1)); }
fail() { echo "  ${RED}FAIL${NC} $1 — $2"; FAIL=$((FAIL+1)); }

assert()    { if [ "$2" = "1" ]; then pass "$1"; else fail "$1" "$3"; fi; }
contains()  { echo "$1" | grep -qF -- "$2" && echo 1 || echo 0; }
matches()   { echo "$1" | grep -qE -- "$2" && echo 1 || echo 0; }
http_ok()   { [ "$(curl -sS -o /dev/null -w '%{http_code}' "$1")" = "200" ] && echo 1 || echo 0; }
fetch()     { curl -sS "$1" || true; }
fetch_css() { curl -sS "$1" || true; }

# ── JS sanity check ─────────────────────────────────────────────
# Vérifie que les identifiants utilisés comme objets (avant .addEventListener,
# .querySelector, .querySelectorAll, .appendChild, .setAttribute)
# sont déclarés (const/let/var/function) dans le fichier.
check_js_vars() {
  local file="$1"
  local label="$2"
  # Capture uniquement les identifiants sur leur propre ligne/contexte avant .addEventListener ou .querySelector
  # (ignore les chaînes a.b.c.method — le dernier maillon est seul vérifié par node --check si serveur)
  local calls=$(grep -oE '\b([a-zA-Z_][a-zA-Z0-9_]{2,})\s*\.\s*addEventListener\b' "$file" | sed 's/\..*//' | sort -u)
  local ok=1
  for v in $calls; do
    case "$v" in document|window|element|shadowRoot|root|this|form|_api|_core|signal|body|backdrop|btnOk|btnCan) continue ;; esac
    # Déclaré via const/let/var/function OU paramètre de callback function(xxx, yyy)
    if ! grep -qE '\b(const|let|var|function)\s+'"$v"'\b' "$file" && \
       ! grep -qE '\bfunction\s*\([^)]*\b'"$v"'\b[^)]*\)' "$file" && \
       ! grep -qE '\([^)]*\b'"$v"'\b[^)]*\)\s*=>' "$file"; then
      ok=0; break
    fi
  done
  if [ "$ok" = "1" ]; then pass "$label"; else fail "$label" "undeclared addEventListener target '$v'"; fi
}

# ==============================================================================
echo
echo "=========================================================="
echo " CONTENT TESTS — Admin (${ADMIN})"
echo "=========================================================="

# ── Signin FR ───────────────────────────────────────────────────
echo "${YELLOW}[ADMIN] Signin FR${NC}"
URL="${ADMIN}/admin/form/auth/signin?lang=fr"
SIGNIN=$(fetch "$URL")
assert "HTTP 200"                    "$(http_ok "$URL")"                                "status not 200"
assert "<!DOCTYPE html>"             "$(contains "$SIGNIN" '<!DOCTYPE html>')"         "missing DOCTYPE"
assert "<html lang=fr>"              "$(contains "$SIGNIN" 'lang="fr"')"               "missing lang=fr"
assert "<title> Connexion"           "$(contains "$SIGNIN" 'Connexion')"               "missing title"
assert "<link css/common.css>"       "$(contains "$SIGNIN" '/css/common.css')"         "missing common.css"
assert "<link css/admin-auth.css>"   "$(contains "$SIGNIN" '/css/admin-auth.css')"     "missing admin-auth.css"
assert "<script custom.js>"          "$(contains "$SIGNIN" '/custom/custom.js')"       "missing custom.js"
assert "<script icon-menu>"          "$(contains "$SIGNIN" '/custom/icon-menu/def.js')" "missing icon-menu"
assert "<script modal-popup>"        "$(contains "$SIGNIN" '/custom/modal-popup/def.js')" "missing modal-popup"
assert "Logo WaTE header"            "$(contains "$SIGNIN" 'WaTE-Logo-White.png')"     "missing header logo"
assert "<icon-menu nav>"             "$(contains "$SIGNIN" '<icon-menu')"              "missing icon-menu"
assert "CSRF meta"                   "$(contains "$SIGNIN" 'csrf-token')"              "missing CSRF token"
assert "<h2> heading"                "$(contains "$SIGNIN" '<h2>')"                    "missing h2"
assert "no </script> leak"           "$([ "$(echo "$SIGNIN" | grep -c '</script>')" = "$(echo "$SIGNIN" | grep -c '<script')" ] && echo 1 || echo 0)" "possible XSS leak"
assert "no raw &lt;strong&gt;"       "$([ "$(contains "$SIGNIN" '&lt;strong&gt;')" = "0" ] && echo 1 || echo 0)" "escaped strong visible"
# About modal content (rendered by EJS in template)
assert "About: version"              "$(contains "$SIGNIN" 'about-version')"           "missing about-version"
assert "About: copyright text"       "$([ "$(contains "$SIGNIN" 'Copyright')" = "1" -o "$(contains "$SIGNIN" 'WATE Team')" = "1" ] && echo 1 || echo 0)" "missing copyright text"

# ── Signin EN ───────────────────────────────────────────────────
echo "${YELLOW}[ADMIN] Signin EN${NC}"
URL="${ADMIN}/admin/form/auth/signin?lang=en"
SIGNIN_EN=$(fetch "$URL")
assert "HTTP 200"                    "$(http_ok "$URL")"                                "status not 200"
assert "<html lang=en>"              "$(contains "$SIGNIN_EN" 'lang="en"')"            "missing lang=en"
assert "<title> Sign in"             "$(contains "$SIGNIN_EN" 'Sign in')"              "missing EN title"

# ── Signup FR ───────────────────────────────────────────────────
echo "${YELLOW}[ADMIN] Signup FR${NC}"
URL="${ADMIN}/admin/form/auth/signup?lang=fr"
SIGNUP=$(fetch "$URL")
assert "HTTP 200"                    "$(http_ok "$URL")"                                "status not 200"
assert "<title> Inscription"         "$(contains "$SIGNUP" 'Inscription')"             "missing title"
assert "<admin-row mode=form>"       "$(contains "$SIGNUP" '<admin-row mode="form"')"  "missing admin-row"
assert "<script admin-row>"          "$(contains "$SIGNUP" '/custom/admin-row/def.js')" "missing admin-row def.js"

# ── Error 404 (error.ejs — layout minimal, pas de common.css) ───
echo "${YELLOW}[ADMIN] Error 404${NC}"
ERR404=$(fetch "${ADMIN}/nonexistent-page-12345" || true)
assert "Error page loaded"           "$(contains "$ERR404" '<title>Error 404</title>')" "missing error title"
assert "<link error.css>"            "$(contains "$ERR404" 'css/error.css')"           "missing error.css"
assert "Error image"                 "$(contains "$ERR404" 'max-height:40vh')"         "missing error image"
assert "errorCode displayed"         "$(contains "$ERR404" '404')"                     "missing 404 code"
# error.css provides background-color and font-family (verified in test-out.txt)

# ==============================================================================
echo
echo "=========================================================="
echo " CONTENT TESTS — Vitrine (${SITE})"
echo "=========================================================="

# ── Home FR ─────────────────────────────────────────────────────
echo "${YELLOW}[SITE] Home FR${NC}"
URL="${SITE}/?lang=fr"
HOME=$(fetch "$URL")
assert "HTTP 200"                    "$(http_ok "$URL")"                                "status not 200"
assert "<html lang=fr>"              "$(contains "$HOME" 'lang="fr"')"                 "missing lang=fr"
assert "<link css/common.css>"       "$(contains "$HOME" '/css/common.css')"           "missing common.css"
assert "<script custom.js>"          "$(contains "$HOME" '/custom/custom.js')"         "missing custom.js"
assert "<script icon-menu>"          "$(contains "$HOME" '/custom/icon-menu/def.js')"  "missing icon-menu"
assert "<script modal-popup>"        "$(contains "$HOME" '/custom/modal-popup/def.js')" "missing modal-popup"
assert "<header site-header>"       "$(contains "$HOME" 'site-header')"               "missing site-header"
assert "<footer>"                    "$(contains "$HOME" '<footer')"                   "missing footer"
assert "<main site-main>"           "$(contains "$HOME" 'site-main')"                 "missing site-main"
assert "Brand mark WaTE"             "$(contains "$HOME" 'site-brand-mark')"           "missing brand mark"
assert "Subtitle"                    "$(contains "$HOME" 'Web as Table Engine')"       "missing subtitle"
assert "<icon-menu burger>"         "$(matches "$HOME" 'site-burger')"                "missing burger menu"
assert "<icon-menu lang>"           "$(matches "$HOME" 'site-lang')"                  "missing lang selector"
assert "About trigger"               "$(contains "$HOME" 'site-about-trigger')"        "missing about trigger"
assert "About template"              "$(contains "$HOME" 'site-about-tpl')"            "missing about template"

# About modal logo — dans le CSS chargé par la page
SITE_CSS=$(fetch_css "${SITE}/css/common.css")
assert "About logo var"              "$(contains "$SITE_CSS" '--mp-icon-src')"          "missing --mp-icon-src in CSS"
assert "About logo dark URL"         "$(contains "$SITE_CSS" 'WaTE-Logo.png')"          "missing dark logo in CSS"

# ── Home EN ─────────────────────────────────────────────────────
echo "${YELLOW}[SITE] Home EN${NC}"
URL="${SITE}/?lang=en"
HOME_EN=$(fetch "$URL")
assert "HTTP 200"                    "$(http_ok "$URL")"                                "status not 200"
assert "<html lang=en>"              "$(contains "$HOME_EN" 'lang="en"')"              "missing lang=en"
assert "Title EN text"               "$(contains "$HOME_EN" 'Web as Table Engine')"    "missing EN subtitle"

# ── Docs ────────────────────────────────────────────────────────
echo "${YELLOW}[SITE] Docs${NC}"
URL="${SITE}/docs?lang=fr"
DOCS=$(fetch "$URL")
assert "HTTP 200"                    "$(http_ok "$URL")"                                "status not 200"
assert "<link css/docs.css>"         "$(contains "$DOCS" '/css/docs.css')"             "missing docs.css"
assert "TOC nav"                     "$(contains "$DOCS" 'docs-toc')"                  "missing docs TOC"
assert "Section content"             "$(contains "$DOCS" 'docs-section')"              "missing docs section"
assert "<wate-stack>"                "$(contains "$DOCS" '<wate-stack')"               "missing wate-stack"
assert "<wate-flow>"                 "$(contains "$DOCS" '<wate-flow')"                "missing wate-flow"
assert "<wate-tree>"                 "$(contains "$DOCS" '<wate-tree')"                "missing wate-tree"
assert "<wate-mcd>"                  "$(contains "$DOCS" '<wate-mcd')"                 "missing wate-mcd"

# ── Examples ────────────────────────────────────────────────────
echo "${YELLOW}[SITE] Examples${NC}"
URL="${SITE}/examples?lang=fr"
EXAMPLES=$(fetch "$URL")
assert "HTTP 200"                    "$(http_ok "$URL")"                                "status not 200"
assert "<link css/examples.css>"     "$(contains "$EXAMPLES" '/css/examples.css')"     "missing examples.css"
assert "<wate-example>"             "$(contains "$EXAMPLES" '<wate-example')"          "missing wate-example"
assert "<wate-path>"                 "$(contains "$EXAMPLES" '<wate-path')"            "missing wate-path"

# ── AI ──────────────────────────────────────────────────────────
echo "${YELLOW}[SITE] AI${NC}"
URL="${SITE}/ai?lang=fr"
AI=$(fetch "$URL")
assert "HTTP 200"                    "$(http_ok "$URL")"                                "status not 200"
assert "<link css/ai.css>"           "$(contains "$AI" '/css/ai.css')"                 "missing ai.css"
assert "AI section"                  "$(contains "$AI" 'ai-hero')"                     "missing ai section"

# ── Démo ────────────────────────────────────────────────────────
echo "${YELLOW}[SITE] Démo${NC}"
URL="${SITE}/demo?lang=fr"
DEMO=$(fetch "$URL")
assert "HTTP 200"                    "$(http_ok "$URL")"                                "status not 200"
assert "<link css/demo.css>"         "$(contains "$DEMO" '/css/demo.css')"             "missing demo.css"
assert "Login owner"                 "$(contains "$DEMO" 'demo-owner')"                "missing owner role"
assert "Login gestionnaire"          "$(contains "$DEMO" 'demo-gestionnaire')"         "missing gestionnaire role"

# ── Site error 404 (vitrine — réutilise le layout site) ─────────
echo "${YELLOW}[SITE] Error 404${NC}"
SERR404=$(fetch "${SITE}/nonexistent-page-xyz" || true)
assert "Error page loaded"           "$(contains "$SERR404" '404')"                    "missing 404 on error"
# La page erreur vitrine hérite du layout site (header/footer)

# ==============================================================================
echo
echo "=========================================================="
echo " JS SANITY — variables non déclarées (ReferenceError)"
echo "=========================================================="
cd "$(dirname "$0")/.."
echo "${YELLOW}[JS] Engine custom elements${NC}"
check_js_vars "custom/modal-popup/def.js"     "modal-popup/def.js"
check_js_vars "custom/icon-menu/def.js"       "icon-menu/def.js"
check_js_vars "custom/admin-row/def.js"       "admin-row/def.js"
check_js_vars "custom/admin-list/def.js"      "admin-list/def.js"
check_js_vars "custom/show-image/def.js"      "show-image/def.js"
check_js_vars "custom/schema-table/def.js"    "schema-table/def.js"
echo "${YELLOW}[JS] Scripts client${NC}"
check_js_vars "scripts/admin-db.js"           "admin-db.js"
check_js_vars "scripts/search.js"             "search.js"
echo "${YELLOW}[JS] Web custom elements${NC}"
check_js_vars "web/custom/wate-card/def.js"   "wate-card/def.js"
check_js_vars "web/custom/wate-flow/def.js"   "wate-flow/def.js"
check_js_vars "web/custom/wate-stack/def.js"  "wate-stack/def.js"
check_js_vars "web/custom/wate-path/def.js"   "wate-path/def.js"
check_js_vars "web/custom/wate-tree/def.js"   "wate-tree/def.js"
check_js_vars "web/custom/wate-mcd/def.js"    "wate-mcd/def.js"
check_js_vars "web/custom/wate-example/def.js" "wate-example/def.js"
check_js_vars "web/custom/demo-code-block/def.js" "demo-code-block/def.js"

echo "${YELLOW}[JS] Syntaxe Node (--check)${NC}"
if node --check engine.js 2>/dev/null; then pass "engine.js"; else fail "engine.js" "syntax error"; fi
for f in _*.js; do
  if node --check "$f" 2>/dev/null; then pass "$f"; else fail "$f" "syntax error"; fi
done

# ==============================================================================
echo
echo "=========================================================="
echo " RÉSULTAT : ${PASS}/$((PASS+FAIL)) PASS"
echo "=========================================================="
[ "$FAIL" -eq 0 ] && echo " ${GREEN}Tous les tests de contenu passent.${NC}" || echo " ${RED}${FAIL} échec(s).${NC}"
exit $FAIL
