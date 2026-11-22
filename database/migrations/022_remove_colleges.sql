-- The app monitors one department and never reads the college level.
ALTER TABLE departments
  DROP FOREIGN KEY fk_departments_college,
  DROP INDEX idx_departments_college,
  DROP COLUMN college_id;

DROP TABLE colleges;
