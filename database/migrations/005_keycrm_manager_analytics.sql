CREATE TABLE IF NOT EXISTS public.keycrm_pipeline_cards (
    card_id bigint PRIMARY KEY,
    pipeline_id bigint NOT NULL,
    source_id bigint,
    manager_id bigint,
    status_id bigint,
    status_alias text,
    status_title text,
    status_is_final boolean,
    is_finished boolean,
    closed_from bigint,
    created_at timestamptz,
    updated_at timestamptz,
    status_changed_at timestamptz,
    payments_total numeric NOT NULL DEFAULT 0,
    products_total numeric NOT NULL DEFAULT 0,
    utm_source text,
    utm_medium text,
    utm_campaign text,
    synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_keycrm_pipeline_cards_manager_created
    ON public.keycrm_pipeline_cards (manager_id, created_at);

CREATE INDEX IF NOT EXISTS idx_keycrm_pipeline_cards_source_created
    ON public.keycrm_pipeline_cards (source_id, created_at);

CREATE INDEX IF NOT EXISTS idx_keycrm_pipeline_cards_status_created
    ON public.keycrm_pipeline_cards (status_alias, created_at);

CREATE INDEX IF NOT EXISTS idx_keycrm_pipeline_cards_updated
    ON public.keycrm_pipeline_cards (updated_at);

CREATE TABLE IF NOT EXISTS public.keycrm_pipeline_assignment_events (
    event_id bigserial PRIMARY KEY,
    card_id bigint NOT NULL,
    changed_at timestamptz NOT NULL,
    old_manager_id bigint,
    new_manager_id bigint,
    old_source_id bigint,
    new_source_id bigint,
    observed_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (
        card_id,
        changed_at,
        old_manager_id,
        new_manager_id,
        old_source_id,
        new_source_id
    )
);

CREATE INDEX IF NOT EXISTS idx_keycrm_pipeline_assignment_events_card
    ON public.keycrm_pipeline_assignment_events (card_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_keycrm_pipeline_assignment_events_new_manager
    ON public.keycrm_pipeline_assignment_events (new_manager_id, changed_at DESC);

CREATE INDEX IF NOT EXISTS idx_keycrm_pipeline_assignment_events_old_manager
    ON public.keycrm_pipeline_assignment_events (old_manager_id, changed_at DESC);

CREATE TABLE IF NOT EXISTS public.keycrm_pipeline_tracking_meta (
    id smallint PRIMARY KEY,
    tracking_started_at timestamptz NOT NULL
);

CREATE TABLE IF NOT EXISTS public.keycrm_pipelines (
    pipeline_id bigint PRIMARY KEY,
    title text NOT NULL DEFAULT '',
    lead_type text,
    keycrm_updated_at timestamptz,
    synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_keycrm_pipelines_lead_type
    ON public.keycrm_pipelines (lead_type);

CREATE TABLE IF NOT EXISTS public.keycrm_sources (
    source_id bigint PRIMARY KEY,
    name text NOT NULL DEFAULT '',
    alias text,
    driver text,
    keycrm_updated_at timestamptz,
    synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_keycrm_sources_name
    ON public.keycrm_sources (lower(name));

CREATE TABLE IF NOT EXISTS public.keycrm_users (
    user_id bigint PRIMARY KEY,
    full_name text NOT NULL DEFAULT '',
    username text,
    status text,
    keycrm_updated_at timestamptz,
    synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_keycrm_users_full_name
    ON public.keycrm_users (lower(full_name));

CREATE INDEX IF NOT EXISTS idx_keycrm_users_status
    ON public.keycrm_users (status);

GRANT SELECT ON
    public.keycrm_pipeline_cards,
    public.keycrm_pipeline_assignment_events,
    public.keycrm_pipeline_tracking_meta,
    public.keycrm_pipelines,
    public.keycrm_sources,
    public.keycrm_users
TO mcp_readonly;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON
    public.keycrm_pipeline_cards,
    public.keycrm_pipeline_assignment_events,
    public.keycrm_pipeline_tracking_meta,
    public.keycrm_pipelines,
    public.keycrm_sources,
    public.keycrm_users
FROM mcp_readonly;
