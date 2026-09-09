# KeyCRM production workflow manifest

Last verified: 2026-09-09.

This manifest records the production n8n workflow IDs and published versions for the KeyCRM CRM/manager analytics layer.

## Model-facing workflows

| Tool | Workflow | Workflow ID | Published version | Status |
| --- | --- | --- | --- | --- |
| `search_customers` | MCP — KeyCRM Customer Search | `yej0SNKc4Ovb4rzq` | see current production export/state | active |
| `get_customer_details` | MCP — KeyCRM Customer Details | `KcrmDetA9V7cQ2Lx` | see current production export/state | active |
| `get_manager_customer_stats` | MCP — KeyCRM Manager Customer Stats | `KcrmMgrStatsA7pQ4Z` | `de05e569-d799-4bb4-b504-31d645447c18` | active |
| `get_manager_call_stats` | MCP — KeyCRM Manager Call Stats | `KcrmMgrCallStatsA9zQ7P` | `8d7196e6-3d2f-4b51-9d87-a85517dfb855` | active |
| `get_manager_sales_stats` | MCP — KeyCRM Manager Sales Stats | `KcrmMgrSalesStatsA1` | `0cc586cd-213d-4b6d-acd6-6e987c873e12` | active |
| `get_manager_lead_stats` | MCP — KeyCRM Manager Lead Stats | `KcrmMgrLeadStatsA1` | `40540161-fbea-4d78-8881-f0bcb5714889` | active |
| `get_manager_assignment_history` | MCP — KeyCRM Manager Assignment History | `KcrmMgrAssignHistA1` | `2082a67c-2899-42fa-86ad-9f5766678e3a` | active |
| `get_manager_call_timeline` | MCP — KeyCRM Manager Call Timeline | `KcrmMgrCallTimelineA1` | `e19c483c-a8aa-4875-9def-64a801bb8642` | active |

## Infrastructure workflows

| Workflow | Workflow ID | Published version | Status / cadence |
| --- | --- | --- | --- |
| ADMIN — KeyCRM Customer Index Sync | `KP1EPFbemTrxbkcY` | bootstrap/admin | inactive after bootstrap |
| ADMIN — KeyCRM Customer Index Incremental Sync | `KCIuipW0TTnCMxkY` | see current production state | active / 15 min |
| ADMIN — KeyCRM Pipeline Card Index Bootstrap | `KcrmPipelineBootstrapA1` | bootstrap/admin | inactive after successful bootstrap |
| ADMIN — KeyCRM Pipeline Card Index Incremental Sync | `KcrmPipelineIncrementalA1` | `c99b91b1-b40d-4422-a044-574d2d972d4c` | active / 15 min |
| ADMIN — KeyCRM Analytics Reference Sync | `KcrmAnalyticsRefsA1` | `606c883e-d165-44c4-bb6c-9775bf7288b1` | active / 15 min |

## Aggregate MCP gateway

```text
Workflow:          MCP — Server
Workflow ID:       dSohghXnQp078EZm
Published version: 3b70da4f-89b0-4bef-bcc1-dab23aa2d94a
Status:            active
```

The aggregate gateway currently contains 17 tools. The KeyCRM subset is:

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

## Database migration

Manager analytics schema:

```text
database/migrations/005_keycrm_manager_analytics.sql
```

## Acceptance evidence

```text
docs/M3_KEYCRM_ACCEPTANCE.md
docs/M3_MANAGER_STATS_ACCEPTANCE.md
docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md
```

The pipeline-card index was reconciled against live KeyCRM counts before the four newest analytics tools were exposed through the aggregate MCP gateway.
