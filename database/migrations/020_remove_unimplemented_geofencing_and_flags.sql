-- Remove empty attendance features that have no application workflow yet.
-- Keep the reporting views valid, but do not credit unverified attendance events.
DROP VIEW IF EXISTS v_teaching_hours;
DROP VIEW IF EXISTS v_session_attendance;
DROP VIEW IF EXISTS v_session_evidence;
DROP VIEW IF EXISTS v_verified_attendance_events;

ALTER TABLE class_sessions
  DROP FOREIGN KEY fk_class_sessions_geofence,
  DROP COLUMN planned_geofence_id;
ALTER TABLE rooms
  DROP FOREIGN KEY fk_rooms_geofence,
  DROP COLUMN geofence_id;

DROP TABLE IF EXISTS attendance_geofence_checks;
DROP TABLE IF EXISTS attendance_flags;
DROP TABLE IF EXISTS campus_geofences;

CREATE OR REPLACE VIEW v_session_evidence AS
SELECT cs.id AS class_session_id, cs.session_date, cs.schedule_id,
       tl.faculty_id, sec.program_id, cs.planned_room_id,
       cs.planned_start_at, cs.planned_end_at, cs.status AS session_status,
       NULL AS check_in_at, NULL AS check_out_at,
       mr.id AS approved_manual_request_id,
       mr.proposed_start_at AS manual_start_at,
       mr.proposed_end_at AS manual_end_at
FROM class_sessions cs
JOIN schedules sc ON sc.id = cs.schedule_id
JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
JOIN sections sec ON sec.id = tl.section_id
LEFT JOIN manual_time_requests mr ON mr.class_session_id = cs.id
  AND mr.id = (SELECT MAX(mr2.id) FROM manual_time_requests mr2
               JOIN manual_time_decisions md2 ON md2.manual_time_request_id = mr2.id
               WHERE mr2.class_session_id = cs.id AND md2.decision = 'approved');

CREATE OR REPLACE VIEW v_session_attendance AS
SELECT e.class_session_id, e.session_date, e.schedule_id, e.faculty_id,
       e.program_id, e.planned_room_id, e.planned_start_at, e.planned_end_at,
       e.check_in_at, e.check_out_at, e.approved_manual_request_id,
       CASE
         WHEN e.session_status = 'cancelled' THEN 0
         WHEN e.approved_manual_request_id IS NOT NULL
           THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(e.manual_start_at, e.planned_start_at),
                LEAST(e.manual_end_at, e.planned_end_at)))
         ELSE 0
       END AS verified_seconds,
       CASE
         WHEN e.session_status = 'cancelled' THEN 0
         WHEN e.approved_manual_request_id IS NOT NULL
           THEN IF(e.manual_start_at <= e.planned_start_at
                   AND e.manual_end_at >= e.planned_end_at, 1, 0)
         ELSE 0
       END AS full_period_verified
FROM v_session_evidence e;

CREATE OR REPLACE VIEW v_teaching_hours AS
SELECT faculty_id, program_id, COUNT(*) AS scheduled_sessions,
       SUM(full_period_verified) AS full_period_sessions,
       ROUND(SUM(verified_seconds) / 3600, 2) AS verified_hours
FROM v_session_attendance
GROUP BY faculty_id, program_id;
