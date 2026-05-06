--liquibase formatted sql

--changeset w12-team:008-merge-projects-into-spaces

-- 1. Add the ticket counter to spaces.
ALTER TABLE spaces ADD COLUMN next_ticket_number INT NOT NULL DEFAULT 1;

-- 2. Backfill: every existing project becomes a space (matched by key if already present).
-- If a project's lower(key) collides with an existing spaces.slug under a
-- different key, this INSERT will fail the spaces_slug_key constraint. That
-- surface-level failure is intentional: it signals a data conflict that must
-- be resolved by a human before migrating.
INSERT INTO spaces (id, key, name, slug, description, next_ticket_number, created_at, updated_at, created_by)
SELECT p.id, p.key, p.name, lower(p.key), p.description, p.next_ticket_number, p.created_at, p.updated_at, p.created_by
  FROM projects p
 WHERE NOT EXISTS (SELECT 1 FROM spaces s WHERE s.key = p.key);

-- 3. Carry the max counter across for keys that already matched an existing space.
UPDATE spaces s
   SET next_ticket_number = GREATEST(s.next_ticket_number, p.next_ticket_number)
  FROM projects p
 WHERE s.key = p.key;

-- 4. Add issues.space_id and backfill.
ALTER TABLE issues ADD COLUMN space_id UUID;

UPDATE issues i
   SET space_id = s.id
  FROM projects p
  JOIN spaces s ON s.key = p.key
 WHERE i.project_id = p.id;

-- 5. Enforce NOT NULL + FK on issues.space_id.
ALTER TABLE issues ALTER COLUMN space_id SET NOT NULL;
ALTER TABLE issues
    ADD CONSTRAINT fk_issues_space
    FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE CASCADE;

CREATE INDEX idx_issues_space_id ON issues(space_id);

-- 6. Drop the old project link and tables.
ALTER TABLE issues DROP CONSTRAINT IF EXISTS issues_project_id_fkey;
DROP INDEX IF EXISTS idx_issues_project_id;
ALTER TABLE issues DROP COLUMN project_id;

DROP TABLE IF EXISTS project_members;
DROP TABLE IF EXISTS projects;

--rollback ALTER TABLE issues ADD COLUMN project_id UUID;
--rollback DROP INDEX IF EXISTS idx_issues_space_id;
--rollback ALTER TABLE issues DROP CONSTRAINT IF EXISTS fk_issues_space;
--rollback ALTER TABLE issues DROP COLUMN IF EXISTS space_id;
--rollback ALTER TABLE spaces DROP COLUMN IF EXISTS next_ticket_number;
--rollback -- NOTE: This migration is one-way. Rollback adds issues.project_id back
--rollback --        as a plain nullable UUID (no FK, no index, no NOT NULL) and does
--rollback --        NOT recreate the projects or project_members tables.
