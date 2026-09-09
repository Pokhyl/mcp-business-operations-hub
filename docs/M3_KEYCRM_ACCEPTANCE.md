# M3 KeyCRM acceptance

Last verified: 2026-09-09.

## Scope

M3 adds read-only CRM access through KeyCRM while preserving the project rule that MCP tools do not mutate business systems.

KeyCRM remains the source of truth. A local PostgreSQL customer index is used only to make natural customer search practical, because the KeyCRM `/buyer` API does not support a general name search filter.

## Provider boundary

KeyCRM API base URL:

```text
https://openapi.keycrm.app/v1
```

Authentication uses the n8n Bearer credential `KeyCRM MCP`.

The customer-facing MCP workflows use GET requests only. The synchronization workflow writes only to the local PostgreSQL index and never writes to KeyCRM.

The documented KeyCRM API limit is 20 requests per minute. Bootstrap and pagination are paced below that limit.

## Local search index

Table:

```text
public.keycrm_customers
```

Stored fields are intentionally minimal:

- `buyer_id`
- `full_name`
- `phones[]`
- `emails[]`
- `keycrm_updated_at`
- `synced_at`

The index does not store orders, notes, photos, conversations, or other full CRM data.

Search reads use the `mcp_read` n8n credential, which maps to PostgreSQL role `mcp_readonly`.

Verified permissions after M3 setup:

```text
SELECT = true
INSERT = false
UPDATE = false
DELETE = false
```

An initial acceptance failure exposed that `mcp_readonly` did not yet have `SELECT` on the newly created `keycrm_customers` table. The query failed with `permission denied for table keycrm_customers`. The defect was fixed by granting only `SELECT`; write permissions remain denied.

## Bootstrap

Workflow:

```text
ADMIN — KeyCRM Customer Index Sync
workflow_id: KP1EPFbemTrxbkcY
```

The bootstrap avoids unstable page-number scanning. It:

```text
Get latest buyer
 -> build buyer_id ranges of 50
 -> Loop Over Items
 -> GET /buyer?filter[buyer_id]=...
 -> normalize
 -> UPSERT local index
 -> wait 4 seconds
 -> next range
```

The first full bootstrap execution completed successfully:

```text
execution_id: 16711
status:       success
rows:         24118
unique IDs:   24118
duplicates:   0
```

## Incremental synchronization

Workflow:

```text
ADMIN — KeyCRM Customer Index Incremental Sync
workflow_id: KCIuipW0TTnCMxkY
version_id: 9d8018ad-dc25-4747-8ca5-26eeb320a9b3
status: active
```

Schedule:

```text
every 15 minutes
```

KeyCRM's allowed `updated_between` filter was verified against the real account. The accepted format is a comma-separated RFC3339 range:

```text
filter[updated_between]=<from>,<to>
```

A real probe returned 57 changed buyers across two pages:

```text
page 1: 50
page 2: 7
```

The production workflow uses:

- `limit=50`
- HTTP Request pagination on `page`
- `4000 ms` between pages
- a two-minute overlap before the previous checkpoint to avoid boundary misses
- deduplication by `buyer_id` before UPSERT
- one PostgreSQL statement that applies changes and advances the checkpoint only after the data write succeeds

Checkpoint table:

```text
public.keycrm_sync_state
```

Automatic trigger acceptance passed:

```text
execution_id: 16742
mode:         trigger
status:       success
changed:      11
```

During acceptance, the local index advanced from the bootstrap state to 24170 unique customers as new/updated KeyCRM records were synchronized.

## `search_customers`

Workflow:

```text
MCP — KeyCRM Customer Search
workflow_id: yej0SNKc4Ovb4rzq
version_id: 312b70c0-9f47-4b17-ac9e-5b61e88ebd2f
status: active
```

Inputs:

```json
{
  "query": "string",
  "limit": 10
}
```

`query` supports:

