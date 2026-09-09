# M3 KeyCRM manager analytics acceptance

Last verified: 2026-09-09.

## Scope

This acceptance covers the read-only manager analytics expansion requested after the initial CRM search/details tools:

```text
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

All four workflows are active and published as independent sub-workflows. They are also attached to the aggregate `MCP — Server` tool surface.

## Pipeline-card analytics index

KeyCRM pipeline cards are used for lead/sales analytics. KeyCRM remains the source of truth.

Local table:

```text
public.keycrm_pipeline_cards
```

Stored fields include:

```text
card_id
pipeline_id
source_id
manager_id
status_id
status_alias
status_title
status_is_final
is_finished
closed_from
created_at
updated_at
status_changed_at
payments_total
products_total
utm_source
utm_medium
utm_campaign
synced_at
```

Reference tables:

```text
public.keycrm_pipelines
public.keycrm_sources
public.keycrm_users
```

Observed reassignment history:

```text
public.keycrm_pipeline_assignment_events
public.keycrm_pipeline_tracking_meta
```

The model-facing PostgreSQL credential uses role `mcp_readonly`. Verified permissions on the analytics tables are:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

Internal synchronization uses the write-capable application PostgreSQL credential, but it writes only to local infrastructure tables and never mutates KeyCRM.

## Bootstrap and integrity reconciliation

Workflow:

```text
ADMIN — KeyCRM Pipeline Card Index Bootstrap
workflow_id: KcrmPipelineBootstrapA1
```

Initial bootstrap execution:

```text
execution_id: 16864
status:       success
started_at:   2026-09-09 15:32:07 UTC
stopped_at:   2026-09-09 17:07:26 UTC
```

Because KeyCRM page numbers can shift while a long bootstrap is running, a post-bootstrap count reconciliation was performed against provider-side `created_between` counts. The discrepancy was isolated to August 2026:

```text
provider August count: 5731
local before repair:   5709
difference:              22
```

The missing cards were isolated generically by date range:

```text
2026-08-17: 1 missing
2026-08-20: 21 missing
```

Those exact provider records were fetched and UPSERTed. Final verification at that point:

```text
provider total: 51781
local total:    51781
unique card_id: 51781
```

After the next incremental run, one newly created card was synchronized and both sides reached `51782`.

## Incremental synchronization

Permanent workflow:

```text
ADMIN — KeyCRM Pipeline Card Index Incremental Sync
workflow_id: KcrmPipelineIncrementalA1
status: active
schedule: every 15 minutes
```

Flow:

```text
load last checkpoint
 -> subtract 2-minute overlap
 -> GET /pipelines/cards with filter[updated_between]
 -> paginate with limit=50 and 4000 ms request interval
 -> detect manager/source changes against the previous local snapshot
 -> write observed reassignment events
 -> UPSERT changed cards
 -> advance checkpoint only after successful write
```

Post-restart manual acceptance:

```text
last_count: 3
assignment_events_created: 0
local total: 51782
unique card_id: 51782
```

## `get_manager_sales_stats`

Workflow:

```text
MCP — KeyCRM Manager Sales Stats
workflow_id: KcrmMgrSalesStatsA1
status: active
```

Inputs:

```json
{
  "manager": "Ilona Kamuz",
  "start": "2026-08-01T00:00:00+02:00",
  "end": "2026-09-01T00:00:00+02:00"
}
```

Production acceptance result:

```text
total_leads_raw:                       646
duplicate_leads:                       165
total_leads_excluding_duplicates:      481
successful_sales:                       76
closed_unsuccessful_excluding_duplicates: 381
open_leads_excluding_duplicates:        24
conversion_percent_raw:               11.76
conversion_percent_excluding_duplicates: 15.80
successful_payments_total:         82760
successful_products_total:         83880
```

Duplicate rule:

```text
status_alias = 'dublikaty'
```

Metric basis is explicitly returned: pipeline cards created in the requested period, using current manager assignment and current card status.

## `get_manager_lead_stats`

Workflow:

```text
MCP — KeyCRM Manager Lead Stats
workflow_id: KcrmMgrLeadStatsA1
status: active
```

The same August acceptance window returned:

```text
total_leads_raw:                  646
duplicate_leads:                  165
total_leads_excluding_duplicates: 481
```

Top raw sources included:

```text
vitasschool                  329
registration for the course 212
Телефонія                     86
WhatsApp                       6
Google Forms                   5
Instagram                      3
```

The tool returns both raw and duplicate-excluded source breakdowns, plus pipeline and status breakdowns.

## `get_manager_call_timeline`

Workflow:

```text
MCP — KeyCRM Manager Call Timeline
workflow_id: KcrmMgrCallTimelineA1
status: active
```

Production acceptance for Ilona on 2026-09-09:

```text
total_calls:                    78
average_positive_gap_minutes:  4.5
longest_gap_minutes:          41.2
gaps_over_15_minutes:           6
gaps_over_30_minutes:           1
```

Each returned call includes its start time, calculated end time, duration, type/state, and related lead/client IDs when present. Gaps are calculated from the previous call end to the next call start.

## `get_manager_assignment_history`

Workflow:

```text
MCP — KeyCRM Manager Assignment History
workflow_id: KcrmMgrAssignHistA1
status: active
```

KeyCRM OpenAPI does not expose a historical assignment action log. Therefore old reassignment history is not fabricated.

Tracking begins at:

```text
2026-09-09T18:37:30.384Z
```

The tool returns:

```text
history_mode: observed_snapshots
observation_cadence_minutes: 15
tracking_started_at
requested_interval_after_tracking_start
incoming_assignments
outgoing_assignments
events[]
coverage_note
```

Each event can include old/new manager IDs and names and old/new source IDs and names. Multiple intermediate reassignments occurring entirely between two 15-minute polls can be collapsed into the final observed change; this limitation is explicitly reported.

## Audit acceptance

Latest low-level production calls for all four tools completed successfully:

```text
get_manager_sales_stats        succeeded
get_manager_lead_stats         succeeded
get_manager_assignment_history succeeded
get_manager_call_timeline      succeeded
```

The normal valid-call lifecycle remains:

```text
validate
 -> audit start
 -> provider/database read
 -> normalize
 -> audit finish
 -> return
```

Finish-audit mappings omit `arguments_json`.

## Remaining client-level acceptance

Low-level production acceptance is complete. The remaining check is natural-language selection through the real MCP client for the four new analytics tools. Example prompts:

```text
Какая конверсия у Илоны за август?
Сколько заявок получила Илона в августе и из каких каналов?
Какие заявки переназначили на Илону после начала отслеживания?
Какие перерывы между звонками делает Илона сегодня?
```
