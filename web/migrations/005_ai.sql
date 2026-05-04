/**
 * \file      (WaTE) web/migrations/005_ai.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      2026-04-29
 * \version   1.0.0
 * \brief     Page /ai — WaTE + Intelligence Artificielle.
 *
 * \details   Rubrique présentant WaTE comme plateforme idéale pour le
 *            développement web assisté par IA. 4 arguments clés, 5 prompts
 *            exemples. Texte intégral en FR et EN via _glossary.
 */

-- ── Page /ai (anonymous) ───────────────────────────────────────────────
INSERT INTO _list VALUES (500);
INSERT INTO _item VALUES (500, 'template', 'site-ai');
INSERT INTO _item VALUES (500, 'css',      'ai.css');
INSERT INTO _item VALUES (500, 'scripts',  '{"type":"text/javascript","path":"/scripts/search.js"}');
INSERT INTO _item VALUES (500, 'title',    'ai-title');
INSERT INTO _item VALUES (500, 'queries',  '');

INSERT INTO _page VALUES ('/ai',
  (SELECT p.id FROM _profil p, _user u, _session s
   WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 500);

-- ── Accès également pour les profils démo ─────────────────────────────
INSERT INTO _page VALUES ('/ai', 10, 500);
INSERT INTO _page VALUES ('/ai', 11, 500);

-- ═══════════════════════════════════════════════════════════════════════
-- FRANÇAIS
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO _glossary VALUES ('fr', 'ai-title',
  'WaTE & l''IA — La plateforme pensée pour le code généré', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-hero-title',
  'WaTE + Intelligence Artificielle', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-hero-subtitle',
  'WaTE est conçu pour que tout — pages, menus, droits, traductions, requêtes —
   soit stocké en base de données SQLite. Résultat : une IA peut générer un site
   web complet en écrivant uniquement des fichiers SQL et quelques modules JS
   de 20 lignes. Pas de framework à expliquer, pas de DSL propriétaire, pas de
   configuration YAML. Juste du SQL standard et du JavaScript simple.', 500);

-- Arguments clés
INSERT INTO _glossary VALUES ('fr', 'ai-arg1-h',
  '1. 100 % base de données', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-arg1-p',
  'Pages, menus, profils, droits d''accès, traductions, requêtes SQL : tout
   est stocké dans SQLite. Pour créer une page, l''IA écrit un INSERT. Pour
   ajouter une langue, un INSERT. Pour modifier les droits, un INSERT.
   Pas de code à recompiler, pas de cache à invalider.', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-arg2-h',
  '2. Moteur générique sans route', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-arg2-p',
  'Aucune route à coder pour les pages standards. Le moteur lit _page,
   charge les _item (template, CSS, queries), exécute les requêtes SQL,
   applique le glossaire i18n, et rend le template EJS. L''IA n''a qu''à
   peupler les tables — le moteur fait le reste.', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-arg3-h',
  '3. Modules applicatifs en 20 lignes', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-arg3-p',
  'Quand une logique métier est nécessaire, un module WaTE se résume à :
   exports.init = function(param, api) { api.app.get("/ma-route", ...) }.
   L''IA peut créer des routes API, des hooks onPageLoad, ou des filtres
   onTableWrite en quelques lignes — l''API est documentée et stable.', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-arg4-h',
  '4. Custom elements autonomes', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-arg4-p',
  'Chaque composant d''interface est un custom element auto-suffisant :
   shadow DOM, template ${attr}, CSS importé. L''IA les combine comme des
   briques LEGO. Un <wate-card>, un <wate-stack>, un <admin-row> —
   chaque brique est documentée, testée, prête à l''emploi.', 500);

-- Prompts
INSERT INTO _glossary VALUES ('fr', 'ai-prompts-title',
  'Exemples de prompts — Ce que vous pouvez demander à une IA', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-prompt1-label', 'Prompt 1 — Blog complet', 500);
INSERT INTO _glossary VALUES ('fr', 'ai-prompt1',
'Crée une migration SQL WaTE pour un blog multi-auteur. Le site doit avoir :
- Une page d''accueil listant les 10 derniers articles (titre, date, auteur, résumé)
- Une page /article?slug=xxx affichant l''article complet
- Une page /author?name=xxx listant les articles d''un auteur
- Trois profils : anonymous (lecture seule), editor (création/modification articles), admin (tous droits)
- Un module applicatif blog.js exposant une route API POST /blog/comment qui ajoute un commentaire
- Le glossaire FR/EN pour tous les labels
- Les custom elements <wate-card> pour la home et <article-view> pour le détail', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-prompt2-label', 'Prompt 2 — Route API email', 500);
INSERT INTO _glossary VALUES ('fr', 'ai-prompt2',
'Écris un module WaTE contact.js qui :
- Expose une route POST /api/contact acceptant { name, email, subject, message }
- Valide que tous les champs sont présents et non vides
- Vérifie que l''email est valide via une regex
- Utilise api.db.run pour stocker le message dans une table contact_messages
- Si le module mail est disponible, envoie une notification à admin@monsite.fr
- Retourne { ok: true } ou { error: "message" } selon le résultat
- Ajoute la migration SQL créant la table contact_messages
- Ajoute le droit _access pour le profil anonymous (insert sur contact_messages)', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-prompt3-label', 'Prompt 3 — Glossaire i18n', 500);
INSERT INTO _glossary VALUES ('fr', 'ai-prompt3',
'Génère le glossaire FR/EN complet (INSERT INTO _glossary) pour une page /about
présentant une entreprise fictive "Acme Corp". Inclus :
- Le titre de page, la meta-description
- 4 sections : Notre histoire, Notre équipe (3 membres), Nos valeurs (5 valeurs), Contact
- Le menu de navigation pour cette page (items nav-about-* avec icônes)
- Les textes doivent être réalistes, professionnels, et cohérents entre les deux langues
- Chaque entrée doit avoir un tag unique (ex: about-history-p1) et être scopée au list_id 500', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-prompt4-label', 'Prompt 4 — Custom element', 500);
INSERT INTO _glossary VALUES ('fr', 'ai-prompt4',
'Crée un custom element WaTE <product-card> qui affiche une fiche produit. Spécifications :
- Attributs : name, price, image, description, link
- Shadow DOM avec template HTML utilisant ${attr}
- CSS importé via @import dans le tagStyle
- Layout : image en haut (300x200), nom en titre, prix en orange, description en texte, lien "Voir" en bouton
- Le CSS doit utiliser les variables --wate-* du thème pour rester cohérent avec le site
- Fournir les trois fichiers : def.js, def.css, et un exemple d''utilisation en HTML', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-prompt5-label', 'Prompt 5 — Module réservation', 500);
INSERT INTO _glossary VALUES ('fr', 'ai-prompt5',
'Écris le module WaTE complet (migration SQL + module JS + vue EJS) pour un système
de réservation de créneaux horaires. Le système doit :
- Avoir une table time_slots (id, date, start_time, end_time, max_capacity)
- Avoir une table bookings (id, slot_id, user_email, created_at)
- Permettre à un utilisateur connecté de réserver un créneau (1 réservation par créneau par utilisateur)
- Afficher les créneaux disponibles pour les 7 prochains jours
- Empêcher la réservation si le créneau est complet
- Envoyer un email de confirmation si le module mail est disponible
- Le module s''appelle booking.js, exposé via mod: [''booking''] dans app.js', 500);

INSERT INTO _glossary VALUES ('fr', 'ai-conclusion',
  'WaTE réduit la surface d''apprentissage pour une IA à trois concepts simples :
   SQL pour les données, EJS pour les vues, et l''API (param, api) pour les
   modules. Pas de routing complexe, pas d''ORM, pas de gestion d''état distribuée.
   C''est la plateforme idéale pour le développement web assisté par IA en 2026.', 500);

-- ═══════════════════════════════════════════════════════════════════════
-- ENGLISH
-- ═══════════════════════════════════════════════════════════════════════

INSERT INTO _glossary VALUES ('en', 'ai-title',
  'WaTE & AI — The platform designed for generated code', 500);

INSERT INTO _glossary VALUES ('en', 'ai-hero-title',
  'WaTE + Artificial Intelligence', 500);

INSERT INTO _glossary VALUES ('en', 'ai-hero-subtitle',
  'WaTE is designed so that everything — pages, menus, permissions, translations,
   queries — lives in a SQLite database. The result: an AI can generate an entire
   website by writing only SQL files and a few 20-line JS modules. No framework to
   explain, no proprietary DSL, no YAML configuration. Just standard SQL and
   straightforward JavaScript.', 500);

INSERT INTO _glossary VALUES ('en', 'ai-arg1-h',
  '1. 100% Database-Driven', 500);

INSERT INTO _glossary VALUES ('en', 'ai-arg1-p',
  'Pages, menus, profiles, access rights, translations, SQL queries: everything
   is stored in SQLite. To create a page, the AI writes an INSERT. To add a
   language, an INSERT. To change permissions, an INSERT. No code to recompile,
   no cache to invalidate.', 500);

INSERT INTO _glossary VALUES ('en', 'ai-arg2-h',
  '2. Generic Engine — No Routes Needed', 500);

INSERT INTO _glossary VALUES ('en', 'ai-arg2-p',
  'No route to code for standard pages. The engine reads _page, loads _item
   (template, CSS, queries), runs SQL queries, applies the i18n glossary, and
   renders the EJS template. The AI only needs to populate the tables — the
   engine handles the rest.', 500);

INSERT INTO _glossary VALUES ('en', 'ai-arg3-h',
  '3. Application Modules in 20 Lines', 500);

INSERT INTO _glossary VALUES ('en', 'ai-arg3-p',
  'When business logic is needed, a WaTE module boils down to:
   exports.init = function(param, api) { api.app.get("/my-route", ...) }.
   The AI can create API routes, onPageLoad hooks, or onTableWrite filters in
   just a few lines — the API is documented and stable.', 500);

INSERT INTO _glossary VALUES ('en', 'ai-arg4-h',
  '4. Self-Contained Custom Elements', 500);

INSERT INTO _glossary VALUES ('en', 'ai-arg4-p',
  'Each UI component is a self-contained custom element: shadow DOM, ${attr}
   template, imported CSS. The AI combines them like LEGO bricks. A <wate-card>,
   a <wate-stack>, an <admin-row> — each brick is documented, tested, ready to use.', 500);

INSERT INTO _glossary VALUES ('en', 'ai-prompts-title',
  'Prompt Examples — What You Can Ask an AI', 500);

INSERT INTO _glossary VALUES ('en', 'ai-prompt1-label', 'Prompt 1 — Full Blog', 500);
INSERT INTO _glossary VALUES ('en', 'ai-prompt1',
'Create a WaTE SQL migration for a multi-author blog. The site must have:
- A home page listing the 10 most recent articles (title, date, author, summary)
- A /article?slug=xxx page displaying the full article
- A /author?name=xxx page listing articles by an author
- Three profiles: anonymous (read-only), editor (create/edit articles), admin (all rights)
- An application module blog.js exposing a POST /blog/comment API route to add a comment
- FR/EN glossary for all labels
- <wate-card> custom elements for the home page and <article-view> for the detail page', 500);

INSERT INTO _glossary VALUES ('en', 'ai-prompt2-label', 'Prompt 2 — Email API Route', 500);
INSERT INTO _glossary VALUES ('en', 'ai-prompt2',
'Write a WaTE module contact.js that:
- Exposes a POST /api/contact route accepting { name, email, subject, message }
- Validates that all fields are present and non-empty
- Checks that the email is valid via regex
- Uses api.db.run to store the message in a contact_messages table
- If the mail module is available, sends a notification to admin@mysite.com
- Returns { ok: true } or { error: "message" } based on the result
- Adds the SQL migration creating the contact_messages table
- Adds _access rights for the anonymous profile (insert on contact_messages)', 500);

INSERT INTO _glossary VALUES ('en', 'ai-prompt3-label', 'Prompt 3 — i18n Glossary', 500);
INSERT INTO _glossary VALUES ('en', 'ai-prompt3',
'Generate the complete FR/EN glossary (INSERT INTO _glossary) for an /about page
presenting a fictional company "Acme Corp". Include:
- Page title, meta description
- 4 sections: Our Story, Our Team (3 members), Our Values (5 values), Contact
- Navigation menu items for this page (nav-about-* items with icons)
- Texts must be realistic, professional, and consistent between both languages
- Each entry must have a unique tag (e.g. about-history-p1) and be scoped to list_id 500', 500);

INSERT INTO _glossary VALUES ('en', 'ai-prompt4-label', 'Prompt 4 — Custom Element', 500);
INSERT INTO _glossary VALUES ('en', 'ai-prompt4',
'Create a WaTE custom element <product-card> that displays a product card. Specifications:
- Attributes: name, price, image, description, link
- Shadow DOM with HTML template using ${attr}
- CSS imported via @import in the tagStyle
- Layout: image on top (300x200), name as title, price in orange, description as text, "View" link as button
- CSS must use --wate-* theme variables to stay consistent with the site
- Provide all three files: def.js, def.css, and an HTML usage example', 500);

INSERT INTO _glossary VALUES ('en', 'ai-prompt5-label', 'Prompt 5 — Booking Module', 500);
INSERT INTO _glossary VALUES ('en', 'ai-prompt5',
'Write the complete WaTE module (SQL migration + JS module + EJS view) for a time
slot booking system. The system must:
- Have a time_slots table (id, date, start_time, end_time, max_capacity)
- Have a bookings table (id, slot_id, user_email, created_at)
- Allow a logged-in user to book a slot (1 booking per slot per user)
- Display available slots for the next 7 days
- Prevent booking if the slot is full
- Send a confirmation email if the mail module is available
- The module is called booking.js, loaded via mod: [''booking''] in app.js', 500);

INSERT INTO _glossary VALUES ('en', 'ai-conclusion',
  'WaTE reduces the learning surface for an AI to three simple concepts:
   SQL for data, EJS for views, and the (param, api) contract for modules.
   No complex routing, no ORM, no distributed state management.
   It is the ideal platform for AI-assisted web development in 2026.', 500);

/* (WaTE) web/migrations/005_ai.sql v1.0.0 */
