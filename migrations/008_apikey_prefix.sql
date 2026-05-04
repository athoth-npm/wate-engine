-- Ajout colonne prefix dans _api_key (clair, pour affichage + révocation)
ALTER TABLE _api_key ADD COLUMN prefix TEXT;
