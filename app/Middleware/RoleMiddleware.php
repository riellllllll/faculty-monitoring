<?php
declare(strict_types=1);

namespace App\Middleware;

use App\Core\Auth;
use App\Core\Request;
use App\Core\Response;

final class RoleMiddleware
{
    public function __construct(private array $roles) {}

    public function handle(Request $request): bool
    {
        if (Auth::hasRole(...$this->roles)) return true;
        Response::fail('Forbidden.', 403);
        return false;
    }
}
