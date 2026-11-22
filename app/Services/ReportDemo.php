<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\Database;
use PDO;

/** Supplies fictional chart points in local development only. */
final class ReportDemo
{
    public static function enabled(): bool
    {
        return in_array(strtolower((string)app_env('APP_ENV', 'local')), ['local', 'development', 'test'], true)
            && filter_var(app_env('APP_REPORT_DEMO', 'false'), FILTER_VALIDATE_BOOL);
    }

    public static function weekly(int $termId, array $programIds = [], ?int $selectedProgram = null): array
    {
        if (!self::enabled() || $termId < 1) return [];

        $sql = 'SELECT week_start, SUM(scheduled_sessions) AS scheduled_sessions,
            SUM(full_period_sessions) AS full_period_sessions,
            ROUND(SUM(verified_hours), 2) AS verified_hours
            FROM report_demo_weekly WHERE semester_id = ?';
        $params = [$termId];
        if ($programIds) {
            $sql .= ' AND program_id IN (' . implode(',', array_fill(0, count($programIds), '?')) . ')';
            array_push($params, ...array_map('intval', $programIds));
        }
        if ($selectedProgram !== null) {
            $sql .= ' AND program_id = ?';
            $params[] = $selectedProgram;
        }
        $sql .= ' GROUP BY week_start ORDER BY week_start';
        $stmt = Database::pdo()->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    /** Fictional individual preview, stable for the same faculty and term. */
    public static function facultyWeekly(int $termId, int $facultyId): array
    {
        if (!self::enabled() || $termId < 1 || $facultyId < 1) return [];

        $stmt = Database::pdo()->prepare('SELECT DISTINCT week_start FROM report_demo_weekly
            WHERE semester_id = ? ORDER BY week_start');
        $stmt->execute([$termId]);
        $weeks = $stmt->fetchAll(PDO::FETCH_COLUMN);
        $points = [];
        foreach ($weeks as $index => $week) {
            $scheduled = 4 + ($facultyId + $index) % 2;
            $full = $scheduled - ($facultyId + $index * 2) % 3;
            $points[] = ['week_start' => $week, 'scheduled_sessions' => $scheduled,
                'full_period_sessions' => $full,
                'verified_hours' => round($full * (1.5 + ($facultyId % 3) * 0.25), 2)];
        }
        return $points;
    }
}
