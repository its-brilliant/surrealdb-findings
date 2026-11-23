-- 2. INSERT under OPTION IMPORT: skips event, AND skips both DEFAULT and VALUE on a SCHEMAFULL table.
OPTION IMPORT;
INSERT INTO ticket [{ id: ticket:imported, subject: 'Bulk Loaded' }];
