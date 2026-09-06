# Current State

Last verified: 2026-09-06.

## Runtime

Production n8n runtime: `2.37.10`.

The runtime was upgraded from `2.33.3` on 2026-09-06 after `HTTP Request` nodes configured with `On Error -> Continue (using error output)` were observed to route a Google Drive 404 payload through the success output instead of the error output. The production upgrade preserved the existing PostgreSQL/n8n data volumes, completed database migrations successfully, and passed health checks.

Before the upgrade a full operational backup was created containing the PostgreSQL dump, n8n data archive, compose file, environment file, and SHA256 checksums.

After the upgrade:

- container image: `n8nio/n8n:2.37.10`
- `/healthz`: OK
- public editor: HTTP 200
- the same Google Drive 404 now follows the HTTP Request error output correctly

The old `2.33.3` image was intentionally retained temporarily for rollback.

## Deployed MCP gateway

Workflow: `MCP — Server`

Status: active.

Authentication: n8n OAuth2 user authentication for the MCP endpoint.

Current production tool surface:

- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_emails`
- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`

Legacy tools `hello_world` and `get_person` have been removed from the deployed MCP server.

## Milestone status

M1 — Production cleanup: complete.

M2 — Google Workspace expansion: in progress.

Implemented and deployed M2 tools:

- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`

Remaining M2 tools:

- `get_calendar_events`
- `find_free_time`

No write-capable behavior is exposed in M2.

## Normalized MCP contract

Read tools use the common success envelope:

```json
{
  "success": true,
  "data": "...",
  "meta": {
    "tool": "...",
    "count": 1
  }
}
```

Errors use:

```json
{
  "success": false,
  "error": {
    "code": "...",
    "message": "..."
  },
  "meta": {
    "tool": "...",
    "count": 0
  }
}
```

Current normalized error codes include:

- `INVALID_INPUT`
- `NOT_FOUND`
- `AMBIGUOUS_ATTACHMENT`
- `UNSUPPORTED_FILE_TYPE`
- `UPSTREAM_ERROR`

## Centralized audit logging

Audit workflow: `MCP — Audit Tool Call`

Audit table: `mcp_tool_calls`

Lifecycle for valid audited calls:

```text
Validate input
 -> Audit start
 -> Provider/database operation
 -> Normalize success/error
 -> Audit finish
 -> Return original MCP response
```

`Audit start` stores sanitized arguments and returns `audit_id` plus `started_at`. `Audit finish` finalizes the same row with `succeeded|failed`, normalized error data, duration, and completion timestamp.

`INVALID_INPUT` remains before `Audit start` and therefore does not create an audit row.

Sensitive-argument sanitization remains centralized in `MCP — Audit Tool Call`. Gmail search queries are always stored as `[REDACTED]`; credential/session-style keys are recursively redacted. Historical raw Gmail-query audit values were backfilled by `database/migrations/002_redact_existing_email_audit_queries.sql`.

All finish-audit subworkflow calls omit `arguments_json`; only audit start writes call arguments.

## Gmail

### `search_emails`

Workflow: `MCP — Gmail Search`

Status: active.

Inputs:

- `query` — required non-empty Gmail search string
- `limit` — optional integer, default `5`, range `1..50`

The Gmail search query is passed through `filters.q`. Output messages include `id`, `threadId`, `from`, `to`, `subject`, `date`, and `body`.

### `get_email_attachment`

Workflow: `MCP — Gmail Attachment`

Status: active and exposed through `MCP — Server`.

Public inputs:

- `message_id` — required; normally obtained internally from `search_emails`
- `filename` — optional exact or partial filename hint

The user is never required to know or provide Gmail `attachmentId`.

The workflow recursively traverses MIME parts, discovers the real Gmail `body.attachmentId` internally, downloads the selected attachment, converts Gmail base64url to standard base64, and returns filename, MIME type, size, and `content_base64`.

## Google Drive

A dedicated Google OAuth2 credential named `Google Drive MCP readonly` is used with scope:

```text
https://www.googleapis.com/auth/drive.readonly
```

### `search_drive_files`

Workflow: `MCP — Drive Search`

Status: active and exposed through `MCP — Server`.

Inputs:

- `query` — required natural search term
- `limit` — optional integer, default `10`, range `1..50`

The workflow builds a Google Drive query internally and searches filename or full-text content while excluding trashed files. Returned file metadata includes:

- `id`
- `name`
- `mime_type`
- `modified_time`
- `size`
- `web_view_link`
- `parents`
- `drive_id`

Verified cases:

- normal search returning real Drive files
- invalid limit -> `INVALID_INPUT`
- nonexistent query -> `success=true`, empty `data`, `count=0`
- natural MCP client search for `TikTok Video Pipeline` returned real matching Google Drive files

### `read_drive_file`

Workflow: `MCP — Drive Read File`

Status: active and exposed through `MCP — Server`.

Input:

- `file_id` — required non-empty Google Drive file ID

Supported content types:

- Google Docs -> exported as `text/plain`
- Google Sheets -> exported as `text/csv`
- Google Slides -> exported as `text/plain`
- PDF -> downloaded and text extracted
- text-based regular files -> downloaded as text

Text output is capped at `50000` characters. The response includes `truncated` and `original_content_length` so truncation is explicit rather than silent.

Unsupported binary types return `UNSUPPORTED_FILE_TYPE`.

Verified low-level cases:

- Google Sheet: PASS
- PDF: PASS
- TXT/Markdown: PASS
- Google Doc: PASS
- Google Slides: PASS
- unsupported MOV binary: `UNSUPPORTED_FILE_TYPE` PASS
- empty/invalid `file_id`: `INVALID_INPUT` PASS
- nonexistent `file_id`: `NOT_FOUND` PASS

The nonexistent-file test was the case that exposed the n8n `2.33.3` HTTP error-output routing defect. After upgrading n8n to `2.37.10`, the provider 404 correctly reached the error branch. `Format Drive error` then normalizes `details.httpCode == 404` to:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Google Drive file not found"
  },
  "meta": {
    "tool": "read_drive_file",
    "count": 0
  }
}
```

