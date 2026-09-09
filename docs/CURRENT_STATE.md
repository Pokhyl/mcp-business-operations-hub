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
version_id:        fcfb4961-f40e-44b6-b2de-627c31f87bea
active_version_id: fcfb4961-f40e-44b6-b2de-627c31f87bea
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
- `search_customers`
- `get_customer_details`

Legacy tools `hello_world` and `get_person` remain removed.

The complete tool surface was re-verified after adding the two KeyCRM tools so the previous Calendar gateway regression pattern is not repeated.

## Milestone status

M0 — Foundation: complete.

M1 — Production cleanup: complete.

M2 — Google Workspace expansion: complete.

M3 — CRM integration: in progress.

M3 low-level production acceptance is complete for:

- KeyCRM customer bootstrap
- scheduled incremental customer synchronization
- `search_customers`
- `get_customer_details`
- aggregate MCP Server integration
- read-only database permission verification

The only remaining M3 acceptance item is the natural-language cross-system customer context demo through the real MCP client.

Detailed M3 evidence: `docs/M3_KEYCRM_ACCEPTANCE.md`.

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

Audit table: `public.mcp_tool_calls`.

Lifecycle for valid audited calls:

```text
Validate input
 -> Audit start
 -> provider/database operation
 -> normalize success/error
 -> Audit finish
 -> return original MCP response
```

`INVALID_INPUT` remains before `Audit start` and therefore does not create an audit row.

All finish-audit subworkflow calls omit `arguments_json`; only audit start writes call arguments.

Sensitive-argument sanitization remains centralized. Gmail search queries and KeyCRM customer search queries are stored as `[REDACTED]`.

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

### `read_drive_file`

Workflow: `MCP — Drive Read File`

Status: active and exposed.

Supported content types include Google Docs, Sheets, Slides, PDF, and text-based regular files. Text is capped at `50000` characters with explicit truncation metadata. Unsupported binaries return `UNSUPPORTED_FILE_TYPE`; missing files return `NOT_FOUND`.

Natural cross-tool search -> read -> client summary acceptance is complete.

## Google Calendar

Credential: `Google Calendar MCP readonly`

Scope:

```text
https://www.googleapis.com/auth/calendar.readonly
```

### `get_calendar_events`

Workflow ID: `IUpcFPRH3xOVbgEq`

Status: active, published, exposed, and accepted end to end.

### `find_free_time`

Workflow ID: `dDiqHH9C5clOrYOX`

Status: active, published, exposed, and accepted end to end.

Final post-recovery natural-language regression acceptance passed on 2026-09-09 for both Calendar tools. Detailed evidence is in `docs/CALENDAR_ACCEPTANCE.md`, `docs/FIND_FREE_TIME_ACCEPTANCE.md`, `docs/ACCEPTANCE_TESTS.md`, and `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

## KeyCRM

Provider API base URL:

```text
https://openapi.keycrm.app/v1
```

Credential: `KeyCRM MCP` using Bearer authentication.

KeyCRM remains the source of truth. MCP does not write to KeyCRM.

### Local customer search index

Table:

```text
public.keycrm_customers
```

Stored fields:

- `buyer_id`
- `full_name`
- `phones[]`
- `emails[]`
- `keycrm_updated_at`
- `synced_at`

The local index intentionally excludes full CRM data such as orders, notes, photos, and conversations.

Initial bootstrap workflow:

```text
ADMIN — KeyCRM Customer Index Sync
workflow_id: KP1EPFbemTrxbkcY
```

The accepted bootstrap loaded `24118` unique customers with zero duplicate `buyer_id` values.

Permanent incremental workflow:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
version_id: 9d8018ad-dc25-4747-8ca5-26eeb320a9b3
status: active
schedule: every 15 minutes
```

Incremental sync uses KeyCRM `filter[updated_between]`, pagination with `limit=50`, a `4000 ms` request interval, a two-minute overlap on the previous checkpoint, UPSERT by `buyer_id`, and `public.keycrm_sync_state` for the successful checkpoint.

A real automatic schedule-trigger execution passed on 2026-09-09.

### `search_customers`

Workflow:

```text
MCP — KeyCRM Customer Search
workflow_id: yej0SNKc4Ovb4rzq
version_id: 312b70c0-9f47-4b17-ac9e-5b61e88ebd2f
status: active
```

Inputs:

- `query` — required non-empty string
- `limit` — optional integer, default `10`, range `1..50`

Search supports customer name, partial name, email, phone, and buyer ID.

Search reads use the `mcp_read` n8n credential. The underlying PostgreSQL role `mcp_readonly` has:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

An initial acceptance failure exposed missing `SELECT` permission on the newly created table; only `SELECT` was granted and the workflow then passed.

### `get_customer_details`

Workflow:

```text
MCP — KeyCRM Customer Details
workflow_id: KcrmDetA9V7cQ2Lx
version_id: 9cca4b55-80d3-4be4-b427-2a533eeaefbf
status: active
```

Input:

- `buyer_id` — positive integer

The workflow performs a fresh `GET /buyer/{buyer_id}` request to KeyCRM.

Accepted cases:

- existing buyer -> normalized success
- nonexistent buyer -> `NOT_FOUND`
- invalid buyer ID -> `INVALID_INPUT`
- succeeded/failed audit finalization

## GitHub

Workflow: `MCP — GitHub Read File`

Status: active and exposed.

Missing files normalize to `NOT_FOUND`; other provider failures use `UPSTREAM_ERROR`.

## PostgreSQL content-job tools

Workflow: `MCP — PostgreSQL Recent Jobs`

Status: active and exposed.

Workflow: `MCP — PostgreSQL Job Details`

Status: active and exposed.

Business-read tools use the read-only PostgreSQL credential.

## Security state

- Gmail, GitHub, Drive, Calendar, and KeyCRM credentials remain in n8n credential storage.
- Drive and Calendar use dedicated read-only OAuth scopes.
- KeyCRM MCP workflows expose read-only CRM behavior; internal synchronization writes only to the local PostgreSQL search index.
- PostgreSQL business-read and CRM-search tools use the read-only credential/role.
- The centralized audit workflow and internal synchronization workflows use the write-capable application PostgreSQL credential only for internal infrastructure tables.
- No write-capable business tool is exposed through MCP.
- Sensitive audit arguments are sanitized or explicitly redacted.

## Repository state

Key M3 documentation/migration files:

- `docs/M3_KEYCRM_ACCEPTANCE.md`
- `database/migrations/003_keycrm_customer_index.sql`

M0-M2 workflow exports and acceptance documents remain in the repository.

## Exact next step

Complete the M3 natural-language cross-system customer-context demo through the real MCP client. Only after that passes should M3 be marked complete and work move to M4 controlled writes.
