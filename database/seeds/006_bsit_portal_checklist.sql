-- BSIT checklist transcribed from the CvSU Imus screenshots supplied on
-- 2026-11-16. This is a course catalogue, not a faculty timetable.
-- Contact-hour splits and prerequisites are not inferred here.

DROP TEMPORARY TABLE IF EXISTS bsit_checklist_import;
CREATE TEMPORARY TABLE bsit_checklist_import (
    code VARCHAR(20) NOT NULL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    units TINYINT UNSIGNED NOT NULL,
    year_level TINYINT UNSIGNED NOT NULL,
    semester_code VARCHAR(10) NOT NULL,
    subject_type VARCHAR(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO bsit_checklist_import (code, title, units, year_level, semester_code, subject_type) VALUES
-- First year, first semester
('GNED 02', 'Ethics', 3, 1, 'S1', 'General Education'),
('GNED 05', 'Purposive Communication', 3, 1, 'S1', 'General Education'),
('GNED 11', 'Kontekstwalisadong Komunikasyon sa Filipino', 3, 1, 'S1', 'General Education'),
('COSC 50A', 'Discrete Structure', 3, 1, 'S1', 'Core'),
('DCIT 21A', 'Introduction to Computing', 3, 1, 'S1', 'Core'),
('DCIT 22A', 'Computer Programming 1', 3, 1, 'S1', 'Core'),
('FITT 1', 'Movement Enhancement', 2, 1, 'S1', 'PE'),
('NSTP 1', 'National Service Training Program 1', 3, 1, 'S1', 'NSTP'),
('CVSU 101', 'Institutional Orientation', 1, 1, 'S1', 'Institutional'),
-- First year, second semester
('GNED 01', 'Art Appreciation', 3, 1, 'S2', 'General Education'),
('GNED 03', 'Mathematics in the Modern World', 3, 1, 'S2', 'General Education'),
('GNED 06', 'Science, Technology and Society', 3, 1, 'S2', 'General Education'),
('GNED 12', 'Dalumat Ng/Sa Filipino', 3, 1, 'S2', 'General Education'),
('DCIT 23A', 'Computer Programming 2', 3, 1, 'S2', 'Core'),
('ITEC 50A', 'Web System and Technologies 1', 3, 1, 'S2', 'Core'),
('FITT 2', 'Fitness Exercise', 2, 1, 'S2', 'PE'),
('NSTP 2', 'National Service Training Program 2', 3, 1, 'S2', 'NSTP'),
-- Second year, first semester
('GNED 04', 'Mga Babasahin Hinggil sa Kasaysayan ng Pilipinas', 3, 2, 'S1', 'General Education'),
('GNED 07', 'The Contemporary World', 3, 2, 'S1', 'General Education'),
('GNED 10A', 'Gender and Society', 3, 2, 'S1', 'General Education'),
('GNED 14', 'Panitikang Panlipunan', 3, 2, 'S1', 'General Education'),
('ITEC 55A', 'Platform Technologies', 3, 2, 'S1', 'Core'),
('DCIT 24A', 'Information Management', 3, 2, 'S1', 'Core'),
('DCIT 50A', 'Object Oriented Programming', 3, 2, 'S1', 'Core'),
('FITT 3', 'Physical Activities Towards Health and Fitness 1', 2, 2, 'S1', 'PE'),
-- Second year, second semester
('GNED 08', 'Understanding the Self', 3, 2, 'S2', 'General Education'),
('DCIT 25A', 'Data Structures and Algorithms', 3, 2, 'S2', 'Core'),
('ITEC 60A', 'Integrated Programming and Technologies 1', 3, 2, 'S2', 'Core'),
('ITEC 65A', 'Open Source Technology', 3, 2, 'S2', 'Core'),
('DCIT 55A', 'Advanced Database Management System', 3, 2, 'S2', 'Core'),
('ITEC 70A', 'Multimedia Systems', 3, 2, 'S2', 'Core'),
('FITT 4', 'Physical Activities Towards Health and Fitness 2', 2, 2, 'S2', 'PE'),
-- Second year, summer term
('STAT 2A', 'Applied Statistics', 3, 2, 'SUM', 'Core'),
('ITEC 75A', 'System Integration and Architecture 1', 3, 2, 'SUM', 'Core'),
-- Third year, first semester
('ITEC 80A', 'Introduction to Human Computer Interaction', 3, 3, 'S1', 'Core'),
('ITEC 85A', 'Information Assurance and Security 1', 3, 3, 'S1', 'Core'),
('ITEC 90', 'Network Fundamentals', 3, 3, 'S1', 'Core'),
('INSY 55', 'System Analysis and Design', 3, 3, 'S1', 'Core'),
('DCIT 26', 'Application Development and Emerging Technologies', 3, 3, 'S1', 'Core'),
('DCIT 60A', 'Methods of Research', 3, 3, 'S1', 'Core'),
-- Third year, second semester
('GNED 09', 'Rizal''s Life and Works', 3, 3, 'S2', 'General Education'),
('ITEC 95', 'Quantitative Methods (Modeling & Simulation)', 3, 3, 'S2', 'Core'),
('ITEC 101A', 'IT Elective 1 (Human Computer Interaction 2)', 3, 3, 'S2', 'Elective'),
('ITEC 106A', 'IT Elective 2 (Web System and Technologies 2)', 3, 3, 'S2', 'Elective'),
('ITEC 100', 'Information Assurance and Security 2', 3, 3, 'S2', 'Core'),
('ITEC 105', 'Network Management', 3, 3, 'S2', 'Core'),
('ITEC 200-A', 'Capstone Project and Research 1', 3, 3, 'S2', 'Core'),
-- Fourth year, first semester
('DCIT 65A', 'Social and Professional Issues', 3, 4, 'S1', 'Core'),
('ITEC 111', 'IT Elective 3 (Integrated Programming and Technologies 2)', 3, 4, 'S1', 'Elective'),
('ITEC 116', 'IT Elective 4 (Systems Integration and Architecture 2)', 3, 4, 'S1', 'Elective'),
('ITEC 110', 'Systems Administration and Maintenance', 3, 4, 'S1', 'Core'),
('ITEC 200-B', 'Capstone Project and Research 2', 3, 4, 'S1', 'Core'),
-- Fourth year, second semester
('ITEC 199', 'Practicum (Minimum 486 Hours)', 6, 4, 'S2', 'Practicum');

-- Shared course codes already imported for BSCS remain a single subject row.
-- BSIT has its own normalized curriculum placements for those subjects.
INSERT IGNORE INTO subjects (code, title, units, lecture_hours, lab_hours)
SELECT code, title, units, 0, 0 FROM bsit_checklist_import;

INSERT INTO program_curriculum
  (program_id, subject_id, subject_type, year_level, semester_code, is_active)
SELECT p.id, s.id, i.subject_type, i.year_level, i.semester_code, 1
FROM bsit_checklist_import i
JOIN subjects s ON s.code = i.code
JOIN programs p ON p.code = 'BSIT'
ON DUPLICATE KEY UPDATE
  subject_type = VALUES(subject_type),
  year_level = VALUES(year_level),
  semester_code = VALUES(semester_code),
  is_active = 1;

-- Retire only the old BSIT demonstration curriculum links. Their subjects,
-- teaching loads, and schedules remain available as historical records.
UPDATE program_curriculum pc
JOIN programs p ON p.id = pc.program_id
JOIN subjects s ON s.id = pc.subject_id
SET pc.is_active = 0
WHERE p.code = 'BSIT' AND s.code IN ('CS101', 'CS102', 'CS301', 'IT202');

DROP TEMPORARY TABLE bsit_checklist_import;
