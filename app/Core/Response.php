<?php
declare(strict_types=1);

namespace App\Core;

class Response
{
    public static function json(mixed $data, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    public static function ok(mixed $data = null, string $message = 'OK'): void
    {
        self::json(['success' => true, 'message' => $message, 'data' => $data]);
    }

    public static function fail(string $message, int $status = 400, mixed $errors = null): void
    {
        self::json(['success' => false, 'message' => $message, 'errors' => $errors], $status);
    }

    public static function redirect(string $url, int $status = 302): void
    {
        http_response_code($status);
        header('Location: ' . $url);
        exit;
    }

    public static function html(string $html, int $status = 200): void
    {
        http_response_code($status);
        header('Content-Type: text/html; charset=utf-8');
        echo $html;
        exit;
    }
}