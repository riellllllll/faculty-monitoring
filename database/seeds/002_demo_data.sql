-- =============================================================================
--  SEED 002 — DEMONSTRATION DATA
--  A realistic single-department scenario:
--      1 Department Chairperson  +  2 Program Coordinators  +  6 Faculty
--      2 Programs (BSIT, BSCS) · 1 academic term · sample schedules
--
--  All demo accounts share the password:  Password123!
--  (bcrypt hash below — change it, or set users.must_change_password = 1,
--   before this data ever reaches a real deployment.)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ORGANISATION
-- -----------------------------------------------------------------------------
INSERT INTO departments (id, code, name) VALUES
    (1, 'DCS', 'Department of Computer Studies')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO programs (id, department_id, code, name, degree_level) VALUES
    (1, 1, 'BSIT', 'BS Information Technology', 'Undergraduate'),
    (2, 1, 'BSCS', 'BS Computer Science',     'Undergraduate')
ON DUPLICATE KEY UPDATE name = VALUES(name), degree_level = VALUES(degree_level);

INSERT INTO school_years (id, label, start_year, end_year, is_active) VALUES
    (1, '2025-2026', 2025, 2026, 1)
ON DUPLICATE KEY UPDATE label = VALUES(label);

INSERT INTO semesters (id, school_year_id, name, code, start_date, end_date, is_active) VALUES
    (1, 1, 'Second Semester', 'S2', '2026-01-05', '2026-05-29', 1),
    (2, 1, 'First Semester',  'S1', '2025-08-04', '2025-12-19', 0)
ON DUPLICATE KEY UPDATE name = VALUES(name), start_date = VALUES(start_date), end_date = VALUES(end_date);

-- -----------------------------------------------------------------------------
-- USERS
-- -----------------------------------------------------------------------------
INSERT INTO users (id, employee_no, email, password_hash, last_name, first_name, middle_name, phone, is_active, must_change_password) VALUES
    (2,  'FAC-0001', 'liza.mendoza@fms.local', '$2y$12$d4bgNf7KjrqOmDlNBsUp6ORPXUstuK46oWgG3r5kGgpI0eViPO25W', 'Mendoza',      'Liza',       'R',     '0917 111 0001', 1, 0),
    (3,  'FAC-0002', 'marco.delacruz@fms.local','$2y$12$d4bgNf7KjrqOmDlNBsUp6ORPXUstuK46oWgG3r5kGgpI0eViPO25W', 'Dela Cruz',    'Marco',      'A',     '0917 111 0002', 1, 0),
    (4,  'FAC-0003', 'jenna.bautista@fms.local','$2y$12$d4bgNf7KjrqOmDlNBsUp6ORPXUstuK46oWgG3r5kGgpI0eViPO25W', 'Bautista',     'Jenna',      'P',     '0917 111 0003', 1, 0),
    (5,  'FAC-0004', 'juan.santos@fms.local',  '$2y$12$d4bgNf7KjrqOmDlNBsUp6ORPXUstuK46oWgG3r5kGgpI0eViPO25W', 'Santos',       'Juan',       'P',     '0917 222 0001', 1, 0),
    (6,  'FAC-0005', 'maria.reyes@fms.local',  '$2y$12$d4bgNf7KjrqOmDlNBsUp6ORPXUstuK46oWgG3r5kGgpI0eViPO25W', 'Reyes',        'Maria',      'L',     '0917 222 0002', 1, 0),
    (7,  'FAC-0006', 'paulo.garcia@fms.local', '$2y$12$d4bgNf7KjrqOmDlNBsUp6ORPXUstuK46oWgG3r5kGgpI0eViPO25W', 'Garcia',       'Paulo',      'G',     '0917 222 0003', 1, 0),
    (8,  'FAC-0007', 'ana.cruz@fms.local',     '$2y$12$d4bgNf7KjrqOmDlNBsUp6ORPXUstuK46oWgG3r5kGgpI0eViPO25W', 'Cruz',         'Ana',        'T',     '0917 333 0001', 1, 0),
    (9,  'FAC-0008', 'jose.rivera@fms.local',  '$2y$12$d4bgNf7KjrqOmDlNBsUp6ORPXUstuK46oWgG3r5kGgpI0eViPO25W', 'Rivera',       'Jose',       'M',     '0917 333 0002', 1, 0),
    (10, 'FAC-0009', 'clara.ramos@fms.local',  '$2y$12$d4bgNf7KjrqOmDlNBsUp6ORPXUstuK46oWgG3r5kGgpI0eViPO25W', 'Ramos',        'Clara',      'S',     '0917 333 0003', 1, 0)
