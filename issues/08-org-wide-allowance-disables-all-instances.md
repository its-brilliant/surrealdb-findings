# 08 · Exceeding the Free allowance in one database disables every instance in the organisation

## Summary

On Earth Free, request-unit allowance is tracked across the whole organisation rather than per instance, so one bulk import (~3.4M request units) pushed our organisation over its monthly allowance and disabled **every** Earth instance in the organisation (`disabled_cause: "over_allowance"`).

## What happens

After a single heavy import into one database consumed roughly 3.4M request units on an Earth Free organisation:
- Every cluster returned by `GET /api/cloud/v0/organizations/<org-id>/clusters` transitioned to `state: "disabled"` with `disabled_cause: "over_allowance"` — including unrelated customer workspace instances and CI instances that had minimal usage.
- `GET /api/cloud/v0/organizations/<org-id>/clusters/<cluster-id>/auth` and new cluster creations returned `409`.

## Why we ran into it

Brilliant is a multi-tenant platform where people build internal business apps with a coding agent. To isolate customers from one another, we provision one SurrealDB Earth instance per customer workspace (and one database per project) inside our SurrealDB Cloud organisation. A single workspace importing a large dataset must never be able to take down every other customer workspace in our organisation.

## How to reproduce

1. On an Earth Free organisation with two or more Earth clusters, run a bulk import in one cluster until organisation usage exceeds the monthly Free request-unit allowance.
2. Inspect all clusters in the organisation via the Cloud API:

```sh
curl -sS \
  -H "Authorization: Bearer $CLOUD_TOKEN" \
  -H "Accept: application/json" \
  "https://api.surrealdb.com/api/cloud/v0/organizations/<org-id>/clusters" \
  | jq '.items | map({name, state, disabled_cause})'
```

Or with environment variables set:

```sh
CLOUD_TOKEN=<pat> ORG_ID=<org-id> bash repro/08-org-wide-allowance-disables-all-instances/run.sh
```

## Observed output

Observed on Earth (trimmed and anonymised):

```json
[
  {
    "name": "<workspace-a>",
    "state": "disabled",
    "disabled_cause": "over_allowance"
  },
  {
    "name": "<workspace-b>",
    "state": "disabled",
    "disabled_cause": "over_allowance"
  },
  {
    "name": "<ci-instance>",
    "state": "disabled",
    "disabled_cause": "over_allowance"
  }
]
```

## Expected / what we'd like

- **Per-instance usage caps or budgets**, with a configurable action (throttle, alert, or disable **only that instance** rather than every instance in the organisation).
- **Advance notification** (webhook or email) at configurable thresholds before any instance or organisation is disabled.
- **Confirmation on Earth Pro:** that Earth Pro never disables instances for usage and only bills overage, alongside an optional organisation-wide spend ceiling / alert API.

## Environment

- SurrealDB engine: `surrealdb-4.0.0` on Earth
- SurrealDB Cloud API: `/api/cloud/v0/organizations/<org-id>/clusters`
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

We upgraded our organisation to Earth Pro (`POST /api/cloud/v0/organizations/<org-id>/earth/subscription`) and are building our own per-workspace usage polling and alerting on top of `/clusters/<cluster-id>/usage` (subject to the ~2-hour lag noted in [issue 15](15-usage-api-lag-and-post-delete.md)).
