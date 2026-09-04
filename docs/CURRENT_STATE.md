# Current State

Last verified: 2026-09-04.

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
    -> true: Get many messages
       -> Error: Format Gmail error
       -> Success: Get a message
          -> Error: Format Gmail error
          -> Success: Format email results
             -> Format MCP response
```

`Format email results` returns:

- `id`
- `threadId`
- `from`
- `to`
- `subject`
- `date`
- `body`

Invalid input returns `INVALID_INPUT`. Gmail-node failures are normalized to `UPSTREAM_ERROR` with `Gmail request failed`.

Manual invalid-input, error-route, and success regression checks were completed before the latest publish.

### GitHub

Workflow: `MCP — GitHub Read File`

Status: active.

Input:

- `path` — repository-relative path

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

Invalid input is rejected before PostgreSQL with `INVALID_INPUT`. Database failures are normalized to `UPSTREAM_ERROR`. Success regression with `limit: 5` was completed.

Workflow: `MCP — PostgreSQL Job Details`

Status: active.

Input:

- `job_id` — UUID string

UUID validation happens before PostgreSQL. Zero-row results are handled separately and return `NOT_FOUND`. Database failures return `UPSTREAM_ERROR`.

Verified success job:

`4372be34-c417-415f-92f6-63481b3b5686`

## Repository export state

The current deployed versions of these workflows are exported to this repository:

- `n8n/MCP_SERVER.json`
- `n8n/github/GET_GITHUB_FILE.json`
- `n8n/gmail/SEARCH_EMAILS.json`
- `n8n/postgres/GET_RECENT_JOBS.json`
- `n8n/postgres/GET_JOB_DETAILS.json`

The exports reference n8n credentials by credential metadata; no plaintext credential values were intentionally added to the repository.

## Security state

- Gmail credential is stored in n8n credentials storage.
- GitHub credential is stored in n8n credentials storage.
- PostgreSQL MCP credential is read-only.
- No write-capable business tool is exposed through MCP yet.
- Audit log schema is defined in this repository but is not yet wired into every tool invocation.

## Remaining M1 work

1. Add centralized tool-call audit logging.
2. Redact sensitive audit arguments.
3. Add a dedicated documented acceptance-test set for all current tools.

## Later gaps

1. Add Drive and Calendar read tools.
2. Add Gmail attachment retrieval as a separate tool.
3. Add write tools only behind explicit approval.
