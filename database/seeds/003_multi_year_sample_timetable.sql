-- Demonstration only: multiple subjects and student year levels per faculty.
-- These are not CvSU Imus approved teaching assignments. Never count them as
-- verified attendance without replacing or confirming the real timetable.

INSERT INTO sections (id, program_id, semester_id, code, name, year_level, capacity, enrolled_count) VALUES
    (6, 2, 1, 'BSCS-2A', 'BSCS 2nd Year Section A', 2, 40, 0),
    (7, 1, 1, 'BSIT-3A', 'BSIT 3rd Year Section A', 3, 40, 0),
    (8, 1, 1, 'BSIT-3B', 'BSIT 3rd Year Section B', 3, 40, 0)
ON DUPLICATE KEY UPDATE id = id;

-- Align the original CS301 examples with the sample curriculum's Year 3.
UPDATE teaching_loads SET section_id = 7
WHERE id = 7 AND faculty_id = 2 AND subject_id = 6 AND section_id = 1;
UPDATE teaching_loads SET section_id = 8
WHERE id = 8 AND faculty_id = 3 AND subject_id = 6 AND section_id = 5;

INSERT INTO teaching_loads (id, faculty_id, subject_id, section_id, load_units, load_type, assigned_by) VALUES
    (9,  5, 4, 5, 3.0, 'Regular', 2),
    (10, 6, 6, 7, 3.0, 'Regular', 2),
    (11, 7, 1, 2, 3.0, 'Regular', 2),
    (12, 8, 5, 6, 3.0, 'Regular', 2),
    (13, 9, 5, 6, 3.0, 'Regular', 2),
    (14, 10, 1, 3, 3.0, 'Regular', 2),
    (15, 2, 4, 5, 3.0, 'Regular', 2),
    (16, 3, 1, 1, 3.0, 'Regular', 2),
    (17, 4, 5, 6, 3.0, 'Regular', 2),
    (18, 4, 1, 3, 3.0, 'Regular', 2)
ON DUPLICATE KEY UPDATE id = id;

INSERT INTO schedules
    (id, teaching_load_id, day_of_week, start_time, end_time, room_id, modality, meeting_type, source) VALUES
    (15, 9,  'Tuesday',   '13:00:00', '14:00:00', 3, 'Face to Face', 'Lecture', 'sample'),
    (16, 10, 'Monday',    '10:00:00', '11:00:00', 3, 'Face to Face', 'Lecture', 'sample'),
    (17, 11, 'Friday',    '13:00:00', '14:00:00', 3, 'Face to Face', 'Lecture', 'sample'),
    (18, 12, 'Wednesday', '08:00:00', '09:00:00', 3, 'Face to Face', 'Lecture', 'sample'),
    (19, 13, 'Monday',    '11:00:00', '12:00:00', 3, 'Face to Face', 'Lecture', 'sample'),
    (20, 14, 'Thursday',  '15:00:00', '16:00:00', 3, 'Face to Face', 'Lecture', 'sample'),
    (21, 15, 'Thursday',  '14:00:00', '15:00:00', 1, 'Face to Face', 'Lecture', 'sample'),
    (22, 16, 'Tuesday',   '11:00:00', '12:00:00', 3, 'Face to Face', 'Lecture', 'sample'),
    (23, 17, 'Wednesday', '09:00:00', '10:00:00', 3, 'Face to Face', 'Lecture', 'sample'),
    (24, 18, 'Monday',    '15:00:00', '16:00:00', 3, 'Face to Face', 'Lecture', 'sample')
ON DUPLICATE KEY UPDATE id = id;
