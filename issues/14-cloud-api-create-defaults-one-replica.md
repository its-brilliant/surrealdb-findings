# 14 · Instances created via the Cloud API without `resources` come up with 1 replica

## Summary

Even though the Earth product catalogue advertises `default_replicas: 100` (`min_replicas: 1`, `max_replicas: 100`), creating a cluster via `POST /api/cloud/v0/organizations/<org-id>/clusters` with `resources` omitted brings the cluster up with `replicas: 1`, requiring a follow-up `PATCH /clusters/<cluster-id>/resources/<resource-id>` (or explicit `replicas: 100`) to autoscale.

## What happens

1. `GET /api/cloud/v0/organizations/<org-id>/products` lists component `cloudflare_surrealdb` with `min_replicas: 1, max_replicas: 100, default_replicas: 100`.
2. When our control plane created clusters via `POST /api/cloud/v0/organizations/<org-id>/clusters` **omitting** `resources` (recording `cells: null` on our side, expecting Earth's product default of 100 autoscaling replicas):
   ```json
   {
     "product_id": "<earth-product-id>",
     "region": "cloudflare-eu",
     "name": "<cluster-name>",
     "cloudflare": {
       "location_hint": "weur",
       "capabilities": { "...": "..." }
     }
   }
   ```
   the created cluster instead came up with a single executor (`resources[0].replicas: 1`).
3. At `replicas: 1` (a single 128 MB executor), normal concurrent traffic from a single app hit `"every executor tried was full or failed"` until we resized existing clusters with:
   ```sh
   curl -sS -X PATCH \
     -H "Authorization: Bearer $CLOUD_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"replicas": 100}' \
     "https://api.surrealdb.com/api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>/resources/<resource-id>"
   ```

## Why we ran into it

Brilliant automatically provisions one SurrealDB Earth instance per customer workspace through the Cloud API when a workspace creates its first project. Because browser live queries, app reads/writes, and our coding agent's schema checks share that workspace instance, a single 128 MB executor saturates under normal single-app use; we need newly created instances to autoscale cleanly without extra manual resize steps or surprise idle charges.

## How to reproduce

1. Create an Earth cluster with `POST /api/cloud/v0/organizations/<org-id>/clusters` omitting the `resources` array.
2. Inspect `resources[0].replicas` on `GET /api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>`:

```sh
CLOUD_TOKEN=<pat> ORG_ID=<org-id> CLUSTER_ID=<cluster-id> \
  bash repro/14-cloud-api-create-defaults-one-replica/run.sh
```

## Observed output

Observed on Earth after `POST /clusters` without `resources`:

```json
{
  "id": "<cluster-id>",
  "name": "<cluster-name>",
  "state": "ready",
  "resources": [
    {
      "id": "<resource-id>",
      "component_slug": "cloudflare_surrealdb",
      "node_tier": "earth-node",
      "replicas": 1,
      "state": "ready"
    }
  ]
}
```

Resizing via `PATCH /clusters/<cluster-id>/resources/<resource-id>` with `{"replicas": 100}` moved `replicas` to `100` and eliminated the "every executor tried was full" errors.

## Expected / what we'd like

- **Create payload clarity:** should `POST /clusters` explicitly send `"resources": [{"component_id": "<component-id>", "replicas": 100}]` to match Studio's default, and why does omitting `resources` yield `1` rather than `default_replicas: 100`?
- **Replica billing and scale-down:** `replicas: 100` is the ceiling Earth autoscales up to — how are `active_seconds` billed (per active replica-second only while serving traffic, or per configured replica?), how quickly do idle replicas scale back down to zero, and is `100` the recommended ceiling for multi-database workspace instances?

## Environment

- SurrealDB engine: `surrealdb-4.0.0` on Earth
- SurrealDB Cloud API: `POST /api/cloud/v0/organizations/<org-id>/clusters`
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

We patched existing clusters via `PATCH /api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>/resources/<resource-id>` with `{"replicas": 100}` and can pass `resources: [{ component_id, replicas: 100 }]` explicitly on create once billing semantics are confirmed.
