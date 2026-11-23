-- Define a source table, plus one NORMAL table, one RELATION table, and one AS SELECT view,
-- each carrying an identical DEFINE EVENT.
DEFINE TABLE src TYPE NORMAL SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD kind ON src TYPE string;

DEFINE TABLE norm TYPE NORMAL SCHEMAFULL PERMISSIONS NONE;
DEFINE EVENT audit ON norm WHEN $event = 'CREATE' THEN {};

DEFINE TABLE rel TYPE RELATION IN src OUT src SCHEMAFULL PERMISSIONS NONE;
DEFINE EVENT audit ON rel WHEN $event = 'CREATE' THEN {};

DEFINE TABLE v TYPE NORMAL AS SELECT kind, count() AS n FROM src GROUP BY kind PERMISSIONS NONE;
DEFINE EVENT audit ON v WHEN $event = 'CREATE' THEN {};

RETURN {
  step: 'before_overwrite',
  norm_events: (INFO FOR TABLE norm).events,
  rel_events:  (INFO FOR TABLE rel).events,
  view_events: (INFO FOR TABLE v).events
};

-- Redefine each table with DEFINE TABLE OVERWRITE to change PERMISSIONS NONE -> PERMISSIONS FULL.
DEFINE TABLE OVERWRITE norm TYPE NORMAL SCHEMAFULL PERMISSIONS FULL;
DEFINE TABLE OVERWRITE rel  TYPE RELATION IN src OUT src SCHEMAFULL PERMISSIONS FULL;
DEFINE TABLE OVERWRITE v    TYPE NORMAL AS SELECT kind, count() AS n FROM src GROUP BY kind PERMISSIONS FULL;

RETURN {
  step: 'after_overwrite',
  norm_events: (INFO FOR TABLE norm).events,
  rel_events:  (INFO FOR TABLE rel).events,
  view_events: (INFO FOR TABLE v).events
};
