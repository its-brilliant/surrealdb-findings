# 18 · Redefining a computed view also wipes its indexes *(found while preparing this repo)*

> **Note:** Found while building the local reproduction for [issue 01](01-view-overwrite-wipes-events.md) on SurrealDB 4.0.1.

## Summary

Running `DEFINE TABLE OVERWRITE v … AS SELECT …` deletes all `DEFINE INDEX` definitions on the view (`indexes: {}`) while keeping its `DEFINE FIELD` definitions, whereas `DEFINE TABLE OVERWRITE` on a `NORMAL` or `RELATION` table keeps both fields and indexes.

## What happens

After defining `DEFINE FIELD` and `DEFINE INDEX` on an `AS SELECT` computed view `v`, `INFO FOR TABLE v` lists both `fields` and `indexes`. Running `DEFINE TABLE OVERWRITE v … AS SELECT …` — for example to change `PERMISSIONS` or to refresh the view after an `OPTION IMPORT` load — leaves `fields` intact but resets `indexes` to `{}`. On `NORMAL` and `RELATION` tables, `DEFINE TABLE OVERWRITE` keeps `indexes` unchanged.

## Why we ran into it

In Brilliant, users build data-heavy dashboards backed by `AS SELECT` summary views, and after bulk-loading data under `OPTION IMPORT` (which does not update computed views automatically; see [issue 04](04-option-import-skips-default-and-value.md)), we refresh views by running `DEFINE TABLE OVERWRITE <view> … AS SELECT …`. If a view has indexes for filtered or sorted reads, refreshing the view with `DEFINE TABLE OVERWRITE` (without also re-running its `DEFINE INDEX` statements) silently drops every index on the view.

## How to reproduce

1. Define a `NORMAL` table, a `RELATION` table, and an `AS SELECT` view, and add an index to each (plus a field on the view).
2. Confirm via `INFO FOR TABLE` that all three carry their indexes.
3. Redefine each with `DEFINE TABLE OVERWRITE` and inspect `INFO FOR TABLE` again.

```sh
bash repro/18-view-overwrite-wipes-indexes/run.sh
```

## Observed output

```json
== 18: Redefining a computed view also wipes its indexes ==
Engine: 4.0.1 for linux on x86_64
[
  {
    "norm_indexes": {
      "kind_idx": "DEFINE INDEX kind_idx ON norm FIELDS kind"
    },
    "rel_indexes": {
      "in_idx": "DEFINE INDEX in_idx ON rel FIELDS in"
    },
    "step": "before_overwrite",
    "view_fields": {
      "kind": "DEFINE FIELD kind ON v TYPE string PERMISSIONS FULL"
    },
    "view_indexes": {
      "kind_idx": "DEFINE INDEX kind_idx ON v FIELDS kind"
    }
  },
  {
    "norm_indexes": {
      "kind_idx": "DEFINE INDEX kind_idx ON norm FIELDS kind"
    },
    "rel_indexes": {
      "in_idx": "DEFINE INDEX in_idx ON rel FIELDS in"
    },
    "step": "after_overwrite",
    "view_fields": {
      "kind": "DEFINE FIELD kind ON v TYPE string PERMISSIONS FULL"
    },
    "view_indexes": {}
  }
]
```

## Expected / what we'd like

`DEFINE TABLE OVERWRITE` on a computed view should preserve `DEFINE INDEX` definitions (and rebuild them against the refreshed view rows), matching how `DEFINE FIELD` on views and `DEFINE INDEX` on `NORMAL`/`RELATION` tables behave.

## Environment

- SurrealDB engine: `4.0.1` (`linux x86_64`, in-memory)
- SurrealKit: `1.0.0-rc.1`
- Environment: reproduced locally while preparing this repo
- Date: November 2026

## Workaround we use

When refreshing a view or editing its schema, run `surreal kit sync` (or re-emit all `DEFINE INDEX` statements on the view) rather than executing a standalone `DEFINE TABLE OVERWRITE` statement.
