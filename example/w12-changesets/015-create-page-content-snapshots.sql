--liquibase formatted sql

--changeset w12-team:015-create-page-content-snapshots
CREATE TABLE page_content_snapshots (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_id     UUID NOT NULL REFERENCES wiki_pages(id) ON DELETE CASCADE,
    version     INTEGER NOT NULL,
    content     TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_page_content_snapshots_page_version UNIQUE (page_id, version)
);

CREATE INDEX idx_page_content_snapshots_page_created
    ON page_content_snapshots (page_id, created_at DESC);

--rollback DROP INDEX IF EXISTS idx_page_content_snapshots_page_created;
--rollback DROP TABLE IF EXISTS page_content_snapshots;
