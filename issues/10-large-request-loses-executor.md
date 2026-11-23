# 10 · One large request (~600 `RELATE`s in a `FOR` loop) loses the Earth executor

## Summary

On SurrealDB Earth (`earth-node`: 1 CPU, 128 MB), a single bulk-seed request inserting 150–250 rows across 4 tables plus ~600 `RELATE` statements in a `FOR` loop consistently fails with `503 not_committed` ("the executor was lost before any of the request committed") or `isolate_memory`, even on an instance scaled to 100 replicas.

## What happens

During bulk imports on Earth (`OPTION IMPORT` + `INSERT` batches + a `FOR` loop of `RELATE` statements), requests repeatedly failed with:

```json
{"error":"not_committed","information":"the executor was lost before any of the request committed","retry":true}
```

as well as:

```text
overloaded: the executor's isolate has no memory for this request now; retry (isolate_memory)
The call has been terminated because the connection was closed
```

Scaling the instance from 1 replica to Earth's autoscaling default of 100 replicas eliminated multi-request "busy" / "full" errors, **but a single request of 150–250 rows with ~600 `RELATE`s in a `FOR` loop still failed every time**, whereas splitting the same data into batches of 10–50 rows succeeded. On self-hosted SurrealDB 4.0.1, the exact same 200-row + 600-`RELATE` request (~68 KB) commits in milliseconds.

## Why we ran into it

In Brilliant, users build data-backed apps with a coding agent, and we both seed demo datasets (such as a music catalogue with 113,842 tracks, 29,747 artists, and 157,940 `performed` graph edges) and migrate existing customer projects onto SurrealDB Earth. Knowing the per-request memory ceiling and which SurrealQL shapes spike executor memory lets our platform and agent size batches safely without losing executors mid-load.

## How to reproduce

`repro/10-large-request-loses-executor/generate.sh` emits the SurrealQL payload (`OPTION IMPORT`, `INSERT` into 4 tables, and a `FOR` loop of `RELATE`s; defaults to 200 rows/table and 600 edges).

Run locally against a throwaway self-hosted 4.0.1 engine (succeeds cleanly):

```sh
bash repro/10-large-request-loses-executor/run.sh
```

Generate the `.surql` file on its own, or compare small vs large batches against an Earth instance:

```sh
# Emit the 200-row / 600-RELATE payload (~68 KB)
bash repro/10-large-request-loses-executor/generate.sh 200 600 > /tmp/batch-large.surql

# Emit a 25-row / 75-RELATE batch (succeeds on Earth)
bash repro/10-large-request-loses-executor/generate.sh 25 75 > /tmp/batch-small.surql

# Run against Earth when EARTH_HOST=<instance>.surrealdb.earth and EARTH_TOKEN=<token> are set:
EARTH_HOST=<instance>.surrealdb.earth EARTH_TOKEN=<token> \
  bash repro/10-large-request-loses-executor/run.sh
```

## Observed output

Local self-hosted run (`4.0.1`):

```json
== 10: One large request (200 rows x 4 tables + 600 RELATEs in a FOR loop) ==
Generated SurrealQL payload: 68116 bytes (200 rows/table, 600 RELATEs)

--- Self-hosted contrast on local 4.0.1 for linux on x86_64 ---
{
  "artists": 200,
  "edges": 600,
  "tracks": 200
}
```

Observed on Earth (`earth-node`, 1 CPU / 128 MB, 100 replicas) for the 150–250 row + ~600 `RELATE` batch:

```http
HTTP/2 503
content-type: application/json

{"error":"not_committed","information":"the executor was lost before any of the request committed","retry":true}
```

## Expected / what we'd like

- Clear documentation of the **per-request memory budget** on `earth-node` (and whether larger executor node tiers are planned).
- Official **bulk-load guidance for Earth**: recommended batch sizes, whether `/import` has a lower memory footprint than `/sql`, and which statement shapes to avoid on 128 MB isolates (for example `FOR` loops of `RELATE` vs batch `INSERT RELATION INTO`, `GROUP BY` over 100k+ rows, or building full-text indexes on 100k+ rows).

## Environment

- SurrealDB engine: `surrealdb-4.0.0` on Earth (`earth-node`, 1 CPU / 128 MB, up to 100 replicas); contrasted locally on `4.0.1` (`linux x86_64`, in-memory)
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

We cut bulk loads down to small batches of 10–50 rows per `/sql` request (and teach our agent never to run unbounded scans or large in-memory aggregations in a single query).
