-- Illustrative dashboard/report preview for the 2025-2026 second semester.
-- Never represents actual faculty attendance or approved teaching hours.
INSERT INTO report_demo_weekly
  (program_id, semester_id, week_start, scheduled_sessions, full_period_sessions, verified_hours)
SELECT p.id, sem.id, dates.week_start, dates.scheduled, dates.full_period, dates.hours
FROM (
  SELECT 'BSIT' AS program_code, '2026-01-05' AS week_start, 18 AS scheduled, 11 AS full_period, 24.50 AS hours
  UNION ALL SELECT 'BSIT','2026-01-12',18,13,27.00
  UNION ALL SELECT 'BSIT','2026-01-19',19,14,29.25
  UNION ALL SELECT 'BSIT','2026-01-26',18,12,26.50
  UNION ALL SELECT 'BSIT','2026-02-02',19,16,33.00
  UNION ALL SELECT 'BSIT','2026-02-09',20,17,35.50
  UNION ALL SELECT 'BSIT','2026-02-16',19,15,31.75
  UNION ALL SELECT 'BSIT','2026-02-23',20,18,37.00
  UNION ALL SELECT 'BSCS','2026-01-05',15,9,19.00
  UNION ALL SELECT 'BSCS','2026-01-12',15,10,21.50
  UNION ALL SELECT 'BSCS','2026-01-19',16,12,25.00
  UNION ALL SELECT 'BSCS','2026-01-26',16,11,23.00
  UNION ALL SELECT 'BSCS','2026-02-02',16,13,27.50
  UNION ALL SELECT 'BSCS','2026-02-09',17,14,29.00
  UNION ALL SELECT 'BSCS','2026-02-16',17,13,27.00
  UNION ALL SELECT 'BSCS','2026-02-23',17,15,31.50
) AS dates
JOIN programs p ON p.code = dates.program_code
JOIN semesters sem ON sem.code = 'S2'
JOIN school_years sy ON sy.id = sem.school_year_id AND sy.label = '2025-2026'
ON DUPLICATE KEY UPDATE
  scheduled_sessions = VALUES(scheduled_sessions),
  full_period_sessions = VALUES(full_period_sessions),
  verified_hours = VALUES(verified_hours);
