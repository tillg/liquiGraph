--liquibase formatted sql

--changeset w12-team:011-create-ticket-change-events
CREATE TABLE ticket_change_events (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id               UUID NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
    user_id                 UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_display_snapshot  VARCHAR(255) NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    changes                 JSONB NOT NULL,
    CONSTRAINT chk_ticket_change_events_changes_object
        CHECK (jsonb_typeof(changes) = 'object' AND changes <> '{}'::jsonb)
);

CREATE INDEX idx_ticket_change_events_ticket_created
    ON ticket_change_events (ticket_id, created_at DESC);

--rollback DROP INDEX IF EXISTS idx_ticket_change_events_ticket_created;
--rollback DROP TABLE IF EXISTS ticket_change_events;
