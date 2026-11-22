<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Audit;
use App\Core\Database;
use App\Core\RateLimiter;
use App\Core\Request;
use App\Core\Response;
use PDO;
use PDOException;

final class EmailChangeController
{
    public function confirm(Request $request): void
    {
        RateLimiter::enforce('email-verify-ip', RateLimiter::clientIp(), 15, 900, 900);
        $tokenInput = $request->input('token', '');
        $token = is_string($tokenInput) ? $tokenInput : '';
        if (!preg_match('/^[a-f0-9]{64}$/', $token)) {
            Response::fail('This confirmation link is invalid or expired.', 410);
        }
        RateLimiter::enforce('email-verify-token', hash('sha256', $token), 5, 900, 900);
        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare('SELECT t.id, t.user_id, t.previous_email, t.new_email
                FROM email_change_tokens t JOIN users u ON u.id = t.user_id
                WHERE t.token_hash = ? AND t.consumed_at IS NULL AND t.expires_at > NOW()
                  AND u.is_active = 1 AND u.email = t.previous_email FOR UPDATE');
            $stmt->execute([hash('sha256', $token)]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$row) {
                $pdo->rollBack();
                Response::fail('This confirmation link is invalid or expired.', 410);
            }
            $pdo->prepare('UPDATE users SET email = ? WHERE id = ? AND email = ?')
                ->execute([$row['new_email'], $row['user_id'], $row['previous_email']]);
            $pdo->prepare('UPDATE email_change_tokens SET consumed_at = NOW() WHERE id = ?')->execute([$row['id']]);
            $pdo->commit();
            Audit::log((int)$row['user_id'], 'email.change_verified', 'users', (int)$row['user_id'],
                ['email' => $row['previous_email']], ['email' => $row['new_email']]);
            Response::ok(null, 'Email confirmed. Use the new address to sign in.');
        } catch (PDOException $error) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            Response::fail($error->getCode() === '23000' ? 'This email address is already registered.' : 'Could not confirm the email address.',
                $error->getCode() === '23000' ? 409 : 500);
        }
    }
}
