# Recruiter Demo Video Script

Target length: **45-75 seconds**.

Goal: demonstrate that the project is a working MCP business-operations gateway, not just a collection of n8n screenshots.

The recording must not expose real mailbox contents, customer PII, credentials, tokens, or confidential CRM metrics.

## Recommended recording format

```text
resolution: 1920x1080 or 1440x900
capture: browser window only
length: 45-75 seconds
sound: optional; captions are enough
editing: trim pauses and loading time
```

Use a clean browser window with unrelated tabs closed.

## Sequence

### 0-8 s — Repository / architecture

Show the GitHub repository README briefly.

Visible items:

```text
MCP Business Operations Hub
17 read-only MCP tools
n8n + PostgreSQL + OAuth2 + Google Workspace + GitHub + KeyCRM
```

Scroll only enough to show the rendered architecture diagram.

Caption:

```text
Self-hosted MCP gateway for real business systems
```

### 8-25 s — Safe real MCP tool call

Use the MCP client with a non-sensitive repository question:

```text
Read docs/CURRENT_STATE.md from the project repository and tell me the current milestone and how many MCP tools are published.
```

Expected tool path:

```text
get_github_file
```

Expected answer should establish, from repository evidence:

```text
M5 Portfolio hardening — in progress
17 published read-only tools
```

This call is safe for recording because it reads the public portfolio repository rather than Gmail, Calendar, or CRM data.

### 25-42 s — Show tool surface

Open the MCP tool list/client tool inspector if available and quickly show that the server exposes tools across multiple systems.

Keep the view moving; do not inspect credential configuration.

Useful visible names:

```text
search_emails
search_drive_files
get_calendar_events
find_free_time
search_customers
get_manager_sales_stats
get_manager_call_timeline
```

Caption:

```text
One MCP gateway, isolated provider workflows
```

### 42-58 s — Engineering evidence

Return to GitHub and show one of:

```text
docs/PORTFOLIO_ARCHITECTURE.md
docs/RUNBOOK.md
.github/workflows/validate-n8n-exports.yml
```

Best choice: GitHub Actions `Validate n8n exports` with a green successful run.

Caption:

```text
Audited, read-only, CI-validated production workflows
```

### 58-70 s — Final frame

Return to the README top section.

Final caption:

```text
MCP Business Operations Hub
n8n • MCP • APIs • PostgreSQL • OAuth2
```

Stop recording without showing private production tabs.

## Optional second demo call

Only use this if a completely non-sensitive Google Drive test file is prepared specifically for portfolio recording.

Prompt:

```text
Find the portfolio demo document in Drive and summarize it.
```

Expected path:

```text
search_drive_files
-> read_drive_file
```

Do not use an existing business Drive document just to make the demo look more complex.

## What not to record

Do not show:

```text
real Gmail messages or search results
real Calendar event names
customer names, phones, emails, buyer IDs
real manager performance numbers
KeyCRM account screens
OAuth client configuration
n8n credentials
API tokens
PostgreSQL passwords/connection strings
server environment variables
private workflow input/output containing PII
```

## Acceptance for the video/GIF roadmap item

Mark the M5 video/GIF item complete only when a real recording exists and has been reviewed for accidental sensitive data.

Required final check:

```text
[ ] real MCP interaction is visible
[ ] architecture/repository is visible
[ ] no PII or secrets are visible
[ ] no confidential business metrics are visible
[ ] loading/dead time is trimmed
[ ] final length is approximately 45-75 seconds
```
