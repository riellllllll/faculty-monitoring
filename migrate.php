<?php

declare(strict_types=1);

/**
 * Migration runner — Faculty Monitoring System
 * ---------------------------------------------------------------------------
 *   php database/migrate.php              Apply pending migrations
 *   php database/migrate.php --seed       Apply pending migrations + seed data
 *   php database/migrate.php --fresh      Drop + recreate the database, migrate, seed
 *   php database/migrate.php --status     Show applied / pending migrations
 *   php database/migrate.php --export-erd Regenerate database/erd/faculty_monitor_erd.sql
 *
 * Configuration is read from the project-root .env file (see .env.example).
 */

if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit("This script may only be run from the command line.\n");
}

require __DIR__ . '/../config/config.php';

// -----------------------------------------------------------------------------
// Console helpers
// -----------------------------------------------------------------------------

function out(string $message = ''): void
{
    fwrite(STDOUT, $message . PHP_EOL);
}

function step(string $message): void
{
    out('  →  ' . $message);
}

function ok(string $message): void
{
    out('  ✓  ' . $message);
}

function fail(string $message): never
{
    fwrite(STDERR, '  ✗  ' . $message . PHP_EOL);
    exit(1);
}

// -----------------------------------------------------------------------------
// SQL statement splitter
//   Splits a migration file into individual statements while respecting
//   quoted strings, backticks and SQL comments.
// -----------------------------------------------------------------------------

function split_sql(string $sql): array
{
    $statements  = [];
    $buffer      = '';
    $length      = strlen($sql);
    $inSingle    = false;
    $inDouble    = false;
    $inBacktick  = false;
    $inLine      = false;
    $inBlock     = false;

    for ($i = 0; $i < $length; $i++) {
        $char = $sql[$i];
        $next = $i + 1 < $length ? $sql[$i + 1] : '';

        if ($inLine) {
            if ($char === "\n") {
                $inLine = false;
                $buffer .= $char;
            }
            continue;
        }

        if ($inBlock) {
            if ($char === '*' && $next === '/') {
                $inBlock = false;
                $i++;
            }
            continue;
        }

        if (! $inSingle && ! $inDouble && ! $inBacktick) {
            if ($char === '-' && $next === '-') {
                $inLine = true;
                $i++;
                continue;
            }
            if ($char === '#') {
                $inLine = true;
                continue;
            }
            if ($char === '/' && $next === '*') {
                $inBlock = true;
                $i++;
                continue;
            }
        }

        if ($char === "'" && ! $inDouble && ! $inBacktick) {
            if ($inSingle && $next === "'") {
                $buffer .= $char . $next;
                $i++;
                continue;
            }
            $inSingle = ! $inSingle;
        } elseif ($char === '"' && ! $inSingle && ! $inBacktick) {
            if ($inDouble && $next === '"') {
                $buffer .= $char . $next;
                $i++;
                continue;
            }
            $inDouble = ! $inDouble;
        } elseif ($char === '`' && ! $inSingle && ! $inDouble) {
            $inBacktick = ! $inBacktick;
        }

        if ($char === ';' && ! $inSingle && ! $inDouble && ! $inBacktick) {
            $trimmed = trim($buffer);
            if ($trimmed !== '') {
                $statements[] = $trimmed;
            }
            $buffer = '';
            continue;
        }

        $buffer .= $char;
    }

    $trimmed = trim($buffer);
    if ($trimmed !== '') {
        $statements[] = $trimmed;
    }

    return $statements;
}

// -----------------------------------------------------------------------------
// Runner
// -----------------------------------------------------------------------------

function ensure_migration_table(PDO $pdo): void
{
    $pdo->exec(
        "CREATE TABLE IF NOT EXISTS schema_migrations (
            id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            version    VARCHAR(190) NOT NULL,
            type       ENUM('migration','seed') NOT NULL DEFAULT 'migration',
            checksum   CHAR(64) NOT NULL DEFAULT '',
            applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            UNIQUE KEY uq_schema_migrations_version (version)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );
}

function applied_versions(PDO $pdo, string $type): array
{
    $statement = $pdo->prepare('SELECT version FROM schema_migrations WHERE type = ?');
    $statement->execute([$type]);

    return array_column($statement->fetchAll(), 'version');
}

