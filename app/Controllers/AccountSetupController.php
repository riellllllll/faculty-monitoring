<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Audit;
use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use App\Core\RateLimiter;
use PDO;

final class AccountSetupController
{
    public function setPassword(Request $request): void
    {
        $tokenInput = $request->input('token', '');
        $passwordInput = $request->input('password', '');
        $confirmInput = $request->input('confirm_password', '');
        $token = is_string($tokenInput) ? $tokenInput : '';
        $password = is_string($passwordInput) ? $passwordInput : '';
        $confirm = is_string($confirmInput) ? $confirmInput : '';
        RateLimiter::enforce('setup-ip', RateLimiter::clientIp(), 15, 900, 900);
        if (preg_match('/^[a-f0-9]{64}$/', $token)) {
            RateLimiter::enforce('setup-token', hash('sha256', $token), 5, 900, 900);
        }
        if (!preg_match('/^[a-f0-9]{64}$/', $token) || strlen($password) < 8 || strlen($password) > 72 || $password !== $confirm) {
            Response::fail('Invalid setup link or password. Use a matching password of 8 to 72 characters.', 422);
            return;
        }
        $pdo = Database::pdo();
        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare('SELECT t.id, t.user_id FROM account_setup_tokens t JOIN users u ON u.id = t.user_id WHERE t.token_hash = ? AND t.consumed_at IS NULL AND t.expires_at > NOW() AND u.is_active = 1 FOR UPDATE');
            $stmt->execute([hash('sha256', $token)]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$row) {
                $pdo->rollBack();
                Response::fail('This setup link is invalid or expired. Ask the chairperson to resend it.', 410);
                return;
            }
            $pdo->prepare('UPDATE users SET password_hash = ?, must_change_password = 0, auth_version = auth_version + 1 WHERE id = ?')
                ->execute([password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]), $row['user_id']]);
            $pdo->prepare('UPDATE account_setup_tokens SET consumed_at = NOW() WHERE id = ?')->execute([$row['id']]);
            $pdo->commit();
            Audit::log((int)$row['user_id'], 'password.setup', 'users', (int)$row['user_id']);
            Response::ok(null, 'Password set. You can sign in now.');
        } catch (\Throwable $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            error_log('Account password setup failed: ' . get_class($e));
            Response::fail('Could not set your password. Please try again.', 500);
        }
    }
}
