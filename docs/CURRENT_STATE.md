# Current State

Last verified: 2026-09-08.

## Runtime

Production n8n runtime: `2.37.10`.

The runtime was upgraded from `2.33.3` on 2026-09-06 after `HTTP Request` nodes configured with `On Error -> Continue (using error output)` were observed to route a Google Drive 404 payload through the success output instead of the error output.

Before the upgrade a full operational backup was created containing the PostgreSQL dump, n8n data archive, compose file, environment file, and SHA256 checksums.

Post-upgrade checks passed:

- container image: `n8nio/n8n:2.37.10`
- `/healthz`: OK
- public editor: HTTP 200
- Google Drive 404 now follows the HTTP Request error output correctly

## Deployed MCP gateway

Workflow: `MCP — Server`

Workflow ID: `dSohghXnQp078EZm`

Status: active.

Authentication: n8n OAuth2 user authentication for the MCP endpoint.

Current published version verified on 2026-09-08:

```text
version_id: 07843872-4ab5-46f1-8df9-9a6bc8418673
active_version_id: 07843872-4ab5-46f1-8df9-9a6bc8418673
```

Current published tool surface:

- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_emails`
- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`
- `get_calendar_events`
- `find_free_time`

Legacy tools `hello_world` and `get_person` remain removed.

A Calendar gateway regression discovered on 2026-09-08 temporarily left the aggregate MCP Server without `get_calendar_events` after `find_free_time` was added. The missing tool has now been restored, both Calendar tools are present in the same active published version, both are connected to `MCP Server Trigger`, and `n8n/MCP_SERVER.json` has been synchronized with the recovered production surface.

The regression record is maintained in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

## Milestone status

M1 — Production cleanup: complete.

M2 — Google Workspace expansion: in progress; only final post-recovery natural-language gateway regression checks remain.

Completed M2 tools:

- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`
- `get_calendar_events`
- `find_free_time`

Structural Calendar gateway recovery is complete. M2 is not marked fully complete until one fresh natural-language request for `get_calendar_events` and one fresh natural-language request for `find_free_time` pass against the recovered aggregate MCP Server version.

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

Dedicated OAuth credential: `Google Drive MCP readonly`.

Scope:

```text
https://www.googleapis.com/auth/drive.readonly
```

### `search_drive_files`

Workflow: `MCP — Drive Search`

Status: active and exposed through `MCP — Server`.

Inputs:

- `query` — required natural search term
- `limit` — optional integer, default `10`, range `1..50`

The workflow builds a Google Drive query internally and searches filename or full-text content while excluding trashed files.

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

Verified low-level cases include Google Sheet, PDF, TXT/Markdown, Google Doc, Google Slides, unsupported MOV, invalid `file_id`, and nonexistent `file_id` -> `NOT_FOUND`.

Natural-language cross-tool acceptance is complete for:

```text
search_drive_files
 -> select real result
 -> read_drive_file(file_id)
 -> client summary
```

## Google Calendar

Dedicated OAuth credential: `Google Calendar MCP readonly`.

Scope:

```text
https://www.googleapis.com/auth/calendar.readonly
```

### `get_calendar_events`

Workflow: `MCP — Calendar Events`

Workflow ID: `IUpcFPRH3xOVbgEq`.

Status: active, published, exposed through `MCP — Server`, and previously accepted end to end.

Inputs:

- `start` — required RFC3339 timestamp with timezone
- `end` — required RFC3339 timestamp with timezone and later than `start`
- `calendar_id` — optional string, defaults to `primary`
- `limit` — optional integer, defaults to `50`, range `1..2500`

The provider call uses `singleEvents=true` and `orderBy=startTime`. Timed events preserve `dateTime`; all-day events preserve `date`.

Accepted cases:

- empty input -> `INVALID_INPUT`
- valid `primary` window -> normalized `success=true`
- nonexistent calendar -> provider 404 -> `NOT_FOUND`
- succeeded and failed audit rows finalized with non-null duration
- natural-language week, month, and year queries through Claude

Detailed acceptance evidence: `docs/CALENDAR_ACCEPTANCE.md`.

### `find_free_time`

Workflow: `MCP — Find Free Time`

Workflow ID: `dDiqHH9C5clOrYOX`.

Status: active, published, exposed through `MCP — Server`, and accepted through a natural-language MCP request.

Inputs:

- `start` — required RFC3339 timestamp with timezone
- `end` — required RFC3339 timestamp with timezone and later than `start`
- `duration_minutes` — optional positive integer, defaults to `30`, must fit within the requested window
- `calendar_id` — optional string, defaults to `primary`

Provider endpoint:

```text
POST https://www.googleapis.com/calendar/v3/freeBusy
```

The workflow:

1. validates the requested window and duration;
2. starts the audit row;
3. requests Google Calendar FreeBusy data;
4. rejects per-calendar provider errors even when the HTTP response itself is 200;
5. clips and merges overlapping busy intervals;
6. computes maximal free windows;
7. keeps only windows at least `duration_minutes` long;
8. finalizes audit success/error;
9. returns the original normalized MCP response.

Natural-language E2E acceptance on 2026-09-08:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

The primary calendar was empty, so the returned free interval covered the full requested window. The corresponding `mcp_tool_calls` row finalized as `succeeded` with `duration_ms=640`.

Detailed acceptance evidence: `docs/FIND_FREE_TIME_ACCEPTANCE.md`.

## GitHub

Workflow: `MCP — GitHub Read File`

Status: active and exposed.

Input: repository-relative `path`.

Missing files normalize to `NOT_FOUND`; other provider failures use `UPSTREAM_ERROR`.

## PostgreSQL

Workflow: `MCP — PostgreSQL Recent Jobs`

Status: active and exposed.

Input: optional `limit`, default `10`, range `1..50`.

Workflow: `MCP — PostgreSQL Job Details`

Status: active and exposed.

Input: UUID `job_id`.

Zero-row results normalize to `NOT_FOUND`. Database failures normalize to `UPSTREAM_ERROR`.

## Repository export state

Current deployed workflow exports include:

- `n8n/MCP_SERVER.json`
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

`n8n/MCP_SERVER.json` now contains both Calendar tools and references published version `07843872-4ab5-46f1-8df9-9a6bc8418673`.

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

1. Run one fresh natural-language `get_calendar_events` request against the recovered MCP Server.
2. Run one fresh natural-language `find_free_time` request against the same recovered MCP Server.
3. If both pass, close `docs/MCP_SERVER_REGRESSION_2026-09-08.md`, mark M2 complete, and move to M3 CRM integration.
