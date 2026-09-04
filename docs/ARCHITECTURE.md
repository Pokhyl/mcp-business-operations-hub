# Architecture

## Goal

Expose selected business capabilities to an AI client through a single controlled MCP gateway while keeping credentials, authorization, and implementation details inside self-hosted infrastructure.

## High-level design

```text
+------------------+
|   MCP Client     |
|     Claude       |
+--------+---------+
         |
         | MCP over HTTPS
         v
+----------------------------+
| n8n MCP Server Trigger     |
| OAuth2 authentication      |
+-------------+--------------+
              |
      tool selection by model
              |
   +----------+-----------+------------------+
   |                      |                  |
   v                      v                  v
Gmail tool workflow   GitHub workflow   PostgreSQL workflows
   |                      |                  |
   v                      v                  v
Google Gmail API      GitHub API         PostgreSQL
```

## Tool isolation

Every capability is implemented as an independent sub-workflow.

This gives four benefits:

1. Each tool has its own explicit input contract.
2. Each external system can use a different least-privilege credential.
3. Tool-specific validation and normalization remain isolated.
4. A failing integration does not require redesigning the whole MCP gateway.

## Response normalization

Raw provider responses are not sent directly to the model when they contain unnecessary metadata.

Example Gmail normalization:

```json
{
  "id": "message-id",
  "threadId": "thread-id",
  "from": "sender",
  "to": "recipient",
  "subject": "subject",
  "date": "ISO timestamp",
  "body": "full plain-text body"
}
```

## Read/write boundary

The project uses two logical classes of tools.

### Read tools

Examples:

- `search_emails`
- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- future `search_drive_files`
- future `get_calendar_events`

These can be eligible for persistent approval at the MCP client level because they do not mutate business state.

### Write tools

Future examples:

- `send_email`
- `create_calendar_event`
- `update_customer`
- `upload_drive_file`

Write tools must have an explicit approval boundary and idempotency protection where applicable.

## Audit pipeline target

Target execution path:

```text
MCP request
 -> validate inputs
 -> audit start
 -> execute provider operation
 -> normalize result / error
 -> audit completion
 -> return MCP tool response
```

See `database/migrations/001_mcp_tool_audit.sql`.
