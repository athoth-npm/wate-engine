CREATE VIRTUAL TABLE _fts USING fts5(source, list_id, lang_id, tag, label);
INSERT INTO _fts(source, list_id, lang_id, tag, label) SELECT 'glossary', list_id, lang_id, tag, label FROM _glossary UNION ALL SELECT 'item', list_id, '', key, value FROM _item;
CREATE TRIGGER _fts_g_ai AFTER INSERT ON _glossary BEGIN INSERT INTO _fts(source, list_id, lang_id, tag, label) VALUES ('glossary', NEW.list_id, NEW.lang_id, NEW.tag, NEW.label); END;
CREATE TRIGGER _fts_g_au AFTER UPDATE ON _glossary BEGIN INSERT INTO _fts(_fts, source, list_id, lang_id, tag, label) VALUES ('delete', 'glossary', OLD.list_id, OLD.lang_id, OLD.tag, OLD.label); INSERT INTO _fts(source, list_id, lang_id, tag, label) VALUES ('glossary', NEW.list_id, NEW.lang_id, NEW.tag, NEW.label); END;
CREATE TRIGGER _fts_g_ad AFTER DELETE ON _glossary BEGIN INSERT INTO _fts(_fts, source, list_id, lang_id, tag, label) VALUES ('delete', 'glossary', OLD.list_id, OLD.lang_id, OLD.tag, OLD.label); END;
-- FIX v1.0.1 #169: substr(value,1,4000) limite l'index FTS5 (perf écritures)
CREATE TRIGGER _fts_i_ai AFTER INSERT ON _item BEGIN INSERT INTO _fts(source, list_id, lang_id, tag, label) VALUES ('item', NEW.list_id, '', NEW.key, substr(NEW.value, 1, 4000)); END;
CREATE TRIGGER _fts_i_au AFTER UPDATE ON _item BEGIN INSERT INTO _fts(_fts, source, list_id, lang_id, tag, label) VALUES ('delete', 'item', OLD.list_id, '', OLD.key, substr(OLD.value, 1, 4000)); INSERT INTO _fts(source, list_id, lang_id, tag, label) VALUES ('item', NEW.list_id, '', NEW.key, substr(NEW.value, 1, 4000)); END;
CREATE TRIGGER _fts_i_ad AFTER DELETE ON _item BEGIN INSERT INTO _fts(_fts, source, list_id, lang_id, tag, label) VALUES ('delete', 'item', OLD.list_id, '', OLD.key, substr(OLD.value, 1, 4000)); END;

-- Page /admin/form/search
INSERT INTO _list VALUES (108);
INSERT INTO _item VALUES (108, 'template', 'search');
INSERT INTO _item VALUES (108, 'title',    'Recherche');
INSERT INTO _page VALUES ('/admin/form/search', 0, 108);
INSERT INTO _page VALUES ('/admin/form/search', 0, 103);
INSERT INTO _page VALUES ('/admin/form/search', 0, 104);
