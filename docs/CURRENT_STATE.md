# Current State

Last verified: 2026-09-09.

## Runtime

Production n8n runtime: `2.37.10`.

Production was upgraded from `2.33.3` after a Google Drive HTTP error-output routing defect. A full backup was created before the upgrade and the post-upgrade regression passed.

## MCP gateway

Workflow: `MCP — Server`

```text
workflow_id:       dSohghXnQp078EZm
version_id:        3b70da4f-89b0-4bef-bcc1-dab23aa2d94a
active_version_id: 3b70da4f-89b0-4bef-bcc1-dab23aa2d94a
status:            active
```

Authentication: n8n OAuth2.

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
- `get_manager_customer_stats`
- `get_manager_call_stats`
- `get_manager_sales_stats`
- `get_manager_lead_stats`
- `get_manager_assignment_history`
- `get_manager_call_timeline`

The complete tool surface was re-verified after the latest gateway edit; no previously accepted tool was removed.

## Milestones

- M0 — Foundation: complete
- M1 — Production cleanup: complete
- M2 — Google Workspace expansion: complete
- M3 — CRM integration: in progress; manager analytics deployed and awaiting final natural-language client acceptance for the four newest tools

Detailed Calendar evidence is in `docs/CALENDAR_ACCEPTANCE.md`, `docs/FIND_FREE_TIME_ACCEPTANCE.md`, and `docs/ACCEPTANCE_TESTS.md`.

Detailed KeyCRM evidence is in:

- `docs/M3_KEYCRM_ACCEPTANCE.md`
- `docs/M3_MANAGER_STATS_ACCEPTANCE.md`
- `docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md`

## Normalized MCP contract

Success:

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

Error:

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

Current error codes include `INVALID_INPUT`, `NOT_FOUND`, `AMBIGUOUS_ATTACHMENT`, `AMBIGUOUS_MANAGER`, `UNSUPPORTED_FILE_TYPE`, and `UPSTREAM_ERROR`.

Valid audited calls follow:

```text
validate
-> audit start
-> provider/database read
-> normalize
-> audit finish
-> return original MCP response
```

`INVALID_INPUT` remains pre-audit. Finish-audit calls omit `arguments_json`. Gmail/customer/manager search arguments that may contain PII are redacted.

## KeyCRM architecture

KeyCRM API base URL:

```text
https://openapi.keycrm.app/v1
```

Credential: `KeyCRM MCP` Bearer authentication.

KeyCRM remains the source of truth. No user-facing MCP tool writes to KeyCRM.

### Local customer index

Table:

```text
public.keycrm_customers
```

Minimal stored fields:

- `buyer_id`
- `full_name`
- `phones[]`
- `emails[]`
- `keycrm_updated_at`
- `manager_id`
- `synced_at`

The local index intentionally excludes orders, notes, photos, conversations, and other full CRM data.

Current production snapshot:

```text
total customers:       24226
with manager_id:       21633
without manager_id:     2593
```

Read-only PostgreSQL access uses n8n credential `mcp_read`, backed by role `mcp_readonly`:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

### Customer incremental sync

