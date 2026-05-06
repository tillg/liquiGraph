--liquibase formatted sql

--changeset w12-team:007-create-wiki-page-drafts
CREATE TABLE wiki_page_drafts (
    page_id UUID PRIMARY KEY REFERENCES wiki_pages(id) ON DELETE CASCADE,
    base_version INTEGER NOT NULL,
    yjs_state BYTEA NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX wiki_page_drafts_updated_at_idx ON wiki_page_drafts(updated_at);

--rollback DROP INDEX IF EXISTS wiki_page_drafts_updated_at_idx;
--rollback DROP TABLE IF EXISTS wiki_page_drafts;
