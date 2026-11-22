<?php
declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../config/config.php';

use App\Core\Request;
use App\Core\Response;
use App\Core\Router;
use App\Core\Session;
use App\Core\Security;
use App\Controllers\AuthController;
use App\Controllers\DashboardController;
use App\Controllers\FacultyController;
use App\Controllers\ReportController;
use App\Controllers\RoomController;
use App\Controllers\ScheduleController;
use App\Controllers\ScheduleCatalogController;
use App\Controllers\SettingsController;
use App\Controllers\UserManagementController;
use App\Controllers\AccountSetupController;
use App\Controllers\NotificationController;
use App\Controllers\CsrfController;
use App\Controllers\EmailChangeController;
use App\Controllers\VerificationController;
use App\Middleware\AuthMiddleware;
use App\Middleware\CapabilityMiddleware;
use App\Middleware\RoleMiddleware;

ini_set('display_errors', '0');
ini_set('log_errors', '1');
Security::headers();
set_exception_handler(static function (Throwable $error): void {
    $incident = bin2hex(random_bytes(6));
    error_log('Unhandled application error [' . $incident . '] ' . get_class($error));
    Response::fail('An unexpected error occurred. Reference: ' . $incident, 500);
});
Session::start();

// Serve static files directly when they exist (built assets, images, etc.)
$requestPath = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';
$docRoot = __DIR__;
$staticFile = $docRoot . $requestPath;
if ($requestPath !== '/' && !is_file($staticFile)) {
    // Vite build output lives under public/app
    $alt = $docRoot . '/app' . $requestPath;
    if (is_file($alt)) $staticFile = $alt;
}
if ($requestPath !== '/' && is_file($staticFile)) {
    $resolved = realpath($staticFile);
    $publicRoot = realpath($docRoot);
    $ext = strtolower(pathinfo($staticFile, PATHINFO_EXTENSION));
    if (!$resolved || !$publicRoot || !str_starts_with($resolved, $publicRoot . DIRECTORY_SEPARATOR)
        || !in_array($ext, ['css', 'js', 'mjs', 'json', 'svg', 'png', 'jpg', 'jpeg', 'gif', 'ico', 'woff', 'woff2', 'ttf', 'html'], true)) {
        Response::fail('Not found.', 404);
    }
    $mimes = [
        'css'  => 'text/css; charset=utf-8',
        'js'   => 'text/javascript; charset=utf-8',
        'mjs'  => 'text/javascript; charset=utf-8',
        'json' => 'application/json; charset=utf-8',
        'svg'  => 'image/svg+xml',
        'png'  => 'image/png',
        'jpg'  => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'gif'  => 'image/gif',
        'ico'  => 'image/x-icon',
        'woff' => 'font/woff',
        'woff2'=> 'font/woff2',
        'ttf'  => 'font/ttf',
        'html' => 'text/html; charset=utf-8',
    ];
    $mime = $mimes[$ext] ?? (mime_content_type($staticFile) ?: 'application/octet-stream');
    header('Content-Type: ' . $mime);
    readfile($staticFile);
    exit;
}

$request = new Request();
Security::requireCsrf($request);
$router = new Router();

$auth = new AuthMiddleware();

// --- Auth (public) ---
$router->post('/api/auth/login', [AuthController::class, 'login']);
$router->get('/api/auth/csrf', [CsrfController::class, 'token']);
$router->post('/api/auth/logout', [AuthController::class, 'logout'], [$auth]);
$router->get('/api/auth/me', [AuthController::class, 'me'], [$auth]);
$router->post('/api/auth/set-password', [AccountSetupController::class, 'setPassword']);
$router->post('/api/auth/verify-email', [EmailChangeController::class, 'confirm']);

// --- Dashboard ---
$router->get('/api/dashboard/stats', [DashboardController::class, 'stats'], [$auth]);

// Each signed-in user can see and acknowledge only their own notifications.
$router->get('/api/notifications', [NotificationController::class, 'index'], [$auth]);
$router->post('/api/notifications/read-all', [NotificationController::class, 'readAll'], [$auth]);
$router->post('/api/notifications/{id}/read', [NotificationController::class, 'read'], [$auth]);

// --- Faculty ---
$router->get('/api/faculty', [FacultyController::class, 'index'], [$auth, new CapabilityMiddleware('faculty.view')]);

// --- Reports (row scoping is enforced inside the controller) ---
$router->get('/api/reports/scheduled-load', [ReportController::class, 'scheduledLoad'], [$auth]);
$router->get('/api/reports/teaching-hours', [ReportController::class, 'teachingHours'], [$auth]);
$router->get('/api/reports/faculty-directory', [ReportController::class, 'facultyDirectory'], [$auth, new CapabilityMiddleware('faculty.view')]);
$router->get('/api/reports/faculty-load', [ReportController::class, 'facultyLoad'], [$auth]);

