-- =============================================================================
--  002 — ACADEMIC STRUCTURE & TEACHING LOAD
--  Subjects, curriculum, rooms, sections, loads and class schedules.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- subjects — catalogue of course offerings
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subjects (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code          VARCHAR(20)  NOT NULL,
    title         VARCHAR(150) NOT NULL,
    description   TEXT NULL,
    units         TINYINT UNSIGNED NOT NULL DEFAULT 3,
    lecture_hours DECIMAL(4,1) NOT NULL DEFAULT 0.0,
    lab_hours     DECIMAL(4,1) NOT NULL DEFAULT 0.0,
    is_active     TINYINT(1)   NOT NULL DEFAULT 1,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_subjects_code (code),
    KEY idx_subjects_title (title),
    CONSTRAINT chk_subjects_units CHECK (units > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- program_curriculum — which subjects belong to which program
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS program_curriculum (
    program_id   BIGINT UNSIGNED NOT NULL,
    subject_id   BIGINT UNSIGNED NOT NULL,
    subject_type ENUM('Core', 'Elective', 'Laboratory', 'PE') NOT NULL DEFAULT 'Core',
    year_level   TINYINT UNSIGNED NOT NULL DEFAULT 1,
    is_active    TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (program_id, subject_id),
    KEY idx_program_curriculum_subject (subject_id),
    CONSTRAINT fk_program_curriculum_program FOREIGN KEY (program_id)
        REFERENCES programs (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_program_curriculum_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- rooms — physical and virtual classrooms
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rooms (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code       VARCHAR(20) NOT NULL,
    name       VARCHAR(100) NOT NULL,
    building   VARCHAR(100) NULL,
    capacity   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    room_type  ENUM('Lecture', 'Laboratory', 'Auditorium', 'Online') NOT NULL DEFAULT 'Lecture',
    is_active  TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_rooms_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- sections — a class offering of a subject in a term
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sections (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    program_id     BIGINT UNSIGNED NOT NULL,
    school_year_id BIGINT UNSIGNED NOT NULL,
    semester_id    BIGINT UNSIGNED NOT NULL,
    code           VARCHAR(20) NOT NULL,
    name           VARCHAR(80) NOT NULL,
    year_level     TINYINT UNSIGNED NOT NULL DEFAULT 1,
    capacity       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    enrolled_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    is_active      TINYINT(1) NOT NULL DEFAULT 1,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_sections_code (code, school_year_id, semester_id),
    KEY idx_sections_program (program_id),
    KEY idx_sections_term (school_year_id, semester_id),
    CONSTRAINT fk_sections_program FOREIGN KEY (program_id)
        REFERENCES programs (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sections_sy FOREIGN KEY (school_year_id)
        REFERENCES school_years (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sections_semester FOREIGN KEY (semester_id)
        REFERENCES semesters (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- teaching_loads — the load assignment given to a faculty member
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS teaching_loads (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    faculty_id     BIGINT UNSIGNED NOT NULL,
    subject_id     BIGINT UNSIGNED NOT NULL,
    section_id     BIGINT UNSIGNED NOT NULL,
    school_year_id BIGINT UNSIGNED NOT NULL,
    semester_id    BIGINT UNSIGNED NOT NULL,
    load_units     DECIMAL(4,1) NOT NULL DEFAULT 3.0,
    load_type      ENUM('Regular', 'Laboratory', 'Research', 'Advisorship', 'Extra') NOT NULL DEFAULT 'Regular',
    is_active      TINYINT(1) NOT NULL DEFAULT 1,
    assigned_by    BIGINT UNSIGNED NULL,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_teaching_loads (faculty_id, section_id, school_year_id, semester_id),
    KEY idx_teaching_loads_faculty (faculty_id, is_active),
    KEY idx_teaching_loads_section (section_id),
    KEY idx_teaching_loads_term (school_year_id, semester_id),
    CONSTRAINT fk_teaching_loads_faculty FOREIGN KEY (faculty_id)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_teaching_loads_subject FOREIGN KEY (subject_id)
        REFERENCES subjects (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_teaching_loads_section FOREIGN KEY (section_id)
        REFERENCES sections (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_teaching_loads_sy FOREIGN KEY (school_year_id)
        REFERENCES school_years (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_teaching_loads_semester FOREIGN KEY (semester_id)
        REFERENCES semesters (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_teaching_loads_assigned_by FOREIGN KEY (assigned_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_teaching_loads_units CHECK (load_units > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- schedules — meeting times of a teaching load
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schedules (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    teaching_load_id BIGINT UNSIGNED NOT NULL,
    day_of_week      ENUM('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday') NOT NULL,
    start_time       TIME NOT NULL,
    end_time         TIME NOT NULL,
    room_id          BIGINT UNSIGNED NULL,
    modality         ENUM('Face to Face', 'Online', 'Hybrid') NOT NULL DEFAULT 'Face to Face',
    meeting_type     ENUM('Lecture', 'Laboratory') NOT NULL DEFAULT 'Lecture',
    created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_schedules_slot (teaching_load_id, day_of_week, start_time),
    KEY idx_schedules_room (room_id, day_of_week, start_time),
    CONSTRAINT fk_schedules_teaching_load FOREIGN KEY (teaching_load_id)
        REFERENCES teaching_loads (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_schedules_room FOREIGN KEY (room_id)
        REFERENCES rooms (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_schedules_time CHECK (end_time > start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
