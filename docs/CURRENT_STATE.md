# Current State

Last verified: 2026-09-08.

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

Workflow ID: `dSohghXnQp078EZm`

Status: active.

Authentication: n8n OAuth2 user authentication for the MCP endpoint.

Current published version verified on 2026-09-08:

```text
version_id: db01b624-5108-4998-8a53-fd12680c9d25
active_version_id: db01b624-5108-4998-8a53-fd12680c9d25
```

Current published tool surface:

- `find_free_time`
- `get_email_attachment`
- `get_github_file`
- `get_job_details`
- `get_recent_jobs`
- `read_drive_file`
- `search_drive_files`
- `search_emails`

Important regression: the previously accepted `get_calendar_events` tool node is currently missing from the published `MCP — Server` surface. The underlying `MCP — Calendar Events` sub-workflow is still active and accepted. The regression is documented in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

The existing repository export `n8n/MCP_SERVER.json` was intentionally not overwritten with this regressed state because it preserves the last accepted `get_calendar_events` tool configuration needed for recovery.

Legacy tools `hello_world` and `get_person` remain removed.

## Milestone status

M1 — Production cleanup: complete.

M2 — Google Workspace expansion: in progress; final Calendar gateway recovery pending.

Completed M2 tools:

- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`
- `get_calendar_events` — implementation and acceptance complete, but current MCP gateway exposure must be restored
- `find_free_time` — implementation, publication, MCP exposure, and natural-language E2E acceptance complete

No write-capable behavior is exposed in M2.

M2 is not considered complete until `get_calendar_events` and `find_free_time` are simultaneously present in the same published MCP Server version and one natural-language regression request for each tool passes.

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

Status: active and exposed through `MCP — Server`.

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

The user supplied neither Drive query syntax nor a file ID.

## Google Calendar

A dedicated Google OAuth2 credential named `Google Calendar MCP readonly` is used with scope:

```text
https://www.googleapis.com/auth/calendar.readonly
```

### `get_calendar_events`

Workflow: `MCP — Calendar Events`

Workflow ID: `IUpcFPRH3xOVbgEq`.

Status: active, published, low-level accepted, and natural-language accepted. Current MCP Server exposure is temporarily missing because of the gateway regression described above.

Inputs:

- `start` — required RFC3339 timestamp with timezone
- `end` — required RFC3339 timestamp with timezone and must be later than `start`
- `calendar_id` — optional string, defaults to `primary`
- `limit` — optional integer, defaults to `50`, range `1..2500`

Provider call:

```text
Google Calendar events.list
```

with `singleEvents=true` and `orderBy=startTime`.

Low-level acceptance:

- empty input -> `INVALID_INPUT` before audit/provider access
- valid `primary` window -> normalized `success=true`; empty results remain a successful empty list
- nonexistent calendar -> provider HTTP 404 -> `NOT_FOUND`
- success and failure audit rows finalize with non-null durations

Natural-language acceptance through Claude:

- current week -> correct empty result
- month -> correct empty result
- year -> correct empty result
- user confirmed the source calendar was actually empty

Detailed evidence: `docs/CALENDAR_ACCEPTANCE.md`.

### `find_free_time`

Workflow: `MCP — Find Free Time`

Workflow ID: `dDiqHH9C5clOrYOX`.

Status: active, published, exposed through the current MCP Server, and natural-language E2E accepted.

Published workflow version:

```text
version_id: efe02511-9b12-4274-9d1a-39e597d7fe3a
active_version_id: efe02511-9b12-4274-9d1a-39e597d7fe3a
```

Inputs:

- `start` — required RFC3339 timestamp with timezone
- `end` — required RFC3339 timestamp with timezone and must be later than `start`
- `duration_minutes` — optional positive integer, defaults to `30`, and must fit within the requested range
- `calendar_id` — optional string, defaults to `primary`

Provider call:

```text
POST https://www.googleapis.com/calendar/v3/freeBusy
```

The workflow explicitly checks per-calendar FreeBusy errors even when the HTTP response is 200, then merges overlapping/touching busy intervals and returns maximal free windows that are at least `duration_minutes` long.

Natural-language production acceptance through Claude:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

The MCP client generated the expected RFC3339 time window for 2026-09-09, used `calendar_id=primary`, and returned the entire 09:00–18:00 range as free. The connected primary calendar was actually empty, so the result matched the source of truth.

Audit evidence for the accepted request:

```text
tool_name:        find_free_time
status:           succeeded
duration_ms:      640
start:            2026-09-09T09:00:00+02:00
end:              2026-09-09T18:00:00+02:00
duration_minutes: 60
calendar_id:      primary
```

Detailed evidence: `docs/FIND_FREE_TIME_ACCEPTANCE.md`.

## GitHub

Workflow: `MCP — GitHub Read File`

Status: active and exposed through `MCP — Server`.

Input: repository-relative `path`.

Missing files normalize to `NOT_FOUND`; other provider failures use `UPSTREAM_ERROR`.

## PostgreSQL

Workflow: `MCP — PostgreSQL Recent Jobs`

Status: active and exposed through `MCP — Server`.

Input: optional `limit`, default `10`, range `1..50`.

Workflow: `MCP — PostgreSQL Job Details`

Status: active and exposed through `MCP — Server`.

Input: UUID `job_id`.

Zero-row results normalize to `NOT_FOUND`. Database failures normalize to `UPSTREAM_ERROR`.

## Acceptance tests

Production acceptance evidence and regression rules are documented in:

- `docs/ACCEPTANCE_TESTS.md`
- `docs/CALENDAR_ACCEPTANCE.md`
- `docs/FIND_FREE_TIME_ACCEPTANCE.md`

The current MCP gateway regression is documented in:

- `docs/MCP_SERVER_REGRESSION_2026-09-08.md`

Provider/database error branches are not deliberately forced by breaking working production credentials or SQL.

## Repository export state

Workflow exports include:

- `n8n/MCP_SERVER.json` — last accepted gateway export containing `get_calendar_events`; intentionally not overwritten with the current regressed production gateway
- `n8n/AUDIT_TOOL_CALL.json`
- `n8n/github/GET_GITHUB_FILE.json`
- `n8n/gmail/SEARCH_EMAILS.json`
- `n8n/gmail/GET_EMAIL_ATTACHMENT.json`
- `n8n/postgres/GET_RECENT_JOBS.json`
- `n8n/postgres/GET_JOB_DETAILS.json`
- `n8n/drive/SEARCH_DRIVE_FILES.json`
- `n8n/drive/READ_DRIVE_FILE.json`
- `n8n/calendar/GET_CALENDAR_EVENTS.json`
- `n8n/calendar/FIND_FREE_TIME.json`

Audit migrations:

- `database/migrations/001_mcp_tool_audit.sql`
- `database/migrations/002_redact_existing_email_audit_queries.sql`

The exports reference n8n credentials by credential metadata only; no plaintext credential values are intentionally stored in the repository.

## Security state

- Gmail, GitHub, Google Drive, and Google Calendar credentials remain in n8n credential storage.
- Google Drive uses a dedicated read-only OAuth scope.
- Google Calendar uses the dedicated `calendar.readonly` OAuth scope.
- PostgreSQL business-read tools use the read-only `mcp_read` credential.
- The centralized audit workflow uses the write-capable application PostgreSQL credential only for `mcp_tool_calls` writes.
- No write-capable business tool is exposed through MCP.
- Sensitive audit arguments are sanitized centrally.
- Gmail `attachmentId` remains an internal implementation detail and is not required from the user.

## Exact next milestone

1. Restore the previously accepted `get_calendar_events` tool node in the current `MCP — Server` without removing `find_free_time`.
2. Publish the server and verify both Calendar tools are present simultaneously.
3. Run one natural-language regression request for `get_calendar_events` and one for `find_free_time`.
4. Export the repaired final MCP Server to `n8n/MCP_SERVER.json`.
5. Close M2 only after those gateway regression checks pass.
