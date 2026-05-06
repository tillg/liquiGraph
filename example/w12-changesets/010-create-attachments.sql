--liquibase formatted sql

--changeset w12-team:010-create-attachments
CREATE TABLE attachments (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id         UUID REFERENCES issues(id) ON DELETE CASCADE,
    page_id           UUID REFERENCES wiki_pages(id) ON DELETE CASCADE,
    uploader_id       UUID NOT NULL REFERENCES users(id),
    original_filename TEXT NOT NULL,
    mime_type         TEXT NOT NULL,
    size_bytes        BIGINT NOT NULL,
    storage_path      TEXT NOT NULL,
    thumbnail_path    TEXT,
    deleted_at        TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_attachments_host_exclusivity CHECK (num_nonnulls(ticket_id, page_id) = 1),
    CONSTRAINT chk_attachments_size_positive CHECK (size_bytes > 0),
    CONSTRAINT chk_attachments_filename_bounds CHECK (length(original_filename) > 0 AND length(original_filename) <= 512)
);

CREATE INDEX idx_attachments_ticket_id ON attachments(ticket_id, created_at DESC) WHERE ticket_id IS NOT NULL;
CREATE INDEX idx_attachments_page_id ON attachments(page_id, created_at DESC) WHERE page_id IS NOT NULL;
CREATE INDEX idx_attachments_uploader_id ON attachments(uploader_id);

CREATE OR REPLACE FUNCTION attachments_set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_attachments_set_updated_at
BEFORE UPDATE ON attachments
FOR EACH ROW EXECUTE FUNCTION attachments_set_updated_at();

--rollback DROP TRIGGER IF EXISTS trg_attachments_set_updated_at ON attachments;
--rollback DROP FUNCTION IF EXISTS attachments_set_updated_at();
--rollback DROP TABLE IF EXISTS attachments;
