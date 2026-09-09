# Acceptance Tests

Last verified: 2026-09-09.

This document records production acceptance evidence for the read-only MCP tool surface.

## Common contract

Successful read tools return:

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

Errors return:

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

For valid audited calls, `Audit start` creates one `mcp_tool_calls` row, the same row is finalized as `succeeded` or `failed`, `duration_ms` is populated, and the original normalized business response is returned. `INVALID_INPUT` is rejected before audit/provider access.

## Test matrix

| ID | Tool | Case | Status |
| --- | --- | --- | --- |
| GH-01 | `get_github_file` | existing file | PASS |
| GH-02 | `get_github_file` | missing file -> `NOT_FOUND` | PASS |
| RJ-01 | `get_recent_jobs` | valid limit | PASS |
| RJ-02 | `get_recent_jobs` | invalid limit -> `INVALID_INPUT` | PASS |
| JD-01 | `get_job_details` | existing job | PASS |
| JD-02 | `get_job_details` | invalid UUID -> `INVALID_INPUT` | PASS |
| JD-03 | `get_job_details` | valid UUID with no row -> `NOT_FOUND` | PASS |
| GM-01 | `search_emails` | valid Gmail search | PASS |
| GM-02 | `search_emails` | invalid input | PASS |
| GM-03 | `search_emails` | stored query redacted | PASS |
| GA-01 | `get_email_attachment` | automatic single attachment selection | PASS |
| GA-02 | `get_email_attachment` | filename mismatch -> `NOT_FOUND` | PASS |
| DS-01 | `search_drive_files` | normal search | PASS |
| DS-02 | `search_drive_files` | invalid limit | PASS |
| DS-03 | `search_drive_files` | no matches -> successful empty list | PASS |
| DS-04 | `search_drive_files` | natural-language MCP search | PASS |
| DR-01 | `read_drive_file` | Google Sheet | PASS |
| DR-02 | `read_drive_file` | PDF | PASS |
| DR-03 | `read_drive_file` | TXT/Markdown | PASS |
| DR-04 | `read_drive_file` | Google Doc | PASS |
| DR-05 | `read_drive_file` | Google Slides | PASS |
| DR-06 | `read_drive_file` | unsupported MOV -> `UNSUPPORTED_FILE_TYPE` | PASS |
| DR-07 | `read_drive_file` | invalid file ID | PASS |
| DR-08 | `read_drive_file` | nonexistent file -> `NOT_FOUND` | PASS |
| DR-09 | Drive cross-tool chain | search -> read -> client summary | PASS |
| CE-01 | `get_calendar_events` | invalid input | PASS |
| CE-02 | `get_calendar_events` | valid primary window | PASS |
| CE-03 | `get_calendar_events` | nonexistent calendar -> `NOT_FOUND` | PASS |
| CE-04 | `get_calendar_events` | audit lifecycle | PASS |
| CE-05 | `get_calendar_events` | natural week/month/year prompts | PASS |
| FF-01 | `find_free_time` | published workflow state | PASS |
| FF-02 | `find_free_time` | natural 60-minute slot request | PASS |
| FF-03 | `find_free_time` | audit lifecycle | PASS |
| GW-01 | MCP Server Calendar surface | both Calendar tools present simultaneously | PASS |
| GW-02 | recovered `get_calendar_events` | fresh natural-language regression request | PASS |
| GW-03 | recovered `find_free_time` | fresh natural-language regression request | PASS |

## Google Drive acceptance notes

The Drive tools use the dedicated `Google Drive MCP readonly` credential with `https://www.googleapis.com/auth/drive.readonly`.

`search_drive_files` accepts a natural search term and builds provider query syntax internally. No matches are a successful empty result.

`read_drive_file` supports Google Docs, Sheets, Slides, PDF, and text files. Text is capped at 50000 characters and truncation is explicit. Missing files normalize to `NOT_FOUND`; unsupported binaries normalize to `UNSUPPORTED_FILE_TYPE`.