- exact or partial customer name
- email
- phone
- `buyer_id`

`limit` defaults to 10 and must be an integer from 1 to 50.

Search is executed against `public.keycrm_customers` with the read-only PostgreSQL credential. Name matching uses exact/prefix/substring ranking plus `pg_trgm` similarity. Email and phone matching are normalized inside SQL.

The audit start stores the customer query as `[REDACTED]` because it may contain PII.

Accepted production workflow call:

```text
status: succeeded
duration_ms: 363
```

Invalid input is rejected before audit/provider access.

## `get_customer_details`

Workflow:

```text
MCP — KeyCRM Customer Details
workflow_id: KcrmDetA9V7cQ2Lx
version_id: 9cca4b55-80d3-4be4-b427-2a533eeaefbf
status: active
```

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

It returns current KeyCRM customer/contact data rather than relying on the local index for full details.

Acceptance:

- existing buyer -> `success=true`, `count=1`
- nonexistent buyer -> `NOT_FOUND`
- invalid `buyer_id` -> `INVALID_INPUT`
- success audit finalized as `succeeded`
- provider 404 audit finalized as `failed`, `error_code=NOT_FOUND`

Observed audit examples:

```text
succeeded duration_ms=331
failed    error_code=NOT_FOUND
```

`Audit success` and `Audit failed` omit `arguments_json` entirely, matching the centralized audit contract.

## MCP Server integration

Aggregate workflow:

```text
MCP — Server
workflow_id: dSohghXnQp078EZm
```

The current published tool surface contains 17 tools and includes all accepted M0-M3 read tools. The communications investigation made no MCP Server change, so no tool was added or removed during that work.

## CRM-native communications investigation

The final customer-context demo exposed that a generic request for `communication/history with this customer` must not be implemented as `customer -> email -> Gmail` by default. KeyCRM itself contains multi-channel communication history in its UI.

The supported-interface investigation was completed on 2026-09-09 against the current official KeyCRM OpenAPI documentation and the exact `api.yaml` loaded by that documentation.

Result:

```text
public OpenAPI communications read endpoint: NOT AVAILABLE
buyer communications include:              NOT AVAILABLE
chat/message webhook event:                 NOT AVAILABLE
```

The current public OpenAPI v1.2.0 contains no documented path for:

```text
communications
chats
messages
conversations
email history
WhatsApp message history
Instagram message history
```

The documented `GET /buyer/{buyerId}` associations are limited to:

```text
manager
shipping
company
loyalty
custom_fields
```

The official outgoing webhook documentation currently lists only:

```text
order.change_order_status
order.change_payment_status
lead.change_lead_status
```

No guessed `/messages` or `/chats` request was treated as an API probe because no such route is present in the official specification. No private/internal keyCRM UI endpoint was introduced.

Detailed evidence is recorded in:

```text
docs/M3_KEYCRM_COMMUNICATIONS_API.md
```

## Communications acceptance decision

`get_customer_communications` is not accepted for implementation against the current public API because there is no supported provider operation behind it.

Current correct behavior boundary:

```text
explicit Gmail/mailbox question
-> search_emails
-> Gmail

customer communication/history in CRM
-> do not silently substitute Gmail
-> provider limitation must be stated until a supported KeyCRM interface exists
```

No production workflow was changed for this result. This preserves the existing security/read-only boundary and avoids an unsupported private-API dependency.

## Remaining M3 acceptance

Low-level production acceptance for customer synchronization, `search_customers`, `get_customer_details`, audit behavior, manager analytics, and the aggregate MCP Server is complete.

The official CRM-native communications API investigation is also complete, with the result `unsupported by current public OpenAPI`.

M3 is intentionally **not** marked complete yet. The remaining decision is how the project closes M3 under this provider limitation. Until that is explicitly resolved:

- do not implement a private/UI communications workaround;
- do not silently substitute Gmail for generic CRM communication history;
- do not start M4 Controlled Writes.
