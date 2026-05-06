--liquibase formatted sql

--changeset w12-team:006-add-membership-tables
CREATE TABLE project_members (
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role       VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, user_id)
);

CREATE INDEX idx_project_members_user ON project_members(user_id);

CREATE TABLE space_members (
    space_id   UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role       VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    PRIMARY KEY (space_id, user_id)
);

CREATE INDEX idx_space_members_user ON space_members(user_id);

--rollback DROP TABLE IF EXISTS space_members;
--rollback DROP TABLE IF EXISTS project_members;
