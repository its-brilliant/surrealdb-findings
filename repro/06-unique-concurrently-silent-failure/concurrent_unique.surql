DEFINE TABLE contact_conc TYPE NORMAL SCHEMAFULL PERMISSIONS FULL;
DEFINE FIELD email ON contact_conc TYPE string;
CREATE contact_conc:1 CONTENT { email: 'dup@example.com' };
CREATE contact_conc:2 CONTENT { email: 'dup@example.com' };
DEFINE INDEX email_uniq ON contact_conc FIELDS email UNIQUE CONCURRENTLY;
