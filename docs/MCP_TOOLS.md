# MCP Tools

Production acceptance cases and regression rules for the current tool surface are documented in `docs/ACCEPTANCE_TESTS.md`. KeyCRM M3 evidence is in `docs/M3_KEYCRM_ACCEPTANCE.md`, `docs/M3_MANAGER_STATS_ACCEPTANCE.md`, and `docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md`.

All model-facing tools are read-only unless explicitly documented otherwise. No write-capable business tool is currently exposed through MCP.

## Gmail

### `search_emails`

Purpose: search Gmail and return normalized matching messages.

Inputs:

```json
{
  "query": "string",
  "limit": 5
}
```

Output per message includes `id`, `threadId`, `from`, `to`, `subject`, `date`, and `body`.

Audit note: the Gmail query is used for the provider request but stored as `[REDACTED]` in audit `arguments_json`.

### `get_email_attachment`

Purpose: retrieve an attachment from a Gmail message without requiring the user to know Gmail's internal attachment ID.

Inputs:

```json
{
  "message_id": "string",
  "filename": "optional string"
}
```

When one normal attachment exists, it is selected automatically. If multiple attachments exist, the tool returns safe attachment metadata so the caller can retry with `filename`.

Possible normalized errors include `NOT_FOUND`, `AMBIGUOUS_ATTACHMENT`, and `UPSTREAM_ERROR`.

## Google Drive

### `search_drive_files`

Purpose: search the connected Google Drive by filename or full-text content.

Inputs:

```json
{
  "query": "string",
  "limit": 10
}
```

Rules:

- `query` must be a non-empty natural search term.
- `limit` defaults to `10` and must be `1..50`.
- trashed files are excluded.

Access: dedicated OAuth credential with `https://www.googleapis.com/auth/drive.readonly`.

### `read_drive_file`

Purpose: read textual contents of a Google Drive file by `file_id`.

Input:

```json
{
  "file_id": "string"
}
```

Supported paths:

```text
Google Docs   -> text/plain export
Google Sheets -> text/csv export
Google Slides -> text/plain export
PDF           -> media download + text extraction
text files    -> media download
```

Text is capped at `50000` characters with explicit truncation metadata.

## GitHub / PostgreSQL project reads

### `get_github_file`

Purpose: read a text file from the configured project repository.

Input:

```json
{
  "path": "docs/CURRENT_STATE.md"
}
```

### `get_recent_jobs`

Purpose: inspect recent production content jobs.

```json
{
  "limit": 10
}
```

### `get_job_details`

Purpose: inspect one content job in detail.

```json
{
  "job_id": "uuid"
}
```

## Google Calendar

### `get_calendar_events`

Workflow: `MCP — Calendar Events` (`IUpcFPRH3xOVbgEq`).

Purpose: read calendar events in an explicit time window.

Inputs:

```json
{
  "start": "2026-09-01T00:00:00+02:00",
  "end": "2026-10-01T00:00:00+02:00",
  "calendar_id": "primary",
  "limit": 50
}
```

Rules:

- RFC3339 timestamps with timezone;
- `end > start`;
- `calendar_id` defaults to `primary`;
- recurring events are expanded and sorted by start time.

### `find_free_time`

Workflow: `MCP — Find Free Time` (`dDiqHH9C5clOrYOX`).

Purpose: return maximal free windows that fit a requested minimum duration.

Inputs:

```json
{
  "start": "2026-09-09T09:00:00+02:00",
  "end": "2026-09-09T18:00:00+02:00",
  "duration_minutes": 60,
  "calendar_id": "primary"
}
```

Both Calendar tools use the dedicated read-only OAuth credential with `https://www.googleapis.com/auth/calendar.readonly`.

## KeyCRM customer tools

### `search_customers`

Workflow: `MCP — KeyCRM Customer Search` (`yej0SNKc4Ovb4rzq`).

Purpose: identify customers by full/partial name, email, phone, or buyer ID using the synchronized minimal PostgreSQL index.

Inputs:

```json
{
  "query": "string",
  "limit": 10
}
```

Rules:

- `query` must be non-empty;
- `limit` defaults to `10` and must be `1..50`;
- search runs against `public.keycrm_customers`;
- KeyCRM remains the source of truth.

Access: n8n credential `mcp_read`, backed by PostgreSQL role `mcp_readonly`.

Audit note: customer query text is stored as `[REDACTED]`.

### `get_customer_details`

Workflow: `MCP — KeyCRM Customer Details` (`KcrmDetA9V7cQ2Lx`).

Purpose: retrieve a fresh KeyCRM buyer record after search identifies `buyer_id`.

Input:

```json
{
  "buyer_id": 12345
}
```

The workflow performs a fresh read from:

```text
GET /buyer/{buyer_id}
```

Errors:

```text
invalid buyer ID -> INVALID_INPUT
missing buyer    -> NOT_FOUND
other API error  -> UPSTREAM_ERROR
```

### `get_manager_customer_stats`

Workflow: `MCP — KeyCRM Manager Customer Stats` (`KcrmMgrStatsA7pQ4Z`).

