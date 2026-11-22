-- 008 — One authoritative academic term per section.
-- semesters.school_year_id defines the year; sections.semester_id defines the
-- section term; teaching_loads.section_id inherits both. Removing redundant
-- term columns prevents internally inconsistent assignments.

DROP VIEW IF EXISTS v_faculty_load;

ALTER TABLE teaching_loads
  DROP FOREIGN KEY fk_teaching_loads_sy,
  DROP FOREIGN KEY fk_teaching_loads_semester;
ALTER TABLE teaching_loads
  DROP INDEX uq_teaching_loads,
  DROP INDEX idx_teaching_loads_term,
  DROP COLUMN school_year_id,
  DROP COLUMN semester_id,
  ADD UNIQUE KEY uq_teaching_loads_assignment (faculty_id, section_id, subject_id);

ALTER TABLE sections DROP FOREIGN KEY fk_sections_sy;
ALTER TABLE sections
  DROP INDEX uq_sections_code,
  DROP INDEX idx_sections_term,
  DROP COLUMN school_year_id,
  ADD UNIQUE KEY uq_sections_code_term (code, semester_id),
  ADD KEY idx_sections_semester (semester_id);

CREATE OR REPLACE VIEW v_faculty_load AS
SELECT tl.id AS teaching_load_id, tl.faculty_id,
       CONCAT_WS(' ', u.first_name, u.middle_name, u.last_name) AS faculty_name,
       fp.rank_code, fp.department_id, sec.program_id,
       p.code AS program_code, p.name AS program_name,
       s.code AS subject_code, s.title AS subject_title, s.units,
       sec.code AS section_code, sec.name AS section_name,
       sy.label AS school_year, sem.name AS semester,
       tl.load_units, tl.load_type, tl.is_active,
       (SELECT COUNT(*) FROM schedules sc WHERE sc.teaching_load_id = tl.id) AS meeting_count,
       (SELECT COALESCE(SUM(TIME_TO_SEC(sc.end_time)-TIME_TO_SEC(sc.start_time)),0)/3600
        FROM schedules sc WHERE sc.teaching_load_id = tl.id) AS weekly_hours
FROM teaching_loads tl
JOIN users u ON u.id = tl.faculty_id
LEFT JOIN faculty_profiles fp ON fp.user_id = u.id
JOIN subjects s ON s.id = tl.subject_id
JOIN sections sec ON sec.id = tl.section_id
JOIN programs p ON p.id = sec.program_id
JOIN semesters sem ON sem.id = sec.semester_id
JOIN school_years sy ON sy.id = sem.school_year_id;