// --- Faculty timetables ---
$scheduleGuard = [$auth, new RoleMiddleware(['chairperson', 'program_coordinator'])];
$scheduleCatalogGuard = [$auth, new RoleMiddleware(['chairperson'])];
$router->get('/api/schedules', [ScheduleController::class, 'index'], [$auth]);
$roomQrGuard = [$auth, new CapabilityMiddleware('room_qr.manage')];
$router->get('/api/rooms', [RoomController::class, 'index'], $roomQrGuard);
$router->get('/api/rooms/resolve', [RoomController::class, 'resolve'], [$auth]);
$router->get('/api/rooms/{id}/qr', [RoomController::class, 'qr'], $roomQrGuard);
$facultyVerificationGuard = [$auth, new RoleMiddleware(['faculty', 'chairperson'])];
$reviewGuard = [$auth, new RoleMiddleware(['chairperson', 'program_coordinator'])];
$router->get('/api/verification/current', [VerificationController::class, 'current'], $facultyVerificationGuard);
$router->post('/api/verification', [VerificationController::class, 'submit'], $facultyVerificationGuard);
$router->get('/api/verification', [VerificationController::class, 'index'], [$auth]);
$router->get('/api/verification/{id}/photo', [VerificationController::class, 'photo'], [$auth]);
$router->post('/api/verification/{id}/decision', [VerificationController::class, 'decide'], $reviewGuard);
$router->post('/api/schedules', [ScheduleController::class, 'create'], $scheduleGuard);
$router->post('/api/schedules/batch-delete', [ScheduleController::class, 'batchDelete'], $scheduleGuard);
$router->put('/api/schedules/{id}', [ScheduleController::class, 'update'], $scheduleGuard);
$router->delete('/api/schedules/{id}', [ScheduleController::class, 'delete'], $scheduleGuard);
$router->post('/api/schedule-catalog/subjects', [ScheduleCatalogController::class, 'subject'], $scheduleCatalogGuard);
$router->post('/api/schedule-catalog/curriculum', [ScheduleCatalogController::class, 'curriculum'], $scheduleCatalogGuard);
$router->post('/api/schedule-catalog/terms', [ScheduleCatalogController::class, 'term'], $scheduleCatalogGuard);
$router->post('/api/schedule-catalog/sections', [ScheduleCatalogController::class, 'section'], $scheduleCatalogGuard);
$router->post('/api/schedule-catalog/rooms', [ScheduleCatalogController::class, 'room'], $roomQrGuard);

// --- Settings: My Account (any signed-in user) ---
$router->get('/api/profile', [SettingsController::class, 'profile'], [$auth]);
$router->put('/api/profile', [SettingsController::class, 'updateProfile'], [$auth]);
$router->post('/api/profile/password', [SettingsController::class, 'changePassword'], [$auth]);

// General account creation is reserved for the chairperson.
$accountGuard = [$auth, new RoleMiddleware(['chairperson'])];
$facultyGuard = [$auth, new RoleMiddleware(['chairperson', 'program_coordinator'])];
$router->get('/api/users', [UserManagementController::class, 'index'], $accountGuard);
$router->post('/api/users', [UserManagementController::class, 'create'], $accountGuard);
$router->put('/api/users/{id}', [UserManagementController::class, 'update'], $accountGuard);
$router->delete('/api/users/{id}', [UserManagementController::class, 'delete'], $accountGuard);
$router->post('/api/users/{id}/restore', [UserManagementController::class, 'restore'], $accountGuard);
$router->post('/api/users/{id}/resend-invite', [UserManagementController::class, 'resendAccount'], $accountGuard);

$router->get('/api/faculty/accounts', [UserManagementController::class, 'facultyIndex'], $facultyGuard);
$router->post('/api/faculty/accounts/check-email', [UserManagementController::class, 'checkEmail'], $facultyGuard);
$router->post('/api/faculty/accounts', [UserManagementController::class, 'createFaculty'], $facultyGuard);
$router->put('/api/faculty/accounts/{id}', [UserManagementController::class, 'updateFaculty'], $facultyGuard);
$router->delete('/api/faculty/accounts/{id}', [UserManagementController::class, 'deleteFaculty'], $facultyGuard);
$router->delete('/api/faculty/accounts/{id}/permanent', [UserManagementController::class, 'permanentlyDeleteFaculty'], $facultyGuard);
$router->post('/api/faculty/accounts/{id}/restore', [UserManagementController::class, 'restoreFaculty'], $facultyGuard);
$router->post('/api/faculty/accounts/{id}/resend-invite', [UserManagementController::class, 'resendFaculty'], $facultyGuard);
$router->get('/api/faculty/{id}', [FacultyController::class, 'show'], [$auth, new CapabilityMiddleware('faculty.view')]);

$router->get('/api/coordinators', [UserManagementController::class, 'coordinatorIndex'], $accountGuard);
$router->post('/api/coordinators', [UserManagementController::class, 'createCoordinator'], $accountGuard);
$router->put('/api/coordinators/{id}', [UserManagementController::class, 'updateCoordinator'], $accountGuard);
$router->delete('/api/coordinators/{id}', [UserManagementController::class, 'deleteCoordinator'], $accountGuard);
$router->post('/api/coordinators/{id}/restore', [UserManagementController::class, 'restoreCoordinator'], $accountGuard);
$router->post('/api/coordinators/{id}/resend-invite', [UserManagementController::class, 'resendCoordinator'], $accountGuard);

// SPA fallback for client-side routing (production build): non-API routes
// serve the built index.html so the client router can take over.
if (!str_starts_with($request->path, '/api')) {
    $fallback = __DIR__ . '/app/index.html';
    if (is_file($fallback)) {
        readfile($fallback);
        exit;
    }
}

$router->dispatch($request);
