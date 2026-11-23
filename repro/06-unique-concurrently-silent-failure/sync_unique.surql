DEFINE TABLE contact_sync TYPE NORMAL SCHEMAFULL PERMISSIONS FULL;
DEFINE FIELD email ON contact_sync TYPE string;
CREATE contact_sync:1 CONTENT { email: 'dup@example.com' };
CREATE contact_sync:2 CONTENT { email: 'dup@example.com' };
DEFINE INDEX email_uniq ON contact_sync FIELDS email UNIQUE;
