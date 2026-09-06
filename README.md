# MCP Business Operations Hub

Self-hosted **Model Context Protocol (MCP) gateway** that lets an AI assistant securely query real business systems through structured read-only tools.

The project uses **n8n**, **PostgreSQL**, **Docker**, **Google Workspace APIs**, and **GitHub API**. The current production MCP server is connected to Claude and exposes working read tools for Gmail, Google Drive, GitHub, and PostgreSQL.

## Why this project exists

Business data is usually fragmented across email, source control, databases, calendars, cloud drives, and CRM systems. This project provides one controlled MCP interface so an AI client can answer cross-system questions without direct unrestricted access to the underlying services.

Examples:

- “Find the latest email about ZUS for August and tell me the amount and due date.”
- “Find the attachment from the latest Paymove email.”
- “Find the TikTok Video Pipeline file in Google Drive and tell me what is in it.”
- “Why did the latest content job fail?”
- “Read `docs/CURRENT_STATE.md` from the production repository.”

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
     +--------+---------+---------+----------------+
     |                  |         |                |
     v                  v         v                v
   Gmail              Drive     GitHub         PostgreSQL
     |                  |         |                |
     v                  v         v                v
 Gmail API          Drive API  GitHub API      job runtime data
```

## Implemented MCP tools

| Tool | Source | Access | Status |
|---|---|---|---|
| `search_emails` | Gmail | Read-only | Working |
| `get_email_attachment` | Gmail | Read-only | Working |
| `search_drive_files` | Google Drive | Read-only | Working |
| `read_drive_file` | Google Drive | Read-only | Working |
| `get_github_file` | GitHub | Read-only | Working |
| `get_recent_jobs` | PostgreSQL | Read-only | Working |
| `get_job_details` | PostgreSQL | Read-only | Working |

Legacy test tools `hello_world` and `get_person` have been removed from production.

## Google Drive flow

The Drive integration deliberately separates discovery from reading:

```text
Claude
  -> search_drive_files(query, limit)
  -> receives normalized file IDs/metadata
  -> read_drive_file(file_id)
  -> receives normalized text content
  -> summarizes the source for the user
```

Drive uses a dedicated OAuth credential restricted to:

```text
https://www.googleapis.com/auth/drive.readonly
```

`read_drive_file` supports Google Docs, Sheets, Slides, PDF, and text-based files. Unsupported binary files return `UNSUPPORTED_FILE_TYPE`; missing files return `NOT_FOUND`.

## Gmail attachment flow

The public attachment contract is intentionally simple:

```text
search_emails
  -> message_id
  -> get_email_attachment(message_id, optional filename)
```

Gmail `attachmentId` is discovered internally and is never required from the user.

## Production debugging flow

```text
Claude
  -> get_recent_jobs
  -> identifies the relevant job
  -> get_job_details(job_id)
  -> analyzes current_stage + last_error
  -> returns a human-readable explanation
```

## Security model

The project follows a least-privilege model:

- MCP endpoint authenticated through OAuth2.
- External credentials stay in n8n credentials storage and are never committed as plaintext secrets.
- Google Drive uses a dedicated `drive.readonly` OAuth credential.
- PostgreSQL business-read credential is read-only.
- Current business tools are read-only.
- Write tools will be separated from read tools and require explicit approval.
- Tool calls use centralized audit logging with sensitive-argument sanitization.

See [docs/SECURITY.md](docs/SECURITY.md).

## Repository structure

```text
mcp-business-operations-hub/
├── README.md
├── docs/
│   ├── ACCEPTANCE_TESTS.md
│   ├── ARCHITECTURE.md
│   ├── CURRENT_STATE.md
│   ├── MCP_TOOLS.md
│   ├── ROADMAP.md
│   ├── SECURITY.md
│   └── USE_CASES.md
├── n8n/
│   ├── MCP_SERVER.json
│   ├── AUDIT_TOOL_CALL.json
│   ├── drive/
│   │   ├── SEARCH_DRIVE_FILES.json
│   │   └── READ_DRIVE_FILE.json
│   ├── gmail/
│   │   ├── SEARCH_EMAILS.json
│   │   └── GET_EMAIL_ATTACHMENT.json
│   ├── github/
│   │   └── GET_GITHUB_FILE.json
│   └── postgres/
│       ├── GET_JOB_DETAILS.json
│       └── GET_RECENT_JOBS.json
├── database/
│   └── migrations/
│       ├── 001_mcp_tool_audit.sql
│       └── 002_redact_existing_email_audit_queries.sql
└── examples/
```

## Engineering principles

1. **No ad-hoc hacks.** Fix reusable system-level problems, not one prompt or one dataset.
2. **Least privilege.** Each credential receives only the permissions required by its tools.
3. **Small tool contracts.** Each MCP tool has a clear purpose and stable input/output shape.
4. **Read/write separation.** Read operations and state-changing operations are never mixed silently.
5. **Source-grounded answers.** The AI receives raw business evidence from tools and reasons over that evidence.
6. **Auditable execution.** Tool calls are observable and attributable.
7. **Fix runtime defects at the runtime layer.** Do not add workflow-specific bypasses for known platform bugs when a supported runtime fix exists.

## Runtime

Production n8n is pinned to `2.37.10`.

On 2026-09-06 production was upgraded from `2.33.3` after a Google Drive 404 exposed incorrect HTTP error-output routing in that runtime. A full backup was created first; post-upgrade health checks and the 404 regression passed.

## Roadmap

Current milestone: **M2 — Google Workspace expansion**.

Completed:

- Gmail attachment retrieval
- Google Drive search
- Google Drive file reading

Next:

- final natural-language Drive cross-tool regression
- Google Calendar read tools
- later CRM reads
- controlled write tools behind explicit approval

See [docs/ROADMAP.md](docs/ROADMAP.md) and [docs/CURRENT_STATE.md](docs/CURRENT_STATE.md).
