<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use App\Services\ReportDemo;
use PDO;

class DashboardController
{
    public function stats(Request $request): void
    {
        $pdo = Database::pdo();
        $scope = Auth::hasRole('chairperson') ? 'department'
            : (Auth::hasRole('program_coordinator') ? 'program' : 'self');
        $programIds = [];
        if ($scope === 'program') {
            $stmt = $pdo->prepare("SELECT DISTINCT pa.program_id FROM program_assignments pa
                JOIN roles r ON r.id = pa.role_id WHERE pa.user_id = ? AND pa.is_active = 1
                AND r.code = 'program_coordinator'");
            $stmt->execute([(int)Auth::id()]);
            $programIds = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
        }

        $term = $pdo->query("SELECT sem.id, sem.name, sy.label AS school_year
            FROM semesters sem JOIN school_years sy ON sy.id = sem.school_year_id
            ORDER BY (CURDATE() BETWEEN sem.start_date AND sem.end_date) DESC,
                sem.start_date DESC LIMIT 1")->fetch(PDO::FETCH_ASSOC) ?: null;
        $weekly = $term && $scope === 'self'
            ? ReportDemo::facultyWeekly((int)$term['id'], (int)Auth::id())
            : ($term && ($scope !== 'program' || $programIds)
                ? ReportDemo::weekly((int)$term['id'], $programIds)
                : []);

        Response::ok([
            'scope' => $scope,
            'stats' => ['scheduled_sessions' => 0, 'full_period_sessions' => 0,
                'verified_hours' => 0, 'pending_manual_requests' => 0],
            'recent_sessions' => [],
            'chart_weekly' => $weekly,
            'chart_source' => $weekly ? 'demo' : 'none',
            'chart_term' => $term,
        ]);
    }
}
