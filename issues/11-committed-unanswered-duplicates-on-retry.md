# 11 · `502 committed_unanswered` loses the reply after commit, causing duplicates on retry

## Summary

On SurrealDB Earth, `/sql` requests occasionally return `502 committed_unanswered` when the transaction committed on the executor but the reply was lost in transit, so retrying the request writes rows and `RELATE` edges a second time.

## What happens

Under load or during bulk seeding over HTTPS (`POST https://<instance>.surrealdb.earth/sql`), some requests return HTTP `502` with error code `committed_unanswered` ("the request committed; …"). Because the caller receives a `502` error without the query result:
- Any standard HTTP retry re-executes the statements.
- Statements without deterministic record ids — such as `CREATE <table> CONTENT …` or `RELATE $from->edge->$to` — create duplicate records and duplicate graph edges. In one bulk seed on Earth we had to deduplicate **1,173 duplicate `performed` edges** created by retries.
- During schema changes (`surreal kit sync`), an interrupted reply leaves the caller unsure how far the migration progressed.

## Why we ran into it

Brilliant runs both schema migrations and data-migration batches against SurrealDB Earth over HTTPS from Cloudflare Workers and workspace containers. When upgrading existing customer projects onto SurrealDB Earth, every batch write must be safe to retry across transient network or gateway drops without silently duplicating user data or graph edges.

## How to reproduce

`committed_unanswered` is a transient gateway/executor condition on Earth rather than something deterministic on a single call, so `repro/11-committed-unanswered-duplicates-on-retry/batch.surql` shows the exact request shape affected when a retry fires after `502 committed_unanswered`:

```surql
BEGIN TRANSACTION;
UPSERT track:1  CONTENT { title: 'Song 1' };
UPSERT artist:1 CONTENT { name: 'Artist 1' };
RELATE track:1->performed->artist:1 SET ord = 1;
COMMIT TRANSACTION;
```

```sh
# Prints "needs EARTH_HOST" and exits 0 when unset:
bash repro/11-committed-unanswered-duplicates-on-retry/run.sh
```

## Observed output

Observed on Earth during bulk loads:

```http
HTTP/2 502
content-type: application/json

{"error":"committed_unanswered","information":"the request committed, ...","retry":false}
```

Retrying a batch containing `RELATE $from->performed->$to` produced duplicate `performed` edge records between identical `(in, out)` pairs (1,173 duplicate edges in our seed dataset).

## Expected / what we'd like

- An **idempotency header / request id** (for example `Idempotency-Key: <uuid>`) that Earth or the engine deduplicates on for a short window, returning the cached outcome (or confirming commit) on retry instead of executing the transaction twice.
- Short of an idempotency key, official guidance on recommended idempotent patterns for bulk writes and `RELATE` edges on Earth.

## Environment

- SurrealDB engine: `surrealdb-4.0.0` on Earth
- Endpoint: `POST https://<instance>.surrealdb.earth/sql`
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

- For data loads, we do not automatically retry `502 committed_unanswered`, and we assign deterministic record ids (including deterministic edge ids or `UNIQUE` `(in, out)` indexes on relation tables) so `UPSERT` / `INSERT … ON DUPLICATE KEY UPDATE` is idempotent.
- For schema changes, we record an `unverified` state in a project lock table when a reply drops and reconcile live `INFO` against the checked schema on the next apply.
