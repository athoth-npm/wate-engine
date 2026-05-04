/**
 * \file      (WaTE) 004_auth_token.sql
 * \author    Romain Légault
 * \copyright 2023-2026 WATE Team.
 * \date      19/04/2026
 * \version   1.0.1
 * \brief     Migration — validation de compte par email + récupération par token.
 *
 * \details   Deux flows pilotés par des tokens à usage unique :
 *              - kind='verify' : lien envoyé après signup pour activer le compte
 *                (TTL 7 jours). Tant que verified=0, /admin/form/auth/signin
 *                refuse le login avec "account-not-verified".
 *              - kind='reset'  : lien envoyé après demande "mot de passe oublié"
 *                (TTL 1h). Le POST /reset change le mot de passe puis supprime
 *                le token.
 *
 *            Dégradation sans nodemailer :
 *              - signup : _user.verified passé à 1 immédiatement (comme avant).
 *              - reset  : les routes /forgot et /reset répondent 404 — le lien
 *                UI n'est pas inséré dans la vue signin.
 *
 *            _user_token.token stocke le hash SHA-256 du token (jamais le token
 *            en clair) : si la DB fuite, les liens actifs restent inutilisables.
 *            La comparaison lors de la validation se fait en timing-safe.
 *
 *            Droits :
 *              - anonymous : insert (pour que POST /forgot puisse créer un
 *                token reset sans session). SELECT/DELETE restent owner only.
 *                La purge des tokens expirés appartient au module _mail/_auth.
 *              - owner     : select/insert/update/delete.
 */

-- =============================================================================
-- SCHÉMA
-- =============================================================================

-- Ajout du flag verified sur _user. 1 par défaut pour ne pas bloquer l'owner
-- initial (owner@wate) ni les comptes créés par migration avant cette feature.
-- Le flux signup le remettra à 0 quand un envoi mail aura réussi.
ALTER TABLE _user ADD COLUMN verified INTEGER NOT NULL DEFAULT 1;

