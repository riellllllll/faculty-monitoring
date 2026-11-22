<?php
declare(strict_types=1);

namespace App\Core;

use PDO;

/** Shared database-backed limits; keys are hashes, never raw email addresses. */
final class RateLimiter
{
    public static function clientIp(): string
    {
        // Do not trust user-controlled Forwarded/X-Forwarded-For headers.
        return (string)($_SERVER['REMOTE_ADDR'] ?? 'unknown');
    }

    public static function enforce(string $action, string $identity, int $limit, int $windowSeconds, int $cooldownSeconds): void
    {
        if (!self::consume($action, $identity, $limit, $windowSeconds, $cooldownSeconds)) {
            header('Retry-After: ' . $cooldownSeconds);
            Response::fail('Too many attempts. Please wait and try again.', 429);
        }
    }

    public static function consume(string $action, string $identity, int $limit, int $windowSeconds, int $cooldownSeconds): bool
    {
        $bucket = hash('sha256', $action . "\0" . strtolower(trim($identity)));
        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            $pdo->prepare('INSERT IGNORE INTO security_rate_limits (bucket_hash, window_started_at) VALUES (?, NOW())')
                ->execute([$bucket]);
            $stmt = $pdo->prepare('SELECT attempts, window_started_at, blocked_until, NOW() AS server_now
                FROM security_rate_limits WHERE bucket_hash = ? FOR UPDATE');
            $stmt->execute([$bucket]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            $now = strtotime($row['server_now']);
            $blocked = $row['blocked_until'] !== null && strtotime($row['blocked_until']) > $now;
            if ($blocked) {
                $pdo->commit();
                return false;
            }

            $reset = ($row['blocked_until'] !== null)
                || ($now - strtotime($row['window_started_at']) >= $windowSeconds);
            $attempts = $reset ? 0 : (int)$row['attempts'];
            if ($attempts >= $limit) {
                $pdo->prepare('UPDATE security_rate_limits SET blocked_until = DATE_ADD(NOW(), INTERVAL ? SECOND)
                    WHERE bucket_hash = ?')->execute([$cooldownSeconds, $bucket]);
                $pdo->commit();
                return false;
            }
            $pdo->prepare('UPDATE security_rate_limits SET attempts = ?, window_started_at =
                CASE WHEN ? = 1 THEN NOW() ELSE window_started_at END, blocked_until = NULL
                WHERE bucket_hash = ?')->execute([$attempts + 1, $reset ? 1 : 0, $bucket]);
            $pdo->commit();
            return true;
        } catch (\Throwable $error) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            throw $error;
        }
    }
}
