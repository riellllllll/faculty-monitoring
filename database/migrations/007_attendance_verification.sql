-- 007 — Replace the former observation/rubric model with attendance evidence.
-- A full backup of the live database must be taken before this migration.
-- Statements are repeatable because MariaDB DDL commits implicitly.

DROP VIEW IF EXISTS v_open_action_items;
DROP VIEW IF EXISTS v_program_performance;
DROP VIEW IF EXISTS v_observation_scores;
DROP VIEW IF EXISTS v_cycle_performance;
DROP TABLE IF EXISTS action_items;
DROP TABLE IF EXISTS observation_scores;
DROP TABLE IF EXISTS observation_raters;
DROP TABLE IF EXISTS performance_summaries;
DROP TABLE IF EXISTS observations;
DROP TABLE IF EXISTS evaluation_form_items;
DROP TABLE IF EXISTS evaluation_forms;
DROP TABLE IF EXISTS criteria;
DROP TABLE IF EXISTS criteria_groups;
DROP TABLE IF EXISTS rating_bands;
DROP TABLE IF EXISTS evaluation_cycles;

DELETE FROM settings WHERE setting_key IN
  ('monitoring.rubric_version', 'rating.scale', 'rating.passing_threshold',
   'observation.min_raters', 'observation.default_minutes');
DELETE FROM capabilities WHERE code IN
  ('cycle.manage', 'observation.create', 'observation.submit', 'observation.approve',
   'observation.view_own', 'observation.view_program', 'observation.view_department',
   'action_items.manage');
DELETE FROM notifications WHERE link LIKE '/observations%' OR type IN ('result','action_item');
DELETE FROM announcements WHERE body LIKE '%observation%' OR title LIKE '%observation%';
DELETE FROM audit_logs WHERE entity_type IN
  ('evaluation_cycle','evaluation_form','observation','observations','performance_summary',
   'action_item','rating_band','criterion','criteria');

UPDATE roles SET description = 'Manages accounts, schedules, rooms, QR credentials and attendance settings.' WHERE code = 'admin';
UPDATE roles SET description = 'Monitors departmental attendance and teaching hours and reviews manual entries.' WHERE code = 'chairperson';
UPDATE roles SET description = 'Maintains faculty records within the assigned program.' WHERE code = 'program_coordinator';
UPDATE roles SET description = 'Checks in and out, views own hours and requests manual time entries.' WHERE code = 'faculty';

INSERT INTO capabilities (code, description) VALUES
  ('attendance.record', 'Check in and out of own scheduled classes.'),
  ('attendance.view_own', 'View own attendance and teaching hours.'),
  ('attendance.view_department', 'View attendance across the department.'),
  ('attendance.review_manual', 'Approve or reject manual time requests.'),
  ('attendance.flag_review', 'Review and resolve suspicious attendance flags.'),
  ('room_qr.manage', 'Issue and rotate classroom QR credentials.'),
  ('geofence.manage', 'Manage campus geofence definitions.')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT IGNORE INTO role_capabilities (role_id, capability_id)
SELECT r.id, c.id FROM roles r JOIN capabilities c
  ON (r.code = 'admin' AND c.code IN
      ('attendance.record','attendance.view_own','attendance.view_department',
       'attendance.review_manual','attendance.flag_review','room_qr.manage','geofence.manage'))
  OR (r.code = 'chairperson' AND c.code IN
      ('attendance.record','attendance.view_own','attendance.view_department',
       'attendance.review_manual','attendance.flag_review','users.manage','settings.manage'))
  OR (r.code = 'program_coordinator' AND c.code IN
      ('attendance.record','attendance.view_own','faculty.manage'))
  OR (r.code = 'faculty' AND c.code IN
      ('attendance.record','attendance.view_own'));

