<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Audit;
use App\Core\Auth;
use App\Core\Database;
use App\Core\Request;
use App\Core\Response;
use App\Core\RateLimiter;
use App\Services\AccountInvitationService;
use PDO;
use PDOException;

/** Account administration. Deletion deactivates an account to retain its records. */
class UserManagementController
{
    private const ROLES = ['chairperson', 'program_coordinator', 'faculty'];

    public function facultyIndex(Request $request): void { $this->directory('faculty'); }
    public function coordinatorIndex(Request $request): void { $this->directory('program_coordinator'); }

    private function directory(string $kind): void
    {
        if (!$this->canAccess() || ($kind === 'program_coordinator' && !$this->canManageAccounts())) return;
        $pdo = Database::pdo();
        $stmt = $pdo->prepare("SELECT u.id, u.employee_no, u.email, u.first_name, u.middle_name, u.last_name, u.phone,
                    u.is_active, fp.rank_code, fp.employment_type, fp.designation, fp.field_of_specialization, fp.hire_date
               FROM users u JOIN user_roles ur ON ur.user_id = u.id JOIN roles r ON r.id = ur.role_id AND r.code = ?
               LEFT JOIN faculty_profiles fp ON fp.user_id = u.id
              ORDER BY u.last_name, u.first_name");
        $stmt->execute([$kind]);
        $users = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $allowed = $this->assignedProgramIds();
        foreach ($users as &$user) {
            $user['roles'] = $this->rolesFor((int)$user['id']);
            $user['program_ids'] = $this->programsFor((int)$user['id']);
        }
        unset($user);
        if ($kind === 'faculty') {
            $users = array_values(array_filter($users, fn($u) => count($u['roles']) === 1 && $u['roles'][0] === 'faculty'
                && ($this->canManageAccounts() || ((bool)$u['program_ids'] && !array_diff($u['program_ids'], $allowed)))));
        }
        $programs = $pdo->query('SELECT id, code, name FROM programs WHERE is_active = 1 ORDER BY code')->fetchAll(PDO::FETCH_ASSOC);
        if (!$this->canManageAccounts()) $programs = array_values(array_filter($programs, fn($p) => in_array((int)$p['id'], $allowed, true)));
        Response::ok(['users' => $users, 'programs' => $programs]);
    }

    public function createFaculty(Request $request): void
    {
        if (!$this->canAccess()) return;
        $request->body['roles'] = ['faculty'];
        $this->create($request);
    }

    public function checkEmail(Request $request): void
    {
        if (!$this->canAccess() || !$this->jsonOnly($request)) return;
        RateLimiter::enforce('email-check-user', (string)Auth::id(), 60, 600, 600);
        $emailInput = $request->input('email', '');
        $email = is_string($emailInput) ? strtolower(trim($emailInput)) : '';
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 120) {
            Response::fail('Enter a valid email address.', 422); return;
        }
        if (!$this->requireAvailableEmail($email)) return;
        Response::ok(['available' => true], 'Email format is valid and the address is not registered.');
    }

    public function createCoordinator(Request $request): void
    {
        if (!$this->canManageAccounts()) { Response::fail('Forbidden.', 403); return; }
        $request->body['roles'] = ['program_coordinator', ...(!empty($request->body['teaches_as_faculty']) ? ['faculty'] : [])];
        $this->create($request);
    }

    public function updateFaculty(Request $request, string $id): void
    {
        if (!$this->requireKind($id, 'faculty')) return;
        $request->body['roles'] = ['faculty'];
        $this->update($request, $id);
    }

    public function updateCoordinator(Request $request, string $id): void
    {
        if (!$this->canManageAccounts() || !$this->requireKind($id, 'program_coordinator')) return;
        $request->body['roles'] = ['program_coordinator', ...(!empty($request->body['teaches_as_faculty']) ? ['faculty'] : [])];
        $this->update($request, $id);
    }

