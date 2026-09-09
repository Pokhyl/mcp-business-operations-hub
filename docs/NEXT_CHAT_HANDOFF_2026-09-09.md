# Next Chat Handoff — 2026-09-09

## Project

```text
Pokhyl/mcp-business-operations-hub
```

This is an existing production project. Do not restart it or perform a new general architecture audit.

GitHub is the source of truth. If chat history or a VPS checkout disagrees with the connected GitHub repository, trust GitHub.

## Read first

Before continuing, read:

```text
docs/CURRENT_STATE.md
docs/ROADMAP.md
docs/ARCHITECTURE.md
docs/MCP_TOOLS.md
docs/M3_KEYCRM_ACCEPTANCE.md
docs/M3_MANAGER_STATS_ACCEPTANCE.md
docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md
docs/M3_KEYCRM_COMMUNICATIONS_API.md
```

## Production

```text
n8n: https://publisher.hodor.com.pl
runtime: 2.37.10
```

MCP Server:

```text
workflow_id: dSohghXnQp078EZm
active_version: 3b70da4f-89b0-4bef-bcc1-dab23aa2d94a
authentication: n8n OAuth2
status: active
```

Current published MCP tool surface remains 17 tools:

```text
get_github_file
get_recent_jobs
get_job_details
search_emails
get_email_attachment
search_drive_files
read_drive_file
find_free_time
get_calendar_events
search_customers
get_customer_details
get_manager_customer_stats
get_manager_call_stats
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

No MCP workflow/tool was added during the communications investigation.

## Completed milestones

```text
M0 Foundation                 complete
M1 Production cleanup         complete
M2 Google Workspace expansion complete
```

M3 CRM integration remains in progress.

Already deployed and accepted:

```text
search_customers
get_customer_details
get_manager_customer_stats
get_manager_call_stats
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

Natural-language client tests for the four newest manager analytics tools passed on 2026-09-09.

## KeyCRM customer index

Table:

```text
public.keycrm_customers
```

Fields:

```text
buyer_id
full_name
phones[]
emails[]
keycrm_updated_at
manager_id
synced_at
```

Permanent sync:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
schedule: every 15 minutes
```

`search_customers` uses this minimal local index. `get_customer_details` performs a fresh `GET /buyer/{buyer_id}` from KeyCRM.

## KeyCRM manager analytics

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

Observed assignment tracking:

```text
public.keycrm_pipeline_assignment_events
public.keycrm_pipeline_tracking_meta
```

Permanent pipeline-card sync:

```text
ADMIN — KeyCRM Pipeline Card Index Incremental Sync
workflow_id: KcrmPipelineIncrementalA1
schedule: every 15 minutes
```

Assignment history remains snapshot-based from:

```text
tracking_started_at: 2026-09-09T18:37:30.384Z
```

Do not infer historical initiators or pre-tracking assignment history.

## Gmail fix already complete

Workflow:

```text
MCP — Gmail Search
workflow_id: tUxRIiXHh2UaWflF
active_version: 98f525fe-84ed-486b-a013-163b5ad0f778
```

Zero Gmail results now return a normal successful empty response instead of no MCP response.

Gmail search audit query is redacted.

`search_emails` remains an independent Gmail/mailbox tool and must not be removed.

## KeyCRM communications investigation — COMPLETE

Do **not** repeat a long investigation of whether the current public KeyCRM OpenAPI exposes CRM-native communication history. This was completed on 2026-09-09 and is documented in:

```text
docs/M3_KEYCRM_COMMUNICATIONS_API.md
```

Result:

```text
official public OpenAPI communications read endpoint: NOT AVAILABLE
official buyer communications include:              NOT AVAILABLE
official chat/message webhook event:                 NOT AVAILABLE
```

The exact OpenAPI document loaded by `https://docs.keycrm.app/` was inspected. It contains no documented communications/chats/messages/conversations resource.

`GET /buyer/{buyerId}` documents only these includes:

```text
manager
shipping
company
loyalty
custom_fields
```

The official outgoing webhook documentation currently exposes only:

```text
order.change_order_status
order.change_payment_status
lead.change_lead_status
```

KeyCRM UI does have chats and multi-channel communication, but UI visibility is not evidence of public API support.

## Required architecture boundary

Generic request:

```text
"show communication/history with this customer"
```

must **not** silently become:

```text
customer email -> Gmail
```

Correct current semantics:

```text
explicit Gmail/mailbox request
-> search_emails
-> Gmail

CRM-native communication/history request
-> current public KeyCRM API cannot supply it
-> report provider limitation
```

Do not:

- invent `/messages`, `/chats`, or other guessed endpoints;
- scrape the KeyCRM UI;
- use private/internal UI endpoints as production architecture without a separate explicit decision;
- fabricate CRM communication content;
- silently treat Gmail as KeyCRM-native history.

## M3 status and exact next decision

M3 is intentionally still open.

The communications API research itself is done. `get_customer_communications` was not implemented because there is no supported provider operation behind it.

Do not start M4 yet.

The next project decision is one of these:

1. keep M3 open until keyCRM publishes a supported communications read API; or
2. explicitly accept the documented provider limitation as the M3 closure condition, then update the milestone status and only afterward proceed to M4.

Do not make that closure decision by silently introducing a private API workaround.

If keyCRM later publishes an official stable communications API, then the next implementation should follow the normal read-only path:

```text
validate
-> audit start
-> official KeyCRM GET/read operation
-> normalize
-> audit finish
-> return
```

with pagination, ambiguity handling, PII-redacted audit fields, and full MCP Server surface verification after integration.

## General production rules

- KeyCRM remains source of truth.
- User-facing CRM tools remain read-only.
- Internal sync may write only to local PostgreSQL infrastructure tables.
- PostgreSQL model-facing credential `mcp_read` maps to role `mcp_readonly`.
- `mcp_readonly` must remain SELECT-only.
- `INVALID_INPUT` stays pre-audit.
- Finish-audit mappings omit `arguments_json` entirely.
- Do not weaken security/read-only gates.
- Do not remove existing MCP tools.
- After any future MCP Server change, verify the complete tool surface.
- After any production workflow change: inspect -> modify -> deploy/publish -> health -> low-level test -> audit check -> natural-language E2E when relevant -> export exact production workflow -> sync GitHub.
- Do not leave production newer than GitHub.
- Do not trust the stale dirty local VPS checkout over connected GitHub.
