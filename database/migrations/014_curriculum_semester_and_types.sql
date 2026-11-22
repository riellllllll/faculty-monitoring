-- Keep curriculum placement separate from an individual school year's semester.
-- NULL retains the existing unrestricted placement for legacy BSIT entries.
ALTER TABLE program_curriculum
  ADD COLUMN IF NOT EXISTS semester_code VARCHAR(10) NULL AFTER year_level;

ALTER TABLE program_curriculum
  MODIFY subject_type ENUM(
    'Core', 'Elective', 'Laboratory', 'PE', 'General Education',
    'NSTP', 'Institutional', 'Practicum', 'Thesis'
  ) NOT NULL DEFAULT 'Core';
