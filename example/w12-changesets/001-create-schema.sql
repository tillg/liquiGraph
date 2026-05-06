--liquibase formatted sql

--changeset w12-team:001-create-schema
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(255) NOT NULL UNIQUE,
    display_name VARCHAR(255) NOT NULL,
    avatar_url  VARCHAR(512),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE projects (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key         VARCHAR(10) NOT NULL UNIQUE,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE issues (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    key         VARCHAR(20) NOT NULL UNIQUE,
    title       VARCHAR(500) NOT NULL,
    description TEXT,
    type        VARCHAR(20) NOT NULL DEFAULT 'TASK',
    status      VARCHAR(20) NOT NULL DEFAULT 'TODO',
    priority    VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    sort_order  INT NOT NULL DEFAULT 0,
    assignee_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_issues_project_id ON issues(project_id);
CREATE INDEX idx_issues_status ON issues(status);
CREATE INDEX idx_issues_assignee_id ON issues(assignee_id);

CREATE TABLE wiki_pages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    parent_id   UUID REFERENCES wiki_pages(id) ON DELETE SET NULL,
    title       VARCHAR(500) NOT NULL,
    content     TEXT NOT NULL DEFAULT '',
    slug        VARCHAR(255) NOT NULL UNIQUE,
    sort_order  INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_wiki_pages_project_id ON wiki_pages(project_id);
CREATE INDEX idx_wiki_pages_parent_id ON wiki_pages(parent_id);

--rollback DROP TABLE IF EXISTS wiki_pages;
--rollback DROP TABLE IF EXISTS issues;
--rollback DROP TABLE IF EXISTS projects;
--rollback DROP TABLE IF EXISTS users;
