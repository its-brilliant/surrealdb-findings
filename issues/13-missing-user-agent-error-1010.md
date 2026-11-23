# 13 · `POST /sql` without a `User-Agent` (or from Python `urllib`) gets `403 Error 1010`

## Summary

Calling `POST https://<instance>.surrealdb.earth/sql` from an HTTP client with no `User-Agent` header — or with Python's default `urllib` signature — is rejected by Earth's Cloudflare edge with `403 Forbidden` (`Error 1010: The owner of this website has banned your access based on your browser's signature`).

## What happens

Requests to `https://<instance>.surrealdb.earth/sql` never reach SurrealDB if the HTTP client omits `User-Agent` or uses Python's standard-library `urllib.request` default (`Python-urllib/3.x`); Cloudflare's Browser Integrity Check intercepts the request at the edge and returns `403` with body `error code: 1010` (or the HTML Error 1010 page). Adding an explicit `User-Agent` header makes the exact same request succeed immediately.

## Why we ran into it

Brilliant hosts business apps on SurrealDB Earth, and both our own scripts during early testing and server-side scripts / webhooks written by customers may call `/sql` over HTTPS using standard-library HTTP clients. Getting a Cloudflare "browser signature" ban on a database API endpoint is unexpected and confusing to debug.

## How to reproduce

With `curl` (stripping `User-Agent` via `-A ''`):

```sh
curl -i -sS -A '' -X POST "https://<instance>.surrealdb.earth/sql" \
  -H "Authorization: Bearer $EARTH_TOKEN" \
  -H "Accept: application/json" \
  -H "surreal-ns: app" \
  -H "surreal-db: main" \
  --data-binary 'RETURN 1;'
```

With Python's standard library (`urllib.request` one-liner):

```sh
EARTH_HOST=<instance>.surrealdb.earth EARTH_TOKEN=<token> \
python3 -c 'import os, urllib.request; req = urllib.request.Request(f"https://{os.environ[\"EARTH_HOST\"]}/sql", data=b"RETURN 1;", headers={"Authorization": f"Bearer {os.environ[\"EARTH_TOKEN\"]}", "Accept": "application/json", "surreal-ns": "app", "surreal-db": "main"}); urllib.request.urlopen(req)'
```

Or via the repro script:

```sh
EARTH_HOST=<instance>.surrealdb.earth EARTH_TOKEN=<token> \
  bash repro/13-missing-user-agent-error-1010/run.sh
```

## Observed output

Observed on Earth without a custom `User-Agent`:

```http
HTTP/2 403
content-type: text/plain; charset=UTF-8

error code: 1010
```

(Or when `Accept: text/html` is sent: `Error 1010: The owner of this website (<instance>.surrealdb.earth) has banned your access based on your browser's signature`.)

With `-A 'surreal-repro/1.0'` added, the same request returns `HTTP/2 200` and `[{"result":1,"status":"OK",...}]`.

## Expected / what we'd like

- Disable Cloudflare's Browser Integrity Check on `*.surrealdb.earth` API endpoints (`/sql`, `/rpc`, `/health`, `/version`), since database clients are predominantly programmatic SDKs, Workers, and server-side scripts rather than browsers.
- If specific client signatures are intentionally blocked, document which HTTP headers/signatures Earth requires.

## Environment

- SurrealDB engine: `surrealdb-4.0.0` behind Earth's Cloudflare edge
- Endpoint: `POST https://<instance>.surrealdb.earth/sql`
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

Ensure every server-side HTTP client calling `*.surrealdb.earth` sets an explicit `User-Agent` header.
