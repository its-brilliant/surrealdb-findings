# 07 · `surreal kit sync` applies `database/schema/*.surql` in filename order

## Summary

`surreal kit sync` executes `database/schema/*.surql` strictly in lexicographical filename order rather than topological dependency order, so a computed view in `a_view.surql` over a source table in `b_source.surql` fails with `The table 'b_source' does not exist`.

## What happens

In a project with one `.surql` file per table under `database/schema/`:
- `database/schema/a_view.surql` defines `DEFINE TABLE a_view … AS SELECT … FROM b_source …`.
- `database/schema/b_source.surql` defines `DEFINE TABLE b_source …`.

Running `surreal kit sync` applies `a_view.surql` first and aborts with:

```text
error applying schema/a_view.surql: schema/a_view.surql: The table 'b_source' does not exist
error: default → default: schema/a_view.surql: The table 'b_source' does not exist
```

Renaming `a_view.surql` to `z_view.surql` without changing a character of SurrealQL makes `surreal kit sync` succeed.

## Why we ran into it

In Brilliant, our coding agent writes one `.surql` file per table under `database/schema/<table_name>.surql` and applies changes through `surreal kit sync`. When the agent adds a summary view whose name happens to sort before the table it reads — for example `category_totals.surql` over `ticket.surql`, or `artist_stats.surql` over `track.surql` — `surreal kit sync` fails on a fresh database or scratch check purely because of the table's name.

## How to reproduce

1. Create a minimal SurrealKit project (`surrealkit.toml`, `database/schema/a_view.surql`, `database/schema/b_source.surql`).
2. Start an in-memory SurrealDB server and run `surreal kit sync`.
3. Rename `a_view.surql` to `z_view.surql` and run `surreal kit sync` against a fresh database.

```sh
bash repro/07-surrealkit-sync-filename-order/run.sh
```

## Observed output

```text
== 07: surreal kit sync applies database/schema/*.surql in filename order ==
Engine:     4.0.1 for linux on x86_64
SurrealKit: 1.0.0-rc.1 for linux on x86_64

--- 1. Sync with a_view.surql + b_source.surql (view sorts alphabetically before source) ---
error applying schema/a_view.surql: schema/a_view.surql: The table 'b_source' does not exist
error: default → default: schema/a_view.surql: The table 'b_source' does not exist
(exit code: 1)

--- 2. Rename a_view.surql -> z_view.surql (identical contents) and sync again ---
applied schema/b_source.surql
applied schema/z_view.surql
```

## Expected / what we'd like

- Ideally, `surreal kit sync` (which already parses `DEFINE` statements for catalog tracking) should topologically sort schema definitions — or apply plain tables before `AS SELECT` views — regardless of filename.
- If lexicographical filename ordering is intentional, documenting that rule prominently in `surreal kit sync --help` and the SurrealKit docs would save surprises.

## Environment

- SurrealDB engine: `4.0.1` (`linux x86_64`, in-memory)
- SurrealKit: `1.0.0-rc.1` (`surreal kit sync`)
- Environment: reproduced locally
- Date: November 2026

## Workaround we use

We instruct our coding agent to place a computed view at the bottom of its source table's `.surql` file (after the `DEFINE TABLE` it reads), and in our own scratch-seeding code we apply non-view tables before `AS SELECT` views.
