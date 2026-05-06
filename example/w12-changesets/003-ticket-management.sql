--liquibase formatted sql

--changeset w12-team:003-ticket-management
ALTER TABLE projects ADD COLUMN next_ticket_number INT NOT NULL DEFAULT 1;
ALTER TABLE issues DROP COLUMN IF EXISTS type;
ALTER TABLE issues DROP COLUMN IF EXISTS priority;
ALTER TABLE issues DROP COLUMN IF EXISTS sort_order;
DROP INDEX IF EXISTS idx_issues_assignee_id;
ALTER TABLE issues DROP COLUMN IF EXISTS assignee_id;
ALTER TABLE issues ADD COLUMN assignee VARCHAR(255);
ALTER TABLE issues ALTER COLUMN status SET DEFAULT 'BACKLOG';
ALTER TABLE issues ADD CONSTRAINT chk_issues_status
    CHECK (status IN ('BACKLOG', 'NEW', 'IN_PROGRESS', 'IN_VERIFICATION', 'DONE'));

--rollback ALTER TABLE issues DROP CONSTRAINT IF EXISTS chk_issues_status;
--rollback ALTER TABLE issues ALTER COLUMN status SET DEFAULT 'TODO';
--rollback ALTER TABLE issues DROP COLUMN IF EXISTS assignee;
--rollback ALTER TABLE projects DROP COLUMN IF EXISTS next_ticket_number;