Purpose: count customers currently assigned to a manager.

Input:

```json
{
  "manager": "Анастасия Быкова"
}
```

Manager resolution reads active KeyCRM users and supports Cyrillic/Latin transliteration-aware matching. The count is read from `public.keycrm_customers` by `manager_id` through the read-only PostgreSQL credential.

Natural-language MCP-client acceptance passed on 2026-09-09.

### `get_manager_call_stats`

Workflow: `MCP — KeyCRM Manager Call Stats` (`KcrmMgrCallStatsA9zQ7P`).

Purpose: get aggregate KeyCRM call statistics for a manager in an explicit time window.

Inputs:

```json
{
  "manager": "Ilona Kamuz",
  "start": "2026-09-09T00:00:00+02:00",
  "end": "2026-09-10T00:00:00+02:00"
}
```

Returns total, incoming, outgoing, finished/unfinished calls and total duration. Maximum window: 31 days.

## KeyCRM manager analytics

### `get_manager_sales_stats`

Workflow: `MCP — KeyCRM Manager Sales Stats` (`KcrmMgrSalesStatsA1`).

Purpose: answer manager sales/conversion questions over an explicit period.

Inputs:

```json
{
  "manager": "Ilona Kamuz",
  "start": "2026-08-01T00:00:00+02:00",
  "end": "2026-09-01T00:00:00+02:00"
}
```

Maximum window: 366 days.

Returns:

```text
total_leads_raw
duplicate_leads
total_leads_excluding_duplicates
successful_sales
closed_unsuccessful_excluding_duplicates
open_leads_excluding_duplicates
conversion_percent_raw
conversion_percent_excluding_duplicates
successful_payments_total
successful_products_total
```

Duplicate rule:

```text
status_alias = 'dublikaty'
```

Metric basis is explicitly returned: pipeline cards created in the requested period, using current manager assignment and current card status.

### `get_manager_lead_stats`

Workflow: `MCP — KeyCRM Manager Lead Stats` (`KcrmMgrLeadStatsA1`).

Purpose: answer questions about lead volume and channels/sources for a manager over an explicit period.

Inputs: same `manager`, `start`, `end` contract as `get_manager_sales_stats`.

Returns:

```text
total_leads_raw
duplicate_leads
total_leads_excluding_duplicates
by_source_raw[]
by_source_excluding_duplicates[]
by_pipeline[]
by_status[]
```

The source breakdown uses synchronized KeyCRM source names rather than exposing only numeric IDs.

### `get_manager_assignment_history`

Workflow: `MCP — KeyCRM Manager Assignment History` (`KcrmMgrAssignHistA1`).

Purpose: answer questions about observed leads reassigned to/from a manager or source changes.

Inputs:

```json
{
  "manager": "Ilona Kamuz",
  "start": "2026-09-09T20:37:31+02:00",
  "end": "2026-09-10T00:00:00+02:00"
}
```

Maximum window: 366 days.

Important limitation: KeyCRM OpenAPI does not expose the historical assignment action log. The system observes `manager_id`/`source_id` differences during permanent 15-minute pipeline-card synchronization.

The tool therefore returns explicit coverage metadata:

```text
tracking_started_at
requested_interval_after_tracking_start
history_mode = observed_snapshots
observation_cadence_minutes = 15
coverage_note
```

Events can include old/new manager IDs/names and old/new source IDs/names. Earlier unsupported history is never fabricated.

### `get_manager_call_timeline`

Workflow: `MCP — KeyCRM Manager Call Timeline` (`KcrmMgrCallTimelineA1`).

Purpose: answer detailed questions about when a manager called and how long the gaps/breaks between calls were.

Inputs:

```json
{
  "manager": "Ilona Kamuz",
  "start": "2026-09-09T00:00:00+02:00",
  "end": "2026-09-10T00:00:00+02:00"
}
```

Maximum window: 31 days.

Returns individual calls and calculated gaps, plus:

```text
average_positive_gap_minutes
longest_gap_minutes
gaps_over_15_minutes
gaps_over_30_minutes
```

Each gap is calculated from the previous call's calculated end time to the next call's start time.

## Internal CRM synchronization

Infrastructure workflows, not MCP tools:

```text
ADMIN — KeyCRM Customer Index Sync
ADMIN — KeyCRM Customer Index Incremental Sync
ADMIN — KeyCRM Pipeline Card Index Bootstrap
ADMIN — KeyCRM Pipeline Card Index Incremental Sync
ADMIN — KeyCRM Analytics Reference Sync
```

Customer and pipeline incremental workflows run every 15 minutes. Provider pagination is rate-limited and successful checkpoints are stored in `public.keycrm_sync_state`.

Pipeline-card synchronization also records observed manager/source changes into `public.keycrm_pipeline_assignment_events` after the documented tracking boundary.

Detailed manager analytics evidence is in `docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md`.

## Write tools — future separate approval class

Examples:

- `send_email`
- `create_calendar_event`
- `update_customer`

Write tools must remain a separate class with explicit approval and idempotency protection where applicable.
