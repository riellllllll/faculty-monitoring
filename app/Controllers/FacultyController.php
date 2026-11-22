<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Request;
use App\Core\Response;
use App\Core\Auth;
use App\Core\Database;
use App\Repositories\FacultyRepository;

class FacultyController
{
    public function index(Request $request): void
    {
        $repo = new FacultyRepository();
        $filters = [];
        if ($request->query['department_id'] ?? null) $filters['department_id'] = (int)$request->query['department_id'];
        if (isset($request->query['is_active'])) $filters['is_active'] = (int)$request->query['is_active'];
        if (!Auth::hasRole('chairperson')) {
            $filters['program_ids'] = $this->programIds();
            $filters['exclude_coordinators'] = true;
        }
        Response::ok($repo->list($filters));
    }

    public function show(Request $request, string $id): void
    {
        $repo = new FacultyRepository();
        $row = $repo->findById((int)$id);
        if (!$row) { Response::fail('Faculty not found.', 404); return; }
        if (!Auth::hasRole('chairperson') && $repo->isCoordinator((int)$id)) {
            Response::fail('Forbidden.', 403); return;
        }
        if (!Auth::hasRole('chairperson') && !$repo->belongsToPrograms((int)$id, $this->programIds())) {
            Response::fail('Faculty not found.', 404); return;
        }
        Response::ok($row);
    }

    private function programIds(): array
    {
        $stmt = Database::pdo()->prepare("SELECT DISTINCT pa.program_id FROM program_assignments pa JOIN roles r ON r.id = pa.role_id WHERE pa.user_id = ? AND pa.is_active = 1 AND r.code = 'program_coordinator'");
        $stmt->execute([Auth::id()]);
        return array_map('intval', $stmt->fetchAll(\PDO::FETCH_COLUMN));
    }
}
