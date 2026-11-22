<?php
declare(strict_types=1);

namespace App\Core;

class Audit
{
    public static function log(?int $userId, string $action, string $entityType, ?int $entityId = null, mixed $old = null, mixed $new = null): void
    {
        $description = null;
        if ($old !== null || $new !== null) {
            $parts = [];
            if ($old !== null) $parts[] = 'old=' . json_encode($old);
            if ($new !== null) $parts[] = 'new=' . json_encode($new);
            $description = substr(implode(' | ', $parts), 0, 500);
        }
        try {
            $stmt = Database::pdo()->prepare(
                'INSERT INTO audit_logs (user_id, action, entity_type, entity_id, description, ip_address, user_agent)
                 VALUES (?, ?, ?, ?, ?, ?, ?)'
            );
            $stmt->execute([
                $userId,
                $action,
                $entityType,
                $entityId,
                $description,
                $_SERVER['REMOTE_ADDR'] ?? null,
                $_SERVER['HTTP_USER_AGENT'] ?? null,
            ]);
        } catch (\Throwable $e) {
            error_log('Audit log failed: ' . get_class($e));
        }
    }
}