function run_directory(PDO $pdo, string $directory, string $type): int
{
    if (! is_dir($directory)) {
        return 0;
    }

    $files = glob($directory . '/*.sql') ?: [];
    sort($files);

    $applied = applied_versions($pdo, $type);
    $count   = 0;

    foreach ($files as $file) {
        $version = basename($file, '.sql');

        if (in_array($version, $applied, true)) {
            step('skip  ' . $version);
            continue;
        }

        $sql      = (string) file_get_contents($file);
        $checksum = hash('sha256', $sql);

        // Note: MySQL/MariaDB perform an implicit COMMIT on every DDL statement,
        // so a transaction cannot wrap a migration. Every object is created with
        // IF NOT EXISTS and every seed uses idempotent inserts, which makes a
        // re-run after a failure safe.
        try {
            foreach (split_sql($sql) as $statement) {
                $pdo->exec($statement);
            }

            $insert = $pdo->prepare(
                'INSERT INTO schema_migrations (version, type, checksum) VALUES (?, ?, ?)'
            );
            $insert->execute([$version, $type, $checksum]);
        } catch (Throwable $exception) {
            fail($version . ' failed: ' . $exception->getMessage());
        }

        ok($version);
        $count++;
    }

    return $count;
}

/** Give pre-existing and seeded rooms one permanent, unique random QR ID. */
function backfill_room_qr_codes(PDO $pdo): int
{
    $column = $pdo->query("SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = 'rooms' AND column_name = 'qr_public_code'")
        ->fetchColumn();
    if (!(int)$column) return 0;

    $ids = $pdo->query('SELECT id FROM rooms WHERE qr_public_code IS NULL ORDER BY id')
        ->fetchAll(PDO::FETCH_COLUMN);
    $update = $pdo->prepare('UPDATE rooms SET qr_public_code = ? WHERE id = ? AND qr_public_code IS NULL');
    foreach ($ids as $id) {
        for ($attempt = 0; $attempt < 5; $attempt++) {
            try {
                $update->execute([bin2hex(random_bytes(16)), (int)$id]);
                break;
            } catch (PDOException $error) {
                if ($error->getCode() !== '23000' || $attempt === 4) throw $error;
            }
        }
    }
    return count($ids);
}

function rebuild_database(PDO $server, array $db): void
{
    $name = $db['name'];

    $server->exec('DROP DATABASE IF EXISTS `' . $name . '`');
    $server->exec(
        'CREATE DATABASE `' . $name . '` CHARACTER SET ' . $db['charset']
        . ' COLLATE ' . $db['collation']
    );
}

function ensure_database(PDO $server, array $db): void
{
    $server->exec(
        'CREATE DATABASE IF NOT EXISTS `' . $db['name'] . '`'
        . ' CHARACTER SET ' . $db['charset']
        . ' COLLATE ' . $db['collation']
    );
}

// -----------------------------------------------------------------------------
// ERD export (MySQL Workbench reverse-engineering source)
// -----------------------------------------------------------------------------

function export_erd(array $paths): void
{
    $pdo = app_db();
    $tables = [];
    foreach ($pdo->query('SHOW FULL TABLES', PDO::FETCH_NUM) as $row) {
        if ($row[1] === 'BASE TABLE') $tables[] = $row[0];
    }
    sort($tables);

    $sql = "-- Current normalized schema from the configured database.\n"
         . "-- Use this file to reverse-engineer the EER diagram.\n"
         . "SET FOREIGN_KEY_CHECKS = 0;\n\n";
    foreach ($tables as $name) {
        $quoted = '`' . str_replace('`', '``', $name) . '`';
        $ddl = $pdo->query('SHOW CREATE TABLE ' . $quoted)->fetch(PDO::FETCH_NUM)[1];
        $sql .= $ddl . ";\n\n";
    }
    $sql .= "SET FOREIGN_KEY_CHECKS = 1;\n";
    $target = $paths['erd'] . '/faculty_monitor_erd.sql';
    if (!is_dir($paths['erd'])) mkdir($paths['erd'], 0775, true);
    file_put_contents($target, $sql);
    ok('ERD source written to ' . $target);
    ok('tables found: ' . count($tables));
}
// -----------------------------------------------------------------------------
// Bundle export — single-file SQL for a phpMyAdmin import
// -----------------------------------------------------------------------------

