# Domain

## Purpose

liquiGraph turns a directory of Liquibase changelogs into a browsable
static HTML site that documents the resulting database schema (tables,
columns, types, constraints, indexes, foreign keys, ER diagrams).

## Vocabulary

| Term | Meaning |
|------|---------|
| **changelog directory** | Host directory containing the user's Liquibase changelogs (XML/YAML/JSON or formatted SQL). The pipeline's input. |
| **master file** | A single Liquibase changelog that includes (directly or via `<include>`) all other changesets. Default name `db.changelog-master.xml`. |
| **changeset** | A single unit of schema change, identified in formatted SQL by a `--changeset author:id` line. |
| **formatted SQL** | A `.sql` file beginning with `--liquibase formatted sql`, where each `--changeset` annotation marks a Liquibase-tracked unit. |
| **staging directory** | A throwaway copy of the changelog directory under `tmp/staging-<ts>-<pid>/`. liquiGraph mutates the staging copy (auto-master, `splitStatements:false`); user sources stay byte-identical. |
| **materialized schema** | The state of the disposable PostgreSQL database after `liquibase update` has applied every changeset. The source of truth for documentation. |
| **schema** | A PostgreSQL schema namespace (default `public`). One run documents one schema. |
| **output site** | The static HTML + SVG site SchemaSpy writes to the user's `--output` directory. |
| **run** | One end-to-end invocation of `run.sh`: stage → up Postgres → liquibase update → schemaspy → tear down. |

## "Materialize, then introspect" principle

liquiGraph deliberately does **not** parse Liquibase XML/YAML/SQL itself.
Liquibase changelogs can contain raw SQL, preconditions, contexts,
labels, `<include>` directives, custom change classes, and
database-specific behavior. Static parsing cannot reliably reconstruct
the final schema. Instead, liquiGraph runs the user's changelog through
a real Liquibase against a real PostgreSQL, and reads the result via
JDBC metadata. The materialized database is the source of truth.

## Determinism

The runtime pipeline is fully deterministic: pinned Docker images for
Postgres / Liquibase / SchemaSpy plus `bash`/`sed` for staging. No AI,
no network calls beyond image pulls and JDBC, no nondeterministic
ordering (staging includes are sorted lexically by filename).

## Actors

| Actor | Role |
|-------|------|
| **Developer / engineer** | Invokes `run.sh` against a changelog directory; consumes the resulting HTML site. The only human in the loop. |
| **CI job** *(future)* | Same invocation surface as a developer. Out of scope for the initial iteration but the design supports it (no manual prerequisites beyond Docker). |

## Non-goals

- Parsing Liquibase XML/YAML/SQL ourselves.
- Diffing two changelog states.
- Editing or authoring changelogs.
- Supporting databases other than PostgreSQL in this iteration.
