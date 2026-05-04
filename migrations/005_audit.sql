CREATE TABLE _audit (id INTEGER PRIMARY KEY AUTOINCREMENT, table_name TEXT NOT NULL, operation TEXT NOT NULL, record_key TEXT, old_values TEXT, new_values TEXT, user_email TEXT NOT NULL, changed_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')));
INSERT INTO _access VALUES ('_audit', 0, 'select');
