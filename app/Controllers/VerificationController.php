<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Audit;
use App\Core\Auth;
use App\Core\Database;
use App\Core\RateLimiter;
use App\Core\Request;
use App\Core\Response;
use App\Services\NotificationService;
use DateTimeImmutable;
use DateTimeZone;
use PDO;
use PDOException;

final class VerificationController
{
    public function current(Request $request): void
    {
        $code = $request->input('code');
        $room = $this->room($code);
        $classes = $this->eligibleClasses((int)$room['id']);
        Response::ok(['room' => $room, 'classes' => $classes]);
    }

    public function submit(Request $request): void
    {
        if (!str_contains($request->headers['content-type'] ?? '', 'application/json')) {
            Response::fail('JSON content type is required.', 415);
        }
        RateLimiter::enforce('class-verification', (string)Auth::id(), 12, 3600, 3600);
        $room = $this->room($request->input('code'));
        $scheduleId = $request->input('schedule_id');
        if (!is_int($scheduleId) || $scheduleId < 1) Response::fail('Choose a scheduled class.', 422);
        $class = null;
        foreach ($this->eligibleClasses((int)$room['id']) as $candidate) {
            if ((int)$candidate['schedule_id'] === $scheduleId) $class = $candidate;
        }
        if (!$class) Response::fail('No current class matches this room and your schedule.', 409);

        $photo = $request->input('selfie');
        if (!is_string($photo) || strlen($photo) > 3000000
            || !str_starts_with($photo, 'data:image/jpeg;base64,')) {
            Response::fail('Capture a new classroom selfie (2 MB maximum).', 422);
        }
        $bytes = base64_decode(substr($photo, 23), true);
        if ($bytes === false || strlen($bytes) > 2000000 || strlen($bytes) < 1000) {
            Response::fail('The selfie image is invalid or too large.', 422);
        }
        $size = @getimagesizefromstring($bytes);
        if (!$size || $size[0] < 320 || $size[1] < 240 || $size[0] > 2048 || $size[1] > 2048
            || (new \finfo(FILEINFO_MIME_TYPE))->buffer($bytes) !== 'image/jpeg') {
            Response::fail('Capture a clear JPEG selfie with the class in view.', 422);
        }

        $now = $this->now();
        try {
            $stmt = Database::pdo()->prepare('INSERT INTO class_verifications
                (schedule_id, room_id, class_date, selfie_jpeg, submitted_at)
                VALUES (?, ?, ?, ?, ?)');
            $stmt->bindValue(1, $scheduleId, PDO::PARAM_INT);
            $stmt->bindValue(2, (int)$room['id'], PDO::PARAM_INT);
            $stmt->bindValue(3, $now->format('Y-m-d'));
            $stmt->bindValue(4, $bytes, PDO::PARAM_LOB);
            $stmt->bindValue(5, $now->format('Y-m-d H:i:s'));
            $stmt->execute();
            $id = (int)Database::pdo()->lastInsertId();
            Audit::log(Auth::id(), 'verification.submit', 'class_verifications', $id);
            Response::ok(['id' => $id, 'status' => 'pending'], 'Class selfie submitted for review.');
        } catch (PDOException $error) {
            if ($error->getCode() === '23000') Response::fail('A selfie for this class was already submitted today.', 409);
            error_log('Class verification submission failed: ' . get_class($error));
            Response::fail('Could not save the classroom selfie.', 500);
        }
    }

    public function index(Request $request): void
    {
        $status = $request->input('status', 'all');
        if (!in_array($status, ['all', 'pending', 'approved', 'rejected'], true)) {
            Response::fail('Invalid review status.', 422);
        }
        $params = [];
        $filters = [];
        if (Auth::hasRole('chairperson')) {
            // Department scope.
        } elseif (Auth::hasRole('program_coordinator')) {
            $programs = $this->coordinatorPrograms();
            if (!$programs) Response::ok([]);
            $filters[] = 'sec.program_id IN (' . implode(',', array_fill(0, count($programs), '?')) . ')';
            $params = $programs;
        } elseif (Auth::hasRole('faculty')) {
            $filters[] = 'tl.faculty_id = ?';
            $params = [(int)Auth::id()];
        } else {
            Response::fail('Forbidden.', 403);
        }
        if ($status !== 'all') {
            $filters[] = 'v.status = ?';
            $params[] = $status;
        }
        $where = $filters ? 'WHERE ' . implode(' AND ', $filters) : '';
        $stmt = Database::pdo()->prepare("SELECT v.id, v.class_date, v.submitted_at, v.status,
            v.review_note, v.reviewed_at, tl.faculty_id, sec.program_id,
            CONCAT_WS(' ', u.first_name, u.last_name) AS faculty_name,
            sub.code AS subject_code, sub.title AS subject_title, sec.code AS section_code,
            r.code AS room_code
            FROM class_verifications v
            JOIN schedules sc ON sc.id = v.schedule_id
            JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
            JOIN users u ON u.id = tl.faculty_id
            JOIN subjects sub ON sub.id = tl.subject_id
            JOIN sections sec ON sec.id = tl.section_id
            JOIN rooms r ON r.id = v.room_id
            {$where} ORDER BY v.submitted_at DESC LIMIT 100");
        $stmt->execute($params);
        Response::ok($stmt->fetchAll(PDO::FETCH_ASSOC));
    }

    public function photo(Request $request, string $id): void
    {
        $record = $this->record($id);
        if (!$this->canView($record)) Response::fail('Forbidden.', 403);
        $stmt = Database::pdo()->prepare('SELECT selfie_jpeg FROM class_verifications WHERE id = ?');
        $stmt->execute([(int)$id]);
        $bytes = $stmt->fetchColumn();
        if (!is_string($bytes)) Response::fail('Selfie not found.', 404);
        http_response_code(200);
        header('Content-Type: image/jpeg');
        header('Cache-Control: no-store');
        header('Content-Disposition: inline; filename="class-selfie.jpg"');
        echo $bytes;
        exit;
    }

    public function decide(Request $request, string $id): void
    {
        if (!Auth::hasRole('chairperson', 'program_coordinator')) Response::fail('Forbidden.', 403);
        $record = $this->record($id);
        if ((int)$record['faculty_id'] === (int)Auth::id() || !$this->canView($record)) {
            Response::fail('You cannot review this submission.', 403);
        }
        if (!str_contains($request->headers['content-type'] ?? '', 'application/json')) {
            Response::fail('JSON content type is required.', 415);
        }
        $status = $request->input('status');
        $note = $request->input('review_note', '');
        if (!in_array($status, ['approved', 'rejected'], true) || !is_string($note)
            || mb_strlen(trim($note)) > 255 || ($status === 'rejected' && trim($note) === '')) {
            Response::fail('Choose a decision and explain any rejection (255 characters maximum).', 422);
        }
        $stmt = Database::pdo()->prepare("UPDATE class_verifications
            SET status = ?, review_note = ?, reviewed_by = ?, reviewed_at = ?
            WHERE id = ? AND status = 'pending'");
        $stmt->execute([$status, trim($note) ?: null, (int)Auth::id(),
            $this->now()->format('Y-m-d H:i:s'), (int)$id]);
        if ($stmt->rowCount() !== 1) Response::fail('This submission has already been reviewed.', 409);
        Audit::log(Auth::id(), 'verification.' . $status, 'class_verifications', (int)$id);
        NotificationService::send(Database::pdo(), (int)$record['faculty_id'], 'verification',
            'Class selfie ' . $status, $status === 'approved' ? 'Your classroom selfie was approved.' : trim($note),
            '/verification');
        Response::ok(['status' => $status], 'Submission ' . $status . '.');
    }

    private function room(mixed $code): array
    {
        if (!is_string($code) || !preg_match('/^[a-f0-9]{32}$/', $code)) {
            Response::fail('Room QR is invalid.', 422);
        }
        $stmt = Database::pdo()->prepare('SELECT id, code, name, building FROM rooms
            WHERE qr_public_code = ? AND is_active = 1 AND room_type <> \'Online\' LIMIT 1');
        $stmt->execute([$code]);
        $room = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$room) Response::fail('Room QR was not found.', 404);
        return $room;
    }

    private function eligibleClasses(int $roomId): array
    {
        $now = $this->now();
        $date = $now->format('Y-m-d');
        $time = $now->format('H:i:s');
        $stmt = Database::pdo()->prepare("SELECT sc.id AS schedule_id,
            TIME_FORMAT(sc.start_time, '%H:%i') AS start_time,
            TIME_FORMAT(sc.end_time, '%H:%i') AS end_time,
            sub.code AS subject_code, sub.title AS subject_title,
            sec.code AS section_code
            FROM schedules sc
            JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
            JOIN subjects sub ON sub.id = tl.subject_id
            JOIN sections sec ON sec.id = tl.section_id
            JOIN semesters sem ON sem.id = sec.semester_id
            WHERE sc.room_id = ? AND tl.faculty_id = ?
              AND sc.is_active = 1 AND sc.source = 'entered'
              AND tl.is_active = 1 AND sec.is_active = 1 AND sem.is_active = 1
              AND sc.modality <> 'Online'
              AND sc.day_of_week = ? AND sem.start_date <= ? AND sem.end_date >= ?
              AND sc.start_time <= ? AND sc.end_time > ?
            ORDER BY sc.start_time, sc.id");
        $stmt->execute([$roomId, (int)Auth::id(), $now->format('l'), $date, $date, $time, $time]);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    private function record(string $id): array
    {
        if (!ctype_digit($id) || (int)$id < 1) Response::fail('Submission not found.', 404);
        $stmt = Database::pdo()->prepare('SELECT v.id, tl.faculty_id, sec.program_id
            FROM class_verifications v
            JOIN schedules sc ON sc.id = v.schedule_id
            JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
            JOIN sections sec ON sec.id = tl.section_id WHERE v.id = ?');
        $stmt->execute([(int)$id]);
        $record = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$record) Response::fail('Submission not found.', 404);
        return $record;
    }

    private function canView(array $record): bool
    {
        return Auth::hasRole('chairperson')
            || (Auth::hasRole('program_coordinator')
                && in_array((int)$record['program_id'], $this->coordinatorPrograms(), true))
            || (Auth::hasRole('faculty') && (int)$record['faculty_id'] === (int)Auth::id());
    }

    private function coordinatorPrograms(): array
    {
        $stmt = Database::pdo()->prepare("SELECT DISTINCT pa.program_id
            FROM program_assignments pa JOIN roles r ON r.id = pa.role_id
            WHERE pa.user_id = ? AND pa.is_active = 1 AND r.code = 'program_coordinator'");
        $stmt->execute([(int)Auth::id()]);
        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
    }

    private function now(): DateTimeImmutable
    {
        return new DateTimeImmutable('now', new DateTimeZone(app_config()['app']['timezone']));
    }
}
