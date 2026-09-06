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
   +----------+-----------+------------------+----------------+
   |                      |                  |                |
   v                      v                  v                v
Gmail workflows       Drive workflows   GitHub workflow   PostgreSQL workflows
   |                      |                  |                |
   v                      v                  v                v
Gmail API             Drive API          GitHub API       PostgreSQL
```

## Tool isolation

Every capability is implemented as an independent sub-workflow.

This gives four benefits:

1. Each tool has its own explicit input contract.
2. Each external system can use a different least-privilege credential.
3. Tool-specific validation and normalization remain isolated.
4. A failing integration does not require redesigning the whole MCP gateway.

Current production sub-workflows include Gmail search/attachment retrieval, Drive search/file reading, GitHub file reading, PostgreSQL job reads, and the centralized audit workflow.

## Google Drive read path

Drive access uses a dedicated OAuth2 credential with only:

```text
https://www.googleapis.com/auth/drive.readonly
```

The model-facing path is intentionally split into two tools:

```text
natural user request
 -> search_drive_files(query, limit)
 -> normalized file metadata + file_id
 -> read_drive_file(file_id)
 -> normalized text content
 -> model summarizes source content
```

`read_drive_file` chooses the provider operation from Drive metadata:

```text
Google Doc    -> Drive export text/plain
Google Sheet  -> Drive export text/csv
Google Slides -> Drive export text/plain
PDF           -> alt=media download -> text extraction
Text file     -> alt=media download -> text
Other binary  -> UNSUPPORTED_FILE_TYPE
```

Text output is capped at 50000 characters and carries explicit truncation metadata.

## Response normalization

Raw provider responses are not sent directly to the model when they contain unnecessary metadata.

All current tools use the shared success/error envelope defined in `docs/CURRENT_STATE.md` and `docs/MCP_TOOLS.md`.

Provider-specific errors are converted into stable application-level codes such as:

- `INVALID_INPUT`
- `NOT_FOUND`
- `AMBIGUOUS_ATTACHMENT`
- `UNSUPPORTED_FILE_TYPE`
- `UPSTREAM_ERROR`

## Read/write boundary

The project uses two logical classes of tools.

### Read tools

Current examples:

- `search_emails`
- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`
- `get_github_file`
- `get_recent_jobs`
- `get_job_details`

Planned read tools:

- `get_calendar_events`
- `find_free_time`

These do not mutate business state.

### Write tools

Future examples:

- `send_email`
- `create_calendar_event`
- `update_customer`
- `upload_drive_file`

Write tools must have an explicit approval boundary and idempotency protection where applicable.

## Audit pipeline

Current execution path for valid audited calls:

```text
MCP request
 -> validate inputs
 -> audit start
 -> execute provider/database operation
 -> normalize result / error
 -> audit completion
 -> return original MCP tool response
```

`INVALID_INPUT` is intentionally rejected before audit/provider access.

Audit storage is implemented by `MCP — Audit Tool Call` and `database/migrations/001_mcp_tool_audit.sql`. Sensitive arguments are sanitized before storage.

## Runtime compatibility rule

Workflow architecture must not absorb known runtime defects through ad-hoc branches when a supported runtime fix is available.

This rule was applied on 2026-09-06 when n8n `2.33.3` misrouted HTTP 404 items through the HTTP Request success output. Production was backed up and upgraded to `2.37.10`; no workflow-specific error-detection bypass was added.
