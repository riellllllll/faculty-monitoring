-- A room has one stable public identifier for its printed QR card. This is
-- deliberately separate from attendance credentials, which may rotate later.
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS qr_public_code CHAR(32) NULL AFTER code;
ALTER TABLE rooms ADD UNIQUE KEY uq_rooms_qr_public_code (qr_public_code);

-- The chairperson can issue and print room QR cards alongside the administrator.
INSERT IGNORE INTO role_capabilities (role_id, capability_id)
SELECT r.id, c.id FROM roles r JOIN capabilities c
WHERE r.code = 'chairperson' AND c.code = 'room_qr.manage';
