--liquibase formatted sql

--changeset w12-team:005-add-audit-columns
ALTER TABLE spaces ADD COLUMN created_by UUID REFERENCES users(id);
ALTER TABLE wiki_pages ADD COLUMN created_by UUID REFERENCES users(id);
ALTER TABLE projects ADD COLUMN created_by UUID REFERENCES users(id);
ALTER TABLE issues ADD COLUMN created_by UUID REFERENCES users(id);

--rollback ALTER TABLE issues DROP COLUMN IF EXISTS created_by;
--rollback ALTER TABLE projects DROP COLUMN IF EXISTS created_by;
--rollback ALTER TABLE wiki_pages DROP COLUMN IF EXISTS created_by;
--rollback ALTER TABLE spaces DROP COLUMN IF EXISTS created_by;
