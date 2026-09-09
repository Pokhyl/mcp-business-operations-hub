# Current State

Last verified: 2026-09-09.

## Runtime

Production n8n runtime: `2.37.10`.

Production was upgraded from `2.33.3` after an HTTP Request error-output routing defect was observed during Google Drive 404 acceptance. A full operational backup was created before the upgrade. Post-upgrade health checks and the Drive 404 regression passed.

## Deployed MCP gateway

Workflow: `MCP — Server`

Workflow ID: `dSohghXnQp078EZm`

Status: active.

Authentication: n8n OAuth2 user authentication for the MCP endpoint.

Current published production version:

```text
version_id:        07843872-4ab5-46f1-8df9-9a6bc8418673
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

The current repository export `n8n/MCP_SERVER.json` contains the same recovered production surface, including both Calendar tools.

## Milestone status

M0 — Foundation: complete.

M1 — Production cleanup: complete.

M2 — Google Workspace expansion: complete.

Completed M2 tools:

- `get_email_attachment`
- `search_drive_files`
- `read_drive_file`
- `get_calendar_events`
- `find_free_time`

No write-capable business behavior is exposed in M2.

A Calendar gateway regression discovered on 2026-09-08 temporarily removed `get_calendar_events` after `find_free_time` was added to the aggregate MCP Server. The missing tool was restored, the server was republished, the GitHub export was synchronized, and post-recovery natural-language regression acceptance passed for both Calendar tools on 2026-09-09. The regression is closed in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

Next milestone: M3 — CRM integration.

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

`INVALID_INPUT` remains before `Audit start` and therefore does not create an audit row.

All finish-audit subworkflow calls omit `arguments_json`; only audit start writes call arguments.

Sensitive-argument sanitization remains centralized. Gmail search queries are stored as `[REDACTED]`; credential/session-style keys are recursively redacted.

## Gmail

### `search_emails`

Workflow: `MCP — Gmail Search`

Status: active and exposed.

Inputs:

- `query` — required non-empty Gmail search string
- `limit` — optional integer, default `5`, range `1..50`

### `get_email_attachment`

Workflow: `MCP — Gmail Attachment`

Status: active and exposed.

Public inputs:

- `message_id` — required; normally obtained from `search_emails`
- `filename` — optional exact or partial filename hint

Gmail `attachmentId` is discovered internally and is never required from the user.

## Google Drive

Credential: `Google Drive MCP readonly`

Scope:

```text
https://www.googleapis.com/auth/drive.readonly
```

### `search_drive_files`

Workflow: `MCP — Drive Search`

Status: active and exposed.

Inputs:

- `query` — required natural search term
- `limit` — optional integer, default `10`, range `1..50`

No matches are a successful empty result.

### `read_drive_file`

Workflow: `MCP — Drive Read File`

Status: active and exposed.

Input:

- `file_id` — required non-empty Google Drive file ID

Supported content types:

- Google Docs -> `text/plain`
- Google Sheets -> `text/csv`
- Google Slides -> `text/plain`
- PDF -> extracted text
- text-based regular files -> text

Text is capped at `50000` characters with explicit truncation metadata. Unsupported binaries return `UNSUPPORTED_FILE_TYPE`. Missing files return `NOT_FOUND`.

Natural cross-tool acceptance for search -> read -> client summary is complete.

## Google Calendar

Credential: `Google Calendar MCP readonly`

Scope:

```text
https://www.googleapis.com/auth/calendar.readonly
```

### `get_calendar_events`

Workflow: `MCP — Calendar Events`

Workflow ID: `IUpcFPRH3xOVbgEq`

Status: active, published, exposed, and accepted end to end.

Inputs:

- `start` — required RFC3339 timestamp with timezone
- `end` — required RFC3339 timestamp with timezone and later than `start`
- `calendar_id` — optional string, defaults to `primary`
- `limit` — optional integer, defaults to `50`, range `1..2500`

Provider behavior uses `singleEvents=true` and `orderBy=startTime`. Timed and all-day events preserve their respective Calendar fields.

Accepted cases include:

- invalid input -> `INVALID_INPUT`
- valid primary window -> normalized success
- nonexistent calendar -> provider 404 -> `NOT_FOUND`
- succeeded/failed audit finalization
- natural week/month/year queries
- final post-recovery gateway regression request on 2026-09-09

Final post-recovery request:

```text
Что у меня завтра в календаре?
```

Resolved tool arguments:

```text
start:       2026-09-10T00:00:00+02:00
end:         2026-09-11T00:00:00+02:00
calendar_id: primary
limit:       50
```

The real primary calendar was empty; Claude reported no events. Audit row: `succeeded`, `duration_ms=606`.

Detailed acceptance: `docs/CALENDAR_ACCEPTANCE.md` and `docs/ACCEPTANCE_TESTS.md`.

### `find_free_time`

Workflow: `MCP — Find Free Time`

Workflow ID: `dDiqHH9C5clOrYOX`

Status: active, published, exposed, and accepted end to end.

Inputs:

- `start` — required RFC3339 timestamp with timezone
- `end` — required RFC3339 timestamp with timezone and later than `start`
- `duration_minutes` — optional positive integer, defaults to `30`, must fit inside the requested window
- `calendar_id` — optional string, defaults to `primary`

Provider endpoint:

```text
POST https://www.googleapis.com/calendar/v3/freeBusy
```

The workflow validates input, starts audit, calls FreeBusy, rejects per-calendar provider errors, clips/merges busy intervals, computes maximal qualifying free windows, finalizes audit, and returns the normalized business result.

Final post-recovery request on 2026-09-09:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

Resolved tool arguments:

```text
start:            2026-09-10T09:00:00+02:00
end:              2026-09-10T18:00:00+02:00
calendar_id:      primary
duration_minutes: 60
```

The real primary calendar was empty, so Claude reported the full 09:00–18:00 interval as available. Audit row: `succeeded`, `duration_ms=450`.

Detailed acceptance: `docs/FIND_FREE_TIME_ACCEPTANCE.md` and `docs/ACCEPTANCE_TESTS.md`.

## GitHub

Workflow: `MCP — GitHub Read File`

Status: active and exposed.

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

Current workflow exports include:

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

Audit migrations:

- `database/migrations/001_mcp_tool_audit.sql`
- `database/migrations/002_redact_existing_email_audit_queries.sql`

Credential values are not intentionally stored in repository exports.

## Security state

- Gmail, GitHub, Google Drive, and Google Calendar credentials remain in n8n credential storage.
- Drive and Calendar use dedicated read-only OAuth scopes.
- PostgreSQL business-read tools use the read-only `mcp_read` credential.
- The centralized audit workflow uses the write-capable application PostgreSQL credential only for audit writes.
- No write-capable business tool is exposed through MCP.
- Sensitive audit arguments are sanitized centrally.

## Exact next milestone

M3 — CRM integration:

1. define the CRM provider and read-only auth boundary;
2. implement `search_customers(query, limit)`;
3. implement `get_customer_details(customer_id)`;
4. run a cross-system customer context demo without introducing write capability.
