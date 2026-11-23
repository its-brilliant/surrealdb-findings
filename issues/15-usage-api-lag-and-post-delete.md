# 15 · `/clusters/<cluster-id>/usage` lags by ~2 hours and cannot be read after deletion

## Summary

The per-instance Earth usage endpoint (`GET /api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>/usage`) lags behind live traffic by roughly two hours, and once a cluster is deleted its final usage reading is no longer retrievable.

## What happens

1. **~2-hour metering lag:** During our benchmark and spike runs on a newly provisioned Earth cluster, querying `GET /api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>/usage` (as well as `/resources/usage` and `/spend`) ~65 minutes after creation — after hundreds of HTTPS, WebSocket, and live-query operations — still returned an empty `earth: []` meter array. (The OpenAPI docs note that `earth` meters can trail `period_end` by about two hours.)
2. **No post-deletion reading:** Once `DELETE /clusters/<cluster-id>` completes (within seconds), `GET /clusters/<cluster-id>/usage` returns `404`, so any un-reported usage accumulated in the final ~2-hour window before deletion cannot be read per cluster.

## Why we ran into it

Brilliant maps each customer workspace to its own SurrealDB Earth instance so we can meter, attribute, and bound usage per customer workspace. Because there is no per-instance spend cap on Earth yet ([issue 08](08-org-wide-allowance-disables-all-instances.md)), a 2-hour lag leaves a wide window in which a runaway workload can burn millions of request units before our control plane sees it, and deleting a customer workspace prevents reading its final two hours of usage for billing reconciliation.

## How to reproduce

1. Provision an Earth cluster, execute queries against it, and poll the usage endpoint over the first hour:

```sh
curl -sS \
  -H "Authorization: Bearer $CLOUD_TOKEN" \
  -H "Accept: application/json" \
  "https://api.surrealdb.com/api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>/usage"
```

2. Delete the cluster (`DELETE /clusters/<cluster-id>`), wait ~10 seconds for deletion to complete, and repeat the `GET …/usage` call.

```sh
CLOUD_TOKEN=<pat> ORG_ID=<org-id> CLUSTER_ID=<cluster-id> \
  bash repro/15-usage-api-lag-and-post-delete/run.sh
```

## Observed output

Observed on Earth ~65 minutes after creating a cluster and running read/write/live-query suites:

```json
{
  "earth": []
}
```

And after `DELETE /clusters/<cluster-id>` completed:

```http
HTTP/2 404
content-type: application/json

{"error":"not_found","message":"cluster not found"}
```

## Expected / what we'd like

- A **lower-latency usage feed** (ideally within a few minutes) so multi-tenant platforms can alert on or throttle runaway customer workloads promptly.
- **Post-deletion usage retention** (for example keeping `/clusters/<cluster-id>/usage` readable for the billing cycle, or an organisation-wide usage breakdown grouped by `cluster_id` including deleted clusters) for accurate final billing.
- Confirmation on whether `live_notifications` count toward billable request units alongside `units`.

## Environment

- SurrealDB engine: `surrealdb-4.0.0` on Earth
- SurrealDB Cloud API: `GET /api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>/usage`
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

We poll `/clusters/<cluster-id>/usage` periodically with tolerance for the 2-hour lag and snapshot the latest known meter reading in our own database before deleting a cluster.