Workflow:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
status: active
schedule: every 15 minutes
```

It uses KeyCRM `filter[updated_between]`, `limit=50`, pagination, `4000 ms` between pages, a two-minute overlap on the previous successful checkpoint, deduplication by `buyer_id`, and UPSERT into the local index. `manager_id` is synchronized with every changed buyer.

Latest verified customer checkpoint:

```text
2026-09-09 18:45:05.162+00
last_count: 1
```

## KeyCRM manager analytics index

Lead/sales analytics use KeyCRM pipeline cards rather than `/order`.

Main table:

```text
public.keycrm_pipeline_cards
```

Reference tables:

```text
public.keycrm_pipelines
public.keycrm_sources
public.keycrm_users
```

Observed reassignment tracking:

```text
public.keycrm_pipeline_assignment_events
public.keycrm_pipeline_tracking_meta
```

Current verified pipeline-card index:

```text
local rows:       51782
unique card_id:   51782
live KeyCRM count at reconciliation: 51782
```

The initial page-based bootstrap completed successfully but concurrent inserts shifted page boundaries and left 22 historical cards absent from the first local snapshot. Provider/local counts were compared by `created_between`, the discrepancy was isolated to 2026-08-17 and 2026-08-20, and those exact records were fetched and UPSERTed. Final provider/local counts matched before the analytics tools were published.

Permanent incremental workflow:

```text
ADMIN — KeyCRM Pipeline Card Index Incremental Sync
workflow_id: KcrmPipelineIncrementalA1
status: active
schedule: every 15 minutes
```

It reads a checkpoint with a two-minute overlap, requests changed cards with `filter[updated_between]`, detects observed `manager_id`/`source_id` changes, records reassignment events, UPSERTs changed cards, and advances the checkpoint only after a successful local write.

Latest verified post-restart run:

```text
last_count: 3
local rows: 51782
unique card_id: 51782
```

Assignment/source history is only reliable from:

```text
tracking_started_at: 2026-09-09T18:37:30.384Z
```

KeyCRM OpenAPI does not expose the historical assignment action log. The MCP tool explicitly reports this coverage limitation instead of reconstructing unsupported history.

## KeyCRM MCP tools

### `search_customers`

Workflow: `MCP — KeyCRM Customer Search` (`yej0SNKc4Ovb4rzq`).

Searches the synchronized local read-only index by full/partial name, email, phone, or `buyer_id`.

### `get_customer_details`

Workflow: `MCP — KeyCRM Customer Details` (`KcrmDetA9V7cQ2Lx`).

Takes a positive `buyer_id` and performs a fresh `GET /buyer/{buyer_id}`.

### `get_manager_customer_stats`

Workflow: `MCP — KeyCRM Manager Customer Stats` (`KcrmMgrStatsA7pQ4Z`).

The real MCP client natural-language acceptance passed on 2026-09-09. The count is point-in-time and continues to change with CRM assignments; the latest direct database snapshot for manager ID `4` is `3381`.

### `get_manager_call_stats`

Workflow: `MCP — KeyCRM Manager Call Stats` (`KcrmMgrCallStatsA9zQ7P`).

Reads KeyCRM `/calls` for a resolved manager and explicit time window and returns total/incoming/outgoing/finished counts and duration.

### `get_manager_sales_stats`

Workflow: `MCP — KeyCRM Manager Sales Stats` (`KcrmMgrSalesStatsA1`).

Low-level production acceptance for Ilona Kamuz, August 2026:

```text
total_leads_raw:                  646
duplicate_leads:                  165
total_leads_excluding_duplicates: 481
successful_sales:                  76
conversion_percent_raw:           11.76
conversion_percent_excluding_duplicates: 15.80
successful_payments_total:      82760
```

### `get_manager_lead_stats`

Workflow: `MCP — KeyCRM Manager Lead Stats` (`KcrmMgrLeadStatsA1`).

Returns raw and duplicate-excluded lead totals plus source, pipeline, and status breakdowns.

### `get_manager_assignment_history`

Workflow: `MCP — KeyCRM Manager Assignment History` (`KcrmMgrAssignHistA1`).

Returns observed manager/source changes from `tracking_started_at`, with explicit coverage metadata and 15-minute observation cadence.

### `get_manager_call_timeline`

Workflow: `MCP — KeyCRM Manager Call Timeline` (`KcrmMgrCallTimelineA1`).

Low-level acceptance for Ilona on 2026-09-09:

```text
total_calls:                    78
average_positive_gap_minutes:  4.5
longest_gap_minutes:          41.2
gaps_over_15_minutes:           6
gaps_over_30_minutes:           1
```

## Security state

- External credentials stay in n8n credential storage.
- Drive and Calendar use dedicated read-only OAuth scopes.
- KeyCRM user-facing tools perform GET/read operations only.
- Internal synchronization writes only to local PostgreSQL infrastructure tables.
- Business-read tools use the read-only PostgreSQL role.
- No write-capable business tool is exposed through MCP.

## Repository state

Key KeyCRM files include:

- `docs/M3_KEYCRM_ACCEPTANCE.md`
- `docs/M3_MANAGER_STATS_ACCEPTANCE.md`
- `docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md`
- `database/migrations/003_keycrm_customer_index.sql`
- `database/migrations/004_keycrm_manager_id.sql`
- `database/migrations/005_keycrm_manager_analytics.sql`

## Exact next step

Run natural-language MCP-client acceptance for the four newest analytics tools, for example:

```text
Какая конверсия у Илоны за август?
Сколько заявок получила Илона в августе и из каких каналов?
Какие заявки переназначили на Илону после начала отслеживания?
Какие перерывы между звонками делает Илона сегодня?
```

Low-level production workflow acceptance for all four already passes.
