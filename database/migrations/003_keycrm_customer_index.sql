CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS public.keycrm_customers (
    buyer_id bigint PRIMARY KEY,
    full_name text NOT NULL DEFAULT '',
    phones text[] NOT NULL DEFAULT ARRAY[]::text[],
    emails text[] NOT NULL DEFAULT ARRAY[]::text[],
    keycrm_updated_at timestamptz,
    synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_keycrm_customers_full_name_trgm
    ON public.keycrm_customers
    USING gin (lower(full_name) gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_keycrm_customers_phones
    ON public.keycrm_customers
    USING gin (phones);

CREATE INDEX IF NOT EXISTS idx_keycrm_customers_emails
    ON public.keycrm_customers
    USING gin (emails);

CREATE TABLE IF NOT EXISTS public.keycrm_sync_state (
    sync_name text PRIMARY KEY,
    last_successful_sync_at timestamptz NOT NULL,
    last_count integer NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.keycrm_customers TO mcp_readonly;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON public.keycrm_customers
    FROM mcp_readonly;
