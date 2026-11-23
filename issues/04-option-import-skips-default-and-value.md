# 04 · `OPTION IMPORT` skips field `DEFAULT` and `VALUE` on `SCHEMAFULL` tables

## Summary

Inserting rows under `OPTION IMPORT` skips field `DEFAULT` and computed `VALUE` expressions alongside events, leaving non-optional fields missing on a `SCHEMAFULL` table so later ordinary `UPDATE`s on those rows fail schema validation.

## What happens

On a `SCHEMAFULL` table with non-optional `created_at TYPE datetime DEFAULT time::now()` and `slug TYPE string VALUE …`:
1. A normal `INSERT` populates `created_at`, computes `slug`, and runs `DEFINE EVENT` triggers.
2. Under `OPTION IMPORT`, `INSERT` skips `DEFINE EVENT` triggers, **and** stores the row without `created_at` or `slug` (without raising a schema error).
3. Any subsequent ordinary `UPDATE` on that imported row fails validation because `DEFAULT` only runs on creation and `created_at` is `NONE`:
   ```text
   Couldn't coerce value for field `created_at` of `ticket:imported`: Expected `datetime` but found `NONE`
   ```

*(We also saw that rows inserted under `OPTION IMPORT` do not update `AS SELECT` computed views until `DEFINE TABLE OVERWRITE` is re-run on each view.)*

## Why we ran into it

Every standard app table in Brilliant is `SCHEMAFULL` with convention fields (`owner` via `VALUE`, `actor` via `VALUE`, `created_at` via `DEFAULT time::now()`) and a platform `DEFINE EVENT` that feeds our automation outbox. When bulk-loading seed data or migrating existing customer projects into SurrealDB Earth, we used `OPTION IMPORT` so an initial import wouldn't flood the automation outbox — and discovered imported rows were missing `created_at`, `owner`, and computed fields.

## How to reproduce

1. Define a `SCHEMAFULL` table with `created_at TYPE datetime DEFAULT time::now()`, a `VALUE` field `slug`, and an event.
2. Insert `ticket:normal` normally, then insert `ticket:imported` under `OPTION IMPORT`.
3. Inspect stored rows and attempt an ordinary `UPDATE` on `ticket:imported`.

```sh
bash repro/04-option-import-skips-default-and-value/run.sh
```

## Observed output

```json
== 04: OPTION IMPORT skips field DEFAULT and VALUE on a SCHEMAFULL table ==
Engine: 4.0.1 for linux on x86_64

--- Stored rows and event outbox after normal INSERT vs OPTION IMPORT ---
{
  "outbox": [
    {
      "ticket": "ticket:normal"
    }
  ],
  "rows": [
    {
      "id": "ticket:imported",
      "subject": "Bulk Loaded"
    },
    {
      "created_at": "2026-11-23T10:44:53.265484865Z",
      "id": "ticket:normal",
      "slug": "hello-world",
      "subject": "Hello World"
    }
  ]
}

--- Later ordinary UPDATE on ticket:imported (fails because created_at was left NONE) ---
{
  "status": "ERR",
  "kind": "Validation",
  "result": "Couldn't coerce value for field `created_at` of `ticket:imported`: Expected `datetime` but found `NONE`"
}
```

## Expected / what we'd like

- Confirmation of whether skipping `DEFAULT` and `VALUE` (and leaving `SCHEMAFULL` non-optional fields unset) under `OPTION IMPORT` is intended, since `OPTION IMPORT` is natural to reach for when restoring backups vs when bulk-loading raw data without firing events.
- Ideally, a bulk-load option (or flag) that suppresses user/platform `DEFINE EVENT` triggers while still evaluating `DEFAULT`, `VALUE`, `ASSERT`, and computed views.

## Environment

- SurrealDB engine: `4.0.1` (`linux x86_64`, in-memory) and `4.0.0` (Earth)
- SurrealKit: `1.0.0-rc.1`
- Environment: reproduced locally (first hit during bulk seeds on Earth)
- Date: November 2026

## Workaround we use

During `OPTION IMPORT` loads we populate `created_at`, `owner`, `actor`, and any `VALUE` fields explicitly in the payload, and afterwards run `DEFINE TABLE OVERWRITE` on any computed views so their summaries catch up.
