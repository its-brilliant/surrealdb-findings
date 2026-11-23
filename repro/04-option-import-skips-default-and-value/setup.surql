DEFINE TABLE outbox TYPE NORMAL SCHEMALESS PERMISSIONS FULL;

DEFINE TABLE ticket TYPE NORMAL SCHEMAFULL PERMISSIONS FULL;
DEFINE FIELD subject    ON ticket TYPE string;
DEFINE FIELD slug       ON ticket TYPE string VALUE string::lowercase(string::replace(subject, ' ', '-'));
DEFINE FIELD created_at ON ticket TYPE datetime DEFAULT time::now();

DEFINE EVENT on_ticket ON ticket WHEN $event = 'CREATE' THEN {
  CREATE outbox CONTENT { ticket: $after.id };
};

-- 1. Normal INSERT (without OPTION IMPORT): populates DEFAULT, VALUE, and fires event.
INSERT INTO ticket [{ id: ticket:normal, subject: 'Hello World' }];
