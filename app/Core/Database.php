<?php
declare(strict_types=1);

namespace App\Core;

require_once dirname(__DIR__, 2) . '/config/config.php';

class Database
{
    public static function pdo(): \PDO
    {
        static $pdo = null;
        if ($pdo === null) {
            $pdo = app_db();
        }
        return $pdo;
    }

    public static function server(): \PDO
    {
        return app_db('');
    }
}