-- =============================================================================
--  004 — FOLLOW-UP ACTIONS, NOTIFICATIONS & AUDIT TRAIL
-- =============================================================================

-- -----------------------------------------------------------------------------
-- action_items — coaching, training and advisory items raised from a rating
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS action_items (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    faculty_id      BIGINT UNSIGNED NOT NULL,
    program_id      BIGINT UNSIGNED NOT NULL,
    cycle_id        BIGINT UNSIGNED NULL,
    observation_id  BIGINT UNSIGNED NULL,
    action_type     ENUM('Commendation', 'Coaching', 'Training', 'Advisory', 'Warning', 'Probation Recommendation') NOT NULL DEFAULT 'Advisory',
    priority        ENUM('Low', 'Medium', 'High', 'Critical') NOT NULL DEFAULT 'Medium',
    title           VARCHAR(180) NOT NULL,
    description     TEXT NULL,
    assigned_to     BIGINT UNSIGNED NULL,
    due_date        DATE NULL,
    status          ENUM('open', 'in_progress', 'completed', 'cancelled') NOT NULL DEFAULT 'open',
    resolution_notes TEXT NULL,
    resolved_by     BIGINT UNSIGNED NULL,
    resolved_at     DATETIME NULL,
    created_by      BIGINT UNSIGNED NOT NULL,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_action_items_faculty (faculty_id, status),
    KEY idx_action_items_program (program_id, status),
    KEY idx_action_items_assigned (assigned_to, status),
    KEY idx_action_items_due (due_date),
    CONSTRAINT fk_action_items_faculty FOREIGN KEY (faculty_id)
        REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_action_items_program FOREIGN KEY (program_id)
        REFERENCES programs (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_action_items_cycle FOREIGN KEY (cycle_id)
        REFERENCES evaluation_cycles (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_action_items_observation FOREIGN KEY (observation_id)
        REFERENCES observations (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_action_items_assigned_to FOREIGN KEY (assigned_to)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_action_items_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_action_items_resolved_by FOREIGN KEY (resolved_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- notifications — in-app alerts (result published, action assigned, ...)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id    BIGINT UNSIGNED NOT NULL,
    type       VARCHAR(40)  NOT NULL DEFAULT 'general',
    title      VARCHAR(180) NOT NULL,
    body       VARCHAR(500) NOT NULL DEFAULT '',
    link       VARCHAR(255) NULL,
    is_read    TINYINT(1)   NOT NULL DEFAULT 0,
    read_at    DATETIME     NULL,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_notifications_user (user_id, is_read, created_at),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- announcements — department-wide bulletins
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS announcements (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    title        VARCHAR(180) NOT NULL,
    body         TEXT NOT NULL,
    audience     ENUM('all', 'faculty', 'coordinators', 'chairperson') NOT NULL DEFAULT 'all',
    program_id   BIGINT UNSIGNED NULL,
    is_published TINYINT(1) NOT NULL DEFAULT 0,
    published_at DATETIME NULL,
    created_by   BIGINT UNSIGNED NOT NULL,
    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_announcements_program (program_id),
    KEY idx_announcements_published (is_published, published_at),
    CONSTRAINT fk_announcements_program FOREIGN KEY (program_id)
        REFERENCES programs (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_announcements_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- audit_logs — every write performed by a user (non-negotiable for a
--   monitoring system: the record must be defensible)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id     BIGINT UNSIGNED NULL,
    action      VARCHAR(60)  NOT NULL,
    entity_type VARCHAR(60)  NOT NULL DEFAULT '',
    entity_id   BIGINT UNSIGNED NULL,
    description VARCHAR(500) NOT NULL DEFAULT '',
    ip_address  VARCHAR(45)  NULL,
    user_agent  VARCHAR(255) NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_audit_logs_user (user_id, created_at),
    KEY idx_audit_logs_entity (entity_type, entity_id),
    KEY idx_audit_logs_created (created_at),
    CONSTRAINT fk_audit_logs_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- login_attempts — brute-force throttling and security reporting
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS login_attempts (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    email           VARCHAR(120) NOT NULL,
    user_id         BIGINT UNSIGNED NULL,
    ip_address      VARCHAR(45)  NULL,
    successful      TINYINT(1)   NOT NULL DEFAULT 0,
    failure_reason  VARCHAR(80)  NULL,
    attempted_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_login_attempts_email (email, attempted_at),
    KEY idx_login_attempts_ip (ip_address, attempted_at),
    CONSTRAINT fk_login_attempts_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
