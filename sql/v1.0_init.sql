-- Drop table if it exists to ensure a clean state for testing
DROP TABLE IF EXISTS app_config;

-- Create a simple configuration table
CREATE TABLE app_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(100) UNIQUE NOT NULL,
    config_value VARCHAR(255) NOT NULL,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial version information
INSERT INTO app_config (config_key, config_value) VALUES ('app_version', '1.0');
INSERT INTO app_config (config_key, config_value) VALUES ('db_schema_version', '1.0');
INSERT INTO app_config (config_key, config_value) VALUES ('feature_flag_x', 'disabled');

-- Grant privileges to your test user (e.g., test_user from Rafeul's setup guide)
GRANT SELECT, INSERT, UPDATE, DELETE ON app_config TO test_user;
GRANT USAGE, SELECT ON SEQUENCE app_config_id_seq TO test_user;

\echo 'Database initialized to Version 1.0 for SimpleWebApp';