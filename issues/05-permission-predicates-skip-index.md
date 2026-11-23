# 05 · Permission predicates (`WHERE owner = $auth.id`) don't use indexes

## Summary

On a table with `PERMISSIONS FOR select WHERE owner = $auth.id` and an index on `owner`, a record user's `SELECT * FROM note` and `SELECT * FROM note WHERE owner = $auth.id` both plan as `PermissionFilter > TableScan`; only an explicit `WHERE owner = $auth` in the query uses `IndexScan`.

## What happens

With `DEFINE INDEX note_owner_idx ON note FIELDS owner` and `PERMISSIONS FOR select WHERE owner = $auth.id`, running `EXPLAIN` as record user `user:alice` gives:
1. `SELECT * FROM note EXPLAIN` → `SelectProject > PermissionFilter > TableScan`.
2. `SELECT * FROM note WHERE owner = $auth EXPLAIN` → `SelectProject > PermissionFilter > IndexScan`.
3. `SELECT * FROM note WHERE owner = $auth.id EXPLAIN` → `SelectProject > Filter (owner = (user:alice).id) > PermissionFilter > TableScan`.

Notice the clue in query 3's `Filter` attribute: `"predicate": "owner = (user:alice).id"`. Substituting `$auth` produces the `RecordId` `user:alice`, leaving `.id` as an unevaluated field access `(user:alice).id` rather than folding it to `user:alice`, so the index planner does not treat the right-hand side as a constant record id. (We also saw that compound rules like `WHERE owner = $auth OR 'admin' IN $token.roles` fall back to `PermissionFilter > TableScan` for non-admin users when `SELECT * FROM note` has no explicit `WHERE owner = $auth`.)

## Why we ran into it

In Brilliant, browser apps connect directly to SurrealDB Earth as record users, and row-level security lives in `DEFINE TABLE … PERMISSIONS` (for example, our "private" preset allows owners and workspace admins to read rows and automatically indexes `owner`). On Earth, every scanned row costs request units and runs inside a 128 MB executor, so a `TableScan` across tens of thousands of rows when a user only owns 20 rows is both slow and expensive.

## How to reproduce

1. Define a `TYPE RECORD` access method (`app`), a `note` table with `PERMISSIONS FOR select WHERE owner = $auth.id`, and `DEFINE INDEX note_owner_idx ON note FIELDS owner`.
2. Seed rows for `user:alice` and `user:bob`, then sign in over HTTP `/signin` as `user:alice`.
3. Run `EXPLAIN` for `SELECT * FROM note`, `SELECT * FROM note WHERE owner = $auth`, and `SELECT * FROM note WHERE owner = $auth.id`.

```sh
bash repro/05-permission-predicates-skip-index/run.sh
```

## Observed output

```json
== 05: Permission predicates (WHERE owner = $auth.id) do not use indexes ==
Engine: 4.0.1 for linux on x86_64
Signed in via HTTP /signin as record user user:alice

--- 1. EXPLAIN: SELECT * FROM note ---
{
  "attributes": {
    "projections": "*"
  },
  "children": [
    {
      "attributes": {
        "predicate": "<permission>"
      },
      "children": [
        {
          "attributes": {
            "direction": "Forward",
            "table": "note"
          },
          "context": "Db",
          "operator": "TableScan"
        }
      ],
      "context": "Db",
      "operator": "PermissionFilter"
    }
  ],
  "context": "Db",
  "operator": "SelectProject"
}

--- 2. EXPLAIN: SELECT * FROM note WHERE owner = $auth ---
{
  "attributes": {
    "projections": "*"
  },
  "children": [
    {
      "attributes": {
        "predicate": "<permission>"
      },
      "children": [
        {
          "attributes": {
            "access": "<permission>",
            "direction": "Forward",
            "index": "<permission>",
            "table": "note"
          },
          "context": "Db",
          "operator": "IndexScan"
        }
      ],
      "context": "Db",
      "operator": "PermissionFilter"
    }
  ],
  "context": "Db",
  "operator": "SelectProject"
}

--- 3. EXPLAIN: SELECT * FROM note WHERE owner = $auth.id ---
{
  "attributes": {
    "projections": "*"
  },
  "children": [
    {
      "attributes": {
        "predicate": "owner = (user:alice).id"
      },
      "children": [
        {
          "attributes": {
            "predicate": "<permission>"
          },
          "children": [
            {
              "attributes": {
                "direction": "Forward",
                "table": "note"
              },
              "context": "Db",
              "operator": "TableScan"
            }
          ],
          "context": "Db",
          "operator": "PermissionFilter"
        }
      ],
      "context": "Db",
      "operator": "Filter"
    }
  ],
  "context": "Db",
  "operator": "SelectProject"
}
```

## Expected / what we'd like

- Constant-fold `$auth.id` (i.e. `(record).id`) to the `RecordId` during planning so `owner = $auth.id` uses indexes identically to `owner = $auth`, both in `WHERE` clauses and inside `PERMISSIONS`.
- Ideally, constant-fold `$token.*` session claims before index selection as well, so a rule like `WHERE 'note' IN $token.tables AND (owner = $auth.id OR 'admin' IN $token.roles)` simplifies to `owner = user:alice` for a non-admin session and plans as `IndexScan` without requiring the client query to repeat the filter.

## Environment

- SurrealDB engine: `4.0.1` (`linux x86_64`, in-memory) and `4.0.0` (Earth)
- SurrealKit: `1.0.0-rc.1`
- Environment: reproduced locally
- Date: November 2026

## Workaround we use

We teach our coding agent to add an explicit `.where(raw("owner = $auth"))` (specifically `$auth`, not `$auth.id`) when querying a user's own rows on a growing table.
