<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Audit;
use App\Core\Auth;
use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use App\Core\RateLimiter;
use App\Core\Session;
use App\Services\AccountInvitationService;
use PDO;

/**
 * Account profile and password settings for the authenticated user.
 */
class SettingsController
{
    // -------------------------------------------------------------------------
    // My Account
    // -------------------------------------------------------------------------
    public function profile(Request $request): void
    {
        $pdo = Database::pdo();
        $me  = (int)Auth::id();

        $stmt = $pdo->prepare(
            "SELECT u.id, u.employee_no, u.email, u.first_name, u.middle_name, u.last_name,
                    u.suffix, u.phone, u.must_change_password, u.last_login_at,
                    fp.rank_code, fp.employment_type, fp.designation, fp.hire_date,
                    d.name AS department_name
               FROM users u
               LEFT JOIN faculty_profiles fp ON fp.user_id = u.id
               LEFT JOIN departments d ON d.id = fp.department_id
              WHERE u.id = ? LIMIT 1"
        );
        $stmt->execute([$me]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC) ?: [];

        $progs = $pdo->prepare(
            "SELECT p.code, p.name FROM program_assignments pa
               JOIN programs p ON p.id = pa.program_id
              WHERE pa.user_id = ? AND pa.is_active = 1 ORDER BY p.code"
        );
        $progs->execute([$me]);

        $row['roles']        = Auth::roles();
        $row['capabilities'] = Auth::capabilities();
        $row['programs']     = $progs->fetchAll(PDO::FETCH_ASSOC);
        $pending = $pdo->prepare('SELECT new_email FROM email_change_tokens WHERE user_id = ?
            AND consumed_at IS NULL AND expires_at > NOW() ORDER BY id DESC LIMIT 1');
        $pending->execute([$me]);
        $row['pending_email'] = $pending->fetchColumn() ?: null;

        Response::ok($row);
    }

    public function updateProfile(Request $request): void
    {
        $me  = (int)Auth::id();
        $pdo = Database::pdo();

        $fields = [];
        $params = [];

        foreach (['first_name', 'last_name'] as $required) {
            $v = $request->input($required);
            if ($v !== null && (!is_string($v) || trim($v) === '' || mb_strlen(trim($v)) > 80)) {
                Response::fail(ucfirst(str_replace('_', ' ', $required)) . ' must be 1 to 80 characters.', 422);
                return;
            }
        }

        $lengths = ['first_name' => 80, 'last_name' => 80, 'middle_name' => 80, 'suffix' => 20, 'phone' => 30];
        foreach (['first_name', 'last_name', 'middle_name', 'suffix', 'phone'] as $f) {
            $value = $request->input($f);
            if ($value !== null) {
                if (!is_string($value) || mb_strlen(trim($value)) > $lengths[$f]) {
                    Response::fail('Profile field is too long or invalid.', 422);
                    return;
                }
                $fields[] = "$f = ?";
                $params[] = trim($value);
            }
        }

        $email = $request->input('email');
        $pendingEmail = null;
        $currentEmail = (string)Auth::user()['email'];
        if ($email !== null) {
            if (!is_string($email)) {
                Response::fail('That email address is not valid.', 422);
                return;
            }
            $email = strtolower(trim($email));
            if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 120) {
                Response::fail('That email address is not valid.', 422);
                return;
            }
            if ($email !== $currentEmail) {
                $dupe = $pdo->prepare('SELECT COUNT(*) FROM users WHERE email = ? AND id <> ?');
                $dupe->execute([$email, $me]);
                if ((int)$dupe->fetchColumn() > 0) {
                    Response::fail('That email is already used by another account.', 409);
                    return;
                }
                RateLimiter::enforce('email-change-user', (string)$me, 3, 3600, 3600);
                $pendingEmail = $email;
            }
        }

        if (!$fields && $pendingEmail === null) {
            Response::fail('Nothing to update.', 422);
            return;
        }

        $before = $pdo->prepare('SELECT first_name, last_name, middle_name, suffix, phone, email FROM users WHERE id = ?');
        $before->execute([$me]);
        $old = $before->fetch(PDO::FETCH_ASSOC);

        if ($fields) {
            $params[] = $me;
            $pdo->prepare('UPDATE users SET ' . implode(', ', $fields) . ' WHERE id = ?')->execute($params);
        }

        $after = $pdo->prepare('SELECT first_name, last_name, middle_name, suffix, phone, email FROM users WHERE id = ?');
        $after->execute([$me]);

        if ($fields) Audit::log($me, 'profile.update', 'users', $me, $old, $after->fetch(PDO::FETCH_ASSOC));
        Auth::reset();

        $emailStatus = null;
        if ($pendingEmail !== null) {
            try {
                $name = trim((string)$request->input('first_name', Auth::user()['first_name']) . ' '
                    . (string)$request->input('last_name', Auth::user()['last_name']));
                $emailStatus = (new AccountInvitationService())->sendEmailChange($me, $currentEmail, $pendingEmail, $name);
            } catch (\Throwable $error) {
                error_log('Could not initiate email verification: ' . get_class($error));
                $emailStatus = 'failed';
            }
        }
        Response::ok(['email_status' => $emailStatus, 'pending_email' => $pendingEmail],
            $pendingEmail === null ? 'Profile updated.' : ($emailStatus === 'sent'
                ? 'Profile updated. Confirm the new email from the link we sent.'
                : 'Profile updated, but the confirmation email failed. Try again later.'));
    }

    public function changePassword(Request $request): void
    {
        $me       = (int)Auth::id();
        RateLimiter::enforce('password-change-ip', RateLimiter::clientIp(), 20, 900, 900);
        RateLimiter::enforce('password-change-user', (string)$me, 5, 900, 900);
        $current  = (string)$request->input('current_password', '');
        $new      = (string)$request->input('new_password', '');
        $confirm  = (string)$request->input('confirm_password', '');

        if ($current === '' || $new === '' || $confirm === '') {
            Response::fail('All three password fields are required.', 422);
            return;
        }
        if ($new !== $confirm) {
            Response::fail('The new password and its confirmation do not match.', 422);
            return;
        }
        if (strlen($new) < 8) {
            Response::fail('The new password must be at least 8 characters.', 422);
            return;
        }
        if (strlen($new) > 72) {
            Response::fail('The new password must be 72 characters or fewer.', 422);
            return;
        }

        $pdo  = Database::pdo();
        $stmt = $pdo->prepare('SELECT password_hash FROM users WHERE id = ?');
        $stmt->execute([$me]);
        $hash = (string)$stmt->fetchColumn();

        if (!password_verify($current, $hash)) {
            Audit::log($me, 'password.change_failed', 'users', $me);
            Response::fail('Your current password is incorrect.', 401);
            return;
        }
        if (password_verify($new, $hash)) {
            Response::fail('The new password must be different from the current one.', 422);
            return;
        }

        $pdo->prepare('UPDATE users SET password_hash = ?, must_change_password = 0, auth_version = auth_version + 1 WHERE id = ?')
            ->execute([password_hash($new, PASSWORD_BCRYPT, ['cost' => 12]), $me]);

        $version = $pdo->prepare('SELECT auth_version FROM users WHERE id = ?');
        $version->execute([$me]);
        Session::set('auth_version', (int)$version->fetchColumn());
        Session::regenerate();

        Audit::log($me, 'password.change', 'users', $me);
        Response::ok(null, 'Password changed.');
    }

}