ON DUPLICATE KEY UPDATE email = VALUES(email), last_name = VALUES(last_name), first_name = VALUES(first_name);

-- Roles: the chairperson and both coordinators are also teaching faculty.
INSERT INTO user_roles (user_id, role_id, assigned_by) VALUES
    (2, 2, NULL), (2, 4, NULL),
    (3, 3, NULL), (3, 4, NULL),
    (4, 3, NULL), (4, 4, NULL),
    (5, 4, NULL), (6, 4, NULL), (7, 4, NULL),
    (8, 4, NULL), (9, 4, NULL), (10, 4, NULL)
ON DUPLICATE KEY UPDATE role_id = role_id;

-- Scope: the chairperson covers both programs; each coordinator covers one.
INSERT INTO program_assignments (id, user_id, program_id, role_id, school_year_id, is_active) VALUES
    (1,  2, 1, 2, 1, 1),
    (2,  2, 2, 2, 1, 1),
    (3,  3, 1, 3, 1, 1),
    (4,  4, 2, 3, 1, 1),
    (5,  5, 1, 4, 1, 1),
    (6,  6, 1, 4, 1, 1),
    (7,  7, 1, 4, 1, 1),
    (8,  8, 2, 4, 1, 1),
    (9,  9, 2, 4, 1, 1),
    (10, 10, 2, 4, 1, 1)
ON DUPLICATE KEY UPDATE is_active = VALUES(is_active);

INSERT INTO faculty_profiles (user_id, department_id, rank_code, employment_type, designation, field_of_specialization, hire_date, is_active) VALUES
    (2,  1, 'Professor',           'Full-time',   'Department Chairperson', 'Information Systems',  '2010-06-01', 1),
    (3,  1, 'Associate Professor', 'Full-time',   'Program Coordinator',    'Software Engineering', '2013-06-01', 1),
    (4,  1, 'Associate Professor', 'Full-time',   'Program Coordinator',    'Computer Science',      '2012-06-01', 1),
    (5,  1, 'Instructor',          'Full-time',   NULL,                     'Computer Networking',   '2019-08-01', 1),
    (6,  1, 'Assistant Professor', 'Full-time',   NULL,                     'Web Systems',           '2017-06-01', 1),
    (7,  1, 'Instructor',          'Part-time',   NULL,                     'Computer Hardware',     '2021-08-01', 1),
    (8,  1, 'Instructor',          'Full-time',   NULL,                     'Algorithms',            '2020-08-01', 1),
    (9,  1, 'Assistant Professor', 'Full-time',   NULL,                     'Data Science',          '2018-06-01', 1),
    (10, 1, 'Instructor',          'Contractual', NULL,                     'Information Security',  '2022-08-01', 1)
ON DUPLICATE KEY UPDATE rank_code = VALUES(rank_code), designation = VALUES(designation);

-- -----------------------------------------------------------------------------
-- ACADEMIC STRUCTURE
-- -----------------------------------------------------------------------------
INSERT INTO subjects (id, code, title, units, lecture_hours, lab_hours) VALUES
    (1, 'CS101', 'Introduction to Computing',          3, 3.0, 0.0),
    (2, 'CS102', 'Structured Programming',            3, 2.0, 3.0),
    (3, 'IT101', 'Computer Hardware',                 3, 1.0, 4.0),
    (4, 'IT202', 'Web Systems and Technologies',       3, 2.0, 3.0),
    (5, 'CS201', 'Discrete Structures',               3, 3.0, 0.0),
    (6, 'CS301', 'IT Project Management',             3, 3.0, 0.0)
ON DUPLICATE KEY UPDATE title = VALUES(title), units = VALUES(units);

INSERT INTO program_curriculum (program_id, subject_id, subject_type, year_level) VALUES
    (1, 1, 'Core', 1), (1, 2, 'Core', 1), (1, 4, 'Core', 2), (1, 6, 'Elective', 3),
    (2, 1, 'Core', 1), (2, 2, 'Core', 1), (2, 3, 'Core', 1), (2, 5, 'Core', 2)
