# Architecture — Initial Setup

## Goal

Produce a self-contained tool that, given a directory containing Liquibase
changelogs, emits a static HTML site documenting the resulting database
schema (tables, columns, types, constraints, indexes, foreign keys, ER
diagrams).

The tool must be runnable on a developer laptop and in CI with no manual
prerequisites beyond Docker.

## Non-goals

- Parsing Liquibase XML/YAML/SQL ourselves.
- Diffing two changelog states.
- Editing or authoring changelogs.
- Supporting databases other than PostgreSQL in this iteration. The
  pipeline generalizes, but we pick one engine to keep scope tight.

## Why "materialize, then introspect"

Liquibase changelogs can contain raw SQL, preconditions, contexts, labels,
`<include>` directives, custom change classes, and database-specific
behavior. Static parsing of the changelog cannot reliably reconstruct the
final schema. Instead we:

1. Spin up an empty PostgreSQL.
2. Let Liquibase apply the changelog the same way it would in production.
3. Read the resulting schema through standard JDBC metadata.

The materialized database is the source of truth. SchemaSpy then renders
that schema as HTML + SVG ER diagrams.

## Component view

```
┌────────────────────────┐    ┌──────────────────────────┐
│  user changelog dir    │    │  liquiGraph repo         │
│  (mounted read-only)   │    │  ├── run.sh              │
└──────────┬─────────────┘    │  ├── docker-compose.yml  │
           │                  │  └── output/             │
           │                  └─────────┬────────────────┘
           │                            │
           ▼                            ▼
┌────────────────────────────────────────────────────────┐
│                   Docker network                       │
│                                                        │
│   ┌────────────┐    ┌──────────────┐    ┌──────────┐   │
│   │ postgres   │◀───│  liquibase   │    │schemaspy │   │
│   │ (empty,    │    │   update     │    │          │   │
│   │ ephemeral) │◀────────────────────── │ (JDBC    │   │
│   └────────────┘                        │  reads)  │   │
│                                         └────┬─────┘   │
└──────────────────────────────────────────────┼─────────┘
                                               │
                                               ▼
                                        ./output/*.html
                                        ./output/diagrams/*.svg
```

### 1. PostgreSQL container

- Official `postgres:<pinned-version>` image.
- No volume; data lives only for the run.
- Healthcheck on `pg_isready` so the next step waits for readiness.
- Credentials are dummy values, scoped to the ephemeral container.

### 2. Liquibase container

- Official `liquibase/liquibase:<pinned-version>` image.
- Mounts the user's changelog directory read-only at a fixed path.
- Runs `liquibase update` against the Postgres container over the Docker
  network.
- Exits non-zero on failure, which fails the pipeline.

### 3. SchemaSpy container

- Official `schemaspy/schemaspy:<pinned-version>` image (bundles Graphviz
  for rendering, includes the Postgres JDBC driver).
- Reads the populated schema via JDBC.
- Writes HTML + SVG diagrams into a mounted `./output` directory on the
  host.

### 4. Orchestrator (`run.sh`)

A thin shell script that:

1. Parses CLI flags (`--changelog-dir`, `--master-file`, `--output`,
   `--schema`).
2. Generates a unique project name so concurrent runs don't collide.
3. `docker compose up -d postgres` and waits for healthy.
4. `docker compose run --rm liquibase update`.
5. `docker compose run --rm schemaspy`.
6. `docker compose down -v` in a trap, so the container is torn down even
   on failure or Ctrl-C.

The script is the single entry point. No Makefile, no task runner — keeps
the dependency surface to "Docker + bash".

## Configuration surface

| Flag              | Default                       | Purpose                              |
|-------------------|-------------------------------|--------------------------------------|
| `--changelog-dir` | `./example/changelogs`        | Host path mounted into Liquibase.    |
| `--master-file`   | `db.changelog-master.xml`     | Path *within* the changelog dir.     |
| `--output`        | `./output`                    | Where SchemaSpy writes HTML.         |
| `--schema`        | `public`                      | Postgres schema to document.         |
| `--pg-version`    | pinned in compose             | Override Postgres image tag.         |

Everything else (DB name, user, password, port) is internal to the
ephemeral container and not user-configurable.

## Failure modes & handling

| Failure                          | Behavior                                              |
|----------------------------------|-------------------------------------------------------|
| Postgres never becomes healthy   | Script aborts with the container logs.                |
| `liquibase update` fails         | Script aborts; Liquibase's own error output is shown. |
| SchemaSpy finds an empty schema  | Script warns and exits non-zero.                      |
| User Ctrl-C mid-run              | `trap` ensures `docker compose down -v` runs.         |

## Security & isolation

- The Postgres container is bound to the Docker network only — no host
  port published by default.
- The user's changelog directory is mounted read-only.
- No credentials are persisted; the throwaway DB password lives in the
  compose file as a literal placeholder.

## What the user gets

`./output/index.html` plus per-table pages, FK relationship diagrams,
constraint listings, and an orphan-table view — all produced by SchemaSpy
from the live introspected schema.
