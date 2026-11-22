-- BSCS checklist transcribed from CvSU Imus student-portal screenshots supplied
-- on 2026-11-15. The screenshots do not show a curriculum revision year.
-- This is a course catalogue, not a verified faculty teaching timetable.
-- Contact hours and prerequisites are not inferred from the checklist.

DROP TEMPORARY TABLE IF EXISTS bscs_checklist_import;
CREATE TEMPORARY TABLE bscs_checklist_import (
    code VARCHAR(20) NOT NULL PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    units TINYINT UNSIGNED NOT NULL,
    year_level TINYINT UNSIGNED NOT NULL,
    semester_code VARCHAR(10) NOT NULL,
    subject_type VARCHAR(30) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO bscs_checklist_import (code, title, units, year_level, semester_code, subject_type) VALUES
-- First year, first semester
('GNED 02', 'Ethics', 3, 1, 'S1', 'General Education'),
('GNED 05', 'Purposive Communication', 3, 1, 'S1', 'General Education'),
('GNED 11', 'Kontekstwalisadong Komunikasyon sa Filipino', 3, 1, 'S1', 'General Education'),
('COSC 50A', 'Discrete Structure', 3, 1, 'S1', 'Core'),
('DCIT 21A', 'Introduction to Computing', 3, 1, 'S1', 'Core'),
('DCIT 22A', 'Computer Programming 1', 3, 1, 'S1', 'Core'),
('FITT 1', 'Movement Enhancement', 2, 1, 'S1', 'PE'),
('CVSU 101', 'Institutional Orientation', 1, 1, 'S1', 'Institutional'),
('NSTP 1', 'National Service Training Program 1', 3, 1, 'S1', 'NSTP'),
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
('MATH 1A', 'Analytic Geometry', 3, 2, 'S1', 'Core'),
('COSC 55A', 'Discrete Structures 2', 3, 2, 'S1', 'Core'),
('COSC 60B', 'Digital Logic Design', 3, 2, 'S1', 'Core'),
('DCIT 50A', 'Object Oriented Programming', 3, 2, 'S1', 'Core'),
('DCIT 24A', 'Information Management', 3, 2, 'S1', 'Core'),
('INSY 50', 'Fundamentals of Information Systems', 3, 2, 'S1', 'Core'),
('FITT 3', 'Physical Activities Towards Health and Fitness 1', 2, 2, 'S1', 'PE'),
-- Second year, second semester
('GNED 08', 'Understanding the Self', 3, 2, 'S2', 'General Education'),
('GNED 14', 'Panitikang Panlipunan', 3, 2, 'S2', 'General Education'),
('MATH 2A', 'Calculus', 3, 2, 'S2', 'Core'),
('COSC 65B', 'Architecture and Organization', 3, 2, 'S2', 'Core'),
('COSC 70A', 'Software Engineering I', 3, 2, 'S2', 'Core'),
('DCIT 25A', 'Data Structures and Algorithms', 3, 2, 'S2', 'Core'),
('DCIT 55A', 'Advance Database Management System', 3, 2, 'S2', 'Core'),
('FITT 4', 'Physical Activities Towards Health and Fitness 2', 2, 2, 'S2', 'PE'),
-- Third year, first semester
('MATH 3A', 'Linear Algebra', 3, 3, 'S1', 'Core'),
('COSC 75A', 'Software Engineering II', 3, 3, 'S1', 'Core'),
('COSC 80B', 'Operating Systems', 3, 3, 'S1', 'Core'),
('COSC 85A', 'Networks and Communication', 3, 3, 'S1', 'Core'),
('COSC 101', 'CS Elective 1 (Computer Graphics and Visual Computing)', 3, 3, 'S1', 'Elective'),
('DCIT 26A', 'Application Dev''t and Emerging Technologies', 3, 3, 'S1', 'Core'),
('DCIT 65A', 'Social and Professional Issues', 3, 3, 'S1', 'Core'),
-- Third year, second semester
('GNED 09', 'Rizal''s Life and Works', 3, 3, 'S2', 'General Education'),
('MATH 4B', 'Experimental Statistics', 3, 3, 'S2', 'Core'),
('COSC 90', 'Design and Analysis of Algorithm', 3, 3, 'S2', 'Core'),
('COSC 95', 'Programming Languages', 3, 3, 'S2', 'Core'),
('COSC 106', 'CS Elective 2 (Introduction to Game Development)', 3, 3, 'S2', 'Elective'),
('DCIT 60B', 'Methods of Research', 3, 3, 'S2', 'Core'),
('ITEC 85C', 'Information Assurance and Security', 2, 3, 'S2', 'Core'),
('GNED 10A', 'Gender and Society', 3, 3, 'S2', 'General Education'),
-- Third year, summer term
('COSC 199B', 'Practicum', 3, 3, 'SUM', 'Practicum'),
-- Fourth year, first semester
('ITEC 80D', 'Human Computer Interaction', 1, 4, 'S1', 'Core'),
('COSC 100B', 'Automata Theory and Formal Languages', 3, 4, 'S1', 'Core'),
('COSC 105', 'Intelligent Systems', 3, 4, 'S1', 'Core'),
('COSC 111B', 'CS Elective 3 (Internet of Things)', 3, 4, 'S1', 'Elective'),
('COSC 200-A', 'Undergraduate Thesis I', 3, 4, 'S1', 'Thesis'),
-- Fourth year, second semester
('GNED 07', 'The Contemporary World', 3, 4, 'S2', 'General Education'),
('COSC 110', 'Numerical and Symbolic Computation', 3, 4, 'S2', 'Core'),
('COSC 200-B', 'Undergraduate Thesis II', 3, 4, 'S2', 'Thesis');

-- Do not overwrite an existing code shared with another program. Newly
-- imported courses have unknown contact-hour splits, so both remain zero.
INSERT IGNORE INTO subjects (code, title, units, lecture_hours, lab_hours)
SELECT code, title, units, 0, 0 FROM bscs_checklist_import;

INSERT INTO program_curriculum
  (program_id, subject_id, subject_type, year_level, semester_code, is_active)
SELECT p.id, s.id, i.subject_type, i.year_level, i.semester_code, 1
FROM bscs_checklist_import i
JOIN subjects s ON s.code = i.code
JOIN programs p ON p.code = 'BSCS'
ON DUPLICATE KEY UPDATE
  subject_type = VALUES(subject_type),
  year_level = VALUES(year_level),
  semester_code = VALUES(semester_code),
  is_active = 1;

-- Retain the original demonstration subjects and teaching loads for history,
-- and leave shared BSIT catalogue links untouched.
UPDATE program_curriculum pc
JOIN programs p ON p.id = pc.program_id
JOIN subjects s ON s.id = pc.subject_id
SET pc.is_active = 0
WHERE p.code = 'BSCS' AND s.code IN ('CS101', 'CS102', 'IT101', 'CS201');

DROP TEMPORARY TABLE bscs_checklist_import;
