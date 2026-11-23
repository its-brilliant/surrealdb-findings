# 06 · `DEFINE INDEX … UNIQUE CONCURRENTLY` over duplicate data succeeds, then refuses later writes

## Summary

Running `DEFINE INDEX … UNIQUE CONCURRENTLY` on a table that already contains duplicate values returns `OK`, leaves the index in a background `error` state invisible in `INFO FOR TABLE`, and causes subsequent `CREATE` and `UPDATE` writes on the table to fail.

## What happens

When `contact` already contains two rows with `email: 'dup@example.com'`:
1. **Without `CONCURRENTLY`:** `DEFINE INDEX email_uniq ON contact_sync FIELDS email UNIQUE` fails immediately with:
   ```text
   Database index `email_uniq` already contains 'dup@example.com', with record `contact_sync:1`
   ```
   and the table stays healthy and writable.
2. **With `CONCURRENTLY`:** `DEFINE INDEX email_uniq ON contact_conc FIELDS email UNIQUE CONCURRENTLY` returns `status: "OK", result: null`.
   - `INFO FOR TABLE contact_conc` renders `"DEFINE INDEX email_uniq ON contact_conc FIELDS email UNIQUE"` with no indication that `CONCURRENTLY` failed.
   - `INFO FOR INDEX email_uniq ON contact_conc` shows `"building": { "status": "error", "error": "Database index `email_uniq` already contains 'dup@example.com', with record `contact_conc:1`" }`.
   - Every later `CREATE` (even with a non-duplicate value) **and** every `UPDATE` (even `UPDATE contact_conc:2 SET email = 'fixed@example.com'` to resolve the duplicate!) fails with:
     ```text
     Database index `email_uniq` on table `contact_conc` failed to build, so it cannot enforce UNIQUE for this write: fix the duplicate values and run REBUILD INDEX, or REMOVE INDEX
     ```

## Why we ran into it

In Brilliant, users ask a coding agent to evolve live business apps that already hold data — for example, adding a unique email constraint to an existing `contact` table. If `CONCURRENTLY` is used so the index build doesn't block live app traffic, our schema apply step (`surreal kit sync` followed by `INFO FOR TABLE` verification) sees the statement succeed and `INFO FOR TABLE` match, while the live app silently loses the ability to create or update rows on that table.

## How to reproduce

1. Create two tables (`contact_sync` and `contact_conc`), each seeded with two duplicate `dup@example.com` rows.
2. Run `DEFINE INDEX … UNIQUE` on `contact_sync` and `DEFINE INDEX … UNIQUE CONCURRENTLY` on `contact_conc`.
3. Inspect `INFO FOR TABLE contact_conc` and `INFO FOR INDEX email_uniq ON contact_conc`, then attempt `CREATE` and `UPDATE` on `contact_conc`.

```sh
bash repro/06-unique-concurrently-silent-failure/run.sh
```

## Observed output

```json
== 06: DEFINE INDEX ... UNIQUE CONCURRENTLY on duplicate data ==
Engine: 4.0.1 for linux on x86_64

--- 1. Without CONCURRENTLY: DEFINE INDEX statement fails immediately with a clear error ---
{
  "status": "ERR",
  "kind": "Internal",
  "result": "Database index `email_uniq` already contains 'dup@example.com', with record `contact_sync:1`"
}

--- 2. With CONCURRENTLY: DEFINE INDEX statement returns OK ---
{
  "status": "OK",
  "result": null
}

--- 3. INFO FOR TABLE contact_conc (shows index as ordinary UNIQUE, no error visible) ---
{
  "email_uniq": "DEFINE INDEX email_uniq ON contact_conc FIELDS email UNIQUE"
}

--- 4. INFO FOR INDEX email_uniq ON contact_conc (building.status = 'error') ---
{
  "building": {
    "active": false,
    "armed_shards": 0,
    "compacting": false,
    "error": "Database index `email_uniq` already contains 'dup@example.com', with record `contact_conc:1`",
    "initial": 0,
    "pending": 0,
    "queued": false,
    "status": "error"
  }
}

--- 5. Later CREATE of a brand-new unique row is refused ---
{
  "status": "ERR",
  "kind": "Query",
  "result": "Database index `email_uniq` on table `contact_conc` failed to build, so it cannot enforce UNIQUE for this write: fix the duplicate values and run REBUILD INDEX, or REMOVE INDEX"
}

--- 6. Even UPDATE contact_conc:2 to fix the duplicate is refused ---
{
  "status": "ERR",
  "kind": "Query",
  "result": "Database index `email_uniq` on table `contact_conc` failed to build, so it cannot enforce UNIQUE for this write: fix the duplicate values and run REBUILD INDEX, or REMOVE INDEX"
}
```

## Expected / what we'd like

- Either automatically roll back / drop a failed concurrent index build (or leave it non-enforcing) rather than wedging writes on the table, or provide a `WAIT` option so schema migration tools like `surreal kit sync` wait for completion and fail the migration if the build errors.
- If a failed `UNIQUE` index remains present until cleaned up, allow `UPDATE`s that resolve the duplicate values (since the error message itself suggests *"fix the duplicate values and run REBUILD INDEX"*), and surface failed index state in `INFO FOR TABLE` or `surreal kit status`.

## Environment

- SurrealDB engine: `4.0.1` (`linux x86_64`, in-memory) and `4.0.0` (Earth)
- SurrealKit: `1.0.0-rc.1`
- Environment: reproduced locally
- Date: November 2026

## Workaround we use

We emit synchronous `DEFINE INDEX … UNIQUE` (without `CONCURRENTLY`) in schema files so duplicate existing rows fail the schema apply up front before wedging the table, and check `INFO FOR INDEX` where needed.
