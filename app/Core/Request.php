<?php
declare(strict_types=1);

namespace App\Core;

class Request
{
    public string $method;
    public string $path;
    public array $query;
    public array $body;
    public array $headers;

    public function __construct()
    {
        $this->method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
        $uri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
        $this->path = rtrim($uri, '/') ?: '/';
        $this->query = $_GET ?? [];
        $this->headers = $this->collectHeaders();

        $raw = file_get_contents('php://input') ?: '';
        $contentType = $this->headers['content-type'] ?? '';
        if (str_contains($contentType, 'application/json')) {
            $decoded = json_decode($raw, true);
            $this->body = is_array($decoded) ? $decoded : [];
        } else {
            $this->body = array_merge($_POST ?? [], $this->query);
        }
    }

    private function collectHeaders(): array
    {
        $h = [];
        foreach ($_SERVER as $k => $v) {
            if (str_starts_with($k, 'HTTP_')) {
                $name = strtolower(str_replace('_', '-', substr($k, 5)));
                $h[$name] = $v;
            }
        }
        if (isset($_SERVER['CONTENT_TYPE'])) {
            $h['content-type'] = $_SERVER['CONTENT_TYPE'];
        }
        if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
            $h['authorization'] = $_SERVER['HTTP_AUTHORIZATION'];
        }
        return $h;
    }

    public function input(string $key, mixed $default = null): mixed
    {
        return $this->body[$key] ?? $this->query[$key] ?? $default;
    }

    public function all(): array
    {
        return array_merge($this->query, $this->body);
    }
}