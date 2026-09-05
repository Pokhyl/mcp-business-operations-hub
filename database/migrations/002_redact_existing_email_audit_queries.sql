BEGIN;

UPDATE mcp_tool_calls
SET arguments_json = jsonb_set(
    arguments_json,
    '{query}',
    to_jsonb('[REDACTED]'::text),
    false
)
WHERE tool_name = 'search_emails'
  AND arguments_json ? 'query'
  AND arguments_json->>'query' <> '[REDACTED]';

COMMIT;
