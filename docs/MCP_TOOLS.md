# MCP Tools

Production acceptance cases and regression rules for the current tool surface are documented in `docs/ACCEPTANCE_TESTS.md`.

## `search_emails`

Purpose: search Gmail and return full normalized message content for matching emails.

Inputs:

```json
{
  "query": "string",
  "limit": 5
}
```

Output per message:

```json
{
  "id": "string",
  "threadId": "string",
  "from": "string|null",
  "to": "string|null",
  "subject": "string|null",
  "date": "string|null",
  "body": "string|null"
}
```

Access: read-only.

Audit note: the Gmail query is used for the provider request but stored as `[REDACTED]` in audit `arguments_json`.

## `get_email_attachment`

Purpose: retrieve an attachment from a Gmail message without requiring the caller or user to know Gmail's internal `attachmentId`.

Inputs:

```json
{
  "message_id": "string",
  "filename": "optional string"
}
```

`message_id` is normally obtained internally from `search_emails`.

`filename` is optional. When the message has exactly one normal attachment, the tool selects it automatically. If multiple attachments exist, the tool returns their filenames, MIME types, and sizes so the agent can retry with an exact or partial `filename`.

The workflow recursively traverses the Gmail MIME tree, discovers the real Gmail `body.attachmentId` internally, downloads the selected attachment through the Gmail API, converts Gmail base64url data to standard base64, and returns:

```json
{
  "success": true,
  "data": {
    "filename": "invoice.pdf",
    "mime_type": "application/pdf",
    "size": 12345,
    "content_base64": "..."
  },
  "meta": {
    "tool": "get_email_attachment",
    "count": 1
  }
}
```

The internal Gmail `attachmentId` is not part of the public MCP contract and is not returned in the success response.

Possible normalized selection errors include `NOT_FOUND` and `AMBIGUOUS_ATTACHMENT`. Gmail API failures use `UPSTREAM_ERROR`.

Access: read-only.

## `get_github_file`

Purpose: read a text file from the configured GitHub repository.

Input:

```json
{
  "path": "docs/CURRENT_STATE.md"
}
```

Access: read-only.

## `get_recent_jobs`

Purpose: inspect recent production content jobs.

Input:

```json
{
  "limit": 10
}
```

Access: read-only PostgreSQL query.

## `get_job_details`

Purpose: inspect one content job in detail.

Input:

```json
{
  "job_id": "uuid"
}
```

Returned fields include status, current stage, last error, review fields, and timestamps.

Access: read-only PostgreSQL query.

## Planned tools

### Google Drive

- `search_drive_files(query, limit)`
- `read_drive_file(file_id)`

### Google Calendar

- `get_calendar_events(start, end)`
- `find_free_time(start, end, duration_minutes)`

### CRM

- `search_customers(query, limit)`
- `get_customer_details(customer_id)`

### Write tools — separate approval class

- `send_email`
- `create_calendar_event`
- `update_customer`
