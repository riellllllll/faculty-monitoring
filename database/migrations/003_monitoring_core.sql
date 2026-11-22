-- =============================================================================
--  003 — MONITORING CORE
--  Evaluation cycles, the rubric, classroom observations and performance
--  summaries.
--
--  DESIGN NOTE — rubric versioning
--  `criteria` holds the master rubric. `evaluation_forms` snapshots that
--  rubric into `evaluation_form_items` for a specific cycle, so a rubric
--  revision in A.Y. 2026-2027 never rewrites the record of an observation
--  conducted in A.Y. 2025-2026.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- evaluation_cycles — a monitoring period (e.g. "A.Y. 2025-2026 2nd Sem")
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS evaluation_cycles (
    id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    name              VARCHAR(120) NOT NULL,
    cycle_type        ENUM('Classroom Observation', 'Performance Review', 'Probationary Review', 'Accreditation Review') NOT NULL DEFAULT 'Classroom Observation',
    school_year_id    BIGINT UNSIGNED NOT NULL,
    semester_id       BIGINT UNSIGNED NULL,
    start_date        DATE NOT NULL,
    end_date          DATE NOT NULL,
    status            ENUM('draft', 'open', 'closed', 'archived') NOT NULL DEFAULT 'draft',
    min_observations  TINYINT UNSIGNED NOT NULL DEFAULT 1,
    required_raters   TINYINT UNSIGNED NOT NULL DEFAULT 1,
    is_approved       TINYINT(1) NOT NULL DEFAULT 0,
    approved_by       BIGINT UNSIGNED NULL,
    approved_at       DATETIME NULL,
    created_by        BIGINT UNSIGNED NOT NULL,
    created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_evaluation_cycles_term (school_year_id, semester_id),
    KEY idx_evaluation_cycles_status (status),
    CONSTRAINT fk_evaluation_cycles_sy FOREIGN KEY (school_year_id)
        REFERENCES school_years (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_evaluation_cycles_semester FOREIGN KEY (semester_id)
        REFERENCES semesters (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_evaluation_cycles_approved_by FOREIGN KEY (approved_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_evaluation_cycles_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_evaluation_cycles_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_evaluation_cycles_raters CHECK (required_raters >= 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- rating_bands — performance bands and the recommendation each one triggers
--   Configurable so the department can raise the passing threshold without a
--   schema change.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rating_bands (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code             VARCHAR(30)  NOT NULL,
    label            VARCHAR(60)  NOT NULL,
    min_score        DECIMAL(5,2) NOT NULL,
    max_score        DECIMAL(5,2) NOT NULL,
    color_hex        VARCHAR(7)   NOT NULL DEFAULT '#6B7280',
    recommendation   VARCHAR(150) NOT NULL DEFAULT '',
    requires_action  TINYINT(1)   NOT NULL DEFAULT 0,
    sort_order       TINYINT UNSIGNED NOT NULL DEFAULT 0,
    is_active        TINYINT(1)   NOT NULL DEFAULT 1,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_rating_bands_code (code),
    KEY idx_rating_bands_range (min_score, max_score),
    CONSTRAINT chk_rating_bands_range CHECK (max_score >= min_score),
    CONSTRAINT chk_rating_bands_min CHECK (min_score >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- criteria_groups — the four competency groups of the rubric
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS criteria_groups (
    id           SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code         VARCHAR(30)  NOT NULL,
    label        VARCHAR(120) NOT NULL,
    description  VARCHAR(255) NOT NULL DEFAULT '',
    group_weight DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    sort_order   TINYINT UNSIGNED NOT NULL DEFAULT 0,
    is_active    TINYINT(1)   NOT NULL DEFAULT 1,
    created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_criteria_groups_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- criteria — individual rubric items with their weights
--   The sum of `weight` across all active criteria must equal 100.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS criteria (
    id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    group_id       SMALLINT UNSIGNED NOT NULL,
    code           VARCHAR(30)  NOT NULL,
    label          VARCHAR(200) NOT NULL,
    description    VARCHAR(255) NOT NULL DEFAULT '',
    indicator_text VARCHAR(255) NOT NULL DEFAULT '',
    weight         DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    max_score      DECIMAL(5,2) NOT NULL DEFAULT 5.00,
    sort_order     TINYINT UNSIGNED NOT NULL DEFAULT 0,
    is_active      TINYINT(1)   NOT NULL DEFAULT 1,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_criteria_code (code),
    KEY idx_criteria_group (group_id, sort_order),
    CONSTRAINT fk_criteria_group FOREIGN KEY (group_id)
        REFERENCES criteria_groups (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_criteria_weight CHECK (weight >= 0),
    CONSTRAINT chk_criteria_max_score CHECK (max_score > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- evaluation_forms — a rubric snapshot bound to one cycle
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS evaluation_forms (
    id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    cycle_id          BIGINT UNSIGNED NOT NULL,
    title             VARCHAR(150) NOT NULL,
    version           SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    rating_scale_min  DECIMAL(5,2) NOT NULL DEFAULT 1.00,
    rating_scale_max  DECIMAL(5,2) NOT NULL DEFAULT 5.00,
    instructions      TEXT NULL,
    created_by        BIGINT UNSIGNED NOT NULL,
    created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_evaluation_forms_cycle_version (cycle_id, version),
    CONSTRAINT fk_evaluation_forms_cycle FOREIGN KEY (cycle_id)
        REFERENCES evaluation_cycles (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_evaluation_forms_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_evaluation_forms_scale CHECK (rating_scale_max > rating_scale_min)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- evaluation_form_items — the frozen rubric rows of a form
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS evaluation_form_items (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    form_id          BIGINT UNSIGNED NOT NULL,
    group_label      VARCHAR(120) NOT NULL,
    criterion_code   VARCHAR(30)  NOT NULL,
    criterion_label  VARCHAR(200) NOT NULL,
    indicator_text   VARCHAR(255) NOT NULL DEFAULT '',
    weight           DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    max_score        DECIMAL(5,2) NOT NULL DEFAULT 5.00,
    sort_order       TINYINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_evaluation_form_items_code (form_id, criterion_code),
    KEY idx_evaluation_form_items_form (form_id, sort_order),
    CONSTRAINT fk_evaluation_form_items_form FOREIGN KEY (form_id)
        REFERENCES evaluation_forms (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- observations — a single monitored class session
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS observations (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    form_id          BIGINT UNSIGNED NOT NULL,
    faculty_id       BIGINT UNSIGNED NOT NULL,
    program_id       BIGINT UNSIGNED NOT NULL,
    teaching_load_id BIGINT UNSIGNED NULL,
    observed_at      DATETIME NOT NULL,
    duration_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 60,
    modality         ENUM('Face to Face', 'Online', 'Hybrid', 'Asynchronous') NOT NULL DEFAULT 'Face to Face',
    status           ENUM('draft', 'submitted', 'returned', 'approved', 'cancelled') NOT NULL DEFAULT 'draft',
    average_score    DECIMAL(6,2) NULL,
    rating_band_id   BIGINT UNSIGNED NULL,
    recommendation   VARCHAR(150) NULL,
    summary_comments TEXT NULL,
    submitted_at     DATETIME NULL,
    approved_by      BIGINT UNSIGNED NULL,
    approved_at      DATETIME NULL,
    created_by       BIGINT UNSIGNED NOT NULL,
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_observations_faculty (faculty_id, status),
    KEY idx_observations_program (program_id, status),
    KEY idx_observations_form (form_id),
    KEY idx_observations_observed_at (observed_at),
    CONSTRAINT fk_observations_form FOREIGN KEY (form_id)
        REFERENCES evaluation_forms (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_observations_faculty FOREIGN KEY (faculty_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_observations_program FOREIGN KEY (program_id)
        REFERENCES programs (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_observations_teaching_load FOREIGN KEY (teaching_load_id)
        REFERENCES teaching_loads (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_observations_band FOREIGN KEY (rating_band_id)
        REFERENCES rating_bands (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_observations_approved_by FOREIGN KEY (approved_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_observations_created_by FOREIGN KEY (created_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- observation_raters — who rates an observation (1..N; chair + coordinator)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS observation_raters (
    observation_id BIGINT UNSIGNED NOT NULL,
    rater_id      BIGINT UNSIGNED NOT NULL,
    rater_role    ENUM('primary', 'secondary') NOT NULL DEFAULT 'primary',
    assigned_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    submitted_at  DATETIME NULL,
    rater_total   DECIMAL(6,2) NULL,
    PRIMARY KEY (observation_id, rater_id),
    KEY idx_observation_raters_rater (rater_id),
    CONSTRAINT fk_observation_raters_observation FOREIGN KEY (observation_id)
        REFERENCES observations (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_observation_raters_user FOREIGN KEY (rater_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- observation_scores — one row per rater per rubric item
--   The composite FK guarantees a score can only exist for an assigned rater.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS observation_scores (
    observation_id BIGINT UNSIGNED NOT NULL,
    rater_id      BIGINT UNSIGNED NOT NULL,
    form_item_id  BIGINT UNSIGNED NOT NULL,
    score         DECIMAL(6,2) NOT NULL,
    comment       VARCHAR(500) NULL,
    PRIMARY KEY (observation_id, rater_id, form_item_id),
    KEY idx_observation_scores_item (form_item_id),
    CONSTRAINT fk_observation_scores_rater FOREIGN KEY (observation_id, rater_id)
        REFERENCES observation_raters (observation_id, rater_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_observation_scores_item FOREIGN KEY (form_item_id)
        REFERENCES evaluation_form_items (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_observation_scores_score CHECK (score >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- performance_summaries — the cycle-level score card of one faculty member
--   Intentionally denormalized: it is a snapshot, not a live derivation.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS performance_summaries (
    id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    cycle_id          BIGINT UNSIGNED NOT NULL,
    faculty_id        BIGINT UNSIGNED NOT NULL,
    program_id        BIGINT UNSIGNED NOT NULL,
    observation_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    rater_count       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    average_score     DECIMAL(6,2) NOT NULL DEFAULT 0.00,
    rating_band_id    BIGINT UNSIGNED NULL,
    recommendation    VARCHAR(150) NULL,
    rank_in_program   SMALLINT UNSIGNED NULL,
    is_finalized      TINYINT(1) NOT NULL DEFAULT 0,
    finalized_by      BIGINT UNSIGNED NULL,
    finalized_at      DATETIME NULL,
    created_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_performance_summaries (cycle_id, faculty_id),
    KEY idx_performance_summaries_program (program_id, average_score),
    KEY idx_performance_summaries_faculty (faculty_id),
    CONSTRAINT fk_performance_summaries_cycle FOREIGN KEY (cycle_id)
        REFERENCES evaluation_cycles (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_performance_summaries_faculty FOREIGN KEY (faculty_id)
        REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_performance_summaries_program FOREIGN KEY (program_id)
        REFERENCES programs (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_performance_summaries_band FOREIGN KEY (rating_band_id)
        REFERENCES rating_bands (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_performance_summaries_finalized_by FOREIGN KEY (finalized_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