Final natural-language cross-tool acceptance is complete. Through Claude, the user asked:

```text
Найди файл TikTok Video Pipeline в моём Google Drive и скажи, что в нём.
```

Observed production behavior:

```text
search_drive_files
 -> found two matching Google Sheets
 -> client selected the more recently modified match
 -> read_drive_file(file_id)
 -> client summarized the real sheet contents
```

The user supplied neither Drive query syntax nor a file ID. Claude summarized the actual intake-sheet columns and the populated request row, confirming that `search_drive_files -> read_drive_file -> client summary` works end to end.

## GitHub

Workflow: `MCP — GitHub Read File`

Status: active.

Input: repository-relative `path`.

Missing files normalize to `NOT_FOUND`; other provider failures use `UPSTREAM_ERROR`.

## PostgreSQL

Workflow: `MCP — PostgreSQL Recent Jobs`

Status: active.

Input: optional `limit`, default `10`, range `1..50`.

Workflow: `MCP — PostgreSQL Job Details`

Status: active.

Input: UUID `job_id`.

Zero-row results normalize to `NOT_FOUND`. Database failures normalize to `UPSTREAM_ERROR`.

## Acceptance tests

Production acceptance evidence and regression rules are documented in:

`docs/ACCEPTANCE_TESTS.md`

Provider/database error branches are not deliberately forced by breaking working production credentials or SQL.

## Repository export state

Current deployed workflow exports:

- `n8n/MCP_SERVER.json`
- `n8n/AUDIT_TOOL_CALL.json`
- `n8n/github/GET_GITHUB_FILE.json`
- `n8n/gmail/SEARCH_EMAILS.json`
- `n8n/gmail/GET_EMAIL_ATTACHMENT.json`
- `n8n/postgres/GET_RECENT_JOBS.json`
- `n8n/postgres/GET_JOB_DETAILS.json`
- `n8n/drive/SEARCH_DRIVE_FILES.json`
- `n8n/drive/READ_DRIVE_FILE.json`

Audit migrations:

- `database/migrations/001_mcp_tool_audit.sql`
- `database/migrations/002_redact_existing_email_audit_queries.sql`

The exports reference n8n credentials by credential metadata only; no plaintext credential values are intentionally stored in the repository.

## Security state

- Gmail, GitHub, and Google Drive credentials remain in n8n credential storage.
- Google Drive uses a dedicated read-only OAuth scope.
- PostgreSQL business-read tools use the read-only `mcp_read` credential.
- The centralized audit workflow uses the write-capable application PostgreSQL credential only for `mcp_tool_calls` writes.
- No write-capable business tool is exposed through MCP.
- Sensitive audit arguments are sanitized centrally.
- Gmail `attachmentId` remains an internal implementation detail and is not required from the user.

## Exact next milestone

1. Implement `get_calendar_events`.
2. Implement `find_free_time`.
