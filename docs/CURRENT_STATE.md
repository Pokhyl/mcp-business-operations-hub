# Current State

Last verified: 2026-09-04.

## Deployed MCP gateway

Workflow: `MCP — Server`

Status: active.

Authentication: n8n OAuth2 user authentication for the MCP endpoint.

Current tool nodes in the deployed workflow:

- `hello_world` — legacy test tool
- `get_person` — legacy test tool
- `get_github_file` — production read tool
- `get_recent_jobs` — production read tool
- `get_job_details` — production read tool
- `search_emails` — production read tool

## Implemented sub-workflows

### Gmail

`MCP — Gmail Search`

Inputs:

- `query` — string, Gmail search syntax
- `limit` — number

Flow:

```text
When Executed by Another Workflow
 -> Get many messages
 -> Get a message
 -> Format email results
```

The workflow searches matching messages, fetches the full message body, and returns a normalized text-first response.

### GitHub

`MCP — GitHub Read File`

Input:

- `path` — repository-relative path

The current implementation reads files from the existing portfolio/production repository using a restricted GitHub credential and decodes the returned content.

### PostgreSQL

`MCP — PostgreSQL Recent Jobs`

Input:

- `limit` — number

Returns recent job metadata.

`MCP — PostgreSQL Job Details`

Input:

- `job_id` — UUID string

Returns detailed runtime state including current stage and last error.

## Security state

- Gmail credential stored only in n8n credentials storage.
- GitHub credential stored only in n8n credentials storage.
- PostgreSQL MCP credential is read-only.
- No write-capable business tool is exposed through MCP yet.
- Audit log schema is defined in this repository but not yet wired into every tool invocation.

## Known gaps

1. Remove `hello_world` and `get_person` from the production MCP surface.
2. Add tool-call audit logging.
3. Add normalized error contracts.
4. Add Drive and Calendar read tools.
5. Add Gmail attachment retrieval as a separate tool.
6. Add write tools only behind explicit approval.