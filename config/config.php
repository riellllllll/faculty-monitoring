<?php

declare(strict_types=1);

/**
 * Application configuration for the Faculty Monitoring System.
 *
 * Dependency-free: values come from environment variables, which are loaded
 * from the project-root .env file when present. No Composer packages required,
 * so this file works before `composer install` has ever been run.
 *
 * Replace the hand-rolled .env parser with vlucas/phpdotenv later if desired —
 * nothing else in the codebase needs to change.
 */

// -----------------------------------------------------------------------------
// .env loader
// -----------------------------------------------------------------------------

if (! function_exists('app_load_env')) {
    /**
     * Read a KEY=VALUE .env file and register the values as environment vars.
     * Existing real environment variables always win over the file.
     */
    function app_load_env(string $path): void
    {
        if (! is_file($path) || ! is_readable($path)) {
            return;
        }

        $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];

        foreach ($lines as $line) {
            $line = trim($line);

            if ($line === '' || $line[0] === '#' || ! str_contains($line, '=')) {
                continue;
            }

            [$key, $value] = array_map('trim', explode('=', $line, 2));

            if ($key === '') {
                continue;
            }

            // Strip matching surrounding quotes.
            $length = strlen($value);
            if ($length >= 2) {
                $first = $value[0];
                $last  = $value[$length - 1];
                if (($first === '"' && $last === '"') || ($first === "'" && $last === "'")) {
                    $value = substr($value, 1, -1);
                }
            }

            if (getenv($key) === false) {
                putenv($key . '=' . $value);
                $_ENV[$key] = $value;
            }
        }
    }
}

app_load_env(dirname(__DIR__) . '/.env');

// -----------------------------------------------------------------------------
// Accessors
// -----------------------------------------------------------------------------

if (! function_exists('app_env')) {
    /** Read an environment value, falling back to $default when empty/unset. */
    function app_env(string $key, mixed $default = null): mixed
    {
        $value = getenv($key);

        return ($value === false || $value === '') ? $default : $value;
    }
}

if (! function_exists('app_config')) {
    /** The whole application configuration array. */
    function app_config(): array
    {
        static $config = null;

        if ($config !== null) {
            return $config;
        }

        $root = dirname(__DIR__);

        $config = [
            'app' => [
                'name'  => (string) app_env('APP_NAME', 'Faculty Monitoring System'),
                'env'   => (string) app_env('APP_ENV', 'local'),
                'debug' => filter_var(app_env('APP_DEBUG', 'false'), FILTER_VALIDATE_BOOL),
                'url'   => rtrim((string) app_env('APP_URL', 'http://localhost:8000'), '/'),
                'timezone' => (string) app_env('APP_TIMEZONE', 'Asia/Manila'),
            ],
            'db' => [
                'host'     => (string) app_env('DB_HOST', '127.0.0.1'),
                'port'     => (int) app_env('DB_PORT', '3306'),
                'name'     => (string) app_env('DB_NAME', 'faculty_monitor'),
                'user'     => (string) app_env('DB_USER', 'root'),
                'password' => (string) app_env('DB_PASSWORD', ''),
                'charset'  => (string) app_env('DB_CHARSET', 'utf8mb4'),
                'collation' => (string) app_env('DB_COLLATION', 'utf8mb4_unicode_ci'),
            ],
            'paths' => [
                'root'       => $root,
                'database'   => $root . '/database',
                'migrations' => $root . '/database/migrations',
                'seeds'      => $root . '/database/seeds',
                'erd'        => $root . '/database/erd',
                'storage'    => $root . '/storage',
            ],
        ];

        return $config;
    }
}

if (! function_exists('app_db_dsn')) {
    /**
     * Build a MySQL DSN.
     *   null  → the configured application database
     *   ''    → server-level connection (no database selected)
     *   other → the named database
     */
    function app_db_dsn(?string $database = null): string
    {
        $db = app_config()['db'];

        if ($database === null) {
            $database = $db['name'];
        }

        $dsn = sprintf('mysql:host=%s;port=%d', $db['host'], $db['port']);

        if ($database !== '') {
            $dsn .= ';dbname=' . $database;
        }

        return $dsn . ';charset=' . $db['charset'];
    }
}

if (! function_exists('app_db')) {
    /** PDO connection to the application database. */
    function app_db(?string $database = null): PDO
    {
        $db = app_config()['db'];

        return new PDO(app_db_dsn($database), $db['user'], $db['password'], [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
            PDO::ATTR_STRINGIFY_FETCHES  => false,
        ]);
    }
}

if (! function_exists('app_db_server')) {
    /** PDO connection to the MySQL server itself (no database selected). */
    function app_db_server(): PDO
    {
        return app_db('');
    }
}
