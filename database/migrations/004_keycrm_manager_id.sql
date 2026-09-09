ALTER TABLE public.keycrm_customers
    ADD COLUMN IF NOT EXISTS manager_id bigint;

CREATE INDEX IF NOT EXISTS idx_keycrm_customers_manager_id
    ON public.keycrm_customers(manager_id);

GRANT SELECT ON public.keycrm_customers TO mcp_readonly;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
    ON public.keycrm_customers
    FROM mcp_readonly;
