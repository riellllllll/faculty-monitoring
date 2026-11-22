-- =============================================================================
--  FACULTY MONITORING SYSTEM — FULL SCHEMA
--  Generated from database/migrations/*.sql by `php database/migrate.php --export-bundle`.
--  Import this file into phpMyAdmin to create the database from scratch.
-- =============================================================================

CREATE DATABASE IF NOT EXISTS `faculty_monitor` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `faculty_monitor`;

SET FOREIGN_KEY_CHECKS = 0;

-- 000_create_migrations_table.sql                             
-- 000 :: schema_migrations tracking table
CREATE TABLE IF NOT EXISTS schema_migrations (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    filename    VARCHAR(255) NOT NULL UNIQUE,
    checksum    CHAR(64)     NOT NULL,
    applied_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 001_core_identity_and_organization.sql                      
-- =============================================================================
--  001 — CORE IDENTITY, ORGANIZATION & ACADEMIC CALENDAR
--  Faculty Monitoring System
--  Target: MySQL 8.0+ / MariaDB 10.4+   |   Engine: InnoDB   |   utf8mb4
-- =============================================================================

-- -----------------------------------------------------------------------------
-- colleges — top-level academic unit (e.g. College of Computing)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS colleges (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code       VARCHAR(20)  NOT NULL,
    name       VARCHAR(150) NOT NULL,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_colleges_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- departments — the monitoring unit of this system (one department per install)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
    id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    college_id  BIGINT UNSIGNED NOT NULL,
    code        VARCHAR(20)  NOT NULL,
    name        VARCHAR(150) NOT NULL,
    created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_departments_code (code),
    KEY idx_departments_college (college_id),
    CONSTRAINT fk_departments_college FOREIGN KEY (college_id)
        REFERENCES colleges (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- programs — degree offerings inside a department (BSIT, BSCS, ...)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS programs (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    department_id BIGINT UNSIGNED NOT NULL,
    code          VARCHAR(20)  NOT NULL,
    name          VARCHAR(150) NOT NULL,
    degree_level  VARCHAR(60)  NOT NULL DEFAULT '',
    is_active     TINYINT(1)   NOT NULL DEFAULT 1,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_programs_code (code),
    KEY idx_programs_department (department_id),
    CONSTRAINT fk_programs_department FOREIGN KEY (department_id)
        REFERENCES departments (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- school_years — academic year labels (2025-2026)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS school_years (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    label      VARCHAR(20)     NOT NULL,
    start_year SMALLINT UNSIGNED NOT NULL,
    end_year   SMALLINT UNSIGNED NOT NULL,
    is_active  TINYINT(1)      NOT NULL DEFAULT 1,
    created_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_school_years_label (label),
    CONSTRAINT chk_school_years_range CHECK (end_year = start_year + 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- semesters — terms within an academic year
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS semesters (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    school_year_id BIGINT UNSIGNED NOT NULL,
    name           VARCHAR(40)  NOT NULL,
    code           VARCHAR(20)  NOT NULL,
    start_date     DATE         NOT NULL,
    end_date       DATE         NOT NULL,
    is_active      TINYINT(1)   NOT NULL DEFAULT 1,
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_semesters_code (school_year_id, code),
    KEY idx_semesters_sy (school_year_id),
    CONSTRAINT fk_semesters_sy FOREIGN KEY (school_year_id)
        REFERENCES school_years (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_semesters_dates CHECK (end_date >= start_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- roles — the four personas of the system
--   scope 'system'     → full access across everything
--   scope 'department' → whole department (Department Chairperson)
--   scope 'program'    → one program only (Program Coordinator)
--   scope 'self'       → own records only (Faculty)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id          SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code        VARCHAR(30) NOT NULL,
    name        VARCHAR(80) NOT NULL,
    scope       ENUM('system', 'department', 'program', 'self') NOT NULL DEFAULT 'self',
    description VARCHAR(255) NOT NULL DEFAULT '',
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_roles_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- capabilities — granular permissions granted to roles
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS capabilities (
    id          SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code        VARCHAR(60)  NOT NULL,
    description VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (id),
    UNIQUE KEY uq_capabilities_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- role_capabilities — many-to-many role → capability grants
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS role_capabilities (
    role_id       SMALLINT UNSIGNED NOT NULL,
    capability_id SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (role_id, capability_id),
    KEY idx_role_capabilities_capability (capability_id),
    CONSTRAINT fk_role_capabilities_role FOREIGN KEY (role_id)
        REFERENCES roles (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_role_capabilities_capability FOREIGN KEY (capability_id)
        REFERENCES capabilities (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- users — every human who can sign in
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    employee_no           VARCHAR(30)  NULL,
    email                 VARCHAR(120) NOT NULL,
    password_hash         VARCHAR(255) NOT NULL,
    last_name             VARCHAR(80)  NOT NULL,
    first_name            VARCHAR(80)  NOT NULL,
    middle_name           VARCHAR(80)  NULL,
    suffix                VARCHAR(20)  NULL,
    phone                 VARCHAR(30)  NULL,
    avatar_url            VARCHAR(255) NULL,
    is_active             TINYINT(1)   NOT NULL DEFAULT 1,
    must_change_password  TINYINT(1)   NOT NULL DEFAULT 0,
    failed_login_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
    locked_until          DATETIME     NULL,
    last_login_at         DATETIME     NULL,
    created_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_users_email (email),
    UNIQUE KEY uq_users_employee_no (employee_no),
    KEY idx_users_names (last_name, first_name),
    KEY idx_users_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- user_roles — a user may hold more than one role
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_roles (
    user_id     BIGINT UNSIGNED NOT NULL,
    role_id     SMALLINT UNSIGNED NOT NULL,
    assigned_by BIGINT UNSIGNED NULL,
    assigned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id),
    KEY idx_user_roles_role (role_id),
    CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_user_roles_role FOREIGN KEY (role_id)
        REFERENCES roles (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_user_roles_assigned_by FOREIGN KEY (assigned_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- program_assignments — the scope of a user inside a program
--   Chairperson  → assigned to every program in the department
--   Coordinator  → assigned to exactly one program
--   Faculty      → assigned to the program they teach in
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS program_assignments (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id        BIGINT UNSIGNED NOT NULL,
    program_id     BIGINT UNSIGNED NOT NULL,
    role_id        SMALLINT UNSIGNED NOT NULL,
    school_year_id BIGINT UNSIGNED NULL,
    starts_on      DATE NULL,
    ends_on        DATE NULL,
    is_active      TINYINT(1) NOT NULL DEFAULT 1,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_program_assignments_user (user_id, is_active),
    KEY idx_program_assignments_program (program_id, is_active),
    KEY idx_program_assignments_role (role_id),
    CONSTRAINT fk_program_assignments_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_program_assignments_program FOREIGN KEY (program_id)
        REFERENCES programs (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_program_assignments_role FOREIGN KEY (role_id)
        REFERENCES roles (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_program_assignments_sy FOREIGN KEY (school_year_id)
        REFERENCES school_years (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- faculty_profiles — employment details for users who carry the Faculty role
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS faculty_profiles (
    id                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id               BIGINT UNSIGNED NOT NULL,
    department_id         BIGINT UNSIGNED NOT NULL,
    rank_code             VARCHAR(40) NOT NULL DEFAULT 'Instructor',
    employment_type       ENUM('Full-time', 'Part-time', 'Contractual', 'Visiting') NOT NULL DEFAULT 'Full-time',
    designation           VARCHAR(80)  NULL,
    field_of_specialization VARCHAR(150) NULL,
    hire_date             DATE NULL,
    is_active             TINYINT(1)   NOT NULL DEFAULT 1,
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_faculty_profiles_user (user_id),
    KEY idx_faculty_profiles_rank (rank_code),
    KEY idx_faculty_profiles_active (is_active),
    KEY idx_faculty_profiles_department (department_id),
    CONSTRAINT fk_faculty_profiles_user FOREIGN KEY (user_id)
        REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_faculty_profiles_department FOREIGN KEY (department_id)
        REFERENCES departments (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- settings — editable system parameters (school name, rating thresholds, ...)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS settings (
    setting_key   VARCHAR(100) NOT NULL,
    setting_value TEXT NULL,
    description   VARCHAR(255) NOT NULL DEFAULT '',
    updated_by    BIGINT UNSIGNED NULL,
    updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (setting_key),
    KEY idx_settings_updated_by (updated_by),
    CONSTRAINT fk_settings_updated_by FOREIGN KEY (updated_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 002_academic_structure_and_teaching_load.sql                
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

-- 003_monitoring_core.sql                                     
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

-- 004_actions_notifications_and_audit.sql                     
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

-- 005_reporting_views.sql                                     
-- =============================================================================
--  005 — REPORTING VIEWS
--  Read-only projections consumed by the dashboard, reports and exports.
--  Keeps every report query in one place and out of the controllers.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- v_faculty_directory — the master roster of monitored faculty
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_faculty_directory AS
SELECT
    u.id                                                         AS user_id,
    u.employee_no,
    CONCAT_WS(' ', u.first_name, u.middle_name, u.last_name)      AS full_name,
    u.last_name,
    u.first_name,
    u.middle_name,
    u.email,
    u.phone,
    u.is_active,
    u.last_login_at,
    fp.id                                                        AS faculty_profile_id,
    fp.rank_code,
    fp.employment_type,
    fp.designation,
    fp.field_of_specialization,
    fp.hire_date,
    d.id                                                         AS department_id,
    d.name                                                       AS department_name,
    GROUP_CONCAT(DISTINCT p.code ORDER BY p.code SEPARATOR ', ') AS program_codes,
    COUNT(DISTINCT p.id)                                         AS program_count
FROM users u
INNER JOIN faculty_profiles fp ON fp.user_id = u.id
INNER JOIN departments d        ON d.id = fp.department_id
LEFT  JOIN program_assignments pa ON pa.user_id = u.id AND pa.is_active = 1
LEFT  JOIN programs p             ON p.id = pa.program_id
GROUP BY
    u.id, u.employee_no, u.last_name, u.first_name, u.middle_name, u.email, u.phone,
    u.is_active, u.last_login_at, fp.id, fp.rank_code, fp.employment_type, fp.designation,
    fp.field_of_specialization, fp.hire_date, d.id, d.name;

-- -----------------------------------------------------------------------------
-- v_faculty_load — teaching load with computed weekly contact hours
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_faculty_load AS
SELECT
    tl.id                                                        AS teaching_load_id,
    tl.faculty_id,
    CONCAT_WS(' ', u.first_name, u.middle_name, u.last_name)      AS faculty_name,
    fp.rank_code,
    fp.department_id,
    sec.program_id,
    p.code                                                       AS program_code,
    p.name                                                       AS program_name,
    s.code                                                       AS subject_code,
    s.title                                                      AS subject_title,
    s.units,
    sec.code                                                     AS section_code,
    sec.name                                                     AS section_name,
    sy.label                                                     AS school_year,
    sem.name                                                     AS semester,
    tl.load_units,
    tl.load_type,
    tl.is_active,
    (SELECT COUNT(*)
       FROM schedules sc
      WHERE sc.teaching_load_id = tl.id)                        AS meeting_count,
    (SELECT COALESCE(SUM(TIME_TO_SEC(sc.end_time) - TIME_TO_SEC(sc.start_time)), 0) / 3600
       FROM schedules sc
      WHERE sc.teaching_load_id = tl.id)                        AS weekly_hours
FROM teaching_loads tl
INNER JOIN users u          ON u.id = tl.faculty_id
LEFT  JOIN faculty_profiles fp ON fp.user_id = u.id
INNER JOIN subjects s       ON s.id = tl.subject_id
INNER JOIN sections sec     ON sec.id = tl.section_id
INNER JOIN programs p       ON p.id = sec.program_id
INNER JOIN school_years sy  ON sy.id = tl.school_year_id
INNER JOIN semesters sem    ON sem.id = tl.semester_id;

-- -----------------------------------------------------------------------------
-- v_cycle_performance — the cycle score card, one row per faculty per cycle
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_cycle_performance AS
SELECT
    ps.cycle_id,
    c.name                                                       AS cycle_name,
    c.cycle_type,
    c.status                                                     AS cycle_status,
    c.school_year_id,
    sy.label                                                     AS school_year,
    sem.name                                                     AS semester,
    ps.faculty_id,
    u.employee_no,
    CONCAT_WS(' ', u.first_name, u.middle_name, u.last_name)      AS faculty_name,
    fp.rank_code,
    ps.program_id,
    p.code                                                       AS program_code,
    p.name                                                       AS program_name,
    ps.observation_count,
    ps.rater_count,
    ps.average_score,
    rb.code                                                      AS band_code,
    rb.label                                                     AS band_label,
    rb.color_hex                                                 AS band_color,
    rb.requires_action,
    ps.recommendation,
    ps.rank_in_program,
    ps.is_finalized
FROM performance_summaries ps
INNER JOIN evaluation_cycles c  ON c.id = ps.cycle_id
INNER JOIN school_years sy      ON sy.id = c.school_year_id
LEFT  JOIN semesters sem        ON sem.id = c.semester_id
INNER JOIN users u              ON u.id = ps.faculty_id
LEFT  JOIN faculty_profiles fp  ON fp.user_id = u.id
INNER JOIN programs p           ON p.id = ps.program_id
LEFT  JOIN rating_bands rb      ON rb.id = ps.rating_band_id;

-- -----------------------------------------------------------------------------
-- v_observation_scores — every rating, flattened, with its weighted points
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_observation_scores AS
SELECT
    o.id                                                         AS observation_id,
    o.faculty_id,
    o.program_id,
    o.observed_at,
    o.status                                                     AS observation_status,
    o.modality,
    o.average_score,
    f.id                                                         AS form_id,
    f.title                                                      AS form_title,
    c.id                                                         AS cycle_id,
    c.name                                                       AS cycle_name,
    orr.rater_id,
    CONCAT_WS(' ', ru.first_name, ru.middle_name, ru.last_name)   AS rater_name,
    orr.rater_role,
    orr.rater_total,
    fi.id                                                        AS form_item_id,
    fi.group_label,
    fi.criterion_code,
    fi.criterion_label,
    fi.weight,
    fi.max_score,
    s.score,
    ROUND((s.score / fi.max_score) * fi.weight, 4)              AS weighted_points
FROM observation_scores s
INNER JOIN observations o        ON o.id = s.observation_id
INNER JOIN observation_raters orr ON orr.observation_id = s.observation_id
                                AND orr.rater_id = s.rater_id
INNER JOIN users ru              ON ru.id = orr.rater_id
INNER JOIN evaluation_form_items fi ON fi.id = s.form_item_id
INNER JOIN evaluation_forms f   ON f.id = o.form_id
INNER JOIN evaluation_cycles c  ON c.id = f.cycle_id;

-- -----------------------------------------------------------------------------
-- v_program_performance — rolled-up program health for the chair's dashboard
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_program_performance AS
SELECT
    p.id                                                         AS program_id,
    p.code                                                       AS program_code,
    p.name                                                       AS program_name,
    d.id                                                         AS department_id,
    d.name                                                       AS department_name,
    COUNT(DISTINCT ps.faculty_id)                                AS faculty_evaluated,
    ROUND(AVG(ps.average_score), 2)                              AS average_score,
    SUM(CASE WHEN rb.requires_action = 1 THEN 1 ELSE 0 END)      AS needing_action,
    SUM(CASE WHEN rb.code IN ('outstanding', 'very_satisfactory') THEN 1 ELSE 0 END) AS commending
FROM programs p
INNER JOIN departments d ON d.id = p.department_id
LEFT  JOIN performance_summaries ps ON ps.program_id = p.id AND ps.is_finalized = 1
LEFT  JOIN rating_bands rb          ON rb.id = ps.rating_band_id
GROUP BY p.id, p.code, p.name, d.id, d.name;

-- -----------------------------------------------------------------------------
-- v_open_action_items — the chair's follow-up queue
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_open_action_items AS
SELECT
    ai.id                                                        AS action_item_id,
    ai.action_type,
    ai.priority,
    ai.title,
    ai.description,
    ai.status,
    ai.due_date,
    ai.faculty_id,
    CONCAT_WS(' ', u.first_name, u.middle_name, u.last_name)      AS faculty_name,
    ai.program_id,
    p.code                                                       AS program_code,
    p.name                                                       AS program_name,
    ai.assigned_to,
    CONCAT_WS(' ', au.first_name, au.middle_name, au.last_name)   AS assignee_name,
    ai.created_at,
    ai.created_by
FROM action_items ai
INNER JOIN users u       ON u.id = ai.faculty_id
INNER JOIN programs p    ON p.id = ai.program_id
LEFT  JOIN users au      ON au.id = ai.assigned_to
WHERE ai.status IN ('open', 'in_progress');

-- 006_account_setup_and_email_delivery.sql                    
CREATE TABLE IF NOT EXISTS account_setup_tokens (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,
    consumed_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_account_setup_token (token_hash),
    KEY idx_account_setup_user (user_id),
    CONSTRAINT fk_account_setup_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS email_deliveries (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NULL,
    recipient_email VARCHAR(120) NOT NULL,
    template_code VARCHAR(50) NOT NULL,
    status ENUM('sent','failed') NOT NULL,
    error_message VARCHAR(500) NULL,
    attempted_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_email_deliveries_status (status, attempted_at),
    KEY idx_email_deliveries_user (user_id),
    CONSTRAINT fk_email_deliveries_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 007_attendance_verification.sql                             
-- 007 — Replace the former observation/rubric model with attendance evidence.
-- A full backup of the live database must be taken before this migration.
-- Statements are repeatable because MariaDB DDL commits implicitly.

DROP VIEW IF EXISTS v_open_action_items;
DROP VIEW IF EXISTS v_program_performance;
DROP VIEW IF EXISTS v_observation_scores;
DROP VIEW IF EXISTS v_cycle_performance;
DROP TABLE IF EXISTS action_items;
DROP TABLE IF EXISTS observation_scores;
DROP TABLE IF EXISTS observation_raters;
DROP TABLE IF EXISTS performance_summaries;
DROP TABLE IF EXISTS observations;
DROP TABLE IF EXISTS evaluation_form_items;
DROP TABLE IF EXISTS evaluation_forms;
DROP TABLE IF EXISTS criteria;
DROP TABLE IF EXISTS criteria_groups;
DROP TABLE IF EXISTS rating_bands;
DROP TABLE IF EXISTS evaluation_cycles;

DELETE FROM settings WHERE setting_key IN
  ('monitoring.rubric_version', 'rating.scale', 'rating.passing_threshold',
   'observation.min_raters', 'observation.default_minutes');
DELETE FROM capabilities WHERE code IN
  ('cycle.manage', 'observation.create', 'observation.submit', 'observation.approve',
   'observation.view_own', 'observation.view_program', 'observation.view_department',
   'action_items.manage');
DELETE FROM notifications WHERE link LIKE '/observations%' OR type IN ('result','action_item');
DELETE FROM announcements WHERE body LIKE '%observation%' OR title LIKE '%observation%';
DELETE FROM audit_logs WHERE entity_type IN
  ('evaluation_cycle','evaluation_form','observation','observations','performance_summary',
   'action_item','rating_band','criterion','criteria');

UPDATE roles SET description = 'Manages accounts, schedules, rooms, QR credentials and attendance settings.' WHERE code = 'admin';
UPDATE roles SET description = 'Monitors departmental attendance and teaching hours and reviews manual entries.' WHERE code = 'chairperson';
UPDATE roles SET description = 'Maintains faculty records within the assigned program.' WHERE code = 'program_coordinator';
UPDATE roles SET description = 'Checks in and out, views own hours and requests manual time entries.' WHERE code = 'faculty';

INSERT INTO capabilities (code, description) VALUES
  ('attendance.record', 'Check in and out of own scheduled classes.'),
  ('attendance.view_own', 'View own attendance and teaching hours.'),
  ('attendance.view_department', 'View attendance across the department.'),
  ('attendance.review_manual', 'Approve or reject manual time requests.'),
  ('attendance.flag_review', 'Review and resolve suspicious attendance flags.'),
  ('room_qr.manage', 'Issue and rotate classroom QR credentials.'),
  ('geofence.manage', 'Manage campus geofence definitions.')
ON DUPLICATE KEY UPDATE description = VALUES(description);

INSERT IGNORE INTO role_capabilities (role_id, capability_id)
SELECT r.id, c.id FROM roles r JOIN capabilities c
  ON (r.code = 'admin' AND c.code IN
      ('attendance.record','attendance.view_own','attendance.view_department',
       'attendance.review_manual','attendance.flag_review','room_qr.manage','geofence.manage'))
  OR (r.code = 'chairperson' AND c.code IN
      ('attendance.record','attendance.view_own','attendance.view_department',
       'attendance.review_manual','attendance.flag_review','users.manage','settings.manage'))
  OR (r.code = 'program_coordinator' AND c.code IN
      ('attendance.record','attendance.view_own','faculty.manage'))
  OR (r.code = 'faculty' AND c.code IN
      ('attendance.record','attendance.view_own'));

CREATE TABLE IF NOT EXISTS campus_geofences (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code VARCHAR(30) NOT NULL,
    name VARCHAR(120) NOT NULL,
    center_latitude DECIMAL(10,7) NOT NULL,
    center_longitude DECIMAL(10,7) NOT NULL,
    radius_meters SMALLINT UNSIGNED NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_campus_geofences_code (code),
    CONSTRAINT chk_geofence_latitude CHECK (center_latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_geofence_longitude CHECK (center_longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_geofence_radius CHECK (radius_meters > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE rooms ADD COLUMN IF NOT EXISTS geofence_id BIGINT UNSIGNED NULL;
ALTER TABLE rooms ADD CONSTRAINT fk_rooms_geofence FOREIGN KEY (geofence_id)
    REFERENCES campus_geofences (id) ON DELETE RESTRICT ON UPDATE CASCADE;

-- Only a hash of each room token is stored. Rotation creates a new row.
CREATE TABLE IF NOT EXISTS room_qr_credentials (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    room_id BIGINT UNSIGNED NOT NULL,
    token_hash CHAR(64) NOT NULL,
    valid_from DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_until DATETIME NULL,
    revoked_at DATETIME NULL,
    created_by BIGINT UNSIGNED NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_room_qr_token_hash (token_hash),
    KEY idx_room_qr_room_validity (room_id, valid_from, valid_until),
    CONSTRAINT fk_room_qr_room FOREIGN KEY (room_id) REFERENCES rooms (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_room_qr_creator FOREIGN KEY (created_by) REFERENCES users (id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_room_qr_validity CHECK (valid_until IS NULL OR valid_until > valid_from)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A dated occurrence of a recurring schedule. Planned values are a historical
-- snapshot, so later schedule edits cannot change the attendance period.
CREATE TABLE IF NOT EXISTS class_sessions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    schedule_id BIGINT UNSIGNED NOT NULL,
    session_date DATE NOT NULL,
    planned_start_at DATETIME NOT NULL,
    planned_end_at DATETIME NOT NULL,
    planned_room_id BIGINT UNSIGNED NULL,
    status ENUM('scheduled','cancelled') NOT NULL DEFAULT 'scheduled',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_class_sessions_schedule_date (schedule_id, session_date),
    KEY idx_class_sessions_date (session_date, status),
    KEY idx_class_sessions_room (planned_room_id, planned_start_at),
    CONSTRAINT fk_class_sessions_schedule FOREIGN KEY (schedule_id) REFERENCES schedules (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_class_sessions_room FOREIGN KEY (planned_room_id) REFERENCES rooms (id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_class_sessions_period CHECK (planned_end_at > planned_start_at),
    CONSTRAINT chk_class_sessions_date CHECK (DATE(planned_start_at) = session_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One accepted check-in and one accepted check-out per session. The server
-- timestamp is authoritative; device time is retained to detect mismatch.
CREATE TABLE IF NOT EXISTS attendance_events (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_session_id BIGINT UNSIGNED NOT NULL,
    event_type ENUM('check_in','check_out') NOT NULL,
    recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    device_reported_at DATETIME NULL,
    latitude DECIMAL(10,7) NULL,
    longitude DECIMAL(10,7) NULL,
    accuracy_meters DECIMAL(8,2) NULL,
    device_fingerprint_hash CHAR(64) NULL,
    status ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_attendance_events_session_type (class_session_id, event_type),
    KEY idx_attendance_events_device (device_fingerprint_hash, recorded_at),
    KEY idx_attendance_events_status (status, recorded_at),
    CONSTRAINT fk_attendance_events_session FOREIGN KEY (class_session_id)
        REFERENCES class_sessions (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_attendance_latitude CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_attendance_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_attendance_accuracy CHECK (accuracy_meters IS NULL OR accuracy_meters >= 0),
    CONSTRAINT chk_attendance_coordinates CHECK ((latitude IS NULL) = (longitude IS NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attendance_geofence_checks (
    attendance_event_id BIGINT UNSIGNED NOT NULL,
    geofence_id BIGINT UNSIGNED NOT NULL,
    distance_meters DECIMAL(9,2) NOT NULL,
    passed TINYINT(1) NOT NULL,
    checked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attendance_event_id),
    KEY idx_attendance_geofence (geofence_id, passed),
    CONSTRAINT fk_attendance_geofence_event FOREIGN KEY (attendance_event_id)
        REFERENCES attendance_events (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_attendance_geofence_area FOREIGN KEY (geofence_id)
        REFERENCES campus_geofences (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_attendance_distance CHECK (distance_meters >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attendance_qr_checks (
    attendance_event_id BIGINT UNSIGNED NOT NULL,
    qr_credential_id BIGINT UNSIGNED NULL,
    passed TINYINT(1) NOT NULL,
    checked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attendance_event_id),
    KEY idx_attendance_qr_credential (qr_credential_id),
    CONSTRAINT fk_attendance_qr_event FOREIGN KEY (attendance_event_id)
        REFERENCES attendance_events (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_attendance_qr_credential FOREIGN KEY (qr_credential_id)
        REFERENCES room_qr_credentials (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Store private file references, never image blobs or public URLs.
CREATE TABLE IF NOT EXISTS attendance_photos (
    attendance_event_id BIGINT UNSIGNED NOT NULL,
    storage_key VARCHAR(255) NOT NULL,
    sha256_hash CHAR(64) NOT NULL,
    captured_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (attendance_event_id),
    KEY idx_attendance_photos_hash (sha256_hash),
    CONSTRAINT fk_attendance_photos_event FOREIGN KEY (attendance_event_id)
        REFERENCES attendance_events (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS attendance_flags (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_session_id BIGINT UNSIGNED NOT NULL,
    attendance_event_id BIGINT UNSIGNED NULL,
    flag_code ENUM('shared_device','time_mismatch','duplicate_photo','location_mismatch','qr_mismatch','missing_evidence','other') NOT NULL,
    severity ENUM('warning','blocking') NOT NULL DEFAULT 'blocking',
    details VARCHAR(500) NOT NULL DEFAULT '',
    raised_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_by BIGINT UNSIGNED NULL,
    resolved_at DATETIME NULL,
    resolution_note VARCHAR(500) NULL,
    PRIMARY KEY (id),
    KEY idx_attendance_flags_session (class_session_id, resolved_at),
    KEY idx_attendance_flags_event (attendance_event_id),
    CONSTRAINT fk_attendance_flags_session FOREIGN KEY (class_session_id)
        REFERENCES class_sessions (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_attendance_flags_event FOREIGN KEY (attendance_event_id)
        REFERENCES attendance_events (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_attendance_flags_resolver FOREIGN KEY (resolved_by)
        REFERENCES users (id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_attendance_flags_resolution CHECK
        ((resolved_at IS NULL AND resolved_by IS NULL) OR (resolved_at IS NOT NULL AND resolved_by IS NOT NULL))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS manual_time_requests (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    class_session_id BIGINT UNSIGNED NOT NULL,
    requested_by BIGINT UNSIGNED NOT NULL,
    proposed_start_at DATETIME NOT NULL,
    proposed_end_at DATETIME NOT NULL,
    reason TEXT NOT NULL,
    requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_manual_requests_session (class_session_id, requested_at),
    KEY idx_manual_requests_faculty (requested_by, requested_at),
    CONSTRAINT fk_manual_requests_session FOREIGN KEY (class_session_id)
        REFERENCES class_sessions (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_manual_requests_faculty FOREIGN KEY (requested_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_manual_requests_period CHECK (proposed_end_at > proposed_start_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Absence of a decision means pending. One immutable decision per request.
CREATE TABLE IF NOT EXISTS manual_time_decisions (
    manual_time_request_id BIGINT UNSIGNED NOT NULL,
    reviewed_by BIGINT UNSIGNED NOT NULL,
    decision ENUM('approved','rejected') NOT NULL,
    review_note VARCHAR(500) NOT NULL DEFAULT '',
    reviewed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (manual_time_request_id),
    KEY idx_manual_decisions_reviewer (reviewed_by, reviewed_at),
    CONSTRAINT fk_manual_decisions_request FOREIGN KEY (manual_time_request_id)
        REFERENCES manual_time_requests (id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_manual_decisions_reviewer FOREIGN KEY (reviewed_by)
        REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A verified pair takes precedence over an approved manual request. Hours are
-- derived from evidence, capped to the scheduled period, and never stored twice.
CREATE OR REPLACE VIEW v_session_attendance AS
SELECT cs.id AS class_session_id, cs.session_date, cs.schedule_id,
       tl.faculty_id, sec.program_id, cs.planned_room_id,
       cs.planned_start_at, cs.planned_end_at,
       ci.recorded_at AS check_in_at, co.recorded_at AS check_out_at,
       mr.id AS approved_manual_request_id,
       CASE
         WHEN cs.status = 'cancelled' THEN 0
         WHEN EXISTS (SELECT 1 FROM attendance_flags af WHERE af.class_session_id = cs.id
                      AND af.severity = 'blocking' AND af.resolved_at IS NULL) THEN 0
         WHEN ci.status = 'verified' AND co.status = 'verified'
           AND ci.recorded_at < co.recorded_at
           THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(ci.recorded_at, cs.planned_start_at),
                LEAST(co.recorded_at, cs.planned_end_at)))
         WHEN mr.id IS NOT NULL THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(mr.proposed_start_at, cs.planned_start_at),
                LEAST(mr.proposed_end_at, cs.planned_end_at)))
         ELSE 0
       END AS verified_seconds,
       CASE
         WHEN cs.status = 'cancelled' OR EXISTS
           (SELECT 1 FROM attendance_flags af WHERE af.class_session_id = cs.id
            AND af.severity = 'blocking' AND af.resolved_at IS NULL) THEN 0
         WHEN ci.status = 'verified' AND co.status = 'verified'
           AND ci.recorded_at <= cs.planned_start_at AND co.recorded_at >= cs.planned_end_at THEN 1
         WHEN mr.id IS NOT NULL AND mr.proposed_start_at <= cs.planned_start_at
           AND mr.proposed_end_at >= cs.planned_end_at THEN 1
         ELSE 0
       END AS full_period_verified
FROM class_sessions cs
JOIN schedules sc ON sc.id = cs.schedule_id
JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
JOIN sections sec ON sec.id = tl.section_id
LEFT JOIN attendance_events ci ON ci.class_session_id = cs.id AND ci.event_type = 'check_in'
LEFT JOIN attendance_events co ON co.class_session_id = cs.id AND co.event_type = 'check_out'
LEFT JOIN manual_time_requests mr ON mr.class_session_id = cs.id
  AND mr.id = (SELECT MAX(mr2.id) FROM manual_time_requests mr2
               JOIN manual_time_decisions md2 ON md2.manual_time_request_id = mr2.id
               WHERE mr2.class_session_id = cs.id AND md2.decision = 'approved');

CREATE OR REPLACE VIEW v_teaching_hours AS
SELECT faculty_id, program_id, COUNT(*) AS scheduled_sessions,
       SUM(full_period_verified) AS full_period_sessions,
       ROUND(SUM(verified_seconds) / 3600, 2) AS verified_hours
FROM v_session_attendance
GROUP BY faculty_id, program_id;

-- 008_normalize_academic_terms.sql                            
-- 008 — One authoritative academic term per section.
-- semesters.school_year_id defines the year; sections.semester_id defines the
-- section term; teaching_loads.section_id inherits both. Removing redundant
-- term columns prevents internally inconsistent assignments.

DROP VIEW IF EXISTS v_faculty_load;

ALTER TABLE teaching_loads
  DROP FOREIGN KEY fk_teaching_loads_sy,
  DROP FOREIGN KEY fk_teaching_loads_semester;
ALTER TABLE teaching_loads
  DROP INDEX uq_teaching_loads,
  DROP INDEX idx_teaching_loads_term,
  DROP COLUMN school_year_id,
  DROP COLUMN semester_id,
  ADD UNIQUE KEY uq_teaching_loads_assignment (faculty_id, section_id, subject_id);

ALTER TABLE sections DROP FOREIGN KEY fk_sections_sy;
ALTER TABLE sections
  DROP INDEX uq_sections_code,
  DROP INDEX idx_sections_term,
  DROP COLUMN school_year_id,
  ADD UNIQUE KEY uq_sections_code_term (code, semester_id),
  ADD KEY idx_sections_semester (semester_id);

CREATE OR REPLACE VIEW v_faculty_load AS
SELECT tl.id AS teaching_load_id, tl.faculty_id,
       CONCAT_WS(' ', u.first_name, u.middle_name, u.last_name) AS faculty_name,
       fp.rank_code, fp.department_id, sec.program_id,
       p.code AS program_code, p.name AS program_name,
       s.code AS subject_code, s.title AS subject_title, s.units,
       sec.code AS section_code, sec.name AS section_name,
       sy.label AS school_year, sem.name AS semester,
       tl.load_units, tl.load_type, tl.is_active,
       (SELECT COUNT(*) FROM schedules sc WHERE sc.teaching_load_id = tl.id) AS meeting_count,
       (SELECT COALESCE(SUM(TIME_TO_SEC(sc.end_time)-TIME_TO_SEC(sc.start_time)),0)/3600
        FROM schedules sc WHERE sc.teaching_load_id = tl.id) AS weekly_hours
FROM teaching_loads tl
JOIN users u ON u.id = tl.faculty_id
LEFT JOIN faculty_profiles fp ON fp.user_id = u.id
JOIN subjects s ON s.id = tl.subject_id
JOIN sections sec ON sec.id = tl.section_id
JOIN programs p ON p.id = sec.program_id
JOIN semesters sem ON sem.id = sec.semester_id
JOIN school_years sy ON sy.id = sem.school_year_id;

-- 009_remove_legacy_metadata.sql                              
-- Remove obsolete evaluation wording left in reference and audit metadata.
UPDATE capabilities SET description = 'View own verified teaching-hour reports.'
  WHERE code = 'report.view_own';
UPDATE capabilities SET description = 'Edit system settings.'
  WHERE code = 'settings.manage';
DELETE FROM notifications WHERE link LIKE '/action-items%';
DELETE FROM audit_logs WHERE description REGEXP 'observation|rubric|performance|rating|coaching';

-- 010_require_layered_evidence_for_hours.sql                  
-- 010 — Attendance hours require the layered proof described in the study.
-- The geofence on a session is a historical snapshot of the room's campus area.
ALTER TABLE class_sessions ADD COLUMN planned_geofence_id BIGINT UNSIGNED NULL;
ALTER TABLE class_sessions ADD CONSTRAINT fk_class_sessions_geofence
  FOREIGN KEY (planned_geofence_id) REFERENCES campus_geofences (id)
  ON DELETE RESTRICT ON UPDATE CASCADE;
UPDATE class_sessions cs JOIN rooms r ON r.id = cs.planned_room_id
  SET cs.planned_geofence_id = r.geofence_id
  WHERE cs.planned_geofence_id IS NULL;

DROP VIEW IF EXISTS v_teaching_hours;
DROP VIEW IF EXISTS v_session_attendance;

CREATE OR REPLACE VIEW v_verified_attendance_events AS
SELECT e.id, e.class_session_id, e.event_type, e.recorded_at
FROM attendance_events e
JOIN class_sessions cs ON cs.id = e.class_session_id
JOIN attendance_photos photo ON photo.attendance_event_id = e.id
JOIN attendance_geofence_checks geo ON geo.attendance_event_id = e.id AND geo.passed = 1
JOIN attendance_qr_checks qr ON qr.attendance_event_id = e.id AND qr.passed = 1
JOIN room_qr_credentials credential ON credential.id = qr.qr_credential_id
WHERE e.status = 'verified'
  AND cs.status = 'scheduled'
  AND cs.planned_geofence_id = geo.geofence_id
  AND cs.planned_room_id = credential.room_id
  AND credential.valid_from <= e.recorded_at
  AND (credential.valid_until IS NULL OR e.recorded_at < credential.valid_until)
  AND (credential.revoked_at IS NULL OR e.recorded_at < credential.revoked_at);

CREATE OR REPLACE VIEW v_session_evidence AS
SELECT cs.id AS class_session_id, cs.session_date, cs.schedule_id,
       tl.faculty_id, sec.program_id, cs.planned_room_id,
       cs.planned_start_at, cs.planned_end_at, cs.status AS session_status,
       ci.recorded_at AS check_in_at, co.recorded_at AS check_out_at,
       mr.id AS approved_manual_request_id,
       mr.proposed_start_at AS manual_start_at, mr.proposed_end_at AS manual_end_at,
       EXISTS (SELECT 1 FROM attendance_flags af
               WHERE af.class_session_id = cs.id AND af.severity = 'blocking'
                 AND af.resolved_at IS NULL) AS has_blocking_flag
FROM class_sessions cs
JOIN schedules sc ON sc.id = cs.schedule_id
JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
JOIN sections sec ON sec.id = tl.section_id
LEFT JOIN v_verified_attendance_events ci
  ON ci.class_session_id = cs.id AND ci.event_type = 'check_in'
LEFT JOIN v_verified_attendance_events co
  ON co.class_session_id = cs.id AND co.event_type = 'check_out'
LEFT JOIN manual_time_requests mr ON mr.class_session_id = cs.id
  AND mr.id = (SELECT MAX(mr2.id) FROM manual_time_requests mr2
               JOIN manual_time_decisions md2 ON md2.manual_time_request_id = mr2.id
               WHERE mr2.class_session_id = cs.id AND md2.decision = 'approved');

CREATE OR REPLACE VIEW v_session_attendance AS
SELECT e.class_session_id, e.session_date, e.schedule_id, e.faculty_id,
       e.program_id, e.planned_room_id, e.planned_start_at, e.planned_end_at,
       e.check_in_at, e.check_out_at, e.approved_manual_request_id,
       CASE
         WHEN e.session_status = 'cancelled' OR e.has_blocking_flag = 1 THEN 0
         WHEN e.check_in_at IS NOT NULL AND e.check_out_at IS NOT NULL
              AND e.check_in_at < e.check_out_at
           THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(e.check_in_at, e.planned_start_at),
                LEAST(e.check_out_at, e.planned_end_at)))
         WHEN e.approved_manual_request_id IS NOT NULL
           THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(e.manual_start_at, e.planned_start_at),
                LEAST(e.manual_end_at, e.planned_end_at)))
         ELSE 0
       END AS verified_seconds,
       CASE
         WHEN e.session_status = 'cancelled' OR e.has_blocking_flag = 1 THEN 0
         WHEN e.check_in_at IS NOT NULL AND e.check_out_at IS NOT NULL
              AND e.check_in_at < e.check_out_at
           THEN IF(e.check_in_at <= e.planned_start_at
                   AND e.check_out_at >= e.planned_end_at, 1, 0)
         WHEN e.approved_manual_request_id IS NOT NULL
           THEN IF(e.manual_start_at <= e.planned_start_at
                   AND e.manual_end_at >= e.planned_end_at, 1, 0)
         ELSE 0
       END AS full_period_verified
FROM v_session_evidence e;

CREATE OR REPLACE VIEW v_teaching_hours AS
SELECT faculty_id, program_id, COUNT(*) AS scheduled_sessions,
       SUM(full_period_verified) AS full_period_sessions,
       ROUND(SUM(verified_seconds) / 3600, 2) AS verified_hours
FROM v_session_attendance
GROUP BY faculty_id, program_id;

-- 011_bind_flags_to_event_session.sql                         
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

-- 012_schedule_provenance_and_status.sql                      
-- Preserve dated attendance when a recurring schedule is retired, and mark
-- the original demo timetable so it cannot be confused with an approved load.
ALTER TABLE schedules
  ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1,
  ADD COLUMN source ENUM('sample','entered') NOT NULL DEFAULT 'entered';

UPDATE schedules SET source = 'sample'
WHERE id BETWEEN 1 AND 14 AND created_at = '2026-10-23 01:22:57';

-- 013_active_schedule_slot_uniqueness.sql                     
-- Retired slots keep their historical rows. Only active slots must be unique.
ALTER TABLE schedules ADD KEY idx_schedules_load (teaching_load_id);
ALTER TABLE schedules DROP INDEX uq_schedules_slot;
ALTER TABLE schedules
  ADD COLUMN active_start_time TIME
    GENERATED ALWAYS AS (CASE WHEN is_active = 1 THEN start_time ELSE NULL END) PERSISTENT,
  ADD UNIQUE KEY uq_schedules_active_slot (teaching_load_id, day_of_week, active_start_time);

-- 014_curriculum_semester_and_types.sql                       
-- Keep curriculum placement separate from an individual school year's semester.
-- NULL retains the existing unrestricted placement for legacy BSIT entries.
ALTER TABLE program_curriculum
  ADD COLUMN IF NOT EXISTS semester_code VARCHAR(10) NULL AFTER year_level;

ALTER TABLE program_curriculum
  MODIFY subject_type ENUM(
    'Core', 'Elective', 'Laboratory', 'PE', 'General Education',
    'NSTP', 'Institutional', 'Practicum', 'Thesis'
  ) NOT NULL DEFAULT 'Core';

-- 015_security_rate_limits.sql                                
CREATE TABLE IF NOT EXISTS security_rate_limits (
    bucket_hash CHAR(64) NOT NULL,
    attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    window_started_at DATETIME NOT NULL,
    blocked_until DATETIME NULL,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (bucket_hash),
    KEY idx_security_rate_limits_updated (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 016_email_change_verification.sql                           
CREATE TABLE IF NOT EXISTS email_change_tokens (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    previous_email VARCHAR(120) NOT NULL,
    new_email VARCHAR(120) NOT NULL,
    token_hash CHAR(64) NOT NULL,
    expires_at DATETIME NOT NULL,
    consumed_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_email_change_token (token_hash),
    KEY idx_email_change_user (user_id, expires_at),
    CONSTRAINT fk_email_change_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 017_auth_session_version.sql                                
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_version INT UNSIGNED NOT NULL DEFAULT 0;

-- 018_prune_unused_metadata_and_report_demo.sql               
-- Remove retired modules and fields confirmed empty and unreferenced by live flows.
ALTER TABLE users DROP COLUMN IF EXISTS avatar_url;
ALTER TABLE program_assignments
  DROP COLUMN IF EXISTS starts_on,
  DROP COLUMN IF EXISTS ends_on;
ALTER TABLE subjects DROP COLUMN IF EXISTS description;

DROP TABLE IF EXISTS announcements;
DROP TABLE IF EXISTS settings;
DELETE FROM capabilities WHERE code IN ('announcement.manage', 'settings.manage');

-- These tokens cannot be used again. Keep audit and login history intact.
DELETE FROM account_setup_tokens WHERE consumed_at IS NOT NULL OR expires_at < NOW();
DELETE FROM security_rate_limits
WHERE updated_at < DATE_SUB(NOW(), INTERVAL 2 DAY)
  AND (blocked_until IS NULL OR blocked_until < NOW());

-- Isolated illustrative aggregates. They never enter verified attendance views.
CREATE TABLE IF NOT EXISTS report_demo_weekly (
  program_id BIGINT UNSIGNED NOT NULL,
  semester_id BIGINT UNSIGNED NOT NULL,
  week_start DATE NOT NULL,
  scheduled_sessions SMALLINT UNSIGNED NOT NULL,
  full_period_sessions SMALLINT UNSIGNED NOT NULL,
  verified_hours DECIMAL(7,2) NOT NULL,
  PRIMARY KEY (program_id, semester_id, week_start),
  KEY idx_report_demo_term_week (semester_id, week_start),
  CONSTRAINT fk_report_demo_program FOREIGN KEY (program_id) REFERENCES programs(id) ON DELETE CASCADE,
  CONSTRAINT fk_report_demo_semester FOREIGN KEY (semester_id) REFERENCES semesters(id) ON DELETE CASCADE,
  CONSTRAINT chk_report_demo_sessions CHECK (full_period_sessions <= scheduled_sessions),
  CONSTRAINT chk_report_demo_hours CHECK (verified_hours >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 019_permanent_room_qr_identifiers.sql                       
-- A room has one stable public identifier for its printed QR card. This is
-- deliberately separate from attendance credentials, which may rotate later.
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS qr_public_code CHAR(32) NULL AFTER code;
ALTER TABLE rooms ADD UNIQUE KEY uq_rooms_qr_public_code (qr_public_code);

-- The chairperson can issue and print room QR cards alongside the administrator.
INSERT IGNORE INTO role_capabilities (role_id, capability_id)
SELECT r.id, c.id FROM roles r JOIN capabilities c
WHERE r.code = 'chairperson' AND c.code = 'room_qr.manage';

-- 020_remove_unimplemented_geofencing_and_flags.sql           
-- Remove empty attendance features that have no application workflow yet.
-- Keep the reporting views valid, but do not credit unverified attendance events.
DROP VIEW IF EXISTS v_teaching_hours;
DROP VIEW IF EXISTS v_session_attendance;
DROP VIEW IF EXISTS v_session_evidence;
DROP VIEW IF EXISTS v_verified_attendance_events;

ALTER TABLE class_sessions
  DROP FOREIGN KEY fk_class_sessions_geofence,
  DROP COLUMN planned_geofence_id;
ALTER TABLE rooms
  DROP FOREIGN KEY fk_rooms_geofence,
  DROP COLUMN geofence_id;

DROP TABLE IF EXISTS attendance_geofence_checks;
DROP TABLE IF EXISTS attendance_flags;
DROP TABLE IF EXISTS campus_geofences;

CREATE OR REPLACE VIEW v_session_evidence AS
SELECT cs.id AS class_session_id, cs.session_date, cs.schedule_id,
       tl.faculty_id, sec.program_id, cs.planned_room_id,
       cs.planned_start_at, cs.planned_end_at, cs.status AS session_status,
       NULL AS check_in_at, NULL AS check_out_at,
       mr.id AS approved_manual_request_id,
       mr.proposed_start_at AS manual_start_at,
       mr.proposed_end_at AS manual_end_at
FROM class_sessions cs
JOIN schedules sc ON sc.id = cs.schedule_id
JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
JOIN sections sec ON sec.id = tl.section_id
LEFT JOIN manual_time_requests mr ON mr.class_session_id = cs.id
  AND mr.id = (SELECT MAX(mr2.id) FROM manual_time_requests mr2
               JOIN manual_time_decisions md2 ON md2.manual_time_request_id = mr2.id
               WHERE mr2.class_session_id = cs.id AND md2.decision = 'approved');

CREATE OR REPLACE VIEW v_session_attendance AS
SELECT e.class_session_id, e.session_date, e.schedule_id, e.faculty_id,
       e.program_id, e.planned_room_id, e.planned_start_at, e.planned_end_at,
       e.check_in_at, e.check_out_at, e.approved_manual_request_id,
       CASE
         WHEN e.session_status = 'cancelled' THEN 0
         WHEN e.approved_manual_request_id IS NOT NULL
           THEN GREATEST(0, TIMESTAMPDIFF(SECOND,
                GREATEST(e.manual_start_at, e.planned_start_at),
                LEAST(e.manual_end_at, e.planned_end_at)))
         ELSE 0
       END AS verified_seconds,
       CASE
         WHEN e.session_status = 'cancelled' THEN 0
         WHEN e.approved_manual_request_id IS NOT NULL
           THEN IF(e.manual_start_at <= e.planned_start_at
                   AND e.manual_end_at >= e.planned_end_at, 1, 0)
         ELSE 0
       END AS full_period_verified
FROM v_session_evidence e;

CREATE OR REPLACE VIEW v_teaching_hours AS
SELECT faculty_id, program_id, COUNT(*) AS scheduled_sessions,
       SUM(full_period_verified) AS full_period_sessions,
       ROUND(SUM(verified_seconds) / 3600, 2) AS verified_hours
FROM v_session_attendance
GROUP BY faculty_id, program_id;

-- 021_remove_unimplemented_attendance_storage.sql             
-- Attendance collection has no routes yet. Refuse to discard any collected data.
CREATE TEMPORARY TABLE attendance_cleanup_guard (
  rows_found BIGINT NOT NULL CHECK (rows_found = 0)
);
INSERT INTO attendance_cleanup_guard (rows_found)
SELECT (SELECT COUNT(*) FROM class_sessions)
     + (SELECT COUNT(*) FROM attendance_events)
     + (SELECT COUNT(*) FROM attendance_photos)
     + (SELECT COUNT(*) FROM attendance_qr_checks)
     + (SELECT COUNT(*) FROM room_qr_credentials)
     + (SELECT COUNT(*) FROM manual_time_requests)
     + (SELECT COUNT(*) FROM manual_time_decisions);
DROP TEMPORARY TABLE attendance_cleanup_guard;

DROP VIEW IF EXISTS v_teaching_hours;
DROP VIEW IF EXISTS v_session_attendance;
DROP VIEW IF EXISTS v_session_evidence;
DROP VIEW IF EXISTS v_verified_attendance_events;

DROP TABLE manual_time_decisions;
DROP TABLE manual_time_requests;
DROP TABLE attendance_photos;
DROP TABLE attendance_qr_checks;
DROP TABLE attendance_events;
DROP TABLE room_qr_credentials;
DROP TABLE class_sessions;

DELETE FROM capabilities WHERE code IN (
  'attendance.record', 'attendance.view_own', 'attendance.view_department',
  'attendance.review_manual', 'attendance.flag_review', 'geofence.manage'
);
UPDATE capabilities SET description = 'View and print room QR cards.'
  WHERE code = 'room_qr.manage';
UPDATE roles SET description = 'Manages accounts, schedules, and room QR cards.' WHERE code = 'admin';
UPDATE roles SET description = 'Monitors the department and manages faculty schedules.' WHERE code = 'chairperson';
UPDATE roles SET description = 'Views own timetable and account.' WHERE code = 'faculty';

-- 022_remove_colleges.sql                                     
-- The app monitors one department and never reads the college level.
ALTER TABLE departments
  DROP FOREIGN KEY fk_departments_college,
  DROP INDEX idx_departments_college,
  DROP COLUMN college_id;

DROP TABLE colleges;

-- 023_remove_system_administrator.sql                         
-- Chairperson already owns the working administrative routes. Keep former
-- administrator records for audit, but retire their login when a chair exists.
SET @admin_role_id = (SELECT id FROM roles WHERE code = 'admin');
SET @chair_role_id = (SELECT id FROM roles WHERE code = 'chairperson');
SET @active_chairs = (SELECT COUNT(*) FROM users u
  JOIN user_roles ur ON ur.user_id = u.id
  WHERE ur.role_id = @chair_role_id AND u.is_active = 1);

UPDATE users u JOIN user_roles ur ON ur.user_id = u.id
SET u.is_active = 0, u.auth_version = u.auth_version + 1
WHERE ur.role_id = @admin_role_id AND @active_chairs > 0 AND u.is_active = 1;

INSERT IGNORE INTO user_roles (user_id, role_id, assigned_by)
SELECT user_id, @chair_role_id, assigned_by FROM user_roles
WHERE role_id = @admin_role_id AND @chair_role_id IS NOT NULL;

UPDATE program_assignments SET role_id = @chair_role_id
WHERE role_id = @admin_role_id AND @chair_role_id IS NOT NULL;

DELETE FROM user_roles WHERE role_id = @admin_role_id;
DELETE FROM roles WHERE id = @admin_role_id;

-- 024_class_verification_submissions.sql                      
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

-- 025_coordinator_room_access.sql                             
-- Coordinators can view, print, and add rooms with permanent QR cards.
INSERT IGNORE INTO role_capabilities (role_id, capability_id)
SELECT r.id, c.id FROM roles r JOIN capabilities c
WHERE r.code = 'program_coordinator' AND c.code = 'room_qr.manage';

UPDATE capabilities SET description = 'View, print, and add rooms with QR cards.'
WHERE code = 'room_qr.manage';

INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('000_create_migrations_table', 'migration', 'e244639860ff62a12e06f408e8960a15f418f966b17ad22f66e07a3e7fb18177');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('001_core_identity_and_organization', 'migration', '4486846edeab5b8f342d139ae9ee4d426d44ce4619e3f227b79c7703acadc4dd');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('002_academic_structure_and_teaching_load', 'migration', '043a10fbe52c3ea4d87f3738e263358fad511a8b36c91511a04d93afecbe4330');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('003_monitoring_core', 'migration', 'ed5511def1d4c8752b5ed5f0b147f342aea892ea44420ab1ccef24b4e2823cd5');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('004_actions_notifications_and_audit', 'migration', 'd62f53d4b64b4c11a67a9c90405fee3a78c7934b11e1ef6955fec706e7f7e785');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('005_reporting_views', 'migration', '22f1baa859fdc65ba9120b518efdf4dc3b938c787fcac29b0893cb98c064c6bd');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('006_account_setup_and_email_delivery', 'migration', '965b4628cc68d8deefa7d0657310ae1d3d9a8b6176cc13715ba749c434cd480a');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('007_attendance_verification', 'migration', '5a0b97f037edd4a6dfcb2e68156eb29963e108dbd07d1c62c8ffccbc2ee07ca1');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('008_normalize_academic_terms', 'migration', '2137dd578c2b10a8e4f2935a3a69bd91c06b3f4513f9cc3581362d496ccf0de7');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('009_remove_legacy_metadata', 'migration', '8f8daa0a1440f79cbf17fd1dbed85d9f2df1da4b1575c59e97fe8d370d2bf42a');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('010_require_layered_evidence_for_hours', 'migration', 'ecf20e16be9f07f39dbb5f1b02cd07412b04781b9e18aeff46b749717bc385d9');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('011_bind_flags_to_event_session', 'migration', 'befbb80acff67d05ae081881e75bd01e084566c73e4722649355fedcd9321dc8');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('012_schedule_provenance_and_status', 'migration', '2f94cefc7ad09b49597d43f4757384f5aadf6c630374caeb96274592711c154f');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('013_active_schedule_slot_uniqueness', 'migration', '6eb5680386fe5cfabfcce3ed3f6a55d5777c35560b21a6dc783be5647931036c');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('014_curriculum_semester_and_types', 'migration', '9aae7b91b287eb3bc7e53f8e46389d65c8123136f340c22b1f838b299d11cd04');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('015_security_rate_limits', 'migration', '66a3723f504416dfc4066aeb2c7309805db21c7975eeeec71c985d716085f69c');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('016_email_change_verification', 'migration', '8f6f3ef3145e85d40c1fc7d26d1d8072658e3ae6caad40cd19a68f49a5b8cd2d');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('017_auth_session_version', 'migration', '069c21796b84d0d1f04b81b9ed3bfe0502bcc52673321984b1e805f5b38f4acb');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('018_prune_unused_metadata_and_report_demo', 'migration', '0a81f8fcbed19e4dfc9dfd938eaf55cd1c4bbc184c7f5e12f22094b4c4647700');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('019_permanent_room_qr_identifiers', 'migration', '918675bd01e62e392c8f9894ed3fbde114114c2aca091dae500306a983dd5df2');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('020_remove_unimplemented_geofencing_and_flags', 'migration', '3008de5c0a92d85c0b0eb44511f299b85fdb74c29b6e49582aacfd5be8b9bdc3');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('021_remove_unimplemented_attendance_storage', 'migration', 'caed8428e502291e231f8e3bf22eb274a7e7c04ca79d30beee5472565411230c');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('022_remove_colleges', 'migration', '4c961974dec7fb9f9a8ae1931316c172f20b240b8400a6510b9341b956805c0c');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('023_remove_system_administrator', 'migration', 'fd7af29090db704015c7e9ac115382a86df5b8fbf360f42022f4e51cc99c4f54');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('024_class_verification_submissions', 'migration', '7bdf9215f29eba8adcda5d5869ba3029fda32f0fc242949b75cb3c310d10a466');
INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ('025_coordinator_room_access', 'migration', '3f74acff2768d5513d4ecd8caaec1842dccec006a851b4b30d637f3e251ce3aa');
SET FOREIGN_KEY_CHECKS = 1;
