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
