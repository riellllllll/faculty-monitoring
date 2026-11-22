<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use PDO;

final class NotificationController
{
    public function index(Request $request): void
    {
        $pdo = Database::pdo();
        $userId = (int)Auth::id();
        $stmt = $pdo->prepare('SELECT id, type, title, body, link, is_read, created_at
            FROM notifications WHERE user_id = ? ORDER BY created_at DESC, id DESC LIMIT 30');
        $stmt->execute([$userId]);
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $count = $pdo->prepare('SELECT COUNT(*) FROM notifications WHERE user_id = ? AND is_read = 0');
        $count->execute([$userId]);
        Response::ok(['items' => $items, 'unread_count' => (int)$count->fetchColumn()]);
    }

    public function read(Request $request, string $id): void
    {
        if (!ctype_digit($id) || (int)$id < 1) Response::fail('Invalid notification.', 422);
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('UPDATE notifications SET is_read = 1, read_at = COALESCE(read_at, NOW())
            WHERE id = ? AND user_id = ?');
        $stmt->execute([(int)$id, (int)Auth::id()]);
        if ($stmt->rowCount() === 0) {
            $check = $pdo->prepare('SELECT 1 FROM notifications WHERE id = ? AND user_id = ?');
            $check->execute([(int)$id, (int)Auth::id()]);
            if (!$check->fetchColumn()) Response::fail('Notification not found.', 404);
        }
        Response::ok(null, 'Notification read.');
    }

    public function readAll(Request $request): void
    {
        $stmt = Database::pdo()->prepare('UPDATE notifications SET is_read = 1, read_at = NOW()
            WHERE user_id = ? AND is_read = 0');
        $stmt->execute([(int)Auth::id()]);
        Response::ok(['updated' => $stmt->rowCount()], 'Notifications read.');
    }
}
