# MCP Business Operations Hub

Self-hosted **Model Context Protocol (MCP) gateway** that lets an AI assistant securely query real business systems through structured tools.

The project uses **n8n**, **PostgreSQL**, **Docker**, **Google Workspace APIs**, and **GitHub API**. The current deployed MCP server is connected to Claude and already exposes working read-only tools for Gmail, GitHub, and PostgreSQL.

## Why this project exists

Business data is usually fragmented across email, source control, databases, calendars, cloud drives, and CRM systems. This project provides one controlled MCP interface so an AI client can answer cross-system questions without direct unrestricted access to the underlying services.

Examples:

- “Find the latest email about ZUS for August and tell me the amount and due date.”
- “Why did the latest content job fail?”
- “Read `docs/CURRENT_STATE.md` from the production repository.”
- Future: “Find the customer, check their latest email, and tell me whether they have a meeting this week.”

## Current architecture

```text
Claude / MCP Client
        |
        v
+---------------------------+
|      n8n MCP Gateway      |
|      OAuth2 protected     |
+-------------+-------------+
              |
     +--------+---------+----------------+
     |                  |                |
     v                  v                v
   Gmail              GitHub         PostgreSQL
     |                  |                |
     v                  v                v
 full email body    repository files   job runtime data
```

## Implemented MCP tools

| Tool | Source | Access | Status |
|---|---|---|---|
| `search_emails` | Gmail | Read-only | Working |
| `get_github_file` | GitHub | Read-only | Working |
| `get_recent_jobs` | PostgreSQL | Read-only | Working |
| `get_job_details` | PostgreSQL | Read-only | Working |

Two legacy test tools (`hello_world`, `get_person`) are still present in the currently deployed gateway and are scheduled for removal from the production tool surface.

## Real use case: accounting email

User prompt:

```text
Find the latest email about ZUS for August and tell me the amount and due date.
```

Execution path:

```text
Claude
  -> search_emails
  -> Gmail search
  -> fetch each matching message
  -> normalize full text body
  -> Claude extracts the relevant business facts
```

The Gmail workflow deliberately returns a compact normalized structure rather than the complete Gmail API payload:

```json
{
  "id": "...",
  "threadId": "...",
  "from": "...",
  "to": "...",
  "subject": "...",
  "date": "...",
  "body": "..."
}
```

## Real use case: production debugging

User prompt:

```text
Why did the latest content job fail?
```

Execution path:

```text
Claude
  -> get_recent_jobs
  -> identifies the latest failed job
  -> get_job_details(job_id)
  -> analyzes current_stage + last_error
  -> returns a human-readable explanation
```

## Security model

The project follows a least-privilege model:

- MCP endpoint authenticated through OAuth2.
- External credentials stay in n8n credentials storage and are never committed to Git.
- PostgreSQL MCP credential is read-only.
- Current business tools are read-only.
- Write tools will be separated from read tools and require explicit approval.
- Every tool invocation is planned to be recorded in an audit log.

See [docs/SECURITY.md](docs/SECURITY.md).

## Repository structure

```text
mcp-business-operations-hub/
├── README.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── CURRENT_STATE.md
│   ├── MCP_TOOLS.md
│   ├── ROADMAP.md
│   ├── SECURITY.md
│   └── USE_CASES.md
├── n8n/
│   ├── MCP_SERVER.json
│   ├── gmail/
│   │   └── SEARCH_EMAILS.json
│   ├── github/
│   │   └── GET_GITHUB_FILE.json
│   └── postgres/
│       ├── GET_JOB_DETAILS.json
│       └── GET_RECENT_JOBS.json
├── database/
│   └── migrations/
│       └── 001_mcp_tool_audit.sql
└── examples/
    ├── accounting-zus.md
    └── production-debugging.md
```

## Planned integrations

Next integrations are deliberately added as independent MCP tools instead of giving the model unrestricted API access:

- Google Drive: `search_drive_files`, `read_drive_file`
- Google Calendar: `get_calendar_events`, `find_free_time`
- CRM: `search_customers`, `get_customer_details`
- Gmail attachments: `get_email_attachment`
- Auditing and observability for every tool call
- Explicit approval boundary for state-changing tools

## Engineering principles

1. **No ad-hoc hacks.** Fix reusable system-level problems, not one prompt or one dataset.
2. **Least privilege.** Each credential receives only the permissions required by its tools.
3. **Small tool contracts.** Each MCP tool has a clear purpose and stable input/output shape.
4. **Read/write separation.** Read operations and state-changing operations are never mixed silently.
5. **Source-grounded answers.** The AI receives raw business evidence from tools and reasons over that evidence.
6. **Auditable execution.** Tool calls are observable and attributable.

## Stack

- n8n self-hosted
- Model Context Protocol (MCP)
- Docker
- PostgreSQL
- Gmail API / OAuth2
- GitHub API
- Claude as MCP client

## Status

**Foundation / working prototype.** The core MCP gateway and four real read-only business tools are operational. The next milestone is production hardening: audit logging, cleanup of legacy test tools, Drive/Calendar integrations, and explicit write-operation approval boundaries.