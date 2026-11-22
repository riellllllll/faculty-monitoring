<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Request;
use App\Core\Response;
use App\Core\Session;
use App\Core\RateLimiter;

class AuthController
{
    public function login(Request $request): void
    {
        $emailInput = $request->input('email', '');
        $passwordInput = $request->input('password', '');
        $email = is_string($emailInput) ? strtolower(trim($emailInput)) : '';
        $password = is_string($passwordInput) ? $passwordInput : '';

        RateLimiter::enforce('login-ip', RateLimiter::clientIp(), 30, 600, 900);
        if ($email !== '') RateLimiter::enforce('login-account', $email, 10, 600, 900);

        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 120
            || $password === '' || strlen($password) > 72) {
            Response::fail('Invalid email or password.', 422);
            return;
        }

        $result = Auth::login($email, $password);
        if (!$result['ok']) {
            Response::fail($result['message'], 401);
            return;
        }
        $user = Auth::user();
        unset($user['password_hash'], $user['failed_login_attempts'], $user['locked_until'], $user['auth_version']);
        Response::ok(['user' => $user], $result['message']);
    }

    public function logout(Request $request): void
    {
        Auth::logout();
        Response::ok(null, 'Logged out.');
    }

    public function me(Request $request): void
    {
        $user = Auth::user();
        if (!$user) {
            Response::fail('Unauthenticated.', 401);
            return;
        }
        unset($user['password_hash'], $user['failed_login_attempts'], $user['locked_until'], $user['auth_version']);
        Response::ok($user);
    }
}
