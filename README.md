# liquiGraph

Self-contained tool that turns a Liquibase changelog into a browsable HTML
schema site (ER diagrams, table details, relationships).

## How it works

liquiGraph does **not** parse Liquibase XML/YAML/SQL directly. Instead it
materializes the changelog into a real database, then introspects that
database. The final database state is the source of truth — this correctly
handles raw SQL, preconditions, contexts, labels, includes, and
database-specific behavior.

```
Liquibase changelogs
        │
        ▼
 disposable PostgreSQL  ◀── spun up in Docker, thrown away after
        │
        ▼
   liquibase update
        │
        ▼
      SchemaSpy        ◀── introspects schema, renders ERDs via Graphviz
        │
        ▼
  HTML + SVG site in ./output
```

## Requirements

- Docker (Postgres, Liquibase, and SchemaSpy all run as containers — no
  local JVM, no local Postgres install)
- A directory of Liquibase changelogs (XML/YAML/JSON, formatted SQL, or
  any mix). A master file is optional — see *Auto-master* below.

The whole pipeline is deterministic: Liquibase + SchemaSpy + Postgres in
pinned containers, plus `bash`/`sed` for staging. No AI is involved at
runtime.

## Quick start

```bash
# default: render the bundled example/changelogs into ./output
./run.sh
open ./output/index.html
```

Or point it at your own changelog directory:

```bash
./run.sh \
  --changelog-dir ./your-changelogs \
  --master-file db.changelog-master.xml \
  --output ./output \
  --schema public

open ./output/index.html
```

The script:

1. Stages the changelog directory (auto-generates a master file if needed
   and patches `splitStatements:false` onto changesets that use `$$` —
   your source files are never modified).
2. Starts an empty PostgreSQL container.
3. Runs `liquibase update` against it.
4. Runs SchemaSpy against the populated schema.
5. Tears the container down (also on Ctrl-C or failure).
6. Leaves the rendered HTML in `./output/`.

### Flags

| Flag              | Default                       | Purpose                              |
|-------------------|-------------------------------|--------------------------------------|
| `--changelog-dir` | `./example/changelogs`        | Host path mounted into Liquibase.    |
| `--master-file`   | `db.changelog-master.xml`     | Master file path *within* that dir.  |
| `--output`        | `./output`                    | Where SchemaSpy writes HTML.         |
| `--schema`        | `public`                      | Postgres schema to document.         |

### Auto-master / SQL-only directories

If `--changelog-dir` does not contain `--master-file`, liquiGraph builds
a deterministic staging copy under `tmp/staging-*/`:

- All `*.sql` files are included in lexical (sorted) order via an
  auto-generated `db.changelog-master.xml`.
- Any changeset whose body uses `$$` quoting (PL/pgSQL, triggers,
  `DO` blocks) gets `splitStatements:false` appended to its
  `--changeset` line, so Liquibase doesn't choke on the dollar-quoted
  bodies.

This means a directory of plain Liquibase formatted-SQL files works
out-of-the-box — no master file required. Your source files are read
only; only the staging copies are touched.

## Repository layout

```
.
├── README.md
├── Spec/                  # design documents per iteration
│   └── 001_initial_setup/
├── docker-compose.yml     # disposable Postgres + tool containers
├── run.sh                 # entry point that orchestrates the pipeline
├── example/               # sample changelogs used for smoke tests
│   ├── changelogs/        #   minimal author/book schema (XML)
│   └── w12-changesets/    #   real-world formatted-SQL changesets
├── tmp/                   # staging dirs + browser screenshots (gitignored)
└── output/                # generated HTML (gitignored)
```

## Pinned versions

| Component  | Image                       |
|------------|-----------------------------|
| PostgreSQL | `postgres:16.4`             |
| Liquibase  | `liquibase/liquibase:4.29`  |
| SchemaSpy  | `schemaspy/schemaspy:7.0.2` |

## Status

Early scaffolding. See `Spec/001_initial_setup/` for the architecture and
implementation plan.
