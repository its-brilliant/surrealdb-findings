# 16 · Personal access token docs say non-GET routes are refused, and missing scopes return an opaque `403 Insufficient scopes`

## Summary

The CLI documentation states that personal access tokens are refused on every non-GET Cloud API route, whereas in reality a token carrying `write:cloud-instances` can create, update, and delete clusters — and a token missing that scope gets `403 Insufficient scopes` without naming which scope is required.

## What happens

1. **Documentation vs actual gateway behaviour:** The CLI docs state that *"the gateway refuses a token on every non-GET Cloud route"*. In fact, `POST`, `PATCH`, and `DELETE` on `/api/cloud/v0/organizations/<org-id>/clusters*` all work with `Authorization: Bearer <personal-access-token>` once the token carries the `write:cloud-instances` scope.
2. **Opaque `403` error:** When a personal access token lacks `write:cloud-instances`, every non-GET Cloud call — even one with an empty `{}` body — fails at the gateway with `403 Insufficient scopes` and gives no indication of which scope is missing, making it look at first as if the docs were right that all non-GET PAT calls are refused.

## Why we ran into it

Brilliant's control plane runs on Cloudflare Workers and provisions one SurrealDB Earth instance per customer workspace automatically through `https://api.surrealdb.com` using a Personal Access Token stored in our secrets store. When our initial token lacked `write:cloud-instances`, combining the `403 Insufficient scopes` response with the CLI documentation saying non-GET routes refuse PATs sent us down a false trail before we verified `write:cloud-instances`.

## How to reproduce

Using a Personal Access Token **without** `write:cloud-instances`:

```sh
curl -i -sS -X POST \
  -H "Authorization: Bearer $CLOUD_TOKEN" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{}' \
  "https://api.surrealdb.com/api/cloud/v0/organizations/<org-id>/clusters"
```

(Sending `{}` avoids creating a cluster if the token *does* have `write:cloud-instances`: a scoped token reaches validation and returns `400`, whereas an unscoped token stops at the gateway with `403 Insufficient scopes`.)

```sh
CLOUD_TOKEN=<pat-without-write-scope> ORG_ID=<org-id> \
  bash repro/16-pat-docs-and-opaque-403-scopes/run.sh
```

## Observed output

With a PAT missing `write:cloud-instances`:

```http
HTTP/2 403
content-type: application/json

{"message":"Insufficient scopes"}
```

With a PAT that includes `write:cloud-instances`, `POST /clusters`, `PATCH /clusters/<id>/cloudflare`, `PATCH /clusters/<id>/resources/<rid>`, and `DELETE /clusters/<id>` all succeed.

## Expected / what we'd like

- Update the CLI / Cloud API documentation to accurately describe Personal Access Token support on write routes and list the required scopes per endpoint (`write:cloud-instances`, `billing:write`, etc.).
- Include the required scope name in `403` responses (for example `"Insufficient scopes: requires write:cloud-instances"` or a `WWW-Authenticate` `scope=` parameter), and/or provide a token introspection endpoint to check granted scopes at startup.

## Environment

- SurrealDB Cloud API: `https://api.surrealdb.com/api/cloud/v0/organizations/<org-id>/clusters`
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

We mint Personal Access Tokens with explicit `write:cloud-instances` (plus read scopes) and strip accidental paste whitespace/quotes before calling the Cloud API.