CREATE TABLE IF NOT EXISTS campus_geofences (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(120) NOT NULL,
    center_latitude DECIMAL(10,7) NOT NULL,
    center_longitude DECIMAL(10,7) NOT NULL,
    radius_meters SMALLINT UNSIGNED NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_campus_geofences_code (code),
    CONSTRAINT chk_geofence_latitude CHECK (center_latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_geofence_longitude CHECK (center_longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_geofence_radius CHECK (radius_meters > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE rooms ADD COLUMN IF NOT EXISTS geofence_id BIGINT UNSIGNED NULL;
ALTER TABLE rooms ADD CONSTRAINT fk_rooms_geofence FOREIGN KEY (geofence_id)
    REFERENCES campus_geofences (id) ON DELETE RESTRICT ON UPDATE CASCADE;

-- Only a hash of each room token is stored. Rotation creates a new row.
CREATE TABLE IF NOT EXISTS room_qr_credentials (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    room_id BIGINT UNSIGNED NOT NULL,
    token_hash CHAR(64) NOT NULL,
    valid_from DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_until DATETIME NULL,
    revoked_at DATETIME NULL,
    created_by BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_room_qr_token_hash (token_hash),
    KEY idx_room_qr_room_validity (room_id, valid_from, valid_until),
    CONSTRAINT fk_room_qr_room FOREIGN KEY (room_id) REFERENCES rooms (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_room_qr_creator FOREIGN KEY (created_by) REFERENCES users (id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_room_qr_validity CHECK (valid_until IS NULL OR valid_until > valid_from)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A dated occurrence of a recurring schedule. Planned values are a historical
-- snapshot, so later schedule edits cannot change the attendance period.
CREATE TABLE IF NOT EXISTS class_sessions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    schedule_id BIGINT UNSIGNED NOT NULL,
    session_date DATE NOT NULL,
    planned_start_at DATETIME NOT NULL,
    planned_end_at DATETIME NOT NULL,
    planned_room_id BIGINT UNSIGNED NULL,
    status ENUM('scheduled','cancelled') NOT NULL DEFAULT 'scheduled',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_class_sessions_schedule_date (schedule_id, session_date),
    KEY idx_class_sessions_date (session_date, status),
    KEY idx_class_sessions_room (planned_room_id, planned_start_at),
    CONSTRAINT fk_class_sessions_schedule FOREIGN KEY (schedule_id) REFERENCES schedules (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_class_sessions_room FOREIGN KEY (planned_room_id) REFERENCES rooms (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_class_sessions_period CHECK (planned_end_at > planned_start_at),
    CONSTRAINT chk_class_sessions_date CHECK (DATE(planned_start_at) = session_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One accepted check-in and one accepted check-out per session. The server
-- timestamp is authoritative; device time is retained to detect mismatch.
CREATE TABLE IF NOT EXISTS attendance_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_session_id BIGINT UNSIGNED NOT NULL,
    event_type ENUM('check_in','check_out') NOT NULL,
    recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_reported_at DATETIME NULL,
    latitude DECIMAL(10,7) NULL,
    longitude DECIMAL(10,7) NULL,
    accuracy_meters DECIMAL(8,2) NULL,
    device_fingerprint_hash CHAR(64) NULL,
    status ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_attendance_events_session_type (class_session_id, event_type),
    KEY idx_attendance_events_device (device_fingerprint_hash, recorded_at),
    KEY idx_attendance_events_status (status, recorded_at),
    CONSTRAINT fk_attendance_events_session FOREIGN KEY (class_session_id)
        REFERENCES class_sessions (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_attendance_latitude CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_attendance_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_attendance_accuracy CHECK (accuracy_meters IS NULL OR accuracy_meters >= 0),
    CONSTRAINT chk_attendance_coordinates CHECK ((latitude IS NULL) = (longitude IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attendance_geofence_checks (
    attendance_event_id BIGINT UNSIGNED NOT NULL,
    geofence_id BIGINT UNSIGNED NOT NULL,
    distance_meters DECIMAL(9,2) NOT NULL,
    passed TINYINT(1) NOT NULL,
    checked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attendance_event_id),
    KEY idx_attendance_geofence (geofence_id, passed),
    CONSTRAINT fk_attendance_geofence_event FOREIGN KEY (attendance_event_id)
        REFERENCES attendance_events (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_attendance_geofence_area FOREIGN KEY (geofence_id)
        REFERENCES campus_geofences (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_attendance_distance CHECK (distance_meters >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attendance_qr_checks (
    attendance_event_id BIGINT UNSIGNED NOT NULL,
    qr_credential_id BIGINT UNSIGNED NULL,
    passed TINYINT(1) NOT NULL,
    checked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attendance_event_id),
    KEY idx_attendance_qr_credential (qr_credential_id),
    CONSTRAINT fk_attendance_qr_event FOREIGN KEY (attendance_event_id)
        REFERENCES attendance_events (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_attendance_qr_credential FOREIGN KEY (qr_credential_id)
        REFERENCES room_qr_credentials (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Store private file references, never image blobs or public URLs.
CREATE TABLE IF NOT EXISTS attendance_photos (
    attendance_event_id BIGINT UNSIGNED NOT NULL,
    storage_key VARCHAR(255) NOT NULL,
    sha256_hash CHAR(64) NOT NULL,
    captured_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attendance_event_id),
    KEY idx_attendance_photos_hash (sha256_hash),
    CONSTRAINT fk_attendance_photos_event FOREIGN KEY (attendance_event_id)
        REFERENCES attendance_events (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attendance_flags (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_session_id BIGINT UNSIGNED NOT NULL,
    attendance_event_id BIGINT UNSIGNED NULL,
    flag_code ENUM('shared_device','time_mismatch','duplicate_photo','location_mismatch','qr_mismatch','missing_evidence','other') NOT NULL,
    severity ENUM('warning','blocking') NOT NULL DEFAULT 'blocking',
    details VARCHAR(500) NOT NULL DEFAULT '',
    raised_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_by BIGINT UNSIGNED NULL,
    resolved_at DATETIME NULL,
    resolution_note VARCHAR(500) NULL,
    PRIMARY KEY (id),
    KEY idx_attendance_flags_session (class_session_id, resolved_at),
    KEY idx_attendance_flags_event (attendance_event_id),
    CONSTRAINT fk_attendance_flags_session FOREIGN KEY (class_session_id)
        REFERENCES class_sessions (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_attendance_flags_event FOREIGN KEY (attendance_event_id)
        REFERENCES attendance_events (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_attendance_flags_resolver FOREIGN KEY (resolved_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_attendance_flags_resolution CHECK
        ((resolved_at IS NULL AND resolved_by IS NULL) OR (resolved_at IS NOT NULL AND resolved_by IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS manual_time_requests (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_session_id BIGINT UNSIGNED NOT NULL,
    requested_by BIGINT UNSIGNED NOT NULL,
    proposed_start_at DATETIME NOT NULL,
    proposed_end_at DATETIME NOT NULL,
    reason TEXT NOT NULL,
    requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_manual_requests_session (class_session_id, requested_at),
    KEY idx_manual_requests_faculty (requested_by, requested_at),
    CONSTRAINT fk_manual_requests_session FOREIGN KEY (class_session_id)
        REFERENCES class_sessions (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_manual_requests_faculty FOREIGN KEY (requested_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_manual_requests_period CHECK (proposed_end_at > proposed_start_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Absence of a decision means pending. One immutable decision per request.
CREATE TABLE IF NOT EXISTS manual_time_decisions (
    manual_time_request_id BIGINT UNSIGNED NOT NULL,
    reviewed_by BIGINT UNSIGNED NOT NULL,
    decision ENUM('approved','rejected') NOT NULL,
    review_note VARCHAR(500) NOT NULL DEFAULT '',
    reviewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (manual_time_request_id),
    KEY idx_manual_decisions_reviewer (reviewed_by, reviewed_at),
    CONSTRAINT fk_manual_decisions_request FOREIGN KEY (manual_time_request_id)
        REFERENCES manual_time_requests (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_manual_decisions_reviewer FOREIGN KEY (reviewed_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A verified pair takes precedence over an approved manual request. Hours are
-- derived from evidence, capped to the scheduled period, and never stored twice.
CREATE OR REPLACE VIEW v_session_attendance AS
SELECT cs.id AS class_session_id, cs.session_date, cs.schedule_id,
       tl.faculty_id, sec.program_id, cs.planned_room_id,
       cs.planned_start_at, cs.planned_end_at,
       ci.recorded_at AS check_in_at, co.recorded_at AS check_out_at,
       mr.id AS approved_manual_request_id,
       CASE
         WHEN cs.status = 'cancelled' THEN 0
         WHEN EXISTS (SELECT 1 FROM attendance_flags af WHERE af.class_session_id = cs.id
                      AND af.severity = 'blocking' AND af.resolved_at IS NULL) THEN 0
         WHEN ci.status = 'verified' AND co.status = 'verified'
           AND ci.recorded_at < co.recorded_at
           THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(ci.recorded_at, cs.planned_start_at),
                LEAST(co.recorded_at, cs.planned_end_at)))
         WHEN mr.id IS NOT NULL THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(mr.proposed_start_at, cs.planned_start_at),
                LEAST(mr.proposed_end_at, cs.planned_end_at)))
         ELSE 0
       END AS verified_seconds,
       CASE
         WHEN cs.status = 'cancelled' OR EXISTS
           (SELECT 1 FROM attendance_flags af WHERE af.class_session_id = cs.id
            AND af.severity = 'blocking' AND af.resolved_at IS NULL) THEN 0
         WHEN ci.status = 'verified' AND co.status = 'verified'
           AND ci.recorded_at <= cs.planned_start_at AND co.recorded_at >= cs.planned_end_at THEN 1
         WHEN mr.id IS NOT NULL AND mr.proposed_start_at <= cs.planned_start_at
           AND mr.proposed_end_at >= cs.planned_end_at THEN 1
         ELSE 0
       END AS full_period_verified
FROM class_sessions cs
JOIN schedules sc ON sc.id = cs.schedule_id
JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
JOIN sections sec ON sec.id = tl.section_id
LEFT JOIN attendance_events ci ON ci.class_session_id = cs.id AND ci.event_type = 'check_in'
LEFT JOIN attendance_events co ON co.class_session_id = cs.id AND co.event_type = 'check_out'
LEFT JOIN manual_time_requests mr ON mr.class_session_id = cs.id
  AND mr.id = (SELECT MAX(mr2.id) FROM manual_time_requests mr2
               JOIN manual_time_decisions md2 ON md2.manual_time_request_id = mr2.id
               WHERE mr2.class_session_id = cs.id AND md2.decision = 'approved');

CREATE OR REPLACE VIEW v_teaching_hours AS
SELECT faculty_id, program_id, COUNT(*) AS scheduled_sessions,
       SUM(full_period_verified) AS full_period_sessions,
       ROUND(SUM(verified_seconds) / 3600, 2) AS verified_hours
FROM v_session_attendance
GROUP BY faculty_id, program_id;
