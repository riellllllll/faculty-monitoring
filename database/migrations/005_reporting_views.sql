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
