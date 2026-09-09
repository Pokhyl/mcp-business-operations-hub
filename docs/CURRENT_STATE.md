# Current State

Last verified: 2026-09-09.

## Runtime

Production n8n runtime: `2.37.10`.

Production n8n:

```text
https://publisher.hodor.com.pl
```

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

```text
get_github_file
get_recent_jobs
get_job_details
search_emails
get_email_attachment
search_drive_files
read_drive_file
get_calendar_events
find_free_time
search_customers
get_customer_details
get_manager_customer_stats
get_manager_call_stats
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

The complete tool surface was re-verified after the latest gateway edit; no previously accepted tool was removed.

## Milestones

```text
M0 Foundation                 complete
M1 Production cleanup         complete
M2 Google Workspace expansion complete
M3 CRM integration            in progress
M4 Controlled writes          not started
M5 Portfolio hardening        not started
```

M3 CRM search/details, customer/manager counts, call statistics, sales/lead analytics, observed reassignment history, and call timeline are already deployed. The newest four manager analytics tools passed natural-language MCP-client acceptance on 2026-09-09.

M3 is NOT closed yet because the final customer-context architecture must use KeyCRM-native customer communications where supported rather than treating Gmail as the primary communication history.

Detailed continuation instructions are in:

```text
docs/NEXT_CHAT_HANDOFF_2026-09-09.md
```

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

Valid audited calls follow:

```text
validate
-> audit start
-> provider/database read
-> normalize
-> audit finish
-> return original MCP response
```

Rules:

- `INVALID_INPUT` remains pre-audit.
- Finish-audit mappings omit `arguments_json` completely.
- Sensitive Gmail/customer/manager search inputs are redacted.
- No user-facing MCP tool currently writes to KeyCRM.

## KeyCRM customer index

KeyCRM remains the source of truth.

Table:

```text
public.keycrm_customers
```

Minimal fields:

```text
buyer_id
full_name
phones[]
emails[]
keycrm_updated_at
manager_id
synced_at
```

Permanent customer sync:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
status: active
schedule: every 15 minutes
```

`search_customers` uses the local index for natural name/email/phone/ID lookup. `get_customer_details` performs a fresh KeyCRM GET after a `buyer_id` is known.

Read-only PostgreSQL access uses credential `mcp_read`, backed by role `mcp_readonly`.

For business-read tables the verified boundary remains:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

## KeyCRM manager analytics

Pipeline-card analytics use:

```text
public.keycrm_pipeline_cards
public.keycrm_pipelines
public.keycrm_sources
public.keycrm_users
```

Observed assignment tracking uses:

```text
public.keycrm_pipeline_assignment_events
public.keycrm_pipeline_tracking_meta
```

Permanent pipeline-card sync:

```text
ADMIN — KeyCRM Pipeline Card Index Incremental Sync
workflow_id: KcrmPipelineIncrementalA1
status: active
schedule: every 15 minutes
```

The full bootstrap was reconciled against KeyCRM after shifting page boundaries caused 22 historical cards to be missed. The exact missing records were recovered and provider/local totals matched before the manager analytics tools were published.

Natural-language accepted manager tools:

```text
get_manager_customer_stats
get_manager_call_stats
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

Accepted August 2026 example for Ilona Kamuz:

```text
total_leads_raw:                  646
duplicate_leads:                  165
total_leads_excluding_duplicates: 481
successful_sales:                  76
conversion_percent_raw:           11.76
conversion_percent_excluding_duplicates: 15.80
successful_payments_total:      82760
```

Accepted call-timeline example:

```text
total_calls:                    78
average_positive_gap_minutes:  4.5
longest_gap_minutes:          41.2
gaps_over_15_minutes:           6
gaps_over_30_minutes:           1
```

## Assignment-history limitation

KeyCRM UI stores an Action History, but the public KeyCRM OpenAPI does not currently expose the historical assignment action log used by the UI.

Therefore `get_manager_assignment_history` is deliberately snapshot-based. It observes manager/source changes every 15 minutes from:

```text
tracking_started_at: 2026-09-09T18:37:30.384Z
```

It does not claim to know the historical initiator of a reassignment or reconstruct unsupported history before the tracking boundary.

## Gmail search fix

Workflow:

```text
MCP — Gmail Search
workflow_id: tUxRIiXHh2UaWflF
active_version_id: 98f525fe-84ed-486b-a013-163b5ad0f778
status: active
```

A real cross-system test exposed a zero-result defect: when Gmail returned zero messages, the workflow emitted no MCP response.

Production fix:

```text
Get many messages (alwaysOutputData=true)
-> Has messages?
   true  -> Get a message -> normal response
   false -> success=true, data=[], count=0
```

The Gmail search query in audit start is now stored as `[REDACTED]`.

Current production export is synchronized to:

```text
n8n/gmail/SEARCH_EMAILS.json
```

`search_emails` reads the connected Gmail mailbox directly. It remains a valid independent Gmail tool.

## Customer communications architecture — important

The previous intended final M3 demo was:

```text
search_customers
-> get_customer_details
-> take email
-> search_emails
-> combine CRM + Gmail
```

That is not the correct default for a request such as `show the communication/history with this customer` because KeyCRM itself contains customer communication history, including email and other connected channels in the CRM UI.

Correct architectural direction:

```text
customer communication/history request
-> resolve customer in KeyCRM
-> read KeyCRM-native communications first, if supported by an official/stable API
-> use Gmail only for explicit Gmail/mailbox questions or as an additional source when requested
```

Do not assume that because the KeyCRM UI shows messages, the public API necessarily exposes them. The next step must verify supported API access first.

## Security state

- External credentials remain in n8n credential storage.
- Drive and Calendar use dedicated read-only OAuth scopes.
- Current KeyCRM user-facing tools use GET/read operations only.
- Internal synchronization writes only to local PostgreSQL infrastructure tables.
- Business-read tools use `mcp_readonly`.
- No write-capable business tool is exposed through MCP.

## Repository evidence

Key files:

```text
docs/ROADMAP.md
docs/ARCHITECTURE.md
docs/MCP_TOOLS.md
docs/M3_KEYCRM_ACCEPTANCE.md
docs/M3_MANAGER_STATS_ACCEPTANCE.md
docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md
docs/NEXT_CHAT_HANDOFF_2026-09-09.md
database/migrations/003_keycrm_customer_index.sql
database/migrations/004_keycrm_manager_id.sql
database/migrations/005_keycrm_manager_analytics.sql
n8n/gmail/SEARCH_EMAILS.json
```

## Exact next step

Before closing M3, research the current official KeyCRM API and verify with safe GET-only probes whether customer communications stored in KeyCRM are accessible through a supported stable interface, including emails/chats/messages and their relation to buyer/lead IDs.

If supported, implement a universal read-only customer-communications tool and then rerun the final natural-language customer-context demo with KeyCRM communications as the primary source.

If not supported, document the limitation explicitly before considering any other architecture.
