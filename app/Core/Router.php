<?php
declare(strict_types=1);

namespace App\Core;

class Router
{
    private array $routes = [];

    public function get(string $path, callable|array $handler, array $middleware = []): void
    {
        $this->add('GET', $path, $handler, $middleware);
    }
    public function post(string $path, callable|array $handler, array $middleware = []): void
    {
        $this->add('POST', $path, $handler, $middleware);
    }
    public function put(string $path, callable|array $handler, array $middleware = []): void
    {
        $this->add('PUT', $path, $handler, $middleware);
    }
    public function delete(string $path, callable|array $handler, array $middleware = []): void
    {
        $this->add('DELETE', $path, $handler, $middleware);
    }

    private function add(string $method, string $path, callable|array $handler, array $middleware): void
    {
        $this->routes[] = [
            'method'     => $method,
            'path'       => $path,
            'handler'    => $handler,
            'middleware' => $middleware,
        ];
    }

    public function dispatch(Request $request): void
    {
        foreach ($this->routes as $route) {
            if ($route['method'] !== $request->method) continue;
            $pattern = preg_replace('#\{([a-zA-Z_]+)\}#', '(?P<$1>[^/]+)', $route['path']);
            $pattern = '#^' . $pattern . '$#';
            if (!preg_match($pattern, $request->path, $matches)) continue;

            $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);

            foreach ($route['middleware'] as $mw) {
                if (is_string($mw)) {
                    $mw = [new $mw(), 'handle'];
                } elseif (is_object($mw) && method_exists($mw, 'handle')) {
                    $mw = [$mw, 'handle'];
                }
                $result = $mw($request);
                if ($result === false) return;
            }

            $handler = $route['handler'];
            if (is_array($handler)) {
                [$class, $method] = $handler;
                $instance = new $class();
                $instance->{$method}($request, ...array_values($params));
            } else {
                $handler($request, ...array_values($params));
            }
            return;
        }

        Response::fail('Not found', 404);
    }
}