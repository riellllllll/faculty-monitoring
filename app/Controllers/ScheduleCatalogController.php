<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Audit;
use App\Core\Auth;
use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use PDOException;

class ScheduleCatalogController
{
    private const SUBJECT_TYPES = [
        'Core', 'Elective', 'Laboratory', 'PE', 'General Education',
        'NSTP', 'Institutional', 'Practicum', 'Thesis',
    ];

    public function curriculum(Request $request): void
    {
        $programId = filter_var($request->input('program_id'), FILTER_VALIDATE_INT);
        $subjectId = filter_var($request->input('subject_id'), FILTER_VALIDATE_INT);
        $type = (string)$request->input('subject_type', 'Core');
        $yearLevel = filter_var($request->input('year_level'), FILTER_VALIDATE_INT);
        $semesterCode = (string)$request->input('semester_code', '');
        if (!$programId || !$subjectId || !in_array($type, self::SUBJECT_TYPES, true)
            || !in_array($semesterCode, ['', 'S1', 'S2', 'SUM'], true)
            || $yearLevel === false || $yearLevel < 1 || $yearLevel > 5) {
            Response::fail('Select a program, subject, type, and year level.', 422); return;
        }
        if (!$this->exists('programs', (int)$programId) || !$this->exists('subjects', (int)$subjectId)) return;
        try {
            Database::pdo()->prepare('INSERT INTO program_curriculum (program_id, subject_id, subject_type, year_level, semester_code)
                VALUES (?, ?, ?, ?, ?)')->execute([$programId, $subjectId, $type, $yearLevel, $semesterCode ?: null]);
            Audit::log(Auth::id(), 'curriculum.assign', 'program_curriculum', null, null,
                ['program_id' => $programId, 'subject_id' => $subjectId]);
            Response::ok(null, 'Subject assigned to program.');
        } catch (PDOException $e) {
            Response::fail($e->getCode() === '23000' ? 'This subject is already assigned to that program.'
                : 'Could not assign subject.', $e->getCode() === '23000' ? 409 : 500);
        }
    }

    public function subject(Request $request): void
    {
        $code = strtoupper(trim((string)$request->input('code', '')));
        $title = trim((string)$request->input('title', ''));
        $units = filter_var($request->input('units'), FILTER_VALIDATE_INT);
        $programId = filter_var($request->input('program_id'), FILTER_VALIDATE_INT);
        $subjectType = (string)$request->input('subject_type', 'Core');
        $yearLevel = filter_var($request->input('year_level'), FILTER_VALIDATE_INT);
        $semesterCode = (string)$request->input('semester_code', '');
        $lectureHours = filter_var($request->input('lecture_hours', 0), FILTER_VALIDATE_FLOAT);
        $labHours = filter_var($request->input('lab_hours', 0), FILTER_VALIDATE_FLOAT);
        if (!preg_match('/^[A-Z0-9 -]{2,20}$/', $code) || $title === '' || mb_strlen($title) > 150
            || $units === false || $units < 1 || $units > 12 || !$programId
            || !in_array($subjectType, self::SUBJECT_TYPES, true)
            || !in_array($semesterCode, ['', 'S1', 'S2', 'SUM'], true)
            || $yearLevel === false || $yearLevel < 1 || $yearLevel > 5
            || $lectureHours === false || $lectureHours < 0 || $lectureHours > 20
            || $labHours === false || $labHours < 0 || $labHours > 20) {
            Response::fail('Enter a valid subject, program, year level, and contact hours.', 422); return;
        }
        $pdo = Database::pdo();
        if (!$this->exists('programs', (int)$programId)) return;
        try {
            $pdo->beginTransaction();
            $pdo->prepare('INSERT INTO subjects (code, title, units, lecture_hours, lab_hours) VALUES (?, ?, ?, ?, ?)')
                ->execute([$code, $title, $units, $lectureHours, $labHours]);
            $id = (int)$pdo->lastInsertId();
            $pdo->prepare('INSERT INTO program_curriculum (program_id, subject_id, subject_type, year_level, semester_code) VALUES (?, ?, ?, ?, ?)')
                ->execute([(int)$programId, $id, $subjectType, $yearLevel, $semesterCode ?: null]);
            $pdo->commit();
            Audit::log(Auth::id(), 'subject.create', 'subjects', $id, null, ['code' => $code, 'title' => $title]);
            Response::ok(['id' => $id], 'Subject added.');
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            Response::fail($e->getCode() === '23000' ? 'Subject code already exists.' : 'Could not add subject.', $e->getCode() === '23000' ? 409 : 500);
        }
    }

    public function term(Request $request): void
    {
        $startYear = filter_var($request->input('start_year'), FILTER_VALIDATE_INT);
        $code = strtoupper(trim((string)$request->input('code', '')));
        $name = trim((string)$request->input('name', ''));
        $start = (string)$request->input('start_date', '');
        $end = (string)$request->input('end_date', '');
        if ($startYear === false || $startYear < 2020 || $startYear > 2100
            || !preg_match('/^[A-Z0-9 -]{1,20}$/', $code) || $name === '' || mb_strlen($name) > 40
            || !$this->validDate($start) || !$this->validDate($end) || $end < $start
            || (int)substr($start, 0, 4) < $startYear || (int)substr($end, 0, 4) > $startYear + 1) {
            Response::fail('Enter a valid academic year, semester, and date range.', 422); return;
        }
        $pdo = Database::pdo();
        $label = $startYear . '-' . ($startYear + 1);
        try {
            $pdo->beginTransaction();
            $find = $pdo->prepare('SELECT id FROM school_years WHERE label = ?');
            $find->execute([$label]);
            $yearId = (int)$find->fetchColumn();
            if (!$yearId) {
                $pdo->prepare('INSERT INTO school_years (label, start_year, end_year) VALUES (?, ?, ?)')
                    ->execute([$label, $startYear, $startYear + 1]);
                $yearId = (int)$pdo->lastInsertId();
            }
            $pdo->prepare('INSERT INTO semesters (school_year_id, name, code, start_date, end_date)
                VALUES (?, ?, ?, ?, ?)')->execute([$yearId, $name, $code, $start, $end]);
            $id = (int)$pdo->lastInsertId();
            $pdo->commit();
            Audit::log(Auth::id(), 'semester.create', 'semesters', $id, null, ['school_year' => $label, 'code' => $code]);
            Response::ok(['id' => $id], 'Academic term added.');
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            Response::fail($e->getCode() === '23000' ? 'That semester already exists in this school year.' : 'Could not add term.', $e->getCode() === '23000' ? 409 : 500);
        }
    }

    public function section(Request $request): void
    {
        $programId = filter_var($request->input('program_id'), FILTER_VALIDATE_INT);
        $semesterId = filter_var($request->input('semester_id'), FILTER_VALIDATE_INT);
        $code = strtoupper(trim((string)$request->input('code', '')));
        $name = trim((string)$request->input('name', ''));
        $yearLevel = filter_var($request->input('year_level'), FILTER_VALIDATE_INT);
        if (!$programId || !$semesterId || !preg_match('/^[A-Z0-9 -]{2,20}$/', $code)
            || $name === '' || mb_strlen($name) > 80 || $yearLevel === false
            || $yearLevel < 1 || $yearLevel > 5) {
            Response::fail('Enter a valid program, term, section, and year level.', 422); return;
        }
        if (!$this->exists('programs', (int)$programId) || !$this->exists('semesters', (int)$semesterId)) return;
        $pdo = Database::pdo();
        try {
            $pdo->prepare('INSERT INTO sections (program_id, semester_id, code, name, year_level)
                VALUES (?, ?, ?, ?, ?)')->execute([$programId, $semesterId, $code, $name, $yearLevel]);
            $id = (int)$pdo->lastInsertId();
            Audit::log(Auth::id(), 'section.create', 'sections', $id, null, ['code' => $code, 'name' => $name]);
            Response::ok(['id' => $id], 'Section added.');
        } catch (PDOException $e) {
            Response::fail($e->getCode() === '23000' ? 'Section code already exists in this term.' : 'Could not add section.', $e->getCode() === '23000' ? 409 : 500);
        }
    }

    public function room(Request $request): void
    {
        $code = strtoupper(trim((string)$request->input('code', '')));
        $name = trim((string)$request->input('name', ''));
        $building = trim((string)$request->input('building', ''));
        $type = (string)$request->input('room_type', 'Lecture');
        $capacity = filter_var($request->input('capacity', 0), FILTER_VALIDATE_INT);
        if (!preg_match('/^[A-Z0-9 -]{2,20}$/', $code) || $name === '' || mb_strlen($name) > 100
            || mb_strlen($building) > 100 || !in_array($type, ['Lecture','Laboratory','Auditorium','Online'], true)
            || $capacity === false || $capacity < 0 || $capacity > 1000) {
            Response::fail('Enter a valid room code, name, type, and capacity.', 422); return;
        }
        $pdo = Database::pdo();
        try {
            $pdo->prepare('INSERT INTO rooms (code, name, building, room_type, capacity, qr_public_code) VALUES (?, ?, ?, ?, ?, ?)')
                ->execute([$code, $name, $building ?: null, $type, $capacity, bin2hex(random_bytes(16))]);
            $id = (int)$pdo->lastInsertId();
            Audit::log(Auth::id(), 'room.create', 'rooms', $id, null, ['code' => $code, 'name' => $name]);
            Response::ok(['id' => $id], 'Room added.');
        } catch (PDOException $e) {
            Response::fail($e->getCode() === '23000' ? 'Room code already exists.' : 'Could not add room.', $e->getCode() === '23000' ? 409 : 500);
        }
    }

    private function exists(string $table, int $id): bool
    {
        $stmt = Database::pdo()->prepare("SELECT COUNT(*) FROM $table WHERE id = ? AND is_active = 1");
        $stmt->execute([$id]);
        if ((int)$stmt->fetchColumn()) return true;
        Response::fail('Selected catalog item is unavailable.', 422);
        return false;
    }

    private function validDate(string $date): bool
    {
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date)) return false;
        $parts = array_map('intval', explode('-', $date));
        return checkdate($parts[1], $parts[2], $parts[0]);
    }
}
