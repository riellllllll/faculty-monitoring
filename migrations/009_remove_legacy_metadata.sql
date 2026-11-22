-- Remove obsolete evaluation wording left in reference and audit metadata.
UPDATE capabilities SET description = 'View own verified teaching-hour reports.'
  WHERE code = 'report.view_own';
UPDATE capabilities SET description = 'Edit system settings.'
  WHERE code = 'settings.manage';
DELETE FROM notifications WHERE link LIKE '/action-items%';
DELETE FROM audit_logs WHERE description REGEXP 'observation|rubric|performance|rating|coaching';