ON DUPLICATE KEY UPDATE year_level = VALUES(year_level);

INSERT INTO rooms (id, code, name, building, capacity, room_type) VALUES
    (1, 'LAB-1',   'Computer Laboratory 1', 'Main Building', 40, 'Laboratory'),
    (2, 'LAB-2',   'Computer Laboratory 2', 'Main Building', 40, 'Laboratory'),
    (3, 'ROOM-101','Room 101',              'Main Building', 50, 'Lecture')
ON DUPLICATE KEY UPDATE name = VALUES(name), capacity = VALUES(capacity);

INSERT INTO sections (id, program_id, semester_id, code, name, year_level, capacity, enrolled_count) VALUES
    (1, 1, 1, 'BSIT-1A',  'BSIT 1st Year Section A', 1, 45, 38),
    (2, 1, 1, 'BSIT-1B',  'BSIT 1st Year Section B', 1, 45, 41),
    (3, 2, 1, 'BSCS-1A',  'BSCS 1st Year Section A', 1, 45, 36),
    (4, 2, 1, 'BSCS-1B',  'BSCS 1st Year Section B', 1, 45, 33),
    (5, 1, 1, 'BSIT-2A',  'BSIT 2nd Year Section A', 2, 40, 35)
ON DUPLICATE KEY UPDATE name = VALUES(name), enrolled_count = VALUES(enrolled_count);

INSERT INTO teaching_loads (id, faculty_id, subject_id, section_id, load_units, load_type, assigned_by) VALUES
    (1, 5,  1, 1, 3.0, 'Regular',   2),
    (2, 6,  2, 2, 3.0, 'Laboratory',2),
    (3, 7,  4, 5, 3.0, 'Laboratory',2),
    (4, 8,  1, 3, 3.0, 'Regular',   4),
    (5, 9,  2, 4, 3.0, 'Laboratory',4),
    (6, 10, 3, 4, 3.0, 'Laboratory',4),
    (7, 2,  6, 1, 3.0, 'Regular',   2),
    (8, 3,  6, 5, 3.0, 'Regular',   2)
ON DUPLICATE KEY UPDATE load_units = VALUES(load_units), load_type = VALUES(load_type);

INSERT INTO schedules (teaching_load_id, day_of_week, start_time, end_time, room_id, modality, meeting_type, source) VALUES
    (1, 'Monday',    '08:00:00', '09:00:00', 1, 'Face to Face', 'Lecture', 'sample'),
    (1, 'Wednesday', '08:00:00', '09:00:00', 1, 'Face to Face', 'Lecture', 'sample'),
    (2, 'Tuesday',   '10:00:00', '12:00:00', 2, 'Face to Face', 'Laboratory', 'sample'),
    (2, 'Thursday',  '10:00:00', '12:00:00', 2, 'Face to Face', 'Laboratory', 'sample'),
    (3, 'Monday',    '13:00:00', '15:00:00', 1, 'Face to Face', 'Laboratory', 'sample'),
    (3, 'Wednesday', '13:00:00', '15:00:00', 1, 'Face to Face', 'Laboratory', 'sample'),
    (4, 'Tuesday',   '08:00:00', '09:00:00', 1, 'Face to Face', 'Lecture', 'sample'),
    (4, 'Thursday',  '08:00:00', '09:00:00', 1, 'Face to Face', 'Lecture', 'sample'),
    (5, 'Friday',    '08:00:00', '10:00:00', 2, 'Face to Face', 'Laboratory', 'sample'),
    (5, 'Tuesday',   '15:00:00', '17:00:00', 2, 'Face to Face', 'Laboratory', 'sample'),
    (6, 'Wednesday', '10:00:00', '12:00:00', 2, 'Face to Face', 'Laboratory', 'sample'),
    (6, 'Friday',    '10:00:00', '12:00:00', 2, 'Face to Face', 'Laboratory', 'sample'),
    (7, 'Thursday',  '13:00:00', '14:00:00', 3, 'Face to Face', 'Lecture', 'sample'),
    (8, 'Friday',    '15:00:00', '16:00:00', 3, 'Face to Face', 'Lecture', 'sample')
ON DUPLICATE KEY UPDATE room_id = VALUES(room_id), end_time = VALUES(end_time);
