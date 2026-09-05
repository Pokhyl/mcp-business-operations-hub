# Current State

Last verified: 2026-09-05.

## Deployed MCP gateway

Workflow: `MCP — Server`

Status: active.

Authentication: n8n OAuth2 user authentication for the MCP endpoint.

Current production tool surface:

- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_emails`

Legacy tools `hello_world` and `get_person` have been removed from the deployed MCP server.

## Normalized MCP contract

All four current read tools return the same success envelope:

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

Errors use the normalized envelope:

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

Current error codes used by the deployed read tools:

- `INVALID_INPUT`
- `NOT_FOUND`
- `UPSTREAM_ERROR`

## Centralized audit logging

Centralized audit logging is deployed.

Audit workflow:

`MCP — Audit Tool Call`

Audit table:

`mcp_tool_calls`

Each audited tool follows the same lifecycle after input validation:

```text
Validate input
 -> Audit start
 -> Provider/database operation
 -> Normalize success/error
 -> Audit finish
 -> Return original MCP response
```

`Audit start` inserts one row with:

- `tool_name`
- `arguments_json`
- `status = started`
- `client_name`
- optional `request_id`
- `started_at`

It returns `audit_id` and `started_at`.

`Audit finish` updates the same row with:

- `status = succeeded|failed`
- `error_code`
- `error_message`
- `duration_ms`
- `completed_at`

Input-validation failures are currently returned before `Audit start` and therefore are not written to the audit table.

Current audited tools:

- `get_github_file`
- `get_recent_jobs`
- `get_job_details`
- `search_emails`

Production audit regression evidence was observed for:

- `get_github_file` success with `docs/CURRENT_STATE.md`
- `get_github_file` `NOT_FOUND` with `docs/THIS_FILE_DOES_NOT_EXIST.md`
- `get_recent_jobs` success with `limit: 5`
- `get_job_details` success with job `4372be34-c417-415f-92f6-63481b3b5686`
- `get_job_details` `NOT_FOUND` with a valid UUID that has no row
- `search_emails` success with `query: newer_than:7d`, `limit: 5`

Audit rows were verified in PostgreSQL with the expected tool name, arguments, status, duration, and error code where applicable.

Sensitive-argument redaction is not implemented yet. Current read-tool arguments are stored as supplied after normalization.

## Implemented sub-workflows

### Gmail

Workflow: `MCP — Gmail Search`

Status: active.

Inputs:

- `query` — required non-empty Gmail search string
- `limit` — optional integer, default `5`, allowed range `1..50`

Current flow:

```text
When Executed by Another Workflow
 -> Validate input
 -> Is input valid?
    -> false: Format invalid input error
    -> true: Audit start
       -> Get many messages
          -> Error: Format Gmail error
          -> Success: Get a message
             -> Error: Format Gmail error
             -> Success: Format email results
                -> Format MCP response
                -> Audit success
                -> Return MCP response
       -> normalized Gmail error
          -> Audit failed
          -> Return MCP error
```

`Get many messages` now passes both normalized inputs explicitly after the audit sub-workflow:

- limit from `Validate input`
- Gmail search query through `filters.q` from `Validate input`

This fixes the prior production defect where the Gmail node had `filters: {}` and therefore did not actually apply the requested search query.

`Format email results` returns:

- `id`
- `threadId`
- `from`
- `to`
- `subject`
- `date`
- `body`

Invalid input returns `INVALID_INPUT`. Gmail-node failures are normalized to `UPSTREAM_ERROR` with `Gmail request failed`.

### GitHub

Workflow: `MCP — GitHub Read File`

Status: active.

Input:

- `path` — repository-relative path

The workflow now performs `Audit start` before the GitHub request and `Audit success` / `Audit failed` after the normalized result.

Because `Audit start` replaces the current item, `Get a file` reads `path` explicitly from the workflow trigger output.

The GitHub node uses a separate Error output. A missing file is normalized to `NOT_FOUND`; other GitHub failures fall back to `UPSTREAM_ERROR`.

Verified missing-file case:

- input: `docs/THIS_FILE_DOES_NOT_EXIST.md`
- upstream message: `The resource you are requesting could not be found`
- normalized code: `NOT_FOUND`

Success regression was checked with `docs/CURRENT_STATE.md`.

### PostgreSQL

Workflow: `MCP — PostgreSQL Recent Jobs`

Status: active.

Input:

- `limit` — optional integer, default `10`, allowed range `1..50`

Invalid input is rejected before PostgreSQL with `INVALID_INPUT`. Valid calls are audited before the query and finalized after the normalized result. The SQL query now reads `limit` explicitly from `Validate input` because `Audit start` replaces the current item.

Database failures are normalized to `UPSTREAM_ERROR`. Success regression with `limit: 5` was completed after audit integration.

Workflow: `MCP — PostgreSQL Job Details`

Status: active.

Input:

- `job_id` — UUID string

UUID validation happens before PostgreSQL. Valid calls are audited before the query. The SQL query reads `job_id` explicitly from `Validate input` after `Audit start`.

Zero-row results are handled separately and return `NOT_FOUND`; the same audit row is finalized with `status = failed` and `error_code = NOT_FOUND`. Database failures return `UPSTREAM_ERROR` and are wired to the same centralized audit finish workflow.

Verified success job:

`4372be34-c417-415f-92f6-63481b3b5686`

## Repository export state

The current deployed workflow versions are exported to this repository:

- `n8n/MCP_SERVER.json`
- `n8n/AUDIT_TOOL_CALL.json`
- `n8n/github/GET_GITHUB_FILE.json`
- `n8n/gmail/SEARCH_EMAILS.json`
- `n8n/postgres/GET_RECENT_JOBS.json`
- `n8n/postgres/GET_JOB_DETAILS.json`

The exports reference n8n credentials by credential metadata only; no plaintext credential values were intentionally added to the repository.

## Security state

- Gmail credential is stored in n8n credentials storage.
- GitHub credential is stored in n8n credentials storage.
- PostgreSQL business-read tools use the read-only `mcp_read` credential.
- The centralized audit workflow uses the separate write-capable application PostgreSQL credential only for `mcp_tool_calls` writes.
- No write-capable business tool is exposed through MCP yet.
- Centralized audit logging is active for all four current read tools.
- Sensitive audit-argument redaction is still pending.

## Remaining M1 work

1. Redact sensitive audit arguments.
2. Add a dedicated documented acceptance-test set for all current tools.

## Later gaps

1. Add Drive and Calendar read tools.
2. Add Gmail attachment retrieval as a separate tool.
3. Add write tools only behind explicit approval.
