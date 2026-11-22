<?php
declare(strict_types=1);

namespace App\Services;

use App\Core\Database;
use PDO;
use Throwable;

final class AccountInvitationService
{
    /** Send credentials for a newly created account without storing the plain password. */
    public function sendInitialCredentials(int $userId, string $email, string $name, string $temporaryPassword): string
    {
        $loginUrl = app_config()['app']['url'] . '/#/login';
        $body = "Hello {$name},\n\nYour Faculty Monitoring System account is ready.\n\n"
            . "Login: {$loginUrl}\nEmail: {$email}\nTemporary password: {$temporaryPassword}\n\n"
            . "Sign in with this password, then change it in Settings before using the system.\n"
            . "If you did not expect this account, contact your department chairperson.\n";
        return $this->deliver($userId, $email, 'Your Faculty Monitoring System login', $body, 'initial_credentials');
    }

    /** Send a one-use, 24-hour recovery link. Never store or log the raw token. */
    public function send(int $userId, string $email, string $name): string
    {
        $token = bin2hex(random_bytes(32));
        $pdo = Database::pdo();
        $pdo->prepare('DELETE FROM account_setup_tokens WHERE user_id = ? AND consumed_at IS NULL')->execute([$userId]);
        $pdo->prepare('INSERT INTO account_setup_tokens (user_id, token_hash, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 24 HOUR))')
            ->execute([$userId, hash('sha256', $token)]);
        $url = app_config()['app']['url'] . '/#/set-password?token=' . rawurlencode($token);
        $body = "Hello {$name},\n\nYour Faculty Monitoring System account is ready.\n"
            . "Set your password using this secure link (valid for 24 hours):\n{$url}\n\n"
            . "If you did not expect this account, contact your department chairperson.\n";
        return $this->deliver($userId, $email, 'Set your Faculty Monitoring System password', $body, 'account_setup');
    }

    public function sendEmailChange(int $userId, string $previousEmail, string $newEmail, string $name): string
    {
        $token = bin2hex(random_bytes(32));
        $pdo = Database::pdo();
        $pdo->prepare('DELETE FROM email_change_tokens WHERE user_id = ? AND consumed_at IS NULL')->execute([$userId]);
        $pdo->prepare('INSERT INTO email_change_tokens (user_id, previous_email, new_email, token_hash, expires_at)
            VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 24 HOUR))')
            ->execute([$userId, $previousEmail, $newEmail, hash('sha256', $token)]);
        $url = app_config()['app']['url'] . '/#/verify-email?token=' . rawurlencode($token);
        $body = "Hello {$name},\n\nConfirm your new Faculty Monitoring System email address using this one-use link (valid for 24 hours):\n{$url}\n\n"
            . "If you did not request this change, contact your department chairperson.\n";
        return $this->deliver($userId, $newEmail, 'Confirm your new email address', $body, 'email_change');
    }

    private function deliver(int $userId, string $email, string $subject, string $body, string $template): string
    {
        try {
            (new SmtpMailer())->send($email, $subject, $body);
            $this->log($userId, $email, $template, 'sent', null);
            return 'sent';
        } catch (Throwable $e) {
            $error = 'SMTP delivery failed. Check the server mail configuration and logs.';
            error_log('Faculty Monitor email delivery failed for user ' . $userId . ': ' . get_class($e));
            $this->log($userId, $email, $template, 'failed', $error);
            return 'failed';
        }
    }

    private function log(int $userId, string $email, string $template, string $status, ?string $error): void
    {
        try {
            $stmt = Database::pdo()->prepare('INSERT INTO email_deliveries (user_id, recipient_email, template_code, status, error_message) VALUES (?, ?, ?, ?, ?)');
            $stmt->execute([$userId, $email, $template, $status, $error]);
        } catch (Throwable $e) {
            error_log('Faculty Monitor could not write email delivery log: ' . get_class($e));
        }
    }
}
