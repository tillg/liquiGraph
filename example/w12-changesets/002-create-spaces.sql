--liquibase formatted sql

--changeset w12-team:002-create-spaces
CREATE TABLE spaces (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(255) NOT NULL,
    key         VARCHAR(40) NOT NULL UNIQUE,
    slug        VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE wiki_pages DROP CONSTRAINT IF EXISTS wiki_pages_project_id_fkey;
ALTER TABLE wiki_pages DROP COLUMN IF EXISTS project_id;
ALTER TABLE wiki_pages DROP COLUMN IF EXISTS sort_order;
ALTER TABLE wiki_pages DROP CONSTRAINT IF EXISTS wiki_pages_slug_key;
ALTER TABLE wiki_pages ADD COLUMN space_id UUID;
ALTER TABLE wiki_pages ADD COLUMN is_home BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE wiki_pages ADD COLUMN version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE wiki_pages
    ADD CONSTRAINT wiki_pages_space_id_fkey
    FOREIGN KEY (space_id) REFERENCES spaces(id) ON DELETE CASCADE;
ALTER TABLE wiki_pages ALTER COLUMN space_id SET NOT NULL;
CREATE UNIQUE INDEX idx_wiki_pages_space_home
    ON wiki_pages (space_id) WHERE is_home = true;
DROP INDEX IF EXISTS idx_wiki_pages_project_id;
CREATE INDEX idx_wiki_pages_space_id ON wiki_pages(space_id);

--rollback DROP INDEX IF EXISTS idx_wiki_pages_space_id;
--rollback DROP INDEX IF EXISTS idx_wiki_pages_space_home;
--rollback ALTER TABLE wiki_pages DROP CONSTRAINT IF EXISTS wiki_pages_space_id_fkey;
--rollback ALTER TABLE wiki_pages DROP COLUMN IF EXISTS version;
--rollback ALTER TABLE wiki_pages DROP COLUMN IF EXISTS is_home;
--rollback ALTER TABLE wiki_pages DROP COLUMN IF EXISTS space_id;
--rollback DROP TABLE IF EXISTS spaces;
