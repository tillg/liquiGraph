--liquibase formatted sql

--changeset w12-team:009-create-comments
CREATE TABLE comments (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id   UUID REFERENCES issues(id) ON DELETE CASCADE,
    page_id     UUID REFERENCES wiki_pages(id) ON DELETE CASCADE,
    author_id   UUID NOT NULL REFERENCES users(id),
    body        TEXT NOT NULL,
    edited_at   TIMESTAMPTZ,
    deleted_at  TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_comments_host_exclusivity CHECK (num_nonnulls(ticket_id, page_id) = 1),
    CONSTRAINT chk_comments_body_bounds CHECK (length(trim(body)) > 0 AND length(body) <= 65536)
);

CREATE INDEX idx_comments_ticket_id ON comments(ticket_id, created_at DESC) WHERE ticket_id IS NOT NULL;
CREATE INDEX idx_comments_page_id ON comments(page_id, created_at DESC) WHERE page_id IS NOT NULL;
CREATE INDEX idx_comments_author_id ON comments(author_id);

CREATE OR REPLACE FUNCTION comments_set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_comments_set_updated_at
BEFORE UPDATE ON comments
FOR EACH ROW EXECUTE FUNCTION comments_set_updated_at();

--rollback DROP TRIGGER IF EXISTS trg_comments_set_updated_at ON comments;
--rollback DROP FUNCTION IF EXISTS comments_set_updated_at();
--rollback DROP TABLE IF EXISTS comments;
