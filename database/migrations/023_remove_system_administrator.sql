-- Chairperson already owns the working administrative routes. Keep former
-- administrator records for audit, but retire their login when a chair exists.
SET @admin_role_id = (SELECT id FROM roles WHERE code = 'admin');
SET @chair_role_id = (SELECT id FROM roles WHERE code = 'chairperson');
SET @active_chairs = (SELECT COUNT(*) FROM users u
  JOIN user_roles ur ON ur.user_id = u.id
  WHERE ur.role_id = @chair_role_id AND u.is_active = 1);

UPDATE users u JOIN user_roles ur ON ur.user_id = u.id
SET u.is_active = 0, u.auth_version = u.auth_version + 1
WHERE ur.role_id = @admin_role_id AND @active_chairs > 0 AND u.is_active = 1;

INSERT IGNORE INTO user_roles (user_id, role_id, assigned_by)
SELECT user_id, @chair_role_id, assigned_by FROM user_roles
WHERE role_id = @admin_role_id AND @chair_role_id IS NOT NULL;

UPDATE program_assignments SET role_id = @chair_role_id
WHERE role_id = @admin_role_id AND @chair_role_id IS NOT NULL;

DELETE FROM user_roles WHERE role_id = @admin_role_id;
DELETE FROM roles WHERE id = @admin_role_id;
