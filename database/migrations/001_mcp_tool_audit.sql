BEGIN;

CREATE TABLE IF NOT EXISTS mcp_tool_calls (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id uuid,
    tool_name text NOT NULL,
    arguments_json jsonb,
    status text NOT NULL CHECK (status IN ('started', 'succeeded', 'failed')),
    error_code text,
    error_message text,
    duration_ms integer CHECK (duration_ms IS NULL OR duration_ms >= 0),
    client_name text,
    started_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_mcp_tool_calls_started_at
    ON mcp_tool_calls (started_at DESC);

CREATE INDEX IF NOT EXISTS idx_mcp_tool_calls_tool_started
    ON mcp_tool_calls (tool_name, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_mcp_tool_calls_status_started
    ON mcp_tool_calls (status, started_at DESC);

COMMIT;