    public function deleteFaculty(Request $request, string $id): void { if ($this->requireKind($id, 'faculty')) $this->delete($request, $id); }
    public function permanentlyDeleteFaculty(Request $request, string $id): void
    {
        if (!$this->requireKind($id, 'faculty') || !$this->jsonOnly($request)) return;
        $userId = (int)$id;
        if (!$this->canManageExisting($userId)) { Response::fail('You cannot delete this faculty account.', 403); return; }

        $pdo = Database::pdo();
        try {
            $pdo->beginTransaction();
            $stmt = $pdo->prepare('SELECT id, email, is_active FROM users WHERE id = ? FOR UPDATE');
            $stmt->execute([$userId]);
            $account = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$account) { $pdo->rollBack(); Response::fail('Faculty account not found.', 404); return; }
            if ((int)$account['is_active'] !== 0) {
                $pdo->rollBack(); Response::fail('Deactivate this faculty account before deleting it permanently.', 409); return;
            }
            if (strtolower(trim((string)$request->input('confirm_email', ''))) !== strtolower($account['email'])) {
                $pdo->rollBack(); Response::fail('Confirm the faculty email address before permanent deletion.', 422); return;
            }
            if ($this->hasProtectedReferences($pdo, $userId)) {
                $pdo->rollBack();
                Response::fail('This faculty account has linked records. It cannot be permanently deleted; keep it inactive to preserve the history.', 409);
                return;
            }

            $pdo->prepare('DELETE FROM email_deliveries WHERE user_id = ? OR recipient_email = ?')
                ->execute([$userId, $account['email']]);
            $pdo->prepare('DELETE FROM login_attempts WHERE user_id = ? OR email = ?')
                ->execute([$userId, $account['email']]);
            $pdo->prepare("UPDATE audit_logs SET description = '' WHERE user_id = ? OR (entity_type = 'users' AND entity_id = ?)")
                ->execute([$userId, $userId]);
            $pdo->prepare('DELETE FROM users WHERE id = ? AND is_active = 0')->execute([$userId]);
            $pdo->commit();
            Audit::log(Auth::id(), 'user.delete_permanent', 'users', $userId);
            Response::ok(null, 'Faculty account permanently deleted. Its email can be used for a new account.');
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            if ($e->getCode() === '23000') { Response::fail('This faculty account has linked records and cannot be permanently deleted.', 409); return; }
            error_log('Permanent faculty deletion failed: ' . get_class($e));
            Response::fail('Could not permanently delete the faculty account.', 500);
        } catch (\Throwable $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            error_log('Permanent faculty deletion failed: ' . get_class($e));
            Response::fail('Could not permanently delete the faculty account.', 500);
        }
    }
    public function deleteCoordinator(Request $request, string $id): void { if ($this->canManageAccounts() && $this->requireKind($id, 'program_coordinator')) $this->delete($request, $id); }
    public function restoreFaculty(Request $request, string $id): void { if ($this->requireKind($id, 'faculty')) $this->restore($request, $id); }
    public function restoreCoordinator(Request $request, string $id): void { if ($this->canManageAccounts() && $this->requireKind($id, 'program_coordinator')) $this->restore($request, $id); }

    public function resendFaculty(Request $request, string $id): void { $this->resend($request, $id, 'faculty'); }
    public function resendCoordinator(Request $request, string $id): void { $this->resend($request, $id, 'program_coordinator'); }
    public function resendAccount(Request $request, string $id): void { $this->resend($request, $id, 'any'); }

    private function resend(Request $request, string $id, string $kind): void
    {
        if (!$this->jsonOnly($request)) return;
        if ($kind === 'any') {
            if (!$this->canManageAccounts()) { Response::fail('Forbidden.', 403); return; }
            if (!ctype_digit($id) || (int)$id < 1) { Response::fail('Invalid account ID.', 422); return; }
        } elseif (!$this->requireKind($id, $kind) || !$this->canManageExisting((int)$id)) return;
        RateLimiter::enforce('invite-actor', (string)Auth::id(), 10, 3600, 3600);
        RateLimiter::enforce('invite-target', $id, 3, 3600, 3600);
        $stmt = Database::pdo()->prepare('SELECT id, email, first_name, last_name FROM users WHERE id = ? AND is_active = 1');
        $stmt->execute([(int)$id]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$user) { Response::fail('Active account not found.', 404); return; }
        $status = $this->sendInvitation((int)$id, $user['email'], trim($user['first_name'] . ' ' . $user['last_name']));
        Response::ok(['email_status' => $status], $status === 'sent' ? 'Setup email sent.' : 'Email delivery failed. Check SMTP settings and try again.');
    }

    private function requireKind(string $id, string $kind): bool
    {
        if (!$this->canAccess()) return false;
        if (!ctype_digit($id) || (int)$id < 1) { Response::fail('Invalid account ID.', 422); return false; }
        $roles = $this->rolesFor((int)$id);
        $matches = $kind === 'faculty' ? $roles === ['faculty'] : in_array('program_coordinator', $roles, true);
        if (!$matches) { Response::fail('Forbidden.', 403); return false; }
        return true;
    }

    private function rolesFor(int $id): array
    {
        $stmt = Database::pdo()->prepare('SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ? ORDER BY r.code');
        $stmt->execute([$id]);
        return $stmt->fetchAll(PDO::FETCH_COLUMN);
    }

    private function programsFor(int $id): array
    {
        $stmt = Database::pdo()->prepare('SELECT DISTINCT program_id FROM program_assignments WHERE user_id = ? AND is_active = 1');
        $stmt->execute([$id]);
        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
    }

    private function canManageAccounts(): bool { return $this->isChair(); }

    private function requireAvailableEmail(string $email): bool
    {
        $account = $this->emailAccount($email);
        if (!$account) return true;
        $id = (int)$account['id'];
        if (!(int)$account['is_active'] && $this->rolesFor($id) === ['faculty'] && $this->canManageExisting($id)) {
            Response::fail('This email belongs to an inactive faculty account. Reactivate that account to keep its records together.', 409,
                ['code' => 'inactive_faculty']);
            return false;
        }
        Response::fail('This email address is already registered.', 409);
        return false;
    }

    private function emailAccount(string $email): ?array
    {
        $stmt = Database::pdo()->prepare('SELECT id, is_active FROM users WHERE email = ? LIMIT 1');
        $stmt->execute([$email]);
        return $stmt->fetch(PDO::FETCH_ASSOC) ?: null;
    }

    private function hasProtectedReferences(PDO $pdo, int $userId): bool
    {
        $owned = [
            'account_setup_tokens.user_id', 'audit_logs.user_id', 'email_deliveries.user_id',
            'faculty_profiles.user_id', 'login_attempts.user_id', 'notifications.user_id',
            'program_assignments.user_id', 'user_roles.user_id',
        ];
        $references = $pdo->query("SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE
            WHERE REFERENCED_TABLE_SCHEMA = DATABASE() AND REFERENCED_TABLE_NAME = 'users'")
            ->fetchAll(PDO::FETCH_ASSOC);
        foreach ($references as $reference) {
            $table = $reference['TABLE_NAME'];
            $column = $reference['COLUMN_NAME'];
            if (in_array($table . '.' . $column, $owned, true)) continue;
            $quotedTable = '`' . str_replace('`', '``', $table) . '`';
            $quotedColumn = '`' . str_replace('`', '``', $column) . '`';
            $stmt = $pdo->prepare("SELECT 1 FROM {$quotedTable} WHERE {$quotedColumn} = ? LIMIT 1");
            $stmt->execute([$userId]);
            if ($stmt->fetchColumn()) return true;
        }
        return false;
    }

    public function index(Request $request): void
    {
        if (!$this->canAccess()) return;
        $pdo = Database::pdo();
        $users = $pdo->query(
            "SELECT u.id, u.employee_no, u.email, u.first_name, u.middle_name, u.last_name, u.phone,
                    u.is_active, u.last_login_at, u.created_at,
                    fp.rank_code, fp.employment_type, fp.designation, fp.field_of_specialization, fp.hire_date
               FROM users u LEFT JOIN faculty_profiles fp ON fp.user_id = u.id
              ORDER BY u.is_active DESC, u.last_name, u.first_name"
        )->fetchAll(PDO::FETCH_ASSOC);
        $roles = $pdo->query(
            'SELECT ur.user_id, r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id'
        )->fetchAll(PDO::FETCH_ASSOC);
        $assignments = $pdo->query(
            "SELECT pa.user_id, pa.program_id, p.code
               FROM program_assignments pa JOIN programs p ON p.id = pa.program_id
              WHERE pa.is_active = 1"
        )->fetchAll(PDO::FETCH_ASSOC);
        foreach ($users as &$user) {
            $id = (int)$user['id'];
            $user['roles'] = array_values(array_unique(array_column(array_filter($roles, fn($r) => (int)$r['user_id'] === $id), 'code')));
            $user['program_ids'] = array_values(array_unique(array_map('intval', array_column(array_filter($assignments, fn($a) => (int)$a['user_id'] === $id), 'program_id'))));
        }
        unset($user);
        $users = array_values(array_filter($users, fn($u) => $this->canSee($u)));
        $programs = $pdo->query('SELECT id, code, name FROM programs WHERE is_active = 1 ORDER BY code')->fetchAll(PDO::FETCH_ASSOC);
        if (!$this->isChair()) {
            $allowed = $this->assignedProgramIds();
            $programs = array_values(array_filter($programs, fn($p) => in_array((int)$p['id'], $allowed, true)));
        }
        Response::ok(['users' => $users, 'programs' => $programs]);
    }

    public function create(Request $request): void
    {
        if (!$this->canAccess()) return;
        if (!$this->jsonOnly($request)) return;
        RateLimiter::enforce('account-create-actor', (string)Auth::id(), 20, 3600, 3600);
        $data = $this->validate($request->all(), true);
        if ($data === null) return;
        if (!$this->canAssign($data['roles'], $data['program_ids'])) {
            Response::fail('You cannot create an account with those roles or programs.', 403); return;
        }
        if (!$this->requireAvailableEmail($data['email'])) return;
        $pdo = Database::pdo();
        try {
            $temporaryPassword = $this->temporaryPassword();
            $pdo->beginTransaction();
            $stmt = $pdo->prepare(
                'INSERT INTO users (employee_no, email, password_hash, first_name, last_name, middle_name, phone, is_active, must_change_password)
                 VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1)'
            );
            $stmt->execute([
                $data['employee_no'], $data['email'], password_hash($temporaryPassword, PASSWORD_BCRYPT, ['cost' => 12]),
                $data['first_name'], $data['last_name'], $data['middle_name'], $data['phone'],
            ]);
            $id = (int)$pdo->lastInsertId();
            $this->saveRolesAndPrograms($pdo, $id, $data);
            $pdo->commit();
            Audit::log(Auth::id(), 'user.create', 'users', $id, null, $this->auditData($data));
            $emailStatus = $this->sendInitialCredentials($id, $data['email'], trim($data['first_name'] . ' ' . $data['last_name']), $temporaryPassword);
            Response::ok(['id' => $id, 'email_status' => $emailStatus], $emailStatus === 'sent' ? 'Account created and login credentials emailed.' : 'Account created, but the credentials email failed. Check SMTP settings and the email delivery log.');
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            Response::fail($e->getCode() === '23000' ? 'Email or employee number is already in use.' : 'Could not create account.', $e->getCode() === '23000' ? 409 : 500);
        }
    }

    public function update(Request $request, string $id): void
    {
        if (!$this->canAccess()) return;
        if (!$this->jsonOnly($request)) return;
        $userId = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if (!$userId) { Response::fail('Invalid account ID.', 422); return; }
        $data = $this->validate($request->all(), false);
        if ($data === null) return;
        if (!$this->canManageExisting((int)$userId) || !$this->canAssign($data['roles'], $data['program_ids'])) {
            Response::fail('You cannot edit this account or assign those roles and programs.', 403); return;
        }
        $pdo = Database::pdo();
        try {
            $pdo->beginTransaction();
            $stmt = $pdo->prepare('SELECT id, email, is_active FROM users WHERE id = ? FOR UPDATE');
            $stmt->execute([$userId]);
            $old = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$old) { $pdo->rollBack(); Response::fail('Account not found.', 404); return; }
            if ($this->removesLastChair($pdo, $userId, $data['roles'])) {
                $pdo->rollBack(); Response::fail('At least one active chairperson is required.', 422); return;
            }
            $sql = 'UPDATE users SET employee_no = ?, email = ?, first_name = ?, last_name = ?, middle_name = ?, phone = ?';
            $params = [$data['employee_no'], $data['email'], $data['first_name'], $data['last_name'], $data['middle_name'], $data['phone']];
            $params[] = $userId;
            $pdo->prepare($sql . ' WHERE id = ?')->execute($params);
            $this->saveRolesAndPrograms($pdo, $userId, $data);
            $pdo->commit();
            Audit::log(Auth::id(), 'user.update', 'users', $userId, $old, $this->auditData($data));
            if ($userId === Auth::id()) Auth::reset();
            Response::ok(null, 'Account updated.');
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            Response::fail($e->getCode() === '23000' ? 'Email or employee number is already in use.' : 'Could not update account.', $e->getCode() === '23000' ? 409 : 500);
        }
    }

    public function delete(Request $request, string $id): void
    {
        if (!$this->canAccess()) return;
        if (!$this->jsonOnly($request)) return;
        $userId = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if (!$userId) { Response::fail('Invalid account ID.', 422); return; }
        if ($userId === Auth::id()) { Response::fail('You cannot deactivate your own account.', 422); return; }
        if (!$this->canManageExisting((int)$userId)) { Response::fail('You cannot deactivate this account.', 403); return; }
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('SELECT id, email, is_active FROM users WHERE id = ?');
        $stmt->execute([$userId]);
        $old = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$old) { Response::fail('Account not found.', 404); return; }
        if (!(int)$old['is_active']) { Response::fail('Account is already inactive.', 409); return; }
        if ($this->removesLastChair($pdo, (int)$userId, [])) {
            Response::fail('At least one active chairperson is required.', 422); return;
        }
        $pdo->prepare('UPDATE users SET is_active = 0 WHERE id = ?')->execute([$userId]);
        Audit::log(Auth::id(), 'user.deactivate', 'users', $userId, $old, ['is_active' => 0]);
        Response::ok(null, 'Account deactivated. Existing teaching records were kept.');
    }

    public function restore(Request $request, string $id): void
    {
        if (!$this->canAccess()) return;
        if (!$this->jsonOnly($request)) return;
        $userId = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if (!$userId) { Response::fail('Invalid account ID.', 422); return; }
        if (!$this->canManageExisting((int)$userId)) { Response::fail('You cannot reactivate this account.', 403); return; }
        $stmt = Database::pdo()->prepare('UPDATE users SET is_active = 1 WHERE id = ? AND is_active = 0');
        $stmt->execute([$userId]);
        if (!$stmt->rowCount()) { Response::fail('Inactive account not found.', 404); return; }
        Audit::log(Auth::id(), 'user.restore', 'users', $userId);
        Response::ok(null, 'Account reactivated.');
    }

    private function jsonOnly(Request $request): bool
    {
        if (!str_contains($request->headers['content-type'] ?? '', 'application/json')) {
            Response::fail('JSON content type is required.', 415);
            return false;
        }
        return true;
    }

    private function isChair(): bool
    {
        return Auth::hasRole('chairperson');
    }

    private function isCoordinator(): bool
    {
        return Auth::hasRole('program_coordinator');
    }

    private function canAccess(): bool
    {
        if ($this->isChair() || $this->isCoordinator()) return true;
        Response::fail('Forbidden: account management is not available for your role.', 403);
        return false;
    }

    private function assignedProgramIds(): array
    {
        $stmt = Database::pdo()->prepare("SELECT DISTINCT pa.program_id FROM program_assignments pa JOIN roles r ON r.id = pa.role_id WHERE pa.user_id = ? AND pa.is_active = 1 AND r.code = 'program_coordinator'");
        $stmt->execute([Auth::id()]);
        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
    }

    private function canSee(array $user): bool
    {
        if ($this->isChair()) return true;
        if ((int)$user['id'] === Auth::id()) return true;
        return in_array('faculty', $user['roles'], true)
            && !array_intersect($user['roles'], ['chairperson', 'program_coordinator'])
            && (bool)array_intersect($user['program_ids'], $this->assignedProgramIds());
    }

    private function canManageExisting(int $userId): bool
    {
        if ($this->canManageAccounts()) return true;
        $pdo = Database::pdo();
        $stmt = $pdo->prepare('SELECT r.code FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ?');
        $stmt->execute([$userId]);
        $roles = $stmt->fetchAll(PDO::FETCH_COLUMN);
        if (!$roles) return false;
        if (!$this->isCoordinator() || count($roles) !== 1 || $roles[0] !== 'faculty') return false;
        $stmt = $pdo->prepare('SELECT DISTINCT program_id FROM program_assignments WHERE user_id = ? AND is_active = 1');
        $stmt->execute([$userId]);
        $programs = array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN));
        return (bool)$programs && !array_diff($programs, $this->assignedProgramIds());
    }

    private function canAssign(array $roles, array $programs): bool
    {
        if ($this->canManageAccounts()) return true;
        return $this->isCoordinator() && $roles === ['faculty'] && (bool)$programs
            && !array_diff($programs, $this->assignedProgramIds());
    }

    private function validate(array $body, bool $creating): ?array
    {
        foreach (['first_name', 'last_name', 'email', 'employee_no', 'password', 'phone', 'middle_name',
            'rank_code', 'employment_type', 'designation', 'field_of_specialization', 'hire_date'] as $field) {
            if (isset($body[$field]) && !is_string($body[$field])) {
                Response::fail('Account field has an invalid type.', 422); return null;
            }
        }
        if (isset($body['roles']) && (!is_array($body['roles'])
            || array_filter($body['roles'], static fn($role) => !is_string($role)))) {
            Response::fail('Choose valid account roles.', 422); return null;
        }
        if (isset($body['program_ids']) && (!is_array($body['program_ids'])
            || array_filter($body['program_ids'], static fn($id) => !is_int($id) && !is_string($id)))) {
            Response::fail('Choose valid programs.', 422); return null;
        }
        $first = trim((string)($body['first_name'] ?? ''));
        $last = trim((string)($body['last_name'] ?? ''));
        $email = strtolower(trim((string)($body['email'] ?? '')));
        $employee = trim((string)($body['employee_no'] ?? ''));
        $password = (string)($body['password'] ?? '');
        $roles = $body['roles'] ?? [];
        $programs = $body['program_ids'] ?? [];
        if ($first === '' || $last === '' || mb_strlen($first) > 80 || mb_strlen($last) > 80) {
            Response::fail('First and last name are required (80 characters maximum).', 422); return null;
        }
        if (!filter_var($email, FILTER_VALIDATE_EMAIL) || strlen($email) > 120) {
            Response::fail('Enter a valid email address.', 422); return null;
        }
        if (strlen($employee) > 30 || strlen((string)($body['phone'] ?? '')) > 30) {
            Response::fail('Employee number or phone is too long.', 422); return null;
        }
        if ($password !== '') {
            Response::fail('Use the secure password setup email instead of assigning a password.', 422); return null;
        }
        if (!is_array($roles) || !$roles || array_diff($roles, self::ROLES) || count($roles) !== count(array_unique($roles))) {
            Response::fail('Choose valid account roles.', 422); return null;
        }
        $leadership = array_intersect($roles, ['chairperson', 'program_coordinator']);
        if (count($leadership) > 1) { Response::fail('Choose only one leadership role.', 422); return null; }
        if (!is_array($programs) || count($programs) !== count(array_unique($programs))) {
            Response::fail('Choose valid programs.', 422); return null;
        }
        foreach ($programs as $programId) {
            if (!ctype_digit((string)$programId) || (int)$programId < 1) {
                Response::fail('Choose valid programs.', 422); return null;
            }
        }
        $programs = array_map('intval', $programs);
        if (in_array('program_coordinator', $roles, true) && count($programs) !== 1) {
            Response::fail('A coordinator must have exactly one program.', 422); return null;
        }
        if (in_array('faculty', $roles, true) && !$programs && !in_array('chairperson', $roles, true)) {
            Response::fail('Faculty must have at least one program.', 422); return null;
        }
        $activePrograms = array_map('intval', Database::pdo()->query('SELECT id FROM programs WHERE is_active = 1')->fetchAll(PDO::FETCH_COLUMN));
        if (array_diff($programs, $activePrograms)) { Response::fail('One or more programs are invalid.', 422); return null; }
        if (in_array('chairperson', $roles, true)) $programs = $activePrograms;
        $rank = trim((string)($body['rank_code'] ?? 'Instructor')) ?: 'Instructor';
        $employment = (string)($body['employment_type'] ?? 'Full-time');
        $designation = trim((string)($body['designation'] ?? ''));
        $specialization = trim((string)($body['field_of_specialization'] ?? ''));
        $hireDate = trim((string)($body['hire_date'] ?? ''));
        if (mb_strlen($rank) > 40 || !in_array($employment, ['Full-time', 'Part-time', 'Contractual', 'Visiting'], true)
            || mb_strlen($designation) > 80 || mb_strlen($specialization) > 150
            || ($hireDate !== '' && (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $hireDate) || !checkdate((int)substr($hireDate, 5, 2), (int)substr($hireDate, 8, 2), (int)substr($hireDate, 0, 4))))) {
            Response::fail('Enter valid faculty employment details.', 422); return null;
        }
        return [
            'first_name' => $first, 'last_name' => $last, 'email' => $email,
            'employee_no' => $employee ?: null, 'middle_name' => trim((string)($body['middle_name'] ?? '')) ?: null,
            'phone' => trim((string)($body['phone'] ?? '')) ?: null, 'password' => $password,
            'roles' => array_values($roles), 'program_ids' => $programs,
            'rank_code' => $rank, 'employment_type' => $employment,
            'designation' => $designation ?: null, 'field_of_specialization' => $specialization ?: null,
            'hire_date' => $hireDate ?: null,
        ];
    }

    private function saveRolesAndPrograms(PDO $pdo, int $userId, array $data): void
    {
        $roles = $data['roles'];
        $programs = $data['program_ids'];
        $roleIds = $pdo->query('SELECT id, code FROM roles')->fetchAll(PDO::FETCH_KEY_PAIR);
        $byCode = array_flip($roleIds);
        $pdo->prepare('DELETE FROM user_roles WHERE user_id = ?')->execute([$userId]);
        $insertRole = $pdo->prepare('INSERT INTO user_roles (user_id, role_id, assigned_by) VALUES (?, ?, ?)');
        foreach ($roles as $role) $insertRole->execute([$userId, $byCode[$role], Auth::id()]);
        $pdo->prepare('UPDATE program_assignments SET is_active = 0 WHERE user_id = ?')->execute([$userId]);
        $assignmentRole = in_array('chairperson', $roles, true) ? 'chairperson' : (in_array('program_coordinator', $roles, true) ? 'program_coordinator' : 'faculty');
        $insertAssignment = $pdo->prepare('INSERT INTO program_assignments (user_id, program_id, role_id, is_active) VALUES (?, ?, ?, 1)');
        foreach ($programs as $programId) $insertAssignment->execute([$userId, $programId, $byCode[$assignmentRole]]);
        if (in_array('faculty', $roles, true)) {
            $department = (int)$pdo->query('SELECT id FROM departments ORDER BY id LIMIT 1')->fetchColumn();
            $stmt = $pdo->prepare("INSERT INTO faculty_profiles (user_id, department_id, rank_code, employment_type, designation, field_of_specialization, hire_date, is_active)
                                   VALUES (?, ?, ?, ?, ?, ?, ?, 1)
                                   ON DUPLICATE KEY UPDATE rank_code = VALUES(rank_code), employment_type = VALUES(employment_type),
                                     designation = VALUES(designation), field_of_specialization = VALUES(field_of_specialization),
                                     hire_date = VALUES(hire_date), is_active = 1");
            $stmt->execute([$userId, $department, $data['rank_code'], $data['employment_type'], $data['designation'], $data['field_of_specialization'], $data['hire_date']]);
        } else {
            $pdo->prepare('UPDATE faculty_profiles SET is_active = 0 WHERE user_id = ?')->execute([$userId]);
        }
    }

    private function removesLastChair(PDO $pdo, int $userId, array $newRoles): bool
    {
        if (in_array('chairperson', $newRoles, true)) return false;
        $current = $pdo->prepare("SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id
                                  WHERE ur.user_id = ? AND r.code = 'chairperson' LIMIT 1");
        $current->execute([$userId]);
        if (!$current->fetchColumn()) return false;
        $stmt = $pdo->prepare("SELECT COUNT(*) FROM users u JOIN user_roles ur ON ur.user_id = u.id
                               JOIN roles r ON r.id = ur.role_id WHERE r.code = 'chairperson' AND u.is_active = 1 AND u.id <> ?");
        $stmt->execute([$userId]);
        return (int)$stmt->fetchColumn() === 0;
    }

    private function auditData(array $data): array
    {
        unset($data['password']);
        return $data;
    }

    private function sendInvitation(int $id, string $email, string $name): string
    {
        try { return (new AccountInvitationService())->send($id, $email, $name); }
        catch (\Throwable $e) {
            error_log('Account invitation could not be prepared for user ' . $id . ': ' . get_class($e));
            return 'failed';
        }
    }

    private function sendInitialCredentials(int $id, string $email, string $name, string $temporaryPassword): string
    {
        try { return (new AccountInvitationService())->sendInitialCredentials($id, $email, $name, $temporaryPassword); }
        catch (\Throwable $e) {
            error_log('Account credentials could not be emailed for user ' . $id . ': ' . get_class($e));
            return 'failed';
        }
    }

    private function temporaryPassword(): string
    {
        $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
        $password = '';
        for ($i = 0; $i < 10; $i++) {
            $password .= $alphabet[random_int(0, strlen($alphabet) - 1)];
        }
        return $password;
    }
}
