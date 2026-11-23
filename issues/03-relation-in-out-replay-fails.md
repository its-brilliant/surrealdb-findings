# 03 · A relation table's `in`/`out` are reported by `INFO FOR TABLE` as ordinary fields, and replaying them fails

## Summary

`INFO FOR TABLE` on a `TYPE RELATION` table returns its automatic `in` and `out` columns as ordinary `DEFINE FIELD` statements, and replaying those statements onto an empty database after `DEFINE TABLE … TYPE RELATION` fails with `The field 'in' already exists`.

## What happens

Defining `DEFINE TABLE performed TYPE RELATION IN track OUT artist SCHEMAFULL` automatically creates `in` and `out` fields on `performed`. Inspecting `INFO FOR TABLE performed` lists them alongside user-defined fields as:

```surql
DEFINE FIELD in ON performed TYPE record<track> PERMISSIONS FULL
DEFINE FIELD out ON performed TYPE record<artist> PERMISSIONS FULL
```

When a schema tool replays `INFO FOR DB` and `INFO FOR TABLE` onto an empty database, `DEFINE TABLE performed TYPE RELATION …` creates `in` and `out`, and the replayed `DEFINE FIELD in` / `DEFINE FIELD out` statements immediately fail with:

```text
The field 'in' already exists
The field 'out' already exists
```

## Why we ran into it

In Brilliant, users build apps by talking to a coding agent that edits `.surql` schema files. Before applying any schema edit to SurrealDB Earth, our platform spins up an in-memory scratch SurrealDB 4.0.1 engine, seeds it with the live database's current definitions read via `INFO FOR DB` and `INFO FOR TABLE`, runs `surreal kit sync`, and compares the engine's before/after `INFO` output. Seeding the scratch engine verbatim from `INFO` failed as soon as a project contained a `TYPE RELATION` edge table.

## How to reproduce

1. Define `track`, `artist`, and `DEFINE TABLE performed TYPE RELATION IN track OUT artist SCHEMAFULL` on one database.
2. Read `(INFO FOR DB).tables` and `(INFO FOR TABLE performed).fields`.
3. Execute those definitions verbatim on a fresh empty database.

```sh
bash repro/03-relation-in-out-replay-fails/run.sh
```

## Observed output

```json
== 03: Replaying a RELATION table's INFO FOR TABLE fields fails on in/out ==
Engine: 4.0.1 for linux on x86_64

--- 1. Define TYPE RELATION table on 'test' and read INFO ---
{
  "fields": {
    "in": "DEFINE FIELD in ON performed TYPE record<track> PERMISSIONS FULL",
    "out": "DEFINE FIELD out ON performed TYPE record<artist> PERMISSIONS FULL",
    "role": "DEFINE FIELD role ON performed TYPE none | string PERMISSIONS FULL"
  },
  "table_def": "DEFINE TABLE performed TYPE RELATION IN track OUT artist SCHEMAFULL PERMISSIONS NONE"
}

--- 2. Replay INFO definitions verbatim onto empty database 'fresh' ---
DEFINE TABLE track TYPE NORMAL SCHEMAFULL PERMISSIONS NONE;
DEFINE TABLE artist TYPE NORMAL SCHEMAFULL PERMISSIONS NONE;
DEFINE TABLE performed TYPE RELATION IN track OUT artist SCHEMAFULL PERMISSIONS NONE;
DEFINE FIELD in ON performed TYPE record<track> PERMISSIONS FULL;
DEFINE FIELD out ON performed TYPE record<artist> PERMISSIONS FULL;
DEFINE FIELD role ON performed TYPE none | string PERMISSIONS FULL;

--- 3. Result of replay ---
[
  {
    "status": "ERR",
    "kind": "Internal",
    "result": "The field 'in' already exists"
  },
  {
    "status": "ERR",
    "kind": "Internal",
    "result": "The field 'out' already exists"
  }
]
```

## Expected / what we'd like

Either `INFO` output should be round-trip replayable onto an empty database (for instance by accepting an identical `DEFINE FIELD in`/`out` after `DEFINE TABLE … TYPE RELATION` or emitting `OVERWRITE`), or `INFO FOR TABLE` should distinguish automatic relation endpoints from user-defined fields unless the user customized them.

## Environment

- SurrealDB engine: `4.0.1` (`linux x86_64`, in-memory) and `4.0.0` (Earth)
- SurrealKit: `1.0.0-rc.1`
- Environment: reproduced locally (first encountered when seeding scratch databases from Earth `INFO`)
- Date: November 2026

## Workaround we use

When seeding our scratch engine from `INFO FOR TABLE`, we rewrite `DEFINE FIELD` statements to `DEFINE FIELD OVERWRITE`.
