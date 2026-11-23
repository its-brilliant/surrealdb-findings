# 09 · A disabled Earth instance cannot be deleted (`409` conflict)

## Summary

Calling `DELETE /api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>` on an Earth cluster in `state: "disabled"` is refused with `409 Conflict` instead of deleting the cluster.

## What happens

When an Earth cluster is disabled (for example `disabled_cause: "over_allowance"`), attempting to delete it via the Cloud API returns HTTP `409`:

```text
the cluster is disabled … it is enabled again once it subscribes to Earth Pro or the month ends
```

## Why we ran into it

Brilliant provisions one Earth instance per customer workspace and also spins up temporary instances for testing. When our organisation hit the Free allowance ([issue 08](08-org-wide-allowance-disables-all-instances.md)), we tried to delete leftover test instances to clean up and reduce storage/instance usage — and found the Cloud API refused every `DELETE` until we subscribed to Earth Pro.

## How to reproduce

With an Earth cluster in `state: "disabled"`:

```sh
curl -i -sS -X DELETE \
  -H "Authorization: Bearer $CLOUD_TOKEN" \
  -H "Accept: application/json" \
  "https://api.surrealdb.com/api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>"
```

Or using the wrapper script:

```sh
CLOUD_TOKEN=<pat> ORG_ID=<org-id> CLUSTER_ID=<cluster-id> bash repro/09-disabled-instance-cannot-be-deleted/run.sh
```

## Observed output

Observed on Earth (anonymised):

```http
HTTP/2 409
content-type: application/json

{
  "error": "failed_precondition",
  "message": "the cluster is disabled; it is enabled again once it subscribes to Earth Pro or the month ends"
}
```

## Expected / what we'd like

Deleting an instance (`DELETE /clusters/<cluster-id>`) should always be permitted when a cluster is `disabled` (or `failed`), so operators can clean up unwanted instances and stop accruing storage usage without first having to re-enable the cluster.

## Environment

- SurrealDB engine: `surrealdb-4.0.0` on Earth
- SurrealDB Cloud API: `DELETE /api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>`
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

Upgrading the organisation to Earth Pro re-enabled the clusters so leftover test instances could be deleted; our control plane now runs on Earth Pro.
