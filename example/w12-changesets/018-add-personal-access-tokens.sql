--liquibase formatted sql

--changeset w12-team:018-add-personal-access-tokens

CREATE TABLE IF NOT EXISTS personal_access_tokens (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name         VARCHAR(80) NOT NULL,
    token_hash   CHAR(64) NOT NULL UNIQUE,
    token_prefix VARCHAR(20) NOT NULL,
    expires_at   TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ,
    revoked_at   TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pat_token_prefix
    ON personal_access_tokens (token_prefix);

CREATE INDEX IF NOT EXISTS idx_pat_user_id
    ON personal_access_tokens (user_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_pat_user_active_name
    ON personal_access_tokens (user_id, name)
    WHERE revoked_at IS NULL;

ALTER TABLE users ADD COLUMN IF NOT EXISTS disabled_at TIMESTAMPTZ NULL;

--rollback DROP INDEX IF EXISTS uq_pat_user_active_name;
--rollback DROP INDEX IF EXISTS idx_pat_user_id;
--rollback DROP INDEX IF EXISTS idx_pat_token_prefix;
--rollback DROP TABLE IF EXISTS personal_access_tokens;
--rollback ALTER TABLE users DROP COLUMN IF EXISTS disabled_at;
