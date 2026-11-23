-- Define a source table, plus one NORMAL table, one RELATION table, and one AS SELECT view,
-- each carrying a DEFINE FIELD (where applicable) and a DEFINE INDEX.
DEFINE TABLE src TYPE NORMAL SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD kind ON src TYPE string;

DEFINE TABLE norm TYPE NORMAL SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD kind ON norm TYPE string;
DEFINE INDEX kind_idx ON norm FIELDS kind;

DEFINE TABLE rel TYPE RELATION IN src OUT src SCHEMAFULL PERMISSIONS NONE;
DEFINE INDEX in_idx ON rel FIELDS in;

DEFINE TABLE v TYPE NORMAL AS SELECT kind, count() AS n FROM src GROUP BY kind PERMISSIONS NONE;
DEFINE FIELD kind ON v TYPE string;
DEFINE INDEX kind_idx ON v FIELDS kind;

RETURN {
  step: 'before_overwrite',
  norm_indexes: (INFO FOR TABLE norm).indexes,
  rel_indexes:  (INFO FOR TABLE rel).indexes,
  view_fields:  (INFO FOR TABLE v).fields,
  view_indexes: (INFO FOR TABLE v).indexes
};

-- Redefine each table with DEFINE TABLE OVERWRITE (for example, changing PERMISSIONS or refreshing the view after OPTION IMPORT).
DEFINE TABLE OVERWRITE norm TYPE NORMAL SCHEMAFULL PERMISSIONS FULL;
DEFINE TABLE OVERWRITE rel  TYPE RELATION IN src OUT src SCHEMAFULL PERMISSIONS FULL;
DEFINE TABLE OVERWRITE v    TYPE NORMAL AS SELECT kind, count() AS n FROM src GROUP BY kind PERMISSIONS FULL;

RETURN {
  step: 'after_overwrite',
  norm_indexes: (INFO FOR TABLE norm).indexes,
  rel_indexes:  (INFO FOR TABLE rel).indexes,
  view_fields:  (INFO FOR TABLE v).fields,
  view_indexes: (INFO FOR TABLE v).indexes
};
