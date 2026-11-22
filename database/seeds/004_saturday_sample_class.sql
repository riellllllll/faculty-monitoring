-- Demonstration Saturday class for the existing Marco Dela Cruz timetable.
-- This is sample data, not a verified CvSU teaching assignment.
INSERT INTO schedules
    (teaching_load_id, day_of_week, start_time, end_time, room_id, modality, meeting_type, source)
SELECT tl.id, 'Saturday', '09:00:00', '10:00:00', r.id, 'Face to Face', 'Lecture', 'sample'
FROM teaching_loads tl
JOIN users u ON u.id = tl.faculty_id
JOIN subjects sub ON sub.id = tl.subject_id
JOIN sections sec ON sec.id = tl.section_id
JOIN rooms r ON r.code = 'ROOM-101' AND r.is_active = 1
WHERE u.employee_no = 'FAC-0002'
  AND sub.code = 'CS101'
  AND sec.code = 'BSIT-1A'
  AND NOT EXISTS (
      SELECT 1 FROM schedules sc
      JOIN teaching_loads occupied ON occupied.id = sc.teaching_load_id
      JOIN sections occupied_section ON occupied_section.id = occupied.section_id
      WHERE sc.is_active = 1
        AND occupied_section.semester_id = sec.semester_id
        AND sc.day_of_week = 'Saturday'
        AND sc.start_time < '10:00:00'
        AND sc.end_time > '09:00:00'
        AND (occupied.faculty_id = tl.faculty_id OR sc.room_id = r.id)
  )
LIMIT 1;
