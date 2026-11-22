<?php
declare(strict_types=1);

namespace App\Core;

final class Security
{
    public static function headers(): void
    {
        header('X-Content-Type-Options: nosniff');
        header('Referrer-Policy: no-referrer');
        header('X-Frame-Options: DENY');
        header("Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'");
        if (str_starts_with($_SERVER['REQUEST_URI'] ?? '', '/api/')) {
            header('Cache-Control: no-store');
        }
    }

    public static function csrfToken(): string
    {
        Session::start();
        $token = Session::get('csrf_token');
        if (!is_string($token) || !preg_match('/^[a-f0-9]{64}$/', $token)) {
            $token = bin2hex(random_bytes(32));
            Session::set('csrf_token', $token);
        }
        return $token;
    }

    public static function requireCsrf(Request $request): void
    {
        if (!in_array($request->method, ['POST', 'PUT', 'PATCH', 'DELETE'], true)
            || !str_starts_with($request->path, '/api/')) return;

        $origin = $request->headers['origin'] ?? null;
        if ($origin !== null && !self::allowedOrigin($origin)) {
            Response::fail('Request origin is not allowed.', 403);
        }
        $supplied = $request->headers['x-csrf-token'] ?? '';
        if (!is_string($supplied) || !hash_equals(self::csrfToken(), $supplied)) {
            Response::fail('Your security token expired. Refresh and try again.', 403, ['code' => 'csrf']);
        }
    }

    private static function allowedOrigin(string $origin): bool
    {
        if ($origin === 'null') return false;
        $configured = array_filter(array_map('trim', explode(',', (string)app_env('APP_ALLOWED_ORIGINS', ''))));
        $allowed = [app_config()['app']['url'], ...$configured];
        foreach ($allowed as $url) {
            $parts = parse_url($url);
            if (!$parts || empty($parts['scheme']) || empty($parts['host'])) continue;
            $trusted = strtolower($parts['scheme'] . '://' . $parts['host'] . (isset($parts['port']) ? ':' . $parts['port'] : ''));
            if (hash_equals($trusted, strtolower($origin))) return true;
        }
        return false;
    }
}
