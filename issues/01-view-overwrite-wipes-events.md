# 01 · Redefining a computed view wipes its events

## Summary

Running `DEFINE TABLE OVERWRITE v … AS SELECT …` deletes all `DEFINE EVENT` definitions attached to the view, whereas the same `DEFINE TABLE OVERWRITE` on a `NORMAL` or `RELATION` table preserves its events.

## What happens

After defining an event on a computed view `v` (`INFO FOR TABLE v` shows `events: { audit: "DEFINE EVENT audit ON v …" }`), running `DEFINE TABLE OVERWRITE v … AS SELECT …` — for example to update its `PERMISSIONS` clause or refresh it — leaves `INFO FOR TABLE v` with `events: {}`. Running `DEFINE TABLE OVERWRITE` on a `NORMAL` or `RELATION` table keeps `events` intact.

*(While building this reproduction we also noticed `DEFINE TABLE OVERWRITE` on a view wipes its `indexes` as well; see [issue 18](18-view-overwrite-wipes-indexes.md).)*

## Why we ran into it

Brilliant is a platform where users build business apps with a coding agent, backed by SurrealDB. Our platform previously attached an internal change-outbox event to every table and verified before applying any schema edit that platform-owned events survived on a scratch 4.0.1 engine. When the agent edited a view's `PERMISSIONS` (for example to allow public read), SurrealKit emitted `DEFINE TABLE OVERWRITE v … AS SELECT …`, which dropped the platform event on the view and caused our safety check to refuse the user's change.

## How to reproduce

1. Define a `NORMAL` table, a `RELATION` table, and an `AS SELECT` computed view, and attach a `DEFINE EVENT` to each.
2. Confirm via `INFO FOR TABLE` that all three carry the event.
3. Redefine each of the three with `DEFINE TABLE OVERWRITE` (changing `PERMISSIONS NONE` to `PERMISSIONS FULL`) and inspect `INFO FOR TABLE` again.

```sh
bash repro/01-view-overwrite-wipes-events/run.sh
```

## Observed output

```json
== 01: Redefining a computed view wipes its events ==
Engine: 4.0.1 for linux on x86_64
[
  {
    "norm_events": {
      "audit": "DEFINE EVENT audit ON norm WHEN $event = 'CREATE' THEN {  }"
    },
    "rel_events": {
      "audit": "DEFINE EVENT audit ON rel WHEN $event = 'CREATE' THEN {  }"
    },
    "step": "before_overwrite",
    "view_events": {
      "audit": "DEFINE EVENT audit ON v WHEN $event = 'CREATE' THEN {  }"
    }
  },
  {
    "norm_events": {
      "audit": "DEFINE EVENT audit ON norm WHEN $event = 'CREATE' THEN {  }"
    },
    "rel_events": {
      "audit": "DEFINE EVENT audit ON rel WHEN $event = 'CREATE' THEN {  }"
    },
    "step": "after_overwrite",
    "view_events": {}
  }
]
```

## Expected / what we'd like

Either `DEFINE TABLE OVERWRITE` on a computed view should preserve attached events consistently with `NORMAL` and `RELATION` tables, or `DEFINE EVENT … ON <view>` should be explicitly refused up front if events on views are not meant to be supported.

## Environment

- SurrealDB engine: `4.0.1` (`linux x86_64`, in-memory)
- SurrealKit: `1.0.0-rc.1` (also observed when `surreal kit sync` rewrites a view)
- Environment: reproduced locally (also hit in our schema-check pipeline)
- Date: November 2026

## Workaround we use

We stopped attaching platform events to `AS SELECT` views (see also [issue 02](02-grouped-view-event-rolls-back-source.md)), only install change-outbox events on writable non-view tables, and clean up any legacy view events during schema apply.
