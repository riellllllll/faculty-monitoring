-- Retired slots keep their historical rows. Only active slots must be unique.
ALTER TABLE schedules ADD KEY idx_schedules_load (teaching_load_id);
ALTER TABLE schedules DROP INDEX uq_schedules_slot;
ALTER TABLE schedules
  ADD COLUMN active_start_time TIME
    GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN start_time ELSE NULL END) PERSISTENT,
  ADD UNIQUE KEY uq_schedules_active_slot (teaching_load_id, day_of_week, active_start_time);
