-- Preserve dated attendance when a recurring schedule is retired, and mark
-- the original demo timetable so it cannot be confused with an approved load.
ALTER TABLE schedules
  ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN source ENUM('sample','entered') NOT NULL DEFAULT 'entered';

UPDATE schedules SET source = 'sample'
WHERE id BETWEEN 1 AND 14 AND created_at = '2026-10-23 01:22:57';
