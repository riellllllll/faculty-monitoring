<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Request;
use App\Core\Response;
use App\Core\Security;
use App\Core\RateLimiter;

final class CsrfController
{
    public function token(Request $request): void
    {
        RateLimiter::enforce('csrf-ip', RateLimiter::clientIp(), 120, 60, 60);
        Response::ok(['token' => Security::csrfToken()]);
    }
}
