-- Add a new column for a new feature (simulates schema change)
ALTER TABLE app_config ADD COLUMN IF NOT EXISTS feature_y_setting VARCHAR(50) DEFAULT 'default_value';

-- Update version information
UPDATE app_config SET config_value = '2.0', last_updated = CURRENT_TIMESTAMP WHERE config_key = 'app_version';
UPDATE app_config SET config_value = '2.0', last_updated = CURRENT_TIMESTAMP WHERE config_key = 'db_schema_version';

-- Enable a feature flag
UPDATE app_config SET config_value = 'enabled', last_updated = CURRENT_TIMESTAMP WHERE config_key = 'feature_flag_x';

-- Insert a new configuration specific to v2.0
INSERT INTO app_config (config_key, config_value) VALUES ('new_v2_parameter', 'active_from_pipeline')
ON CONFLICT (config_key) DO UPDATE SET config_value = EXCLUDED.config_value, last_updated = CURRENT_TIMESTAMP;

\echo 'Database upgraded to Version 2.0 for SimpleWebApp by Jenkins pipeline';