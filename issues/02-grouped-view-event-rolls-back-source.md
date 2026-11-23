# 02 · An event on a `GROUP BY` view fires with `NONE` ids and rolls back writes to the source table

## Summary

When a `DEFINE EVENT` is attached to a `GROUP BY` computed view, writing to the view's source table fires the event synchronously during materialisation with `$before.id = NONE` and `$after.id = NONE`, and any error inside the event rolls back the write to the source table.

## What happens

1. Querying a `GROUP BY` computed view returns rows with an `id` field (such as `totals_by_category:['books']`).
2. However, when a `CREATE`, `UPDATE`, or `DELETE` on the source table updates the materialised view, any `DEFINE EVENT` on the view receives `$before` and `$after` objects containing the projected fields (`category`, `total_qty`, `n`) **without** `id` — so `$before.id` and `$after.id` evaluate to `NONE`.
3. If the event body expects a record id — for example `record::id($after.id ?? $before.id)` — it fails with:
   ```text
   Error while processing event outbox: Incorrect arguments for function record::id(). Argument 1 was the wrong type. Expected `record` but found `NONE`
   ```
   and rolls back the `CREATE`, `UPDATE`, or `DELETE` on the **source** table.

## Why we ran into it

Brilliant lets users build business apps with a coding agent on SurrealDB, and supports background automations ("when a row changes, run an action") backed by a platform `DEFINE EVENT` that writes changed record ids (`record::id($after.id ?? $before.id)`) into an outbox table. Initially our platform attached that outbox event to every table in the project, including `AS SELECT … GROUP BY` summary views. Our 72-case schema-alter test matrix caught that any write to the underlying source table failed and rolled back whenever a grouped view had that event.

## How to reproduce

1. Define a source table (`order_item`) and a `GROUP BY` computed view (`totals_by_category`) over it.
2. Attach a logging event on the view and run `CREATE`, `UPDATE`, and `DELETE` on `order_item` to inspect `$event`, `$before`, and `$after` alongside `SELECT * FROM totals_by_category`.
3. Replace the logging event with one that calls `record::id($after.id ?? $before.id)` and attempt `CREATE`, `UPDATE`, and `DELETE` on `order_item`, then check `SELECT * FROM order_item`.

```sh
bash repro/02-grouped-view-event-rolls-back-source/run.sh
```

## Observed output

```json
== 02: Event on GROUP BY view fires with NONE ids and rolls back source writes ==
Engine: 4.0.1 for linux on x86_64

--- Part 1: What SELECT on the view returns vs what $event / $before / $after hold ---
{
  "logged_events": [
    {
      "after": {
        "category": "books",
        "n": 1,
        "total_qty": 2
      },
      "after_id": null,
      "before": null,
      "before_id": null,
      "ev": "CREATE"
    },
    {
      "after": null,
      "after_id": null,
      "before": {
        "category": "books",
        "n": 1,
        "total_qty": 5
      },
      "before_id": null,
      "ev": "DELETE"
    },
    {
      "after": {
        "category": "books",
        "n": 1,
        "total_qty": 5
      },
      "after_id": null,
      "before": {
        "category": "books",
        "n": 1,
        "total_qty": 2
      },
      "before_id": null,
      "ev": "UPDATE"
    }
  ],
  "view_rows_after_create": [
    {
      "category": "books",
      "id": "totals_by_category:['books']",
      "n": 1,
      "total_qty": 2
    }
  ]
}

--- Part 2: Event calling record::id($after.id ?? $before.id) rolls back CREATE / UPDATE / DELETE on source ---
CREATE on source:
{
  "status": "ERR",
  "kind": "Internal",
  "result": "Error while processing event outbox: Incorrect arguments for function record::id(). Argument 1 was the wrong type. Expected `record` but found `NONE`"
}
UPDATE on source:
{
  "status": "ERR",
  "kind": "Internal",
  "result": "Error while processing event outbox: Incorrect arguments for function record::id(). Argument 1 was the wrong type. Expected `record` but found `NONE`"
}
DELETE on source:
{
  "status": "ERR",
  "kind": "Internal",
  "result": "Error while processing event outbox: Incorrect arguments for function record::id(). Argument 1 was the wrong type. Expected `record` but found `NONE`"
}
Source table rows afterwards (all three writes rolled back):
[
  {
    "category": "music",
    "id": "order_item:existing",
    "qty": 1
  }
]
```

## Expected / what we'd like

Confirmation of whether `DEFINE EVENT` on a computed view is meant to be supported:
- If supported, `$before` and `$after` in a view event should include the view row's `id` (matching `SELECT * FROM <view>`), and documentation should note that synchronous view events run inside the source write's transaction.
- If not supported, `DEFINE EVENT … ON <view>` should be rejected at definition time.

## Environment

- SurrealDB engine: `4.0.1` (`linux x86_64`, in-memory)
- SurrealKit: `1.0.0-rc.1`
- Environment: reproduced locally
- Date: November 2026

## Workaround we use

We never attach events to `AS SELECT` views (only to writable tables), and our control plane refuses converting a table into a view while an automation watches that table.