function export_bundle(array $paths, array $db): void
{
    $migrations = glob($paths['migrations'] . '/*.sql') ?: [];
    $seeds      = glob($paths['seeds'] . '/*.sql') ?: [];
    sort($migrations);
    sort($seeds);

    $schema = "-- =============================================================================\n"
        . "--  FACULTY MONITORING SYSTEM — FULL SCHEMA\n"
        . "--  Generated from database/migrations/*.sql by `php database/migrate.php --export-bundle`.\n"
        . "--  Import this file into phpMyAdmin to create the database from scratch.\n"
        . "-- =============================================================================\n\n"
        . 'CREATE DATABASE IF NOT EXISTS `' . $db['name'] . '`'
        . ' CHARACTER SET ' . $db['charset'] . ' COLLATE ' . $db['collation'] . ";\n"
        . 'USE `' . $db['name'] . '`' . ";\n\n"
        . 'SET FOREIGN_KEY_CHECKS = 0;' . "\n\n";

    foreach ($migrations as $file) {
        $schema .= '-- ' . basename($file) . str_repeat(' ', max(1, 60 - strlen(basename($file)))) . PHP_EOL;
        $schema .= rtrim((string) file_get_contents($file)) . PHP_EOL . PHP_EOL;
    }

    foreach ($migrations as $file) {
        $version = basename($file, '.sql');
        $checksum = hash('sha256', (string) file_get_contents($file));
        $schema .= "INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ("
            . "'" . $version . "', 'migration', '" . $checksum . "');" . PHP_EOL;
    }

    $schema .= 'SET FOREIGN_KEY_CHECKS = 1;' . PHP_EOL;

    file_put_contents($paths['database'] . '/schema.sql', $schema);
    ok('schema.sql written (' . count($migrations) . ' migrations)');

    $demo = "-- =============================================================================\n"
        . "--  FACULTY MONITORING SYSTEM — DEMONSTRATION DATA\n"
        . "--  Generated from database/seeds/*.sql by `php database/migrate.php --export-bundle`.\n"
        . "--  Import AFTER schema.sql. Demo accounts use the password: Password123!\n"
        . "-- =============================================================================\n\n"
        . 'USE `' . $db['name'] . '`' . ";\n\n"
        . 'SET FOREIGN_KEY_CHECKS = 0;' . "\n\n";

    foreach ($seeds as $file) {
        $demo .= '-- ' . basename($file) . str_repeat(' ', max(1, 60 - strlen(basename($file)))) . PHP_EOL;
        $demo .= rtrim((string) file_get_contents($file)) . PHP_EOL . PHP_EOL;
    }

    foreach ($seeds as $file) {
        $version = basename($file, '.sql');
        $checksum = hash('sha256', (string) file_get_contents($file));
        $demo .= "INSERT IGNORE INTO schema_migrations (version, type, checksum) VALUES ("
            . "'" . $version . "', 'seed', '" . $checksum . "');" . PHP_EOL;
    }

    $demo .= 'SET FOREIGN_KEY_CHECKS = 1;' . PHP_EOL;

    file_put_contents($paths['database'] . '/demo_data.sql', $demo);
    ok('demo_data.sql written (' . count($seeds) . ' seed files)');
}

// -----------------------------------------------------------------------------
// Entry point
// -----------------------------------------------------------------------------

$options = array_slice($argv, 1);
$config  = app_config();
$db      = $config['db'];
$paths   = $config['paths'];

if (in_array('--export-erd', $options, true)) {
    out('');
    out('Exporting ERD source...');
    export_erd($paths);
    out('');
    exit(0);
}

if (in_array('--export-bundle', $options, true)) {
    out('');
    out('Exporting phpMyAdmin bundle...');
    export_bundle($paths, $db);
    out('');
    exit(0);
}

out('');
out('  Faculty Monitoring System — Database Migrations');
out('  Target: ' . $db['host'] . ':' . $db['port'] . '/' . $db['name']);
out('');

$fresh = in_array('--fresh', $options, true);
$seed  = in_array('--seed', $options, true) || $fresh;

if (in_array(strtolower($config['app']['env']), ['production', 'prod'], true) && $seed) {
    fail('Demo seeding and --fresh are disabled in production. Run migrations without those options.');
}

try {
    if ($fresh) {
        step('dropping and recreating database `' . $db['name'] . '`');
        $server = app_db('');
        rebuild_database($server, $db);
        unset($server);
        ok('database recreated');
    } else {
        $server = app_db('');
        ensure_database($server, $db);
        unset($server);
    }

    $pdo = app_db();
    ensure_migration_table($pdo);

    if (in_array('--status', $options, true)) {
        $applied = applied_versions($pdo, 'migration');
        $files   = glob($paths['migrations'] . '/*.sql') ?: [];
        sort($files);

        foreach ($files as $file) {
            $version = basename($file, '.sql');
            $state   = in_array($version, $applied, true) ? 'applied' : 'pending';
            out(sprintf('  %-8s %s', $state, $version));
        }

        out('');
        exit(0);
    }

    out('  Applying migrations');
    $migrated = run_directory($pdo, $paths['migrations'], 'migration');
    ok($migrated === 0 ? 'schema already up to date' : $migrated . ' migration(s) applied');

    if ($seed) {
        out('');
        out('  Applying seeds');
        $seeded = run_directory($pdo, $paths['seeds'], 'seed');
        ok($seeded === 0 ? 'seeds already applied' : $seeded . ' seed file(s) applied');
    }

    $roomQrCount = backfill_room_qr_codes($pdo);
    if ($roomQrCount > 0) ok($roomQrCount . ' room QR identifier(s) created');

    out('');
    out('  Done.');
    out('');
} catch (Throwable $exception) {
    fail($exception->getMessage());
}
