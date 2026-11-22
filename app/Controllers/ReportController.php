<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use App\Services\ReportDemo;
use PDO;

/**
 * Reporting endpoints.
 *
 * Every report is filtered by the caller's scope before it leaves the server:
 *   department  -> whole department
 *   program     -> only the coordinator's assigned programs
 *   self        -> only the caller's own rows
 */
class ReportController
{
    public function scheduledLoad(Request $request): void
    {
        $scope = $this->scope();
        if ($scope === 'self' && !Auth::hasCapability('report.view_own')) Response::fail('Forbidden.', 403);

        $pdo = Database::pdo();
        $requestedFaculty = $request->input('faculty_id');
        if ($requestedFaculty !== null && $requestedFaculty !== ''
            && ((!is_string($requestedFaculty) && !is_int($requestedFaculty))
                || !ctype_digit((string)$requestedFaculty) || (int)$requestedFaculty < 1)) {
            Response::fail('Select a valid faculty member.', 422);
        }
        if ($requestedFaculty !== null && $requestedFaculty !== '' && $scope !== 'department'
            && ($scope !== 'self' || (int)$requestedFaculty !== (int)Auth::id())) {
            Response::fail('Forbidden.', 403);
        }
        $selectedFaculty = $scope === 'self' ? (int)Auth::id()
            : ($scope === 'department' && $requestedFaculty ? (int)$requestedFaculty : null);
        $faculty = [];
        if ($scope === 'department') {
            $facultyQuery = $pdo->prepare("SELECT u.id, CONCAT_WS(' ', u.first_name, u.last_name) AS name
                FROM users u WHERE u.is_active = 1 AND (u.id = ? OR EXISTS
                    (SELECT 1 FROM faculty_profiles fp WHERE fp.user_id = u.id AND fp.is_active = 1))
                ORDER BY u.last_name, u.first_name");
            $facultyQuery->execute([(int)Auth::id()]);
            $faculty = $facultyQuery->fetchAll(PDO::FETCH_ASSOC);
            if ($selectedFaculty !== null
                && !in_array($selectedFaculty, array_map('intval', array_column($faculty, 'id')), true)) {
                Response::fail('Faculty member not found.', 404);
            }
        }
        $programIds = $scope === 'program' ? $this->assignedProgramIds() : [];
        $programSql = 'SELECT id, code, name FROM programs WHERE is_active = 1';
        if ($scope === 'program') {
            $programSql .= $programIds
                ? ' AND id IN (' . implode(',', array_fill(0, count($programIds), '?')) . ')'
                : ' AND 1 = 0';
        }
        if ($scope === 'self') $programSql .= ' AND 1 = 0';
        $programSql .= ' ORDER BY code';
        $programQuery = $pdo->prepare($programSql);
        $programQuery->execute($programIds);
        $programs = $programQuery->fetchAll(PDO::FETCH_ASSOC);

        $terms = $pdo->query('SELECT sem.id, sem.name, sem.start_date, sem.end_date,
            sy.label AS school_year FROM semesters sem
            JOIN school_years sy ON sy.id = sem.school_year_id
            ORDER BY sem.start_date DESC, sem.id DESC')->fetchAll(PDO::FETCH_ASSOC);
        $requestedTerm = $request->input('semester_id');
        if ($requestedTerm !== null && $requestedTerm !== ''
            && (!ctype_digit((string)$requestedTerm) || (int)$requestedTerm < 1)) {
            Response::fail('Select a valid academic term.', 422);
        }
        $today = date('Y-m-d');
        $currentTerm = null;
        foreach ($terms as $term) {
            if ($term['start_date'] <= $today && $term['end_date'] >= $today) {
                $currentTerm = (int)$term['id'];
                break;
            }
        }
        $termId = $requestedTerm ? (int)$requestedTerm : ($currentTerm ?? (int)($terms[0]['id'] ?? 0));
        if ($termId && !in_array($termId, array_map('intval', array_column($terms, 'id')), true)) {
            Response::fail('Academic term not found.', 422);
        }

        $requestedProgram = $request->input('program_id');
        if ($requestedProgram !== null && $requestedProgram !== ''
            && (!ctype_digit((string)$requestedProgram) || (int)$requestedProgram < 1)) {
            Response::fail('Select a valid program.', 422);
        }
        $selectedProgram = $requestedProgram ? (int)$requestedProgram : null;
        if ($scope === 'self' && $selectedProgram !== null) Response::fail('Forbidden.', 403);
        if ($selectedProgram !== null
            && !in_array($selectedProgram, array_map('intval', array_column($programs, 'id')), true)) {
            Response::fail('Forbidden.', 403);
        }

        $rows = [];
        if ($termId && ($scope !== 'program' || $programIds)) {
            $hours = 'TIME_TO_SEC(TIMEDIFF(sc.end_time, sc.start_time)) / 3600';
            $sql = "SELECT tl.faculty_id, CONCAT_WS(' ', u.first_name, u.last_name) AS faculty_name,
                p.id AS program_id, p.code AS program_code,
                COUNT(sc.id) AS slot_count, COUNT(DISTINCT tl.subject_id) AS subject_count,
                ROUND(SUM($hours), 2) AS planned_hours,
                ROUND(SUM(CASE WHEN sc.source = 'entered' THEN $hours ELSE 0 END), 2) AS entered_hours,
                ROUND(SUM(CASE WHEN sc.source = 'sample' THEN $hours ELSE 0 END), 2) AS sample_hours
                FROM schedules sc
                JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
                JOIN users u ON u.id = tl.faculty_id
                JOIN sections sec ON sec.id = tl.section_id
                JOIN programs p ON p.id = sec.program_id
                WHERE sc.is_active = 1 AND tl.is_active = 1 AND u.is_active = 1
                  AND sec.semester_id = ?";
            $params = [$termId];
            if ($scope === 'program') {
                $sql .= ' AND sec.program_id IN (' . implode(',', array_fill(0, count($programIds), '?')) . ')';
                array_push($params, ...$programIds);
                // Coordinators cannot view another coordinator's records.
                $sql .= " AND (tl.faculty_id = ? OR NOT EXISTS
                    (SELECT 1 FROM user_roles ur JOIN roles role ON role.id = ur.role_id
                     WHERE ur.user_id = tl.faculty_id AND role.code = 'program_coordinator'))";
                $params[] = (int)Auth::id();
            }
            if ($selectedFaculty !== null) {
                $sql .= ' AND tl.faculty_id = ?';
                $params[] = $selectedFaculty;
            }
            if ($selectedProgram !== null) {
                $sql .= ' AND sec.program_id = ?';
                $params[] = $selectedProgram;
            }
            $sql .= ' GROUP BY tl.faculty_id, p.id, p.code, u.first_name, u.last_name
                ORDER BY planned_hours DESC, u.last_name, u.first_name, p.code';
            $query = $pdo->prepare($sql);
            $query->execute($params);
            $rows = $query->fetchAll(PDO::FETCH_ASSOC);
        }

        $demoWeekly = $selectedFaculty !== null
            ? ReportDemo::facultyWeekly($termId, $selectedFaculty)
            : (($scope !== 'program' || $programIds)
                ? ReportDemo::weekly($termId, $scope === 'program' ? $programIds : [], $selectedProgram)
                : []);

        Response::ok(['scope' => $scope, 'terms' => $terms, 'programs' => $programs,
            'faculty' => $faculty, 'selected_faculty_id' => $selectedFaculty,
            'selected_term_id' => $termId, 'selected_program_id' => $selectedProgram,
            'rows' => $rows, 'weekly' => [], 'demo_weekly' => $demoWeekly]);
    }

    public function teachingHours(Request $request): void
    {
        Response::ok([]);
    }
    public function facultyDirectory(Request $request): void
    {
        if (Auth::hasRole('chairperson')) {
            $rows = Database::pdo()->query('SELECT * FROM v_faculty_directory ORDER BY last_name, first_name')->fetchAll(PDO::FETCH_ASSOC);
            Response::ok($rows);
            return;
        }
        $ids = $this->assignedProgramIds();
        if (!$ids) { Response::ok([]); return; }
        $in = implode(',', array_fill(0, count($ids), '?'));
        $stmt = Database::pdo()->prepare("SELECT * FROM v_faculty_directory v WHERE EXISTS
            (SELECT 1 FROM program_assignments pa WHERE pa.user_id = v.user_id AND pa.is_active = 1 AND pa.program_id IN ($in))
            AND NOT EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = v.user_id AND r.code = 'program_coordinator')
            ORDER BY last_name, first_name");
        $stmt->execute($ids);
        Response::ok($stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function facultyLoad(Request $request): void
    {
        $scope  = $this->scope();
        $sql    = 'SELECT * FROM v_faculty_load v WHERE v.is_active = 1';
        $params = [];

        if ($scope === 'program') {
            $ids = $this->assignedProgramIds();
            if (!$ids) { Response::ok([]); return; }
            $in = implode(',', array_fill(0, count($ids), '?'));
            $sql .= " AND v.program_id IN ($in)";
            $params = $ids;
            $sql .= " AND (v.faculty_id = ? OR NOT EXISTS (SELECT 1 FROM user_roles ur
                JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = v.faculty_id AND r.code = 'program_coordinator'))";
            $params[] = (int)Auth::id();
        } elseif ($scope === 'self') {
            $sql .= ' AND v.faculty_id = ?';
            $params[] = (int)Auth::id();
        }

        $sql .= ' ORDER BY faculty_name, subject_code';
        $stmt = Database::pdo()->prepare($sql);
        $stmt->execute($params);
        Response::ok($stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    // -------------------------------------------------------------------------
    private function scope(): string
    {
        if (Auth::hasCapability('report.view_department')) return 'department';
        if (Auth::hasCapability('report.view_program'))    return 'program';
        return 'self';
    }

    private function assignedProgramIds(): array
    {
        $stmt = Database::pdo()->prepare(
            "SELECT DISTINCT pa.program_id FROM program_assignments pa JOIN roles r ON r.id = pa.role_id WHERE pa.user_id = ? AND pa.is_active = 1 AND r.code = 'program_coordinator'"
        );
        $stmt->execute([Auth::id()]);
        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
    }
}
