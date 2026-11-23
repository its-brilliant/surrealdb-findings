# 17 · Earth runs `surrealdb-4.0.0` behind `4.0.1`, and engine upgrades aren't announced in advance

## Summary

`GET https://<instance>.surrealdb.earth/version` reports `surrealdb-4.0.0` while the current public SurrealDB release is `4.0.1`, and Earth engine rollouts are not announced ahead of time.

## What happens

Querying `/version` on an Earth instance returns `surrealdb-4.0.0`, whereas the current `surreal` binary installed in developer environments and CI is `4.0.1`. Because Earth instances are managed and upgraded automatically, `INFO` rendering or SurrealQL edge cases can differ slightly between the pinned engine we validate schemas against and the engine running on Earth.

## Why we ran into it

Before Brilliant applies any coding-agent schema edit to a customer's Earth database, our platform replays the live schema plus `surreal kit sync` on a pinned in-memory SurrealDB engine (`4.0.1`), runs permission tests, diffs the engine's own `INFO FOR DB` / `INFO FOR TABLE` rendering, and after applying on Earth verifies that Earth's `INFO` matches the scratch result. An unannounced engine upgrade on Earth (or a rendering change between patch/minor versions) can cause that post-apply `INFO` verification or client SDK version check to trip until we update our pinned scratch binary.

## How to reproduce

Compare the local engine version with Earth's `/version` endpoint:

```sh
curl -sS "https://<instance>.surrealdb.earth/version"
```

Or via the repro script:

```sh
EARTH_HOST=<instance>.surrealdb.earth bash repro/17-earth-engine-version-lag-and-notice/run.sh
```

## Observed output

Observed on Earth vs local in November 2026:

```text
Local engine version: 4.0.1 for linux on x86_64
Earth /version:       surrealdb-4.0.0
```

## Expected / what we'd like

- **Advance notice** (changelog, status feed, or email/webhook) before Earth rolls out a new SurrealDB engine version, ideally with a staging window or version field visible on the cluster/product API so we can test and pin the matching binary ahead of the rollout.

## Environment

- SurrealDB engine on Earth: `surrealdb-4.0.0`
- Local / CI SurrealDB engine: `4.0.1` (`linux x86_64`)
- Status: observed on Earth (engine 4.0.0), Nov 2026

## Workaround we use

Our compatibility check compares `major.minor` (`4.0`) rather than failing on patch-version differences between `4.0.0` and `4.0.1` (and we plan to send a small PR to `surrealdb.js` to allow skipping its per-connection version check RPC).
