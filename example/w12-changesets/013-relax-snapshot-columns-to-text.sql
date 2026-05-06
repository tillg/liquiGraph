--liquibase formatted sql

--changeset w12-team:013-relax-snapshot-columns-to-text
ALTER TABLE ticket_change_events ALTER COLUMN actor_display_snapshot TYPE TEXT;
ALTER TABLE comment_change_events ALTER COLUMN actor_display_snapshot TYPE TEXT;

--rollback ALTER TABLE ticket_change_events ALTER COLUMN actor_display_snapshot TYPE VARCHAR(255);
--rollback ALTER TABLE comment_change_events ALTER COLUMN actor_display_snapshot TYPE VARCHAR(255);
