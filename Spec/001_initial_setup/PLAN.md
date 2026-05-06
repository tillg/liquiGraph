# Implementation Plan — Initial Setup

Each step lists a **success criterion** that must mechanically pass before
the step is considered done.

## Step 1 — Repository scaffolding

Create:

- `.gitignore` (ignores `output/`, `tmp/`, `.env`, `*.log`).
- `example/changelogs/db.changelog-master.xml` — a minimal changelog with
  two related tables (e.g. `author` and `book` with a FK), enough to
  produce a non-trivial ER diagram.
- `Spec/001_initial_setup/ARCHITECTURE.md` (already written).
- `Spec/001_initial_setup/PLAN.md` (this file).

**Verify:** `git status` shows the new files; the example XML parses as
valid XML (`xmllint --noout` if available, otherwise visual review).

## Step 2 — Docker Compose with disposable Postgres

Add `docker-compose.yml` with a single `postgres` service:

- Image pinned to a specific minor version.
- `POSTGRES_DB=liquigraph`, `POSTGRES_USER=liquigraph`,
  `POSTGRES_PASSWORD=liquigraph` (ephemeral, never persisted).
- `healthcheck` running `pg_isready -U liquigraph`.
- No `ports:` mapping (network-internal only).
- No named volume.

**Verify:**
`docker compose up -d postgres && docker compose ps`
shows the container as `healthy` within ~10 seconds, and
`docker compose down -v` removes it cleanly.

## Step 3 — Liquibase service in compose

Add a `liquibase` service:

- Image: `liquibase/liquibase` pinned.
- `depends_on: postgres` with `condition: service_healthy`.
- Mounts `${LIQUIGRAPH_CHANGELOG_DIR}:/liquibase/changelog:ro`.
- Default command: `update --changelog-file=${LIQUIGRAPH_MASTER_FILE} --url=jdbc:postgresql://postgres:5432/liquigraph --username=liquigraph --password=liquigraph`.

**Verify:** With env vars pointing at `example/changelogs`,
`docker compose run --rm liquibase` exits 0, and a follow-up
`docker compose exec postgres psql -U liquigraph -c '\dt'` lists the
expected tables.

## Step 4 — SchemaSpy service in compose

Add a `schemaspy` service:

- Image: `schemaspy/schemaspy` pinned.
- `depends_on: postgres` (healthy).
- Mounts `${LIQUIGRAPH_OUTPUT_DIR}:/output`.
- Command flags: `-t pgsql11 -host postgres -port 5432 -db liquigraph -u liquigraph -p liquigraph -s ${LIQUIGRAPH_SCHEMA} -o /output`.

**Verify:** After Steps 2–3 succeed,
`docker compose run --rm schemaspy` produces
`./output/index.html` and `./output/diagrams/` containing SVGs. Opening
`output/index.html` in a browser shows the example tables and an ER
diagram with the FK between them.

## Step 5 — `run.sh` orchestrator

Implement the entry script:

- Parse `--changelog-dir`, `--master-file`, `--output`, `--schema` with
  sensible defaults pointing at the example.
- `set -euo pipefail`.
- Generate a unique compose project name per invocation
  (`liquigraph-$(date +%s)-$$`) so parallel runs don't collide.
- Export the env vars consumed by compose.
- `trap 'docker compose -p "$PROJECT" down -v' EXIT`.
- Run the three compose steps in order.
- Print the absolute path to `output/index.html` on success.

**Verify:**
```
./run.sh --changelog-dir ./example/changelogs \
         --master-file db.changelog-master.xml \
         --output ./output
```
exits 0, prints the output path, and `output/index.html` exists. A second
invocation overwrites the output cleanly.

## Step 6 — Failure-path tests

Run the script against deliberately broken inputs and confirm sensible
behavior:

- Non-existent changelog dir → script aborts before starting Postgres.
- Master file missing → Liquibase step fails, container is torn down,
  script exits non-zero.
- Ctrl-C during `liquibase update` → trap fires, no orphan containers
  (`docker ps` shows none from this run).

**Verify:** Each scenario above; `docker ps -a | grep liquigraph` is
empty after each.

## Step 7 — Smoke test in browser

Per global testing rules: open the generated site in the browser via the
agent-browser skill, confirm:

- `index.html` renders.
- The tables list shows the example tables.
- Clicking a table opens the detail page with columns and FK info.
- The relationships diagram is a non-empty SVG showing the FK.

Save screenshots into `tmp/`. Add `tmp/` and `output/` to `.gitignore`
before generating any artifacts.

**Verify:** Screenshots exist; user has a working app to interact with.

## Step 8 — README polish

Once the pipeline works end-to-end, revisit `README.md` to ensure the
"Quick start" matches the actual CLI surface of `run.sh`. Replace any
placeholder paths with the ones we settled on.

**Verify:** A reader following only `README.md` from a clean clone can
produce `output/index.html` against `example/changelogs` without
consulting the spec.

## Out of scope for this iteration

- CI integration (GitHub Actions etc.).
- Multi-database support (MySQL, Oracle, MSSQL).
- Custom theming of the SchemaSpy output.
- Diff between two changelog revisions.
- Publishing the output anywhere; the tool just emits a directory.
