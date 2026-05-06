#!/usr/bin/env bash
set -euo pipefail

CHANGELOG_DIR="./example/changelogs"
MASTER_FILE="db.changelog-master.xml"
OUTPUT_DIR="./output"
SCHEMA="public"

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --changelog-dir DIR   Directory with Liquibase changelogs (default: $CHANGELOG_DIR)
  --master-file FILE    Master changelog file, relative to changelog dir (default: $MASTER_FILE)
  --output DIR          Where to write the rendered HTML site (default: $OUTPUT_DIR)
  --schema NAME         PostgreSQL schema to document (default: $SCHEMA)
  -h, --help            Show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --changelog-dir) CHANGELOG_DIR="$2"; shift 2 ;;
        --master-file)   MASTER_FILE="$2";   shift 2 ;;
        --output)        OUTPUT_DIR="$2";    shift 2 ;;
        --schema)        SCHEMA="$2";        shift 2 ;;
        -h|--help)       usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

if [ ! -d "$CHANGELOG_DIR" ]; then
    echo "error: --changelog-dir does not exist or is not a directory: $CHANGELOG_DIR" >&2
    exit 2
fi

mkdir -p "$OUTPUT_DIR"

CHANGELOG_DIR_ABS="$(cd "$CHANGELOG_DIR" && pwd)"
OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" && pwd)"

# If no master file is present, build a deterministic staging copy:
#   - sorted *.sql files included in lexical order via an auto-generated XML
#   - any changeset whose file body uses `$$` is annotated with
#     `splitStatements:false` (PL/pgSQL bodies, triggers, DO blocks).
# The user's source directory is never modified.
if [ ! -f "$CHANGELOG_DIR_ABS/$MASTER_FILE" ]; then
    SQL_FILES=( $(cd "$CHANGELOG_DIR_ABS" && ls *.sql 2>/dev/null | LC_ALL=C sort) )
    if [ ${#SQL_FILES[@]} -eq 0 ]; then
        echo "error: master file not found and no *.sql files in: $CHANGELOG_DIR_ABS" >&2
        exit 2
    fi

    SCRIPT_DIR_INIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    STAGING_DIR="$SCRIPT_DIR_INIT/tmp/staging-$(date +%s)-$$"
    mkdir -p "$STAGING_DIR"

    echo "==> no $MASTER_FILE in input; auto-generating into $STAGING_DIR"

    for f in "${SQL_FILES[@]}"; do
        src="$CHANGELOG_DIR_ABS/$f"
        dst="$STAGING_DIR/$f"
        if grep -q '\$\$' "$src"; then
            # Annotate every `--changeset ...` line that lacks splitStatements
            sed -E 's/^(--[[:space:]]*changeset[[:space:]]+[^[:space:]]+)([[:space:]]*)$/\1 splitStatements:false/' "$src" > "$dst"
        else
            cp "$src" "$dst"
        fi
    done

    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<databaseChangeLog'
        echo '    xmlns="http://www.liquibase.org/xml/ns/dbchangelog"'
        echo '    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
        echo '    xsi:schemaLocation="http://www.liquibase.org/xml/ns/dbchangelog'
        echo '                        http://www.liquibase.org/xml/ns/dbchangelog/dbchangelog-4.20.xsd">'
        for f in "${SQL_FILES[@]}"; do
            printf '    <include file="%s" relativeToChangelogFile="true"/>\n' "$f"
        done
        echo '</databaseChangeLog>'
    } > "$STAGING_DIR/$MASTER_FILE"

    CHANGELOG_DIR_ABS="$STAGING_DIR"
fi

if [ ! -f "$CHANGELOG_DIR_ABS/$MASTER_FILE" ]; then
    echo "error: master file not found after staging: $CHANGELOG_DIR_ABS/$MASTER_FILE" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

PROJECT="liquigraph-$(date +%s)-$$"

export LIQUIGRAPH_CHANGELOG_DIR="$CHANGELOG_DIR_ABS"
export LIQUIGRAPH_MASTER_FILE="$MASTER_FILE"
export LIQUIGRAPH_OUTPUT_DIR="$OUTPUT_DIR_ABS"
export LIQUIGRAPH_SCHEMA="$SCHEMA"

cleanup() {
    docker compose -f "$COMPOSE_FILE" -p "$PROJECT" down -v >/dev/null 2>&1 || true
}
on_signal() {
    local sig="$1"
    cleanup
    trap - EXIT "$sig"
    kill -"$sig" $$
}
trap cleanup EXIT
trap 'on_signal INT' INT
trap 'on_signal TERM' TERM

rm -rf "${OUTPUT_DIR_ABS:?}/"* 2>/dev/null || true

echo "==> starting postgres (project: $PROJECT)"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT" up -d postgres

echo "==> running liquibase update"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT" run --rm liquibase

echo "==> running schemaspy"
docker compose -f "$COMPOSE_FILE" -p "$PROJECT" run --rm schemaspy

if [ ! -f "$OUTPUT_DIR_ABS/index.html" ]; then
    echo "error: schemaspy finished but $OUTPUT_DIR_ABS/index.html was not produced" >&2
    exit 1
fi

echo
echo "==> done"
echo "$OUTPUT_DIR_ABS/index.html"
