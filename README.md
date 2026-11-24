# SurrealDB / Earth / SurrealKit findings from Brilliant

Thanks again for the great conversation. This repo collects the SurrealDB engine, SurrealKit, and SurrealDB Earth behaviours and operational sharp edges we ran into through November 2026, each as a standalone write-up with a minimal reproduction where possible.

## Who we are

**Brilliant** is a platform where people build internal business apps by talking to a coding agent. Under the hood, every customer workspace gets its own SurrealDB Earth instance and every project gets its own database (with browser live queries over WebSocket, row-level `PERMISSIONS` backed by ES256 record-user JWTs, and schema changes validated on a pinned scratch SurrealDB 4.0.1 engine via `surreal kit sync` before they are applied to Earth).

## Running the reproductions

The local Engine and SurrealKit reproductions (`01`–`07`, `18`, and the local self-hosted contrast in `10`) start a throwaway in-memory `surreal` server on a random local port, run the reproduction over HTTP `/sql`, and clean up on exit. They need only `bash`, `surreal` (with `surreal kit` for `07`), `curl`, and optionally `jq`:

```sh
# Run one reproduction (defaults to `surreal` on PATH, or ~/.surrealdb/surreal)
SURREAL_BIN=~/.surrealdb/surreal bash repro/01-view-overwrite-wipes-events/run.sh

# Run every reproduction sequentially (Earth-only scripts print "needs EARTH_HOST" and exit 0)
for f in repro/*/run.sh; do SURREAL_BIN=~/.surrealdb/surreal bash "$f"; done
```

Earth and Cloud API scripts (`08`–`17`) do not run anything remotely unless `EARTH_HOST` / `EARTH_TOKEN` / `CLOUD_TOKEN` are explicitly provided in the environment; see each issue file for the exact `curl` or SurrealQL request with placeholders.

## Findings index

| # | Title | Area | Severity for us | Status | Issue & repro |
| --- | --- | --- | --- | --- | --- |
| 01 | Redefining a computed view (`DEFINE TABLE OVERWRITE v … AS SELECT …`) wipes its events | Engine | High | reproduced locally (4.0.1) | [issue](issues/01-view-overwrite-wipes-events.md) · [repro](repro/01-view-overwrite-wipes-events/run.sh) |
| 02 | An event on a `GROUP BY` view fires with `NONE` ids and rolls back writes to the source table | Engine | Blocker | reproduced locally (4.0.1) | [issue](issues/02-grouped-view-event-rolls-back-source.md) · [repro](repro/02-grouped-view-event-rolls-back-source/run.sh) |
| 03 | A relation table's `in`/`out` are reported by `INFO FOR TABLE` as ordinary fields, and replaying them fails | Engine | Low | reproduced locally (4.0.1) | [issue](issues/03-relation-in-out-replay-fails.md) · [repro](repro/03-relation-in-out-replay-fails/run.sh) |
| 04 | `OPTION IMPORT` skips field `DEFAULT` and `VALUE` on `SCHEMAFULL` tables | Engine | Medium | reproduced locally (4.0.1) | [issue](issues/04-option-import-skips-default-and-value.md) · [repro](repro/04-option-import-skips-default-and-value/run.sh) |
| 05 | Permission predicates (`WHERE owner = $auth.id`) don't use indexes | Engine | High | reproduced locally (4.0.1) | [issue](issues/05-permission-predicates-skip-index.md) · [repro](repro/05-permission-predicates-skip-index/run.sh) |
| 06 | `DEFINE INDEX … UNIQUE CONCURRENTLY` over duplicate data succeeds, then refuses later writes | Engine | High | reproduced locally (4.0.1) | [issue](issues/06-unique-concurrently-silent-failure.md) · [repro](repro/06-unique-concurrently-silent-failure/run.sh) |
| 07 | `surreal kit sync` applies `database/schema/*.surql` in filename order | SurrealKit | Medium | reproduced locally (kit 1.0.0-rc.1, engine 4.0.1) | [issue](issues/07-surrealkit-sync-filename-order.md) · [repro](repro/07-surrealkit-sync-filename-order/run.sh) |
| 08 | Exceeding the Free allowance in one database disables every instance in the organisation | Earth | Blocker | observed on Earth (engine 4.0.0), Nov 2026 | [issue](issues/08-org-wide-allowance-disables-all-instances.md) · [repro](repro/08-org-wide-allowance-disables-all-instances/run.sh) |
| 09 | A disabled Earth instance cannot be deleted (`409` conflict) | Earth | High | observed on Earth (engine 4.0.0), Nov 2026 | [issue](issues/09-disabled-instance-cannot-be-deleted.md) · [repro](repro/09-disabled-instance-cannot-be-deleted/run.sh) |
| 10 | One large request (~600 `RELATE`s in a `FOR` loop) loses the Earth executor (`503 not_committed` / `isolate_memory`) | Earth | Blocker | observed on Earth (engine 4.0.0), Nov 2026 *(contrasted locally on 4.0.1)* | [issue](issues/10-large-request-loses-executor.md) · [repro](repro/10-large-request-loses-executor/run.sh) |
| 11 | `502 committed_unanswered` loses the reply after commit, causing duplicates on retry | Earth | Blocker | observed on Earth (engine 4.0.0), Nov 2026 | [issue](issues/11-committed-unanswered-duplicates-on-retry.md) · [repro](repro/11-committed-unanswered-duplicates-on-retry/run.sh) |
| 12 | Company networks block `wss://<instance>.surrealdb.earth/rpc` | Earth | High | observed on Earth (engine 4.0.0), Nov 2026 | [issue](issues/12-corporate-networks-block-earth-wss.md) · [repro](repro/12-corporate-networks-block-earth-wss/run.sh) |
| 13 | `POST /sql` without a `User-Agent` (or from Python `urllib`) gets `403 Error 1010` | Earth | Low | observed on Earth (engine 4.0.0), Nov 2026 | [issue](issues/13-missing-user-agent-error-1010.md) · [repro](repro/13-missing-user-agent-error-1010/run.sh) |
| 14 | Instances created via the Cloud API without `resources` come up with 1 replica | Earth | High | observed on Earth (engine 4.0.0), Nov 2026 | [issue](issues/14-cloud-api-create-defaults-one-replica.md) · [repro](repro/14-cloud-api-create-defaults-one-replica/run.sh) |
| 15 | `/clusters/<cluster-id>/usage` lags by ~2 hours and cannot be read after deletion | Earth | Medium | observed on Earth (engine 4.0.0), Nov 2026 | [issue](issues/15-usage-api-lag-and-post-delete.md) · [repro](repro/15-usage-api-lag-and-post-delete/run.sh) |
| 16 | Personal access token docs say non-GET routes are refused, and missing scopes return an opaque `403 Insufficient scopes` | Docs | Low | observed on Earth (engine 4.0.0), Nov 2026 | [issue](issues/16-pat-docs-and-opaque-403-scopes.md) · [repro](repro/16-pat-docs-and-opaque-403-scopes/run.sh) |
| 17 | Earth runs `surrealdb-4.0.0` behind `4.0.1`, and engine upgrades aren't announced in advance | Earth | Medium | observed on Earth (engine 4.0.0), Nov 2026 | [issue](issues/17-earth-engine-version-lag-and-notice.md) · [repro](repro/17-earth-engine-version-lag-and-notice/run.sh) |
| 18 | Redefining a computed view also wipes its indexes *(found while preparing this repo)* | Engine | Medium | reproduced locally (4.0.1) | [issue](issues/18-view-overwrite-wipes-indexes.md) · [repro](repro/18-view-overwrite-wipes-indexes/run.sh) |

