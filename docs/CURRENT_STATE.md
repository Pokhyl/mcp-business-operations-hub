# Current State

Last verified: 2026-09-10.

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

Total: 17 tools.

No gateway/workflow change was required to close M3 on 2026-09-10. The KeyCRM communications investigation established a provider limitation rather than an implementation defect.

## Milestones

```text
M0 Foundation                 complete
M1 Production cleanup         complete
M2 Google Workspace expansion complete
M3 CRM integration            complete
M4 Controlled writes          deferred / not started
M5 Portfolio hardening        not started
```

M3 was explicitly closed on 2026-09-10 with the current KeyCRM communications limitation accepted as a provider boundary.

On 2026-09-10 the user explicitly decided to close KeyCRM work for now and leave M4/write integrations for later. Therefore no further KeyCRM development, OAuth/write-scope changes, Gmail/Calendar writes, or CRM write tools should be started unless the user explicitly resumes that scope.

The accepted M3 scope includes deployed read-only CRM customer search/details, manager customer/call statistics, sales/lead analytics, observed reassignment history, and call timeline. The existing CRM tools passed low-level and natural-language acceptance where applicable.

## M3 communications closure decision

The current official KeyCRM OpenAPI v1.2.0 does not expose a supported read resource for CRM-native communications/chats/messages/conversations.

The investigation established:

```text
public communications read endpoint: NOT AVAILABLE
buyer communications include:        NOT AVAILABLE
chat/message webhook event:           NOT AVAILABLE
```

`GET /buyer/{buyerId}` documents only these includes:

```text
manager
shipping
company
loyalty
custom_fields
```

The official outgoing webhook documentation currently exposes order/payment/lead-status events, not chat/message events.

Therefore `get_customer_communications` is intentionally not implemented. This is an accepted provider limitation for M3 closure, not an incomplete implementation item.

Required semantics remain:

```text
explicit Gmail/mailbox request
-> search_emails
-> Gmail

CRM-native communication/history request
-> current public KeyCRM API cannot supply it
-> report provider limitation
```

Do not silently substitute Gmail for KeyCRM-native history. Do not invent `/messages`, `/chats`, scrape the UI, or use private/internal KeyCRM endpoints as production architecture without a separate explicit architecture/security decision.

Evidence:

```text
docs/M3_KEYCRM_COMMUNICATIONS_API.md
docs/M3_KEYCRM_ACCEPTANCE.md
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
- Current user-facing CRM tools are read-only.

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

Verified business-read permissions remain:

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

The full bootstrap was reconciled against KeyCRM after shifting page boundaries caused 22 historical cards to be missed. The exact missing records were recovered and provider/local totals matched before manager analytics acceptance.

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

KeyCRM UI stores an Action History, but the public KeyCRM OpenAPI does not expose the historical assignment action log used by the UI.

`get_manager_assignment_history` therefore remains snapshot-based from:

```text
tracking_started_at: 2026-09-09T18:37:30.384Z
```

It must not claim to know the historical initiator of a reassignment or reconstruct unsupported history before the tracking boundary.

## Gmail search

Workflow:

```text
MCP — Gmail Search
workflow_id: tUxRIiXHh2UaWflF
active_version_id: 98f525fe-84ed-486b-a013-163b5ad0f778
status: active
```

Zero-result behavior is fixed: Gmail returning no messages now produces `success=true`, `data=[]`, `count=0` rather than no MCP response.

The Gmail search query in audit start is stored as `[REDACTED]`.

Production export:

```text
n8n/gmail/SEARCH_EMAILS.json
```

`search_emails` remains a valid independent Gmail capability.

## Security state

- External credentials remain in n8n credential storage.
- Drive and Calendar use dedicated read-only OAuth scopes.
- Current KeyCRM user-facing tools use GET/read operations only.
- Internal synchronization writes only to local PostgreSQL infrastructure tables.
- Business-read tools use `mcp_readonly`.
- No unsupported KeyCRM communications endpoint was introduced.
- No M4 write credential/scope changes have been made.

## Repository evidence

Key files:

```text
docs/ROADMAP.md
docs/ARCHITECTURE.md
docs/MCP_TOOLS.md
docs/M3_KEYCRM_ACCEPTANCE.md
docs/M3_MANAGER_STATS_ACCEPTANCE.md
docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md
docs/M3_KEYCRM_COMMUNICATIONS_API.md
docs/NEXT_CHAT_HANDOFF_2026-09-10.md
database/migrations/003_keycrm_customer_index.sql
database/migrations/004_keycrm_manager_id.sql
database/migrations/005_keycrm_manager_analytics.sql
n8n/gmail/SEARCH_EMAILS.json
```

## Exact next step

There is no active KeyCRM/M4 implementation step.

M3 is complete and KeyCRM work is closed for now. M4 Controlled Writes remains planned but is explicitly deferred by the user.

Do not automatically start credential/scope changes, `send_email`, `create_calendar_event`, or a KeyCRM write operation in a future chat. Resume M4 only after an explicit user instruction.

When M4 is resumed, first verify the actual production OAuth scopes/credentials separately from API capability. Existing read-only credentials must not be silently broadened.

If KeyCRM later publishes an official stable customer-communications read API, that capability can be considered as a separate future enhancement without invalidating the completed M3 milestone.