The Drive cross-tool natural-language acceptance verified:

```text
natural user request
 -> search_drive_files
 -> select real result
 -> read_drive_file(file_id)
 -> client summary
```

During Drive acceptance, n8n `2.33.3` incorrectly routed a real Google Drive 404 through the HTTP Request success output despite `Continue (using error output)`. Production was backed up and upgraded to `2.37.10`; the same 404 then followed the expected error branch and normalized to `NOT_FOUND`.

## Google Calendar acceptance notes

The Calendar tools use the dedicated `Google Calendar MCP readonly` credential with:

```text
https://www.googleapis.com/auth/calendar.readonly
```

Detailed `get_calendar_events` evidence is in `docs/CALENDAR_ACCEPTANCE.md`.

Detailed `find_free_time` evidence is in `docs/FIND_FREE_TIME_ACCEPTANCE.md`.

### CE-05 — natural-language calendar events

Through Claude, natural requests for a week, month, and year invoked `get_calendar_events` and returned source-accurate empty results for the real empty primary calendar.

### FF-02 — natural-language free-time search

A natural request for a 60-minute slot between 09:00 and 18:00 invoked `find_free_time`. The empty primary calendar produced the full requested interval as available.

## Final Calendar gateway regression acceptance

A gateway regression discovered on 2026-09-08 temporarily left `MCP — Server` with `find_free_time` but without the previously accepted `get_calendar_events` node.

The missing tool was restored and the recovered aggregate MCP Server was published as:

```text
workflow_id:       dSohghXnQp078EZm
version_id:        07843872-4ab5-46f1-8df9-9a6bc8418673
active_version_id: 07843872-4ab5-46f1-8df9-9a6bc8418673
```

Direct production inspection on 2026-09-09 confirmed both tools are present simultaneously:

```text
get_calendar_events
find_free_time
```

### GW-02 — post-recovery `get_calendar_events`

Natural request through Claude:

```text
Что у меня завтра в календаре?
```

The client resolved tomorrow as 2026-09-10 and invoked:

```text
start:       2026-09-10T00:00:00+02:00
end:         2026-09-11T00:00:00+02:00
calendar_id: primary
limit:       50
```

Claude reported no events, matching the real primary calendar.

Audit evidence:

```text
tool_name:   get_calendar_events
status:      succeeded
duration_ms: 606
```

Status: PASS.

### GW-03 — post-recovery `find_free_time`

Natural request through Claude:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

The client invoked:

```text
start:            2026-09-10T09:00:00+02:00
end:              2026-09-10T18:00:00+02:00
calendar_id:      primary
duration_minutes: 60
```

Claude reported the full 09:00–18:00 interval as free, matching the real empty primary calendar.

Audit evidence:

```text
tool_name:   find_free_time
status:      succeeded
duration_ms: 450
```

Status: PASS.

The gateway regression is closed. M2 — Google Workspace expansion is fully accepted.

## Regression rules for future changes

At minimum:

- validation remains before provider access;
- normalized envelopes remain stable unless intentionally versioned;
- one valid provider call creates and finalizes one audit row;
- audit integration does not replace the business response;
- Gmail search keeps provider functionality while audit storage redacts queries;
- Gmail attachment retrieval never requires a user-supplied Gmail `attachmentId`;
- Drive uses the dedicated read-only credential;
- Drive no-match remains a successful empty result;
- missing Drive files remain `NOT_FOUND`;
- unsupported Drive binaries remain `UNSUPPORTED_FILE_TYPE`;
- Calendar read tools use the dedicated `calendar.readonly` credential;
- FreeBusy per-calendar errors are not treated as successful free-time responses;
- adding an MCP Server tool must not remove previously accepted tool nodes;
- after every MCP Server edit, verify the complete expected tool surface before milestone closure;
- working production credentials or SQL are not deliberately broken to manufacture failure tests.
