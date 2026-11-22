-- A room scan and one classroom selfie are evidence for a scheduled class.
-- Approval is a human review, not an automatic teaching-hours credit.
CREATE TABLE IF NOT EXISTS class_verifications (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    schedule_id BIGINT UNSIGNED NOT NULL,
    room_id BIGINT UNSIGNED NOT NULL,
    class_date DATE NOT NULL,
    selfie_jpeg MEDIUMBLOB NOT NULL,
    submitted_at DATETIME NOT NULL,
    status ENUM('pending', 'approved', 'rejected') NOT NULL DEFAULT 'pending',
    reviewed_by BIGINT UNSIGNED NULL,
    reviewed_at DATETIME NULL,
    review_note VARCHAR(255) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_class_verifications_schedule_date (schedule_id, class_date),
    KEY idx_class_verifications_review (status, submitted_at),
    CONSTRAINT fk_class_verifications_schedule FOREIGN KEY (schedule_id)
        REFERENCES schedules (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_class_verifications_room FOREIGN KEY (room_id)
        REFERENCES rooms (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_class_verifications_reviewer FOREIGN KEY (reviewed_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
