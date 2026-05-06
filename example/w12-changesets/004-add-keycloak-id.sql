--liquibase formatted sql

--changeset w12-team:004-add-keycloak-id
ALTER TABLE users ADD COLUMN keycloak_id VARCHAR(255) UNIQUE;
CREATE INDEX idx_users_keycloak_id ON users(keycloak_id);

--rollback DROP INDEX IF EXISTS idx_users_keycloak_id;
--rollback ALTER TABLE users DROP COLUMN IF EXISTS keycloak_id;
