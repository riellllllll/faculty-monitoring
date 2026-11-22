<?php
declare(strict_types=1);

namespace App\Core;

class Rbac
{
    public static function requireAuth(Request $request): bool
    {
        if (!Auth::check()) {
            Response::fail('Unauthenticated.', 401);
            return false;
        }
        return true;
    }

    public static function requireCapability(string $cap): bool
    {
        if (!Auth::check()) {
            Response::fail('Unauthenticated.', 401);
            return false;
        }
        if (!Auth::hasCapability($cap)) {
            Response::fail('Forbidden: missing capability ' . $cap . '.', 403);
            return false;
        }
        return true;
    }

    public static function requireRole(string ...$roles): bool
    {
        if (!Auth::check()) {
            Response::fail('Unauthenticated.', 401);
            return false;
        }
        if (!Auth::hasRole(...$roles)) {
            Response::fail('Forbidden: insufficient role.', 403);
            return false;
        }
        return true;
    }
}