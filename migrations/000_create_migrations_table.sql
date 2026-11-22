-- 000 :: schema_migrations tracking table
CREATE TABLE IF NOT EXISTS schema_migrations (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    filename    VARCHAR(255) NOT NULL UNIQUE,
    checksum    CHAR(64)     NOT NULL,
    applied_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
