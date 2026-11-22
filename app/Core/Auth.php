<?php
declare(strict_types=1);

namespace App\Core;

use PDO;

class Auth
{
    private const DUMMY_HASH = '$2y$12$izzo86.JBdRXD.ER0VV1QeEvK1hPWsPQD7BqU5H5Bjs5geyjuPksy';
    /** Per-request cache: the identity is resolved once, not on every guard. */
    private static bool $loaded = false;
    private static ?array $cached = null;

    /** Forget the cached identity (call after login, logout or a profile edit). */
    public static function reset(): void
    {
        self::$loaded = false;
        self::$cached  = null;
    }

    public static function user(): ?array
    {
        if (self::$loaded) return self::$cached;

        self::$loaded = true;
        Session::start();
        $id = Session::get('user_id');
        if (!$id) return self::$cached = null;

        $lastActivity = Session::get('last_activity');
        $idleMinutes = filter_var(app_env('SESSION_IDLE_TIMEOUT', '30'), FILTER_VALIDATE_INT,
            ['options' => ['min_range' => 5, 'max_range' => 480]]) ?: 30;
        if (is_int($lastActivity) && time() - $lastActivity > $idleMinutes * 60) {
            Session::destroy();
            return self::$cached = null;
        }
        Session::set('last_activity', time());

        $stmt = Database::pdo()->prepare(
            "SELECT u.*,
                    (SELECT GROUP_CONCAT(DISTINCT r.code ORDER BY r.code)
                       FROM user_roles ur
                       JOIN roles r ON r.id = ur.role_id
                      WHERE ur.user_id = u.id) AS role_codes,
                    (SELECT GROUP_CONCAT(DISTINCT c.code ORDER BY c.code)
                       FROM user_roles ur
                       JOIN role_capabilities rc ON rc.role_id = ur.role_id
                       JOIN capabilities c ON c.id = rc.capability_id
                      WHERE ur.user_id = u.id) AS capability_codes
               FROM users u
              WHERE u.id = ? AND u.is_active = 1
              LIMIT 1"
        );
        $stmt->execute([$id]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$row) return self::$cached = null;
        if (Session::get('auth_version') !== (int)$row['auth_version']) {
            Session::destroy();
            return self::$cached = null;
        }

        $row['roles']        = $row['role_codes']      ? explode(',', $row['role_codes'])      : [];
        $row['capabilities'] = $row['capability_codes'] ? explode(',', $row['capability_codes']) : [];
        unset($row['role_codes'], $row['capability_codes']);

        return self::$cached = $row;
    }

    public static function check(): bool
    {
        return self::user() !== null;
    }

    public static function id(): ?int
    {
        $u = self::user();
        return $u ? (int)$u['id'] : null;
    }

    public static function roles(): array
    {
        $u = self::user();
        return $u['roles'] ?? [];
    }

    public static function hasRole(string ...$roles): bool
    {
        return (bool) array_intersect(self::roles(), $roles);
    }

    public static function capabilities(): array
    {
        return self::user()['capabilities'] ?? [];
    }

    public static function hasCapability(string $cap): bool
    {
        return in_array($cap, self::capabilities(), true);
    }

    /** True when the user holds any one of the given capabilities. */
    public static function hasAnyCapability(string ...$caps): bool
    {
        return (bool) array_intersect($caps, self::capabilities());
    }

    public static function login(string $email, string $password): array
    {
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('SELECT * FROM users WHERE email = ? LIMIT 1');
        $stmt->execute([$email]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user) {
            password_verify($password, self::DUMMY_HASH);
            self::recordAttempt($email, null, false, 'unknown_email');
            return ['ok' => false, 'message' => 'Invalid credentials.'];
        }
        if (!$user['is_active']) {
            password_verify($password, $user['password_hash']);
            self::recordAttempt($email, (int)$user['id'], false, 'inactive');
            return ['ok' => false, 'message' => 'Invalid credentials.'];
        }
        if (!empty($user['locked_until']) && strtotime($user['locked_until']) > time()) {
            password_verify($password, $user['password_hash']);
            self::recordAttempt($email, (int)$user['id'], false, 'locked');
            return ['ok' => false, 'message' => 'Invalid credentials.'];
        }
        if (!password_verify($password, $user['password_hash'])) {
            $attempts = min(255, (int)$user['failed_login_attempts'] + 1);
            $lockUntil = null;
            if ($attempts >= 5) {
                $lockUntil = date('Y-m-d H:i:s', time() + 15 * 60);
            }
            $pdo->prepare('UPDATE users SET failed_login_attempts = ?, locked_until = ? WHERE id = ?')
                ->execute([$attempts, $lockUntil, $user['id']]);
            self::recordAttempt($email, (int)$user['id'], false, 'bad_password');
            return ['ok' => false, 'message' => 'Invalid credentials.'];
        }

        $pdo->prepare('UPDATE users SET failed_login_attempts = 0, locked_until = NULL, last_login_at = NOW() WHERE id = ?')
            ->execute([$user['id']]);

        Session::start();
        Session::regenerate();
        Session::set('user_id', (int)$user['id']);
        Session::set('auth_version', (int)$user['auth_version']);
        Session::set('last_activity', time());
        self::reset();
        self::recordAttempt($email, (int)$user['id'], true, null);

        Audit::log((int)$user['id'], 'login', 'users', (int)$user['id'], null, ['email' => $email]);
        return ['ok' => true, 'message' => 'Logged in.'];
    }

    public static function logout(): void
    {
        $id = self::id();
        if ($id) {
            Audit::log($id, 'logout', 'users', $id, null, null);
        }
        Session::destroy();
        self::reset();
    }

    private static function recordAttempt(string $email, ?int $userId, bool $success, ?string $reason): void
    {
        try {
            $stmt = Database::pdo()->prepare(
                'INSERT INTO login_attempts (email, user_id, ip_address, successful, failure_reason) VALUES (?, ?, ?, ?, ?)'
            );
            $stmt->execute([$email, $userId, $_SERVER['REMOTE_ADDR'] ?? null, $success ? 1 : 0, $reason]);
        } catch (\Throwable $e) {
            // non-fatal
        }
    }
}
