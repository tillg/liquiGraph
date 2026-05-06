--liquibase formatted sql

--changeset w12-team:016-widen-comment-change-events
ALTER TABLE comment_change_events ALTER COLUMN ticket_id DROP NOT NULL;
ALTER TABLE comment_change_events ADD COLUMN page_id UUID REFERENCES wiki_pages(id) ON DELETE CASCADE;
ALTER TABLE comment_change_events
    ADD CONSTRAINT chk_comment_change_events_host
        CHECK (num_nonnulls(ticket_id, page_id) = 1);

CREATE INDEX idx_comment_change_events_page_created
    ON comment_change_events (page_id, created_at DESC);

--rollback DROP INDEX IF EXISTS idx_comment_change_events_page_created;
--rollback ALTER TABLE comment_change_events DROP CONSTRAINT IF EXISTS chk_comment_change_events_host;
--rollback ALTER TABLE comment_change_events DROP COLUMN IF EXISTS page_id;
--rollback ALTER TABLE comment_change_events ALTER COLUMN ticket_id SET NOT NULL;
