<?php
declare(strict_types=1);

namespace App\Middleware;

use App\Core\Request;
use App\Core\Rbac;

class CapabilityMiddleware
{
    public function __construct(private string $capability) {}
    public function handle(Request $request): bool
    {
        return Rbac::requireCapability($this->capability);
    }
}