## SurrealDB's response (Drew, Earth engineering, November 2026)

| # | Response | Our follow-up |
| --- | --- | --- |
| 01, 02, 18 | Confirmed: redefining a computed view drops its events and indexes, and events on GROUP BY views get no id. For now, put events only on normal tables, and re-run a view's `DEFINE INDEX` after changing it. | Done: no platform events on views (#750). Re-defining view indexes after a change is still to do. |
| 03 | Use `DEFINE FIELD OVERWRITE` when replaying INFO. | Already our workaround. |
| 04 | `OPTION IMPORT` skips DEFAULT and VALUE: set them explicitly. | Upgrade copy and guidance (#844). |
| 05 | Write `owner = $auth`, not `owner = $auth.id`. The first uses the index, including inside PERMISSIONS. | Presets (#826), guidance (#844). |
| 06 | Use plain `UNIQUE` when duplicates may exist (it fails up front). | Guidance (#844). |
| 07 | Files apply alphabetically: put a view after its source, or below it in the same file. | Platform check (#827). |
| 08 | The Free allowance is per organisation. Pro bills overage and disables nothing. Per-cluster caps and alerts are in progress. | Waiting on SurrealDB. |
| 09 | A disabled cluster can't be changed or deleted until the org is back under its allowance. Being investigated. | Waiting on SurrealDB. |
| 10 | Prefer set-based SQL: `INSERT RELATION INTO edge [{ in, out }, ...]` instead of FOR loops of RELATE, and keep batches modest. The executor's memory limit will matter less over time. | Upgrade copy and guidance (#844). |
| 11 | `committed_unanswered` means the commit went through: don't retry automatically. Use deterministic ids with UPSERT. An idempotency key is tracked as a request. | Upgrade copy follows this. |
| 12 | Custom domains for instances aren't supported yet and are tracked. The same-origin relay is a good workaround. | Relay in place (#717). |
| 13 | Set a `User-Agent` on server-side clients. | Done. |
| 14 | When `resources` is omitted, the API now defaults to 100 replicas. Replicas aren't billed individually: billing is request units, active executor time, live notifications, connection time and storage. | Done (#732). |
| 15 | Usage closes hourly plus a settle window, so it runs about 2 h behind. Per-cluster usage returns 404 after deletion, but org-level usage still includes deleted clusters. Live notifications are billed. | Reconcile at org level. |
| 16 | The 403 doesn't name the missing scope, and the per-route scopes aren't documented. Being looked into. | Waiting on SurrealDB. |
| 17 | Earth reports 4.0.0, and comparing major.minor is fine. No breaking changes without a lot of notice, and probably opt-in. | Pin the scratch engine to Earth's version (#841). |

Architecture suggestions from the same review:
- **Apply from outside the container:** keep the apply credential out of the container, or make it very short-lived (#843).
- **ASYNC outbox:** make the outbox event `ASYNC` with `RETRY`, install it only where an automation needs it, and prune the outbox (#840).
- **Revocation:** an `AUTHENTICATE` membership lookup can revoke access within the 15-minute token window (#842).
- **Lock expiry:** give the lock an owner and an expiry. We already have both: the lock records its run and becomes stale after the apply deadline.
