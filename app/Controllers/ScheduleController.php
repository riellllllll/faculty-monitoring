<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Audit;
use App\Core\Auth;
use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use App\Services\NotificationService;
use PDO;
use PDOException;

class ScheduleController
{
    private const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    private const MODALITIES = ['Face to Face', 'Online', 'Hybrid'];
    private const MEETING_TYPES = ['Lecture', 'Laboratory'];

    public function index(Request $request): void
    {
        $pdo = Database::pdo();
        $manager = Auth::hasRole('chairperson');
        $programIds = $this->coordinatorProgramIds($pdo);
        $editor = $manager || (Auth::hasRole('program_coordinator') && (bool)$programIds);
        $where = 'fp.is_active = 1 AND u.is_active = 1';
        $params = [];
        if (!$manager && $programIds) {
            $where .= ' AND EXISTS (SELECT 1 FROM program_assignments pa WHERE pa.user_id = u.id
                AND pa.program_id IN (' . implode(',', array_fill(0, count($programIds), '?')) . ')
                AND pa.is_active = 1)';
            $params = $programIds;
            $where .= " AND (u.id = ? OR NOT EXISTS (SELECT 1 FROM user_roles ur
                JOIN roles role ON role.id = ur.role_id WHERE ur.user_id = u.id AND role.code = 'program_coordinator'))";
            $params[] = (int)Auth::id();
        } elseif (!$manager) {
            $where .= ' AND u.id = ?';
            $params[] = (int)Auth::id();
        }
        $facultyQuery = $pdo->prepare("SELECT u.id, u.employee_no, u.email, u.first_name, u.last_name,
            u.is_active, fp.rank_code, d.name AS department_name,
            CONCAT_WS(' ', u.first_name, u.last_name) AS full_name,
            (SELECT GROUP_CONCAT(DISTINCT r.code ORDER BY r.code SEPARATOR ', ')
               FROM user_roles ur JOIN roles r ON r.id = ur.role_id
              WHERE ur.user_id = u.id) AS role_codes,
            (SELECT GROUP_CONCAT(DISTINCT p.code ORDER BY p.code SEPARATOR ', ')
               FROM program_assignments pa JOIN programs p ON p.id = pa.program_id
              WHERE pa.user_id = u.id AND pa.is_active = 1) AS program_codes
            FROM users u JOIN faculty_profiles fp ON fp.user_id = u.id
            LEFT JOIN departments d ON d.id = fp.department_id
            WHERE $where ORDER BY u.last_name, u.first_name");
        $facultyQuery->execute($params);
        $faculty = $facultyQuery->fetchAll(PDO::FETCH_ASSOC);

        $entryWhere = 'sc.is_active = 1 AND tl.is_active = 1 AND u.is_active = 1';
        $entryParams = [];
        if (!$manager && $programIds) {
            $entryWhere .= ' AND sec.program_id IN (' . implode(',', array_fill(0, count($programIds), '?')) . ')';
            $entryParams = $programIds;
            $entryWhere .= " AND (tl.faculty_id = ? OR NOT EXISTS (SELECT 1 FROM user_roles ur
                JOIN roles role ON role.id = ur.role_id WHERE ur.user_id = tl.faculty_id AND role.code = 'program_coordinator'))";
            $entryParams[] = (int)Auth::id();
        } elseif (!$manager) {
            $entryWhere .= ' AND tl.faculty_id = ?';
            $entryParams[] = (int)Auth::id();
        }
        $entriesQuery = $pdo->prepare("SELECT sc.id, sc.teaching_load_id, sc.day_of_week,
            TIME_FORMAT(sc.start_time, '%H:%i') AS start_time,
            TIME_FORMAT(sc.end_time, '%H:%i') AS end_time,
            sc.room_id, sc.modality, sc.meeting_type, sc.source,
            tl.faculty_id, CONCAT_WS(' ', u.first_name, u.last_name) AS faculty_name,
            sub.id AS subject_id, sub.code AS subject_code, sub.title AS subject_title,
            sec.id AS section_id, sec.code AS section_code, sec.name AS section_name,
            sec.year_level,
            p.id AS program_id, p.code AS program_code,
            sem.id AS semester_id, sem.name AS semester_name, sem.start_date, sem.end_date,
            sy.label AS school_year, r.code AS room_code, r.name AS room_name
            FROM schedules sc
            JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
            JOIN users u ON u.id = tl.faculty_id
            JOIN subjects sub ON sub.id = tl.subject_id
            JOIN sections sec ON sec.id = tl.section_id
            JOIN programs p ON p.id = sec.program_id
            JOIN semesters sem ON sem.id = sec.semester_id
            JOIN school_years sy ON sy.id = sem.school_year_id
            LEFT JOIN rooms r ON r.id = sc.room_id
            WHERE $entryWhere
            ORDER BY sy.start_year DESC, sem.start_date DESC, u.last_name, u.first_name,
            FIELD(sc.day_of_week, 'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'), sc.start_time");
        $entriesQuery->execute($entryParams);
        $entries = $entriesQuery->fetchAll(PDO::FETCH_ASSOC);

        $terms = $pdo->query("SELECT sem.id, sem.name, sem.start_date, sem.end_date,
            sy.label AS school_year FROM semesters sem JOIN school_years sy ON sy.id = sem.school_year_id
            ORDER BY sem.start_date DESC")->fetchAll(PDO::FETCH_ASSOC);
        $options = [];
        if ($editor) {
            $scope = $manager ? '' : ' AND id IN (' . implode(',', $programIds) . ')';
            $options['programs'] = $pdo->query('SELECT id, code, name FROM programs WHERE is_active = 1' . $scope . ' ORDER BY code')->fetchAll(PDO::FETCH_ASSOC);
            $options['subjects'] = $pdo->query($manager
                ? 'SELECT id, code, title, units FROM subjects WHERE is_active = 1 ORDER BY code'
                : 'SELECT DISTINCT sub.id, sub.code, sub.title, sub.units FROM subjects sub JOIN program_curriculum pc ON pc.subject_id = sub.id WHERE sub.is_active = 1 AND pc.is_active = 1 AND pc.program_id IN (' . implode(',', $programIds) . ') ORDER BY sub.code')
                ->fetchAll(PDO::FETCH_ASSOC);
            $options['sections'] = $pdo->query("SELECT sec.id, sec.code, sec.name, sec.year_level, sec.program_id,
                sec.semester_id, p.code AS program_code, sem.name AS semester_name, sem.code AS semester_code,
                sy.label AS school_year FROM sections sec
                JOIN programs p ON p.id = sec.program_id JOIN semesters sem ON sem.id = sec.semester_id
                JOIN school_years sy ON sy.id = sem.school_year_id
                WHERE sec.is_active = 1" . ($manager ? '' : ' AND sec.program_id IN (' . implode(',', $programIds) . ')') . " ORDER BY sy.start_year DESC, p.code, sec.code")
                ->fetchAll(PDO::FETCH_ASSOC);
            $options['rooms'] = $pdo->query('SELECT id, code, name, room_type FROM rooms WHERE is_active = 1 ORDER BY code')->fetchAll(PDO::FETCH_ASSOC);
            $options['faculty_programs'] = $pdo->query("SELECT DISTINCT pa.user_id, pa.program_id FROM program_assignments pa
                JOIN faculty_profiles fp ON fp.user_id = pa.user_id WHERE pa.is_active = 1 AND fp.is_active = 1" . ($manager ? '' : ' AND pa.program_id IN (' . implode(',', $programIds) . ')'))
                ->fetchAll(PDO::FETCH_ASSOC);
            $options['curriculum'] = $pdo->query('SELECT program_id, subject_id, year_level, semester_code FROM program_curriculum WHERE is_active = 1' . ($manager ? '' : ' AND program_id IN (' . implode(',', $programIds) . ')'))
                ->fetchAll(PDO::FETCH_ASSOC);
        }
        $occupancy = [];
        if ($editor) {
            $occupancy = $pdo->query("SELECT sc.id, sc.day_of_week,
                TIME_FORMAT(sc.start_time, '%H:%i') AS start_time,
                TIME_FORMAT(sc.end_time, '%H:%i') AS end_time,
                sc.room_id, tl.faculty_id, sec.semester_id, sec.program_id,
                CONCAT_WS(' ', u.first_name, u.last_name) AS faculty_name,
                sub.code AS subject_code, sec.code AS section_code
                FROM schedules sc JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
                JOIN users u ON u.id = tl.faculty_id
                JOIN subjects sub ON sub.id = tl.subject_id
                JOIN sections sec ON sec.id = tl.section_id
                WHERE sc.is_active = 1 AND tl.is_active = 1 AND u.is_active = 1
                  AND sc.room_id IS NOT NULL")->fetchAll(PDO::FETCH_ASSOC);
            if (!$manager) {
                $coordinatorUsers = array_map('intval', $pdo->query("SELECT DISTINCT ur.user_id FROM user_roles ur
                    JOIN roles role ON role.id = ur.role_id WHERE role.code = 'program_coordinator'")->fetchAll(PDO::FETCH_COLUMN));
                foreach ($occupancy as &$booking) {
                    if (!in_array((int)$booking['program_id'], $programIds, true)
                        || ((int)$booking['faculty_id'] !== (int)Auth::id() && in_array((int)$booking['faculty_id'], $coordinatorUsers, true))) {
                        $booking['id'] = null;
                        $booking['faculty_id'] = null;
                        $booking['program_id'] = null;
                        $booking['faculty_name'] = 'Room reserved';
                        $booking['subject_code'] = null;
                        $booking['section_code'] = null;
                    }
                }
                unset($booking);
            }
        }
        Response::ok(['faculty' => $faculty, 'entries' => $entries, 'terms' => $terms, 'occupancy' => $occupancy,
            'options' => $options, 'can_manage' => $editor, 'can_catalog' => $manager]);
    }

    public function batchDelete(Request $request): void
    {
        if (!$this->requireManager()) return;
        $ids = $request->input('ids');
        $facultyId = $request->input('faculty_id');
        $termId = $request->input('semester_id');
        if (!is_array($ids) || !$ids || count($ids) > 100
            || !ctype_digit((string)$facultyId) || (int)$facultyId < 1
            || !ctype_digit((string)$termId) || (int)$termId < 1) {
            Response::fail('Select one or more schedules for a faculty member and term.', 422);
        }
        $unique = [];
        foreach ($ids as $id) {
            if (!ctype_digit((string)$id) || (int)$id < 1 || isset($unique[(int)$id])) {
                Response::fail('Invalid or repeated schedule ID.', 422);
            }
            $unique[(int)$id] = true;
        }
        $pdo = Database::pdo();
        $rows = [];
        foreach (array_keys($unique) as $id) {
            $row = $this->findActive($pdo, (string)$id);
            if ((int)$row['faculty_id'] !== (int)$facultyId || (int)$row['semester_id'] !== (int)$termId) {
                Response::fail('All selected schedules must belong to the same faculty member and term.', 422);
            }
            $rows[$id] = $row;
        }
        try {
            $pdo->beginTransaction();
            $update = $pdo->prepare('UPDATE schedules SET is_active = 0 WHERE id = ? AND is_active = 1');
            foreach ($rows as $id => $row) {
                $update->execute([$id]);
                if ($update->rowCount() !== 1) {
                    $pdo->rollBack();
                    Response::fail('A selected schedule changed. Reload and try again.', 409);
                }
            }
            $pdo->commit();
            foreach ($rows as $id => $row) {
                Audit::log(Auth::id(), 'schedule.retire', 'schedules', (int)$id, $row, ['is_active' => 0]);
            }
            NotificationService::schedulesRemoved($pdo, (int)$facultyId, (int)$termId, count($rows));
            Response::ok(['deleted' => count($rows)], 'Selected schedules removed.');
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            Response::fail('Could not remove the selected schedules.', 500);
        }
    }

    public function create(Request $request): void
    {
        if (!$this->requireManager()) return;
        $pdo = Database::pdo();
        $data = $this->validate($request);
        if ($data === null) return;
        if (!$this->validAssignment($pdo, $data)) return;
        if (!$this->available($pdo, $data)) return;
        try {
            $pdo->beginTransaction();
            $find = $pdo->prepare('SELECT id FROM teaching_loads WHERE faculty_id = ? AND subject_id = ? AND section_id = ?');
            $find->execute([$data['faculty_id'], $data['subject_id'], $data['section_id']]);
            $loadId = (int)$find->fetchColumn();
            if ($loadId) {
                $pdo->prepare('UPDATE teaching_loads SET is_active = 1 WHERE id = ?')->execute([$loadId]);
            } else {
                $stmt = $pdo->prepare("INSERT INTO teaching_loads
                    (faculty_id, subject_id, section_id, load_units, assigned_by)
                    SELECT ?, s.id, ?, s.units, ? FROM subjects s WHERE s.id = ?");
                $stmt->execute([$data['faculty_id'], $data['section_id'], Auth::id(), $data['subject_id']]);
                $loadId = (int)$pdo->lastInsertId();
            }
            $stmt = $pdo->prepare("INSERT INTO schedules
                (teaching_load_id, day_of_week, start_time, end_time, room_id, modality, meeting_type, source)
                VALUES (?, ?, ?, ?, ?, ?, ?, 'entered')");
            $stmt->execute([$loadId, $data['day_of_week'], $data['start_time'], $data['end_time'],
                $data['room_id'], $data['modality'], $data['meeting_type']]);
            $id = (int)$pdo->lastInsertId();
            $pdo->commit();
            Audit::log(Auth::id(), 'schedule.create', 'schedules', $id, null, $data);
            NotificationService::scheduleChanged($pdo, $id, 'added');
            Response::ok(['id' => $id], 'Schedule added.');
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            Response::fail($e->getCode() === '23000' ? 'That class slot already exists.' : 'Could not add schedule.', $e->getCode() === '23000' ? 409 : 500);
        }
    }

    public function update(Request $request, string $id): void
    {
        if (!$this->requireManager()) return;
        $pdo = Database::pdo();
        $current = $this->findActive($pdo, $id);
        if (!$current) return;
        $data = $this->validate($request, $current);
        if ($data === null) return;
        if (!$this->available($pdo, $data, (int)$id)) return;
        try {
            $pdo->prepare("UPDATE schedules SET day_of_week = ?, start_time = ?, end_time = ?,
                room_id = ?, modality = ?, meeting_type = ?, source = 'entered' WHERE id = ?")
                ->execute([$data['day_of_week'], $data['start_time'], $data['end_time'],
                    $data['room_id'], $data['modality'], $data['meeting_type'], (int)$id]);
            Audit::log(Auth::id(), 'schedule.update', 'schedules', (int)$id, $current, $data);
            NotificationService::scheduleChanged($pdo, (int)$id, 'updated');
            Response::ok(null, 'Schedule updated.');
        } catch (PDOException $e) {
            Response::fail($e->getCode() === '23000' ? 'That class slot already exists.' : 'Could not update schedule.', $e->getCode() === '23000' ? 409 : 500);
        }
    }

    public function delete(Request $request, string $id): void
    {
        if (!$this->requireManager()) return;
        $pdo = Database::pdo();
        $current = $this->findActive($pdo, $id);
        if (!$current) return;
        $pdo->prepare('UPDATE schedules SET is_active = 0 WHERE id = ?')->execute([(int)$id]);
        Audit::log(Auth::id(), 'schedule.retire', 'schedules', (int)$id, $current, ['is_active' => 0]);
        NotificationService::scheduleChanged($pdo, (int)$id, 'removed');
        Response::ok(null, 'Schedule removed from the active timetable.');
    }

    private function requireManager(): bool
    {
        if (Auth::hasRole('chairperson')) return true;
        if (Auth::hasRole('program_coordinator') && $this->coordinatorProgramIds(Database::pdo())) return true;
        Response::fail('Forbidden.', 403);
        return false;
    }

    private function findActive(PDO $pdo, string $id): ?array
    {
        if (!ctype_digit($id) || (int)$id < 1) { Response::fail('Invalid schedule ID.', 422); return null; }
        $stmt = $pdo->prepare('SELECT sc.*, tl.faculty_id, tl.subject_id, tl.section_id, sec.program_id, sec.semester_id FROM schedules sc
            JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
            JOIN sections sec ON sec.id = tl.section_id WHERE sc.id = ? AND sc.is_active = 1');
        $stmt->execute([(int)$id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) { Response::fail('Schedule not found.', 404); return null; }
        if (!Auth::hasRole('chairperson') && !in_array((int)$row['program_id'], $this->coordinatorProgramIds($pdo), true)) {
            Response::fail('Forbidden.', 403); return null;
        }
        if (!Auth::hasRole('chairperson') && (int)$row['faculty_id'] !== (int)Auth::id()) {
            $coordinator = $pdo->prepare("SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
                WHERE ur.user_id = ? AND r.code = 'program_coordinator' LIMIT 1");
            $coordinator->execute([(int)$row['faculty_id']]);
            if ($coordinator->fetchColumn()) { Response::fail('Forbidden.', 403); return null; }
        }
        return $row;
    }

    private function validate(Request $request, ?array $current = null): ?array
    {
        $ids = [];
        foreach (['faculty_id', 'subject_id', 'section_id'] as $key) {
            $value = $current[$key] ?? $request->input($key);
            if (!ctype_digit((string)$value) || (int)$value < 1) {
                Response::fail('Select a faculty member, subject, and section.', 422); return null;
            }
            $ids[$key] = (int)$value;
        }
        $day = (string)$request->input('day_of_week', $current['day_of_week'] ?? '');
        $start = (string)$request->input('start_time', $current['start_time'] ?? '');
        $end = (string)$request->input('end_time', $current['end_time'] ?? '');
        $modality = (string)$request->input('modality', $current['modality'] ?? 'Face to Face');
        $meetingType = (string)$request->input('meeting_type', $current['meeting_type'] ?? 'Lecture');
        $roomValue = $request->input('room_id', $current['room_id'] ?? null);
        $roomId = $roomValue === '' || $roomValue === null ? null : (int)$roomValue;
        if (!in_array($day, self::DAYS, true) || !preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $start)
            || !preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $end) || $end <= $start
            || $start < '07:00' || $end > '20:00'
            || !in_array($modality, self::MODALITIES, true)
            || !in_array($meetingType, self::MEETING_TYPES, true)
            || ($modality !== 'Online' && (!$roomId || $roomId < 1))) {
            Response::fail('Enter a valid day, time between 7:00 AM and 8:00 PM, modality, and room.', 422); return null;
        }
        return $ids + ['day_of_week' => $day, 'start_time' => $start, 'end_time' => $end,
            'room_id' => $roomId, 'modality' => $modality, 'meeting_type' => $meetingType];
    }

    private function validAssignment(PDO $pdo, array $data): bool
    {
        if (!Auth::hasRole('chairperson')) {
            $scope = $pdo->prepare('SELECT program_id FROM sections WHERE id = ?');
            $scope->execute([$data['section_id']]);
            if (!in_array((int)$scope->fetchColumn(), $this->coordinatorProgramIds($pdo), true)) {
                Response::fail('Forbidden.', 403); return false;
            }
            if ((int)$data['faculty_id'] !== (int)Auth::id()) {
                $coordinator = $pdo->prepare("SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
                    WHERE ur.user_id = ? AND r.code = 'program_coordinator' LIMIT 1");
                $coordinator->execute([$data['faculty_id']]);
                if ($coordinator->fetchColumn()) { Response::fail('Forbidden.', 403); return false; }
            }
        }
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM users u
            JOIN faculty_profiles fp ON fp.user_id = u.id AND fp.is_active = 1
            JOIN program_assignments pa ON pa.user_id = u.id AND pa.is_active = 1
            JOIN sections sec ON sec.program_id = pa.program_id AND sec.is_active = 1
            JOIN subjects sub ON sub.id = ? AND sub.is_active = 1
            JOIN program_curriculum pc ON pc.program_id = sec.program_id AND pc.subject_id = sub.id
                AND pc.year_level = sec.year_level AND pc.is_active = 1
            JOIN semesters sem ON sem.id = sec.semester_id
                AND (pc.semester_code IS NULL OR pc.semester_code = sem.code)
            WHERE u.id = ? AND u.is_active = 1 AND sec.id = ?");
        $stmt->execute([$data['subject_id'], $data['faculty_id'], $data['section_id']]);
        if (!(int)$stmt->fetchColumn()) {
            Response::fail('Faculty, subject, and section must be active and match the assigned program, year level, and semester.', 422);
            return false;
        }
        if ($data['room_id'] !== null) {
            $room = $pdo->prepare('SELECT COUNT(*) FROM rooms WHERE id = ? AND is_active = 1');
            $room->execute([$data['room_id']]);
            if (!(int)$room->fetchColumn()) { Response::fail('Select an active room.', 422); return false; }
        }
        return true;
    }

    private function available(PDO $pdo, array $data, ?int $exceptId = null): bool
    {
        $term = $pdo->prepare('SELECT semester_id FROM sections WHERE id = ?');
        $term->execute([$data['section_id']]);
        $semesterId = (int)$term->fetchColumn();
        if (!$semesterId) { Response::fail('Section not found.', 422); return false; }
        $stmt = $pdo->prepare("SELECT sc.id,
            CASE WHEN tl.faculty_id = ? THEN 'faculty' ELSE 'room' END AS conflict_type
            FROM schedules sc JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
            JOIN sections sec ON sec.id = tl.section_id
            WHERE sc.is_active = 1 AND tl.is_active = 1 AND sec.semester_id = ?
              AND sc.day_of_week = ? AND sc.start_time < ? AND sc.end_time > ?
              AND sc.id <> ? AND (tl.faculty_id = ? OR (sc.room_id = ? AND ? IS NOT NULL))
            LIMIT 1");
        $stmt->execute([$data['faculty_id'], $semesterId, $data['day_of_week'],
            $data['end_time'], $data['start_time'], $exceptId ?? 0,
            $data['faculty_id'], $data['room_id'], $data['room_id']]);
        $conflict = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($conflict) {
            Response::fail($conflict['conflict_type'] === 'faculty'
                ? 'This faculty member already has a class at that time.'
                : 'This room is already booked at that time.', 409);
            return false;
        }
        return true;
    }

    private function coordinatorProgramIds(PDO $pdo): array
    {
        if (!Auth::hasRole('program_coordinator')) return [];
        $stmt = $pdo->prepare("SELECT DISTINCT pa.program_id FROM program_assignments pa
            JOIN roles r ON r.id = pa.role_id WHERE pa.user_id = ? AND pa.is_active = 1
            AND r.code = 'program_coordinator'");
        $stmt->execute([Auth::id()]);
        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
    }
}
