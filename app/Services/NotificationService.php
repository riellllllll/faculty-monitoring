<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\Auth;
use PDO;
use Throwable;

/** In-app messages are best effort; a notification failure never undoes a saved schedule. */
final class NotificationService
{
    public static function send(PDO $pdo, int $userId, string $type, string $title, string $body, ?string $link = null): void
    {
        if ($userId < 1) return;
        try {
            $stmt = $pdo->prepare('INSERT INTO notifications (user_id, type, title, body, link) VALUES (?, ?, ?, ?, ?)');
            $stmt->execute([$userId, $type, $title, $body, $link]);
        } catch (Throwable $error) {
            error_log('Notification delivery failed for user ' . $userId . ': ' . get_class($error));
        }
    }

    public static function scheduleChanged(PDO $pdo, int $scheduleId, string $action): void
    {
        try {
            $stmt = $pdo->prepare('SELECT tl.faculty_id, sec.semester_id, sub.code AS subject_code,
                sec.code AS section_code, sc.day_of_week,
                TIME_FORMAT(sc.start_time, \'%h:%i %p\') AS start_label,
                TIME_FORMAT(sc.end_time, \'%h:%i %p\') AS end_label
                FROM schedules sc
                JOIN teaching_loads tl ON tl.id = sc.teaching_load_id
                JOIN subjects sub ON sub.id = tl.subject_id
                JOIN sections sec ON sec.id = tl.section_id
                WHERE sc.id = ?');
            $stmt->execute([$scheduleId]);
            $slot = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$slot) return;

            $titles = ['added' => 'Class added to your schedule', 'updated' => 'Your schedule was changed',
                'removed' => 'Class removed from your schedule'];
            if (!isset($titles[$action])) return;
            $actor = Auth::user();
            $actorName = trim((string)($actor['first_name'] ?? '') . ' ' . (string)($actor['last_name'] ?? ''));
            $actorRole = Auth::hasRole('chairperson') ? 'Department Chairperson'
                : (Auth::hasRole('program_coordinator') ? 'Program Coordinator' : 'Schedule editor');
            $body = $slot['subject_code'] . ' · ' . $slot['section_code'] . ' · '
                . $slot['day_of_week'] . ', ' . $slot['start_label'] . '–' . $slot['end_label'] . '. '
                . 'By ' . ($actorName !== '' ? $actorName . ' (' . $actorRole . ')' : $actorRole) . '.';
            self::send($pdo, (int)$slot['faculty_id'], 'schedule', $titles[$action], $body,
                '/schedules?faculty=' . (int)$slot['faculty_id'] . '&term=' . (int)$slot['semester_id']);
        } catch (Throwable $error) {
            error_log('Schedule notification failed for slot ' . $scheduleId . ': ' . get_class($error));
        }
    }

    public static function schedulesRemoved(PDO $pdo, int $facultyId, int $semesterId, int $count): void
    {
        self::send($pdo, $facultyId, 'schedule', 'Classes removed from your schedule',
            $count . ' class ' . ($count === 1 ? 'slot was' : 'slots were') . ' removed from your timetable.',
            '/schedules?faculty=' . $facultyId . '&term=' . $semesterId);
    }
}
