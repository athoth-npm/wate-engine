CREATE TABLE _api_key (key TEXT PRIMARY KEY, user_email TEXT NOT NULL REFERENCES _user(email) ON DELETE CASCADE, label TEXT, created_at INTEGER DEFAULT (strftime('%s', 'now')), last_used INTEGER);
INSERT INTO _access VALUES ('_api_key', 0, 'select');
INSERT INTO _access VALUES ('_api_key', 0, 'insert');
INSERT INTO _access VALUES ('_api_key', 0, 'delete');
