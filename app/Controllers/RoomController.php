<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use PDO;

final class RoomController
{
    public function index(Request $request): void
    {
        $rooms = Database::pdo()->query('SELECT id, code, name, building, room_type, capacity,
            qr_public_code IS NOT NULL AS has_qr FROM rooms WHERE is_active = 1 ORDER BY building, code')
            ->fetchAll(PDO::FETCH_ASSOC);
        Response::ok($rooms);
    }

    public function qr(Request $request, string $id): void
    {
        if (!ctype_digit($id) || (int)$id < 1) Response::fail('Room not found.', 404);
        $stmt = Database::pdo()->prepare('SELECT id, code, name, building, qr_public_code
            FROM rooms WHERE id = ? AND is_active = 1 LIMIT 1');
        $stmt->execute([(int)$id]);
        $room = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$room || !$room['qr_public_code']) Response::fail('Room QR is not available.', 404);

        $room['url'] = app_config()['app']['url'] . '/#/room?code=' . $room['qr_public_code'];
        Response::ok($room);
    }

    /** A scanned card identifies the room; it does not record attendance. */
    public function resolve(Request $request): void
    {
        $code = $request->input('code');
        if (!is_string($code) || !preg_match('/^[a-f0-9]{32}$/', $code)) {
            Response::fail('Room QR is invalid.', 422);
        }
        $stmt = Database::pdo()->prepare('SELECT code, name, building, room_type
            FROM rooms WHERE qr_public_code = ? AND is_active = 1 LIMIT 1');
        $stmt->execute([$code]);
        $room = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$room) Response::fail('Room QR was not found.', 404);
        Response::ok($room);
    }
}
