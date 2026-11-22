<?php
declare(strict_types=1);

namespace App\Middleware;

use App\Core\Request;
use App\Core\Rbac;
use App\Core\Auth;
use App\Core\Response;

class AuthMiddleware
{
    public function handle(Request $request): bool
    {
        if (!Rbac::requireAuth($request)) return false;
        if (!empty(Auth::user()['must_change_password']) && !in_array($request->path, [
            '/api/auth/me', '/api/auth/logout', '/api/profile', '/api/profile/password',
        ], true)) {
            Response::fail('Change your password before continuing.', 403, ['code' => 'PASSWORD_CHANGE_REQUIRED']);
            return false;
        }
        return true;
    }
}
