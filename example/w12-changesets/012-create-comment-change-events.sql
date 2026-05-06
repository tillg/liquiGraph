--liquibase formatted sql

--changeset w12-team:012-create-comment-change-events
CREATE TABLE comment_change_events (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    comment_id              UUID NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
    ticket_id               UUID NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    user_id                 UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_display_snapshot  VARCHAR(255) NOT NULL,
    action                  VARCHAR(16) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_comment_change_events_action CHECK (action IN ('edited','deleted'))
);

CREATE INDEX idx_comment_change_events_ticket_created
    ON comment_change_events (ticket_id, created_at DESC);

--rollback DROP INDEX IF EXISTS idx_comment_change_events_ticket_created;
--rollback DROP TABLE IF EXISTS comment_change_events;
