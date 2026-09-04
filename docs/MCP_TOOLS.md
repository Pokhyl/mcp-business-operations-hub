# MCP Tools

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

### Gmail

- `get_email_attachment(message_id, attachment_id)`

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
