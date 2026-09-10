# M3 KeyCRM acceptance

Last verified: 2026-09-10.

Status: COMPLETE.

## Scope

M3 provides read-only CRM integration through KeyCRM while preserving the project rule that model-facing business tools do not mutate business systems.

KeyCRM remains the source of truth. Local PostgreSQL tables are used only for search/analytics support where repeated live provider scans would be impractical.

## Provider boundary

KeyCRM API base URL:

```text
https://openapi.keycrm.app/v1
```

Authentication uses the n8n Bearer credential `KeyCRM MCP`.

Current model-facing KeyCRM workflows use GET/read operations only. Internal synchronization writes only to local PostgreSQL infrastructure tables.

The documented KeyCRM API limit remains 20 requests per minute; bootstrap and pagination paths are paced below that limit.

## Customer search and details acceptance

Customer search index:

```text
public.keycrm_customers
```

Minimal indexed fields:

```text
buyer_id
full_name
phones[]
emails[]
keycrm_updated_at
manager_id
synced_at
```

Model-facing PostgreSQL credential:

```text
credential: mcp_read
role:       mcp_readonly
```

Verified business-read boundary:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

Permanent customer synchronization:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
schedule: every 15 minutes
```

Accepted model-facing tools:

```text
search_customers
get_customer_details
```

`search_customers` supports natural customer lookup by full/partial name, email, phone, and buyer ID through the minimal local index.

`get_customer_details` performs a fresh provider read:

```text
GET /buyer/{buyer_id}
```

Accepted errors include `INVALID_INPUT`, `NOT_FOUND`, and `UPSTREAM_ERROR` according to the shared normalized MCP contract.

## Manager analytics acceptance

Accepted deployed tools:

```text
get_manager_customer_stats
get_manager_call_stats
get_manager_sales_stats
get_manager_lead_stats
get_manager_assignment_history
get_manager_call_timeline
```

Manager analytics uses synchronized KeyCRM pipeline/customer data and fresh KeyCRM call reads as documented in:

```text
docs/M3_MANAGER_STATS_ACCEPTANCE.md
docs/M3_MANAGER_ANALYTICS_ACCEPTANCE.md
```

The initial pipeline-card bootstrap discrepancy caused by shifting provider page boundaries was reconciled, including recovery of the 22 missing historical cards before analytics acceptance.

Natural-language MCP-client acceptance for the manager analytics tools passed on 2026-09-09.

## Assignment-history limitation

KeyCRM OpenAPI does not expose the historical Action History used by the UI.

Therefore `get_manager_assignment_history` intentionally uses observed snapshots beginning at:

```text
2026-09-09T18:37:30.384Z
```

The tool does not fabricate historical initiators or reconstruct unsupported history before that boundary.

## Gmail regression fix included in final M3 context work

`search_emails` remains a separate Gmail capability.

A real final-context test exposed a zero-result defect where Gmail returned no MCP response. Production was fixed so zero matches now return:

```json
{
  "success": true,
  "data": [],
  "meta": {
    "count": 0
  }
}
```

The Gmail search query is redacted in audit start.

## CRM-native communications investigation

The project explicitly investigated whether communication history visible in the KeyCRM UI can be read through an official, stable public API.

Result:

```text
public OpenAPI communications read endpoint: NOT AVAILABLE
buyer communications include:              NOT AVAILABLE
chat/message webhook event:                 NOT AVAILABLE
```

The current official KeyCRM OpenAPI v1.2.0 contains no documented communications/chats/messages/conversations resource.

`GET /buyer/{buyerId}` documents only these includes:

```text
manager
shipping
company
loyalty
custom_fields
```

The documented outgoing webhook surface exposes order/payment/lead-status events, not chat/message events.

No guessed `/messages` or `/chats` endpoint was used, and no private/internal KeyCRM UI endpoint or scraping path was introduced.

Detailed evidence:

```text
docs/M3_KEYCRM_COMMUNICATIONS_API.md
```

## M3 closure decision

On 2026-09-10 the project explicitly accepted the absence of a supported KeyCRM communications API as a provider limitation and closed M3.

`get_customer_communications` is therefore **not an incomplete M3 implementation**. It is intentionally not implemented because the current supported provider interface cannot supply that data.

The accepted production behavior is:

```text
explicit Gmail/mailbox question
-> search_emails
-> Gmail

CRM-native communication/history question
-> current public KeyCRM API cannot supply it
-> report provider limitation
```

The system must not silently substitute Gmail for KeyCRM-native history and must not use private/guessed provider interfaces without a separate future architecture/security decision.

## Aggregate MCP acceptance

Production aggregate workflow:

```text
MCP — Server
workflow_id: dSohghXnQp078EZm
active_version_id: 3b70da4f-89b0-4bef-bcc1-dab23aa2d94a
status: active
```

Current published tool surface remains 17 tools. No tool was added or removed as part of the communications limitation/closure decision.

## Final M3 result

```text
M3 CRM integration: COMPLETE
closure date:       2026-09-10
```

M4 Controlled Writes is now unblocked but remains not started.
