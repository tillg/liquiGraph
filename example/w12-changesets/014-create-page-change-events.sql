--liquibase formatted sql

--changeset w12-team:014-create-page-change-events
CREATE TABLE page_change_events (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_id                 UUID NOT NULL REFERENCES wiki_pages(id) ON DELETE CASCADE,
    user_id                 UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_display_snapshot  VARCHAR(255) NOT NULL,
    kind                    VARCHAR(16) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    changes                 JSONB NOT NULL,
    CONSTRAINT chk_page_change_events_kind
        CHECK (kind IN ('update', 'revert')),
    CONSTRAINT chk_page_change_events_changes_object
        CHECK (jsonb_typeof(changes) = 'object' AND changes <> '{}'::jsonb)
);

CREATE INDEX idx_page_change_events_page_created
    ON page_change_events (page_id, created_at DESC);

--rollback DROP INDEX IF EXISTS idx_page_change_events_page_created;
--rollback DROP TABLE IF EXISTS page_change_events;
