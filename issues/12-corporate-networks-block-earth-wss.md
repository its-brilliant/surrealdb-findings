# 12 · Company networks block `wss://<instance>.surrealdb.earth/rpc`

## Summary

Corporate firewalls and DNS filters at customer sites block WebSocket connections to `wss://<instance>.surrealdb.earth/rpc`, causing browser apps that talk directly to Earth to fail to load data.

## What happens

When a user opens a web app from behind a restrictive corporate firewall or DNS filter (for example blocking newly seen or `.earth` TLDs), the browser's `surrealdb.js` WebSocket connection to `wss://<instance>.surrealdb.earth/rpc` is silently dropped or refused before completing the handshake. Browser `WebSocket` errors expose no diagnostic detail to JavaScript, so the app simply stalls with no data loaded while first-party HTTPS requests to the app's own domain succeed.

## Why we ran into it

Apps built on Brilliant run in end users' browsers inside companies, and use `surrealdb.js` over WebSocket for reads, writes, and live queries bounded by table `PERMISSIONS`. A customer testing their app on a company network hit this immediately: the app UI loaded from Brilliant's domain, while every query to `wss://<instance>.surrealdb.earth/rpc` failed silently.

## How to reproduce

From a network whose firewall or DNS policy blocks `*.surrealdb.earth` (or to verify WebSocket upgrade reachability from a client network):

```sh
EARTH_HOST=<instance>.surrealdb.earth bash repro/12-corporate-networks-block-earth-wss/run.sh
```

In the browser DevTools Network tab on an affected corporate network, `wss://<instance>.surrealdb.earth/rpc` stays pending or fails with `(failed) / net::ERR_NAME_NOT_RESOLVED` or `net::ERR_CONNECTION_TIMED_OUT`, while a same-origin WebSocket upgrade to `wss://<app-domain>/__db/rpc` succeeds with `101 Switching Protocols`.

## Observed output

Observed in customer browsers behind a corporate firewall:

```text
WebSocket connection to 'wss://<instance>.surrealdb.earth/rpc' failed
```

while the page itself and same-origin WebSockets on the app's domain worked normally.

## Expected / what we'd like

1. **Custom domains (CNAME) for Earth instances:** do you support — or plan to support — attaching custom domains under our own TLD to Earth instances?
2. **Pass-through WebSocket relay support:** is terminating the browser WebSocket on a Cloudflare Worker on the app's own domain and piping frames untouched to `wss://<instance>.surrealdb.earth/rpc` an officially supported setup? Does relaying lose or affect anything on Earth's side (per-IP rate limiting, `CF-Connecting-IP`, connection limits, or session revocation)?

## Environment

- SurrealDB engine: `surrealdb-4.0.0` on Earth
- Endpoint: `wss://<instance>.surrealdb.earth/rpc` (`surrealdb.js` in browser)
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

Browsers connect same-origin to `wss://<app-domain>/__db/rpc`, where a Cloudflare Worker validates the `Origin` header, resolves the admitted project's fixed `<instance>.surrealdb.earth` hostname (never from user input), and passes the WebSocket frames straight through to Earth.
