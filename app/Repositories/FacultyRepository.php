<?php
declare(strict_types=1);

namespace App\Repositories;

use App\Core\Database;
use PDO;

class FacultyRepository
{
    public function list(array $filters = []): array
    {
        $sql = "SELECT u.id, u.employee_no, u.email, u.first_name, u.middle_name, u.last_name,
                       u.phone, u.is_active, u.last_login_at,
                       fp.id AS profile_id, fp.rank_code, fp.employment_type, fp.designation,
                       fp.field_of_specialization, fp.hire_date,
                       d.id AS department_id, d.name AS department_name,
                       GROUP_CONCAT(DISTINCT p.code ORDER BY p.code SEPARATOR ', ') AS program_codes,
                       (SELECT GROUP_CONCAT(DISTINCT r.code ORDER BY r.code SEPARATOR ', ')
                          FROM user_roles ur JOIN roles r ON r.id = ur.role_id
                         WHERE ur.user_id = u.id) AS role_codes
                FROM users u
                INNER JOIN faculty_profiles fp ON fp.user_id = u.id
                INNER JOIN departments d ON d.id = fp.department_id
                LEFT JOIN program_assignments pa ON pa.user_id = u.id AND pa.is_active = 1
                LEFT JOIN programs p ON p.id = pa.program_id
                WHERE fp.is_active = 1";
        $params = [];
        if (!empty($filters['department_id'])) {
            $sql .= ' AND fp.department_id = ?';
            $params[] = $filters['department_id'];
        }
        if (isset($filters['is_active'])) {
            $sql .= ' AND u.is_active = ?';
            $params[] = $filters['is_active'];
        }
        if (isset($filters['program_ids'])) {
            if (!$filters['program_ids']) return [];
            $in = implode(',', array_fill(0, count($filters['program_ids']), '?'));
            $sql .= " AND EXISTS (SELECT 1 FROM program_assignments scope_pa WHERE scope_pa.user_id = u.id AND scope_pa.is_active = 1 AND scope_pa.program_id IN ($in))";
            $params = array_merge($params, $filters['program_ids']);
        }
        if (!empty($filters['exclude_coordinators'])) {
            $sql .= " AND NOT EXISTS (SELECT 1 FROM user_roles scope_ur JOIN roles scope_r ON scope_r.id = scope_ur.role_id WHERE scope_ur.user_id = u.id AND scope_r.code = 'program_coordinator')";
        }
        $sql .= ' GROUP BY u.id, fp.id, d.id ORDER BY u.last_name, u.first_name';
        $stmt = Database::pdo()->prepare($sql);
        $stmt->execute($params);
        return $stmt->fetchAll(PDO::FETCH_ASSOC);
    }

    public function findById(int $id): ?array
    {
        $stmt = Database::pdo()->prepare(
            "SELECT u.id, u.employee_no, u.email, u.first_name, u.middle_name, u.last_name, u.phone, u.is_active,
                    fp.id AS profile_id, fp.rank_code, fp.employment_type, fp.designation, fp.field_of_specialization, fp.hire_date,
                    d.name AS department_name
             FROM users u
             INNER JOIN faculty_profiles fp ON fp.user_id = u.id AND fp.is_active = 1
             LEFT JOIN departments d ON d.id = fp.department_id
             WHERE u.id = ? LIMIT 1"
        );
        $stmt->execute([$id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row ?: null;
    }

    public function belongsToPrograms(int $userId, array $programIds): bool
    {
        if (!$programIds) return false;
        $in = implode(',', array_fill(0, count($programIds), '?'));
        $stmt = Database::pdo()->prepare("SELECT 1 FROM program_assignments WHERE user_id = ? AND is_active = 1 AND program_id IN ($in) LIMIT 1");
        $stmt->execute(array_merge([$userId], $programIds));
        return (bool)$stmt->fetchColumn();
    }

    public function isCoordinator(int $userId): bool
    {
        $stmt = Database::pdo()->prepare("SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ? AND r.code = 'program_coordinator' LIMIT 1");
        $stmt->execute([$userId]);
        return (bool)$stmt->fetchColumn();
    }

    public function countActive(): int
    {
        return (int) Database::pdo()->query(
            "SELECT COUNT(*) FROM users u INNER JOIN faculty_profiles fp ON fp.user_id = u.id WHERE u.is_active = 1"
        )->fetchColumn();
    }
}
