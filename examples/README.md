# Sanitized Portfolio Examples

These examples demonstrate the production MCP contracts without publishing mailbox contents, customer PII, real customer identifiers, access tokens, or confidential business metrics.

Values marked as sanitized are representative of the accepted response shape, not production business data.

## 1. Cross-system email lookup

User request:

```text
Find the latest email about the August social-insurance payment and tell me the amount and due date.
```

Tool path:

```text
search_emails
-> Gmail API
-> normalized message evidence
-> model extracts requested fields
```

Sanitized result shape:

```json
{
  "success": true,
  "data": [
    {
      "id": "<redacted-message-id>",
      "from": "<redacted-sender>",
      "subject": "<redacted-subject>",
      "date": "2026-08-XXTXX:XX:XX+02:00",
      "body": "<redacted-mail-body>"
    }
  ],
  "meta": {
    "tool": "search_emails",
    "count": 1
  }
}
```

Security note: the actual Gmail search query is stored as `[REDACTED]` in the audit record.

## 2. Google Drive discovery and reading

User request:

```text
Find the project specification in Drive and summarize the current architecture section.
```

Tool path:

```text
search_drive_files(query)
-> file_id
-> read_drive_file(file_id)
-> normalized text
-> model summary
```

Why two tools: discovery and content access remain separate, keeping each contract small and making ambiguity explicit.

Sanitized result shape:

```json
{
  "success": true,
  "data": {
    "file_id": "<redacted-drive-id>",
    "name": "Project specification",
    "mime_type": "application/vnd.google-apps.document",
    "text": "<sanitized document excerpt>"
  },
  "meta": {
    "tool": "read_drive_file",
    "count": 1
  }
}
```

## 3. Calendar availability

User request:

```text
Show my meetings tomorrow between 09:00 and 18:00 and find a free 60-minute slot.
```

Tool path:

```text
get_calendar_events(start, end)
+
find_free_time(start, end, duration_minutes=60)
```

Sanitized free-time result:

```json
{
  "success": true,
  "data": [
    {
      "start": "2026-09-11T13:00:00+02:00",
      "end": "2026-09-11T15:00:00+02:00",
      "duration_minutes": 120
    }
  ],
  "meta": {
    "tool": "find_free_time",
    "count": 1
  }
}
```

The example timestamps are illustrative and do not represent the user's real calendar.

## 4. Production job diagnosis

User request:

```text
Why did the latest content job fail?
```

Tool path:

```text
get_recent_jobs
-> identify relevant job
-> get_job_details(job_id)
-> reason from current_stage + last_error
```

Sanitized evidence:

```json
{
  "success": true,
  "data": {
    "job_id": "00000000-0000-0000-0000-000000000000",
    "status": "failed",
    "current_stage": "media_processing",
    "last_error": "<sanitized upstream error>"
  },
  "meta": {
    "tool": "get_job_details",
    "count": 1
  }
}
```

The model must explain only what the returned operational evidence supports.

## 5. KeyCRM customer lookup

User request:

```text
Find customer Example Customer and show current contact details.
```

Tool path:

```text
search_customers("Example Customer")
-> local minimal PostgreSQL index
-> buyer_id
-> get_customer_details(buyer_id)
-> fresh KeyCRM GET
```

Sanitized output:

```json
{
  "success": true,
  "data": {
    "buyer_id": 12345,
    "full_name": "Example Customer",
    "phones": ["+48XXXXXXXXX"],
    "emails": ["example@example.invalid"]
  },
  "meta": {
    "tool": "get_customer_details",
    "count": 1
  }
}
```

The local customer index is used for discovery only; fresh customer details still come from KeyCRM.

## 6. Manager analytics

User request:

```text
What was Example Manager's conversion last month and which channels produced the most leads?
```

Tool path:

```text
get_manager_sales_stats(manager, start, end)
+
get_manager_lead_stats(manager, start, end)
```

Sanitized representative metrics:

```json
{
  "manager": "Example Manager",
  "total_leads_raw": 120,
  "duplicate_leads": 20,
  "total_leads_excluding_duplicates": 100,
  "successful_sales": 25,
  "conversion_percent_excluding_duplicates": 25.0,
  "by_source_excluding_duplicates": [
    {"source": "Website", "count": 45},
    {"source": "Social", "count": 35},
    {"source": "Other", "count": 20}
  ]
}
```

These numbers are intentionally synthetic. The production tools return the same documented metric categories over the requested period.

## 7. Manager call timeline

User request:

```text
Show Example Manager's call activity today and tell me the longest break between calls.
```

Tool path:

```text
get_manager_call_timeline(manager, start, end)
-> fresh KeyCRM call data
-> calculate positive call-to-call gaps
```

Sanitized representative summary:

```json
{
  "manager": "Example Manager",
  "total_calls": 18,
  "average_positive_gap_minutes": 7.4,
  "longest_gap_minutes": 28.0,
  "gaps_over_15_minutes": 2,
  "gaps_over_30_minutes": 0
}
```

Again, the values are synthetic and exist only to demonstrate the accepted output shape.

## 8. Explicit provider limitation

User request:

```text
Show the complete chat history with this customer from KeyCRM.
```

Correct behavior:

```text
resolve the CRM context
-> do not silently use Gmail
-> report that the current public KeyCRM OpenAPI does not expose CRM-native chat history
```

This is deliberate behavior. The project does not scrape the KeyCRM UI or guess private `/messages` or `/chats` endpoints.

## What these examples demonstrate

- multi-step MCP composition;
- normalized provider evidence;
- read-only business-system access;
- PII-aware audit handling;
- fresh reads versus local analytics indexes;
- explicit ambiguity and provider-limit handling;
- no fabricated business data in public portfolio documentation.
