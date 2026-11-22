-- Remove retired modules and fields confirmed empty and unreferenced by live flows.
ALTER TABLE users DROP COLUMN IF EXISTS avatar_url;
ALTER TABLE program_assignments
  DROP COLUMN IF EXISTS starts_on,
  DROP COLUMN IF EXISTS ends_on;
ALTER TABLE subjects DROP COLUMN IF EXISTS description;

DROP TABLE IF EXISTS announcements;
DROP TABLE IF EXISTS settings;
DELETE FROM capabilities WHERE code IN ('announcement.manage', 'settings.manage');

-- These tokens cannot be used again. Keep audit and login history intact.
DELETE FROM account_setup_tokens WHERE consumed_at IS NOT NULL OR expires_at < NOW();
DELETE FROM security_rate_limits
WHERE updated_at < DATE_SUB(NOW(), INTERVAL 2 DAY)
  AND (blocked_until IS NULL OR blocked_until < NOW());

-- Isolated illustrative aggregates. They never enter verified attendance views.
CREATE TABLE IF NOT EXISTS report_demo_weekly (
  program_id BIGINT UNSIGNED NOT NULL,
  semester_id BIGINT UNSIGNED NOT NULL,
  week_start DATE NOT NULL,
  scheduled_sessions SMALLINT UNSIGNED NOT NULL,
  full_period_sessions SMALLINT UNSIGNED NOT NULL,
  verified_hours DECIMAL(7,2) NOT NULL,
  PRIMARY KEY (program_id, semester_id, week_start),
  KEY idx_report_demo_term_week (semester_id, week_start),
  CONSTRAINT fk_report_demo_program FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE CASCADE,
  CONSTRAINT fk_report_demo_semester FOREIGN KEY (semester_id) REFERENCES semesters(id) ON DELETE CASCADE,
  CONSTRAINT chk_report_demo_sessions CHECK (full_period_sessions <= scheduled_sessions),
  CONSTRAINT chk_report_demo_hours CHECK (verified_hours >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
