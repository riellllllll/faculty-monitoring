-- Coordinators can view, print, and add rooms with permanent QR cards.
INSERT IGNORE INTO role_capabilities (role_id, capability_id)
SELECT r.id, c.id FROM roles r JOIN capabilities c
WHERE r.code = 'program_coordinator' AND c.code = 'room_qr.manage';

UPDATE capabilities SET description = 'View, print, and add rooms with QR cards.'
WHERE code = 'room_qr.manage';
