--liquibase formatted sql

--changeset w12-team:017-ticket-state-machine

CREATE TABLE IF NOT EXISTS ticket_types (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key         VARCHAR(64) NOT NULL UNIQUE,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    color       VARCHAR(32),
    icon        VARCHAR(64),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by  UUID REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS state_machines (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key         VARCHAR(64) NOT NULL UNIQUE,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by  UUID REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS state_machine_states (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_machine_id UUID NOT NULL REFERENCES state_machines(id) ON DELETE CASCADE,
    key              VARCHAR(64) NOT NULL,
    name             VARCHAR(255) NOT NULL,
    state_order      INTEGER NOT NULL,
    category         VARCHAR(64),
    is_initial       BOOLEAN NOT NULL DEFAULT false,
    is_terminal      BOOLEAN NOT NULL DEFAULT false,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by       UUID REFERENCES users(id),
    CONSTRAINT uq_state_machine_states_machine_key UNIQUE (state_machine_id, key),
    CONSTRAINT uq_state_machine_states_id_machine UNIQUE (id, state_machine_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_state_machine_states_initial_once
    ON state_machine_states (state_machine_id)
    WHERE is_initial = true;

CREATE INDEX IF NOT EXISTS idx_state_machine_states_machine_order
    ON state_machine_states (state_machine_id, state_order);

CREATE TABLE IF NOT EXISTS state_machine_transitions (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state_machine_id UUID NOT NULL REFERENCES state_machines(id) ON DELETE CASCADE,
    from_state_id    UUID NOT NULL,
    to_state_id      UUID NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_state_machine_transitions_not_self CHECK (from_state_id <> to_state_id),
    CONSTRAINT uq_state_machine_transitions_machine_edge UNIQUE (state_machine_id, from_state_id, to_state_id),
    CONSTRAINT fk_state_machine_transitions_from_state
        FOREIGN KEY (from_state_id, state_machine_id)
        REFERENCES state_machine_states(id, state_machine_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_state_machine_transitions_to_state
        FOREIGN KEY (to_state_id, state_machine_id)
        REFERENCES state_machine_states(id, state_machine_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_state_machine_transitions_machine_from
    ON state_machine_transitions (state_machine_id, from_state_id);

CREATE TABLE IF NOT EXISTS space_ticket_types (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    space_id         UUID NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
    ticket_type_id   UUID NOT NULL REFERENCES ticket_types(id) ON DELETE RESTRICT,
    state_machine_id UUID NOT NULL REFERENCES state_machines(id) ON DELETE RESTRICT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by       UUID REFERENCES users(id),
    CONSTRAINT uq_space_ticket_types_space_type UNIQUE (space_id, ticket_type_id)
);

CREATE INDEX IF NOT EXISTS idx_space_ticket_types_space
    ON space_ticket_types (space_id);

ALTER TABLE issues ADD COLUMN IF NOT EXISTS ticket_type_id UUID;
ALTER TABLE issues ADD COLUMN IF NOT EXISTS status_id UUID;

INSERT INTO ticket_types (key, name, description, color, icon, created_by)
VALUES ('DEFAULT', 'Default', 'Legacy default ticket type', '#6b7280', 'ticket', NULL)
ON CONFLICT (key) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    color = EXCLUDED.color,
    icon = EXCLUDED.icon,
    updated_at = now();

INSERT INTO state_machines (key, name, description, created_by)
VALUES ('DEFAULT', 'Default', 'Legacy default workflow', NULL)
ON CONFLICT (key) DO UPDATE
SET name = EXCLUDED.name,
    description = EXCLUDED.description,
    updated_at = now();

WITH default_machine AS (
    SELECT id
    FROM state_machines
    WHERE key = 'DEFAULT'
)
INSERT INTO state_machine_states (
    state_machine_id, key, name, state_order, category, is_initial, is_terminal, created_by
)
SELECT dm.id, seed.key, seed.name, seed.state_order, seed.category, seed.is_initial, seed.is_terminal, NULL
FROM default_machine dm
JOIN (
    VALUES
        ('BACKLOG', 'Backlog', 0, 'TODO', true, false),
        ('NEW', 'New', 1, 'TODO', false, false),
        ('IN_PROGRESS', 'In Progress', 2, 'ACTIVE', false, false),
        ('IN_VERIFICATION', 'In Verification', 3, 'ACTIVE', false, false),
        ('DONE', 'Done', 4, 'DONE', false, true)
) AS seed(key, name, state_order, category, is_initial, is_terminal) ON true
ON CONFLICT (state_machine_id, key) DO UPDATE
SET name = EXCLUDED.name,
    state_order = EXCLUDED.state_order,
    category = EXCLUDED.category,
    is_initial = EXCLUDED.is_initial,
    is_terminal = EXCLUDED.is_terminal,
    updated_at = now();

WITH transition_seed AS (
    SELECT
        sm.id AS state_machine_id,
        from_state.id AS from_state_id,
        to_state.id AS to_state_id
    FROM state_machines sm
    JOIN state_machine_states from_state
        ON from_state.state_machine_id = sm.id
    JOIN state_machine_states to_state
        ON to_state.state_machine_id = sm.id
    JOIN (
        VALUES
            ('BACKLOG', 'NEW'),
            ('NEW', 'BACKLOG'),
            ('NEW', 'IN_PROGRESS'),
            ('IN_PROGRESS', 'IN_VERIFICATION'),
            ('IN_VERIFICATION', 'DONE'),
            ('DONE', 'IN_PROGRESS')
    ) AS seed(from_key, to_key)
        ON from_state.key = seed.from_key
       AND to_state.key = seed.to_key
    WHERE sm.key = 'DEFAULT'
)
INSERT INTO state_machine_transitions (state_machine_id, from_state_id, to_state_id)
SELECT state_machine_id, from_state_id, to_state_id
FROM transition_seed
ON CONFLICT (state_machine_id, from_state_id, to_state_id) DO NOTHING;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM issues i
        LEFT JOIN state_machines sm
            ON sm.key = 'DEFAULT'
        LEFT JOIN state_machine_states sms
            ON sms.state_machine_id = sm.id
           AND sms.key = i.status
        WHERE sms.id IS NULL
    ) THEN
        RAISE EXCEPTION
            '017-ticket-state-machine: found issues.status value outside seeded DEFAULT workflow';
    END IF;
END $$;

WITH default_type AS (
    SELECT id
    FROM ticket_types
    WHERE key = 'DEFAULT'
),
default_machine AS (
    SELECT id
    FROM state_machines
    WHERE key = 'DEFAULT'
)
INSERT INTO space_ticket_types (space_id, ticket_type_id, state_machine_id, created_by)
SELECT s.id, dt.id, dm.id, s.created_by
FROM spaces s
CROSS JOIN default_type dt
CROSS JOIN default_machine dm
ON CONFLICT (space_id, ticket_type_id) DO UPDATE
SET state_machine_id = EXCLUDED.state_machine_id,
    updated_at = now();

WITH default_type AS (
    SELECT id
    FROM ticket_types
    WHERE key = 'DEFAULT'
),
default_states AS (
    SELECT sms.id, sms.key
    FROM state_machine_states sms
    JOIN state_machines sm
        ON sm.id = sms.state_machine_id
    WHERE sm.key = 'DEFAULT'
)
UPDATE issues i
SET ticket_type_id = dt.id,
    status_id = ds.id
FROM default_type dt,
     default_states ds
WHERE ds.key = i.status
  AND (i.ticket_type_id IS DISTINCT FROM dt.id
       OR i.status_id IS DISTINCT FROM ds.id);

ALTER TABLE issues ALTER COLUMN ticket_type_id SET NOT NULL;
ALTER TABLE issues ALTER COLUMN status_id SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_issues_ticket_type'
    ) THEN
        ALTER TABLE issues
            ADD CONSTRAINT fk_issues_ticket_type
            FOREIGN KEY (ticket_type_id)
            REFERENCES ticket_types(id)
            ON DELETE RESTRICT;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_issues_status_state'
    ) THEN
        ALTER TABLE issues
            ADD CONSTRAINT fk_issues_status_state
            FOREIGN KEY (status_id)
            REFERENCES state_machine_states(id)
            ON DELETE RESTRICT;
    END IF;
END $$;

ALTER TABLE issues DROP CONSTRAINT IF EXISTS chk_issues_status;

CREATE INDEX IF NOT EXISTS idx_issues_ticket_type_status
    ON issues (ticket_type_id, status_id);

--rollback DROP INDEX IF EXISTS idx_issues_ticket_type_status;
--rollback ALTER TABLE issues ADD CONSTRAINT chk_issues_status CHECK (status IN ('BACKLOG', 'NEW', 'IN_PROGRESS', 'IN_VERIFICATION', 'DONE'));
--rollback ALTER TABLE issues DROP CONSTRAINT IF EXISTS fk_issues_status_state;
--rollback ALTER TABLE issues DROP CONSTRAINT IF EXISTS fk_issues_ticket_type;
--rollback ALTER TABLE issues DROP COLUMN IF EXISTS status_id;
--rollback ALTER TABLE issues DROP COLUMN IF EXISTS ticket_type_id;
--rollback DROP INDEX IF EXISTS idx_space_ticket_types_space;
--rollback DROP TABLE IF EXISTS space_ticket_types;
--rollback DROP INDEX IF EXISTS idx_state_machine_transitions_machine_from;
--rollback DROP TABLE IF EXISTS state_machine_transitions;
--rollback DROP INDEX IF EXISTS idx_state_machine_states_machine_order;
--rollback DROP INDEX IF EXISTS idx_state_machine_states_initial_once;
--rollback DROP TABLE IF EXISTS state_machine_states;
--rollback DROP TABLE IF EXISTS state_machines;
--rollback DROP TABLE IF EXISTS ticket_types;