CREATE TABLE _user_token (
  token       TEXT    PRIMARY KEY,                 -- SHA-256(token_clair) en hex
  user_email  TEXT    NOT NULL,
  kind        TEXT    NOT NULL,                    -- 'verify' | 'reset'
  expires_at  INTEGER NOT NULL,                    -- epoch seconds
  FOREIGN KEY (user_email) REFERENCES _user(email) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_user_token_email ON _user_token(user_email);
CREATE INDEX idx_user_token_exp   ON _user_token(expires_at);

-- =============================================================================
-- DROITS
-- =============================================================================

INSERT INTO _access VALUES ('_user_token', 0, 'select');
INSERT INTO _access VALUES ('_user_token', 0, 'insert');
INSERT INTO _access VALUES ('_user_token', 0, 'update');
INSERT INTO _access VALUES ('_user_token', 0, 'delete');

-- =============================================================================
-- LISTES + PAGES — forgot / reset
-- =============================================================================

INSERT INTO _list VALUES (7);    -- /admin/form/auth/forgot
INSERT INTO _list VALUES (8);    -- /admin/form/auth/reset

-- Page forgot (list_id 7).
INSERT INTO _glossary VALUES ('fr', 'btn-forgot',        'Envoyer le lien',       7);
INSERT INTO _glossary VALUES ('fr', 'btn-forgot-other',  'Retour à la connexion', 7);
INSERT INTO _glossary VALUES ('fr', 'next-forgot-other', 'signin',                7);
INSERT INTO _glossary VALUES ('fr', 'nav-forgot',        'Mot de passe oublié',   7);
INSERT INTO _glossary VALUES ('fr', 'forgot-sent',       'Si un compte existe pour cette adresse, un lien de réinitialisation vient d''être envoyé.', 7);
INSERT INTO _glossary VALUES ('en', 'btn-forgot',        'Send link',             7);
INSERT INTO _glossary VALUES ('en', 'btn-forgot-other',  'Back to sign-in',       7);
INSERT INTO _glossary VALUES ('en', 'next-forgot-other', 'signin',                7);
INSERT INTO _glossary VALUES ('en', 'nav-forgot',        'Forgot password',       7);
INSERT INTO _glossary VALUES ('en', 'forgot-sent',       'If an account exists for this address, a reset link has just been sent.', 7);

-- Page reset (list_id 8).
INSERT INTO _glossary VALUES ('fr', 'btn-reset',        'Valider le nouveau mot de passe', 8);
INSERT INTO _glossary VALUES ('fr', 'btn-reset-other',  'Retour à la connexion', 8);
INSERT INTO _glossary VALUES ('fr', 'next-reset-other', 'signin',                8);
INSERT INTO _glossary VALUES ('fr', 'nav-reset',        'Nouveau mot de passe',  8);
INSERT INTO _glossary VALUES ('fr', 'reset-invalid',    'Ce lien est invalide ou a expiré. Redemandez un nouveau lien.', 8);
INSERT INTO _glossary VALUES ('en', 'btn-reset',        'Set new password',      8);
INSERT INTO _glossary VALUES ('en', 'btn-reset-other',  'Back to sign-in',       8);
INSERT INTO _glossary VALUES ('en', 'next-reset-other', 'signin',                8);
INSERT INTO _glossary VALUES ('en', 'nav-reset',        'New password',          8);
INSERT INTO _glossary VALUES ('en', 'reset-invalid',    'This link is invalid or has expired. Please request a new one.', 8);

-- Glossaire nav toujours chargé — lien « Mot de passe oublié ? » sur page signin.
INSERT INTO _glossary VALUES ('fr', 'link-forgot',      'Mot de passe oublié ?', NULL);
INSERT INTO _glossary VALUES ('en', 'link-forgot',      'Forgot password?',      NULL);

-- Messages d'erreur signin liés à la vérification.
INSERT INTO _glossary VALUES ('fr', 'account-not-verified', 'Compte non validé — vérifiez votre messagerie ou cliquez sur le lien de validation reçu par email.', NULL);
INSERT INTO _glossary VALUES ('en', 'account-not-verified', 'Account not verified — check your inbox or click the verification link sent by email.',                NULL);
INSERT INTO _glossary VALUES ('fr', 'account-verified',              'Votre compte est maintenant validé, vous pouvez vous connecter.',                                      NULL);
INSERT INTO _glossary VALUES ('en', 'account-verified',              'Your account is now verified, you can sign in.',                                                       NULL);
INSERT INTO _glossary VALUES ('fr', 'verify-resend',                 'Renvoyer le lien de vérification',                                                                    NULL);
INSERT INTO _glossary VALUES ('en', 'verify-resend',                 'Resend verification link',                                                                             NULL);
INSERT INTO _glossary VALUES ('fr', 'verify-resend-ok',              'Un nouveau lien de vérification vient d''être envoyé — vérifiez votre messagerie.',                    NULL);
INSERT INTO _glossary VALUES ('en', 'verify-resend-ok',              'A new verification link has just been sent — check your inbox.',                                      NULL);
INSERT INTO _glossary VALUES ('fr', 'verify-resend-email-required',  'Veuillez saisir votre adresse email pour recevoir un nouveau lien de vérification.',                    NULL);
INSERT INTO _glossary VALUES ('en', 'verify-resend-email-required',  'Please enter your email address to receive a new verification link.',                                 NULL);

-- Sujet + corps des emails. Le corps utilise les placeholders {url} et {ttl_h}
-- substitués par _mail.js avant l'envoi (text uniquement — pas d'HTML pour éviter
-- les problèmes de rendu et la besoin d'échapper).
INSERT INTO _glossary VALUES ('fr', 'mail-verify-subject', 'Validez votre compte WaTE',                                                                           NULL);
INSERT INTO _glossary VALUES ('fr', 'mail-verify-body',    'Bonjour,\n\nMerci pour votre inscription. Pour activer votre compte, cliquez sur le lien suivant :\n\n{url}\n\nCe lien est valable {ttl_h} heures.\n\nSi vous n''êtes pas à l''origine de cette inscription, ignorez ce message.\n\n— WaTE', NULL);
INSERT INTO _glossary VALUES ('en', 'mail-verify-subject', 'Verify your WaTE account',                                                                             NULL);
INSERT INTO _glossary VALUES ('en', 'mail-verify-body',    'Hello,\n\nThanks for signing up. To activate your account, click the link below:\n\n{url}\n\nThis link is valid for {ttl_h} hours.\n\nIf you did not request this, ignore this message.\n\n— WaTE', NULL);

INSERT INTO _glossary VALUES ('fr', 'mail-reset-subject', 'Réinitialisation de votre mot de passe WaTE',                                                          NULL);
INSERT INTO _glossary VALUES ('fr', 'mail-reset-body',    'Bonjour,\n\nUne réinitialisation de mot de passe a été demandée pour ce compte. Cliquez sur le lien suivant pour choisir un nouveau mot de passe :\n\n{url}\n\nCe lien est valable {ttl_h} heures.\n\nSi vous n''êtes pas à l''origine de cette demande, ignorez ce message — votre mot de passe actuel reste valable.\n\n— WaTE', NULL);
INSERT INTO _glossary VALUES ('en', 'mail-reset-subject', 'Reset your WaTE password',                                                                             NULL);
INSERT INTO _glossary VALUES ('en', 'mail-reset-body',    'Hello,\n\nA password reset has been requested for this account. Click the link below to choose a new password:\n\n{url}\n\nThis link is valid for {ttl_h} hours.\n\nIf you did not request this, ignore this message — your current password remains valid.\n\n— WaTE', NULL);

-- Sous-requête anonymous réutilisée (comme signin/signup).
-- _list 7 (forgot) — email seulement (pas de password). Utilise la list 106 (email).
INSERT INTO _item VALUES (7, 'title',    'Mot de passe oublié');
INSERT INTO _item VALUES (7, 'mode',     'forgot');
INSERT INTO _item VALUES (7, 'next',     '/admin/form/auth/signin');
INSERT INTO _page VALUES ('/admin/form/auth/forgot',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 7);
INSERT INTO _page VALUES ('/admin/form/auth/forgot',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 100);
INSERT INTO _page VALUES ('/admin/form/auth/forgot',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 103);
INSERT INTO _page VALUES ('/admin/form/auth/forgot',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 105);
INSERT INTO _page VALUES ('/admin/form/auth/forgot',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 106);

-- _list 8 (reset) — password + confirm, PAS d'email (pas de list 106 rattachée).
INSERT INTO _item VALUES (8, 'title',    'Nouveau mot de passe');
INSERT INTO _item VALUES (8, 'mode',     'reset');
INSERT INTO _item VALUES (8, 'next',     '/admin/form/auth/signin');
INSERT INTO _item VALUES (8, 'fields',   '{"name":"password","type":"password","mandatory":true,"order":2,"tag":"passwd"},{"name":"password_confirm","type":"password","mandatory":true,"order":3,"tag":"passwd-confirm","confirm":"password"}');
INSERT INTO _page VALUES ('/admin/form/auth/reset',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 8);
INSERT INTO _page VALUES ('/admin/form/auth/reset',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 100);
INSERT INTO _page VALUES ('/admin/form/auth/reset',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 103);
INSERT INTO _page VALUES ('/admin/form/auth/reset',
  (SELECT p.id FROM _profil p, _user u, _session s WHERE p.id = u.profil_id AND u.email = s.user_email AND s.id = '0'), 105);

-- =============================================================================
-- CONFIGURATION PAR DÉFAUT
-- =============================================================================

INSERT INTO _config VALUES ('auth.verify.ttl',  '604800');  -- 7 jours
INSERT INTO _config VALUES ('auth.reset.ttl',   '3600');    -- 1 heure
INSERT INTO _config VALUES ('mail.from',        'no-reply@localhost');
INSERT INTO _config VALUES ('mail.baseUrl',     '');        -- vide = déduit de req (req.protocol + req.get('host'))
-- SMTP : si mail.smtp.host est vide, _mail.js tente de require('nodemailer') ;
-- s'il échoue ou que la config est incomplète, le module devient no-op et
-- les flows vérification/récupération sont dégradés (cf. header _mail.js).
INSERT INTO _config VALUES ('mail.smtp.host',   '');
INSERT INTO _config VALUES ('mail.smtp.port',   '587');
INSERT INTO _config VALUES ('mail.smtp.secure', '0');       -- 1 = TLS direct, 0 = STARTTLS
INSERT INTO _config VALUES ('mail.smtp.user',   '');
INSERT INTO _config VALUES ('mail.smtp.pass',   '');

/* (WaTE) 004_auth_token.sql v1.0.1 — _list 6→7 (forgot) et 7→8 (reset) : 6 est pris par 003_stats.sql */
