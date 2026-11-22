-- An event-specific flag must belong to the same class session as its event.
ALTER TABLE attendance_events
  ADD UNIQUE KEY uq_attendance_event_session (id, class_session_id);
ALTER TABLE attendance_flags
  DROP FOREIGN KEY fk_attendance_flags_event;
ALTER TABLE attendance_flags
  ADD CONSTRAINT fk_attendance_flags_event_session
    FOREIGN KEY (attendance_event_id, class_session_id)
    REFERENCES attendance_events (id, class_session_id)
    ON DELETE RESTRICT ON UPDATE CASCADE;
