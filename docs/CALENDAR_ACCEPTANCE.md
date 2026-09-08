# Google Calendar Workflow Acceptance

Last verified: 2026-09-08.

Credential: `Google Calendar MCP readonly`

OAuth scope:

```text
https://www.googleapis.com/auth/calendar.readonly
```

This document covers the accepted read-only Calendar workflows:

- `get_calendar_events` -> `MCP — Calendar Events` (`IUpcFPRH3xOVbgEq`)
- `find_free_time` -> `MCP — Find Free Time` (`dDiqHH9C5clOrYOX`)

## `get_calendar_events`

### Contract

Inputs:

```json
{
  "start": "RFC3339 timestamp with timezone",
  "end": "RFC3339 timestamp with timezone",
  "calendar_id": "optional string, default primary",
  "limit": "optional integer, default 50, range 1..2500"
}
```

Success envelope:

```json
{
  "success": true,
  "data": [],
  "meta": {
    "tool": "get_calendar_events",
    "count": 0,
    "calendar_id": "primary",
    "time_zone": "UTC"
  }
}
```

Errors use the standard MCP envelope with `INVALID_INPUT`, `NOT_FOUND`, or `UPSTREAM_ERROR`.

### Execution flow

```text
When Executed by Another Workflow
 -> Validate input
 -> Is input valid?
    -> false: Format invalid input error
    -> true: Audit start
             -> Get calendar events
                -> Success: Format calendar events
                            -> Audit success
                            -> Return MCP response
                -> Error: Format Calendar error
                          -> Audit failed
                          -> Return MCP error
```

`arguments_json` is supplied only on `Audit start`. Both `Audit success` and `Audit failed` omit it.

### CE-01 — invalid input

A CLI execution with no sub-workflow input followed the validation failure branch and returned `INVALID_INPUT`. `Audit start` and Google Calendar were not executed.

Status: PASS.

### CE-02 — valid primary-calendar request

A production-credential smoke execution used:

```json
{
  "start": "2026-09-01T00:00:00+02:00",
  "end": "2026-10-01T00:00:00+02:00",
  "calendar_id": "primary",
  "limit": 50
}
```

Google Calendar returned a valid `calendar#events` response. The tested window contained no events, so the normalized business response was `success=true`, `data=[]`, `count=0`, and `calendar_id=primary`. The audit row finalized as `succeeded`.

Status: PASS.

### CE-03 — nonexistent calendar

A deliberately nonexistent calendar ID produced the real n8n provider error object with `details.httpCode="404"`.

Observed path:

```text
Get calendar events
 -> Error output
 -> Format Calendar error
 -> Audit failed
 -> Return MCP error
```

Final normalized result:

```json
{
  "success": false,
  "error": {
    "code": "NOT_FOUND",
    "message": "Google Calendar not found"
  },
  "meta": {
    "tool": "get_calendar_events",
    "count": 0
  }
}
```

The audit row finalized as `failed` with `error_code=NOT_FOUND`.

Status: PASS.

### CE-04 — audit lifecycle

Verified database evidence contains one succeeded and one failed `get_calendar_events` row, both with non-null `duration_ms` and completion timestamps.

Status: PASS.

### CE-05 — natural-language MCP client acceptance

`get_calendar_events` was exposed through `MCP — Server` with all four workflow inputs defined by the model:

- `start` — RFC3339 start of requested window
- `end` — RFC3339 end of requested window
- `calendar_id` — defaults to `primary`
- `limit` — defaults to `50`

Natural-language testing was performed through Claude without supplying RFC3339 timestamps, calendar IDs, or other API parameters manually.

Observed requests and behavior:

1. The user asked what was in the calendar for the current week. Claude invoked `get_calendar_events` and reported no events for 7–13 September 2026.
2. The user then asked for a month. Claude invoked `get_calendar_events` again and reported no events for 8 September–8 October 2026.
3. The user then asked for a year. Claude invoked `get_calendar_events` again and reported that the primary calendar was empty for the requested year window.
4. The user confirmed that the calendar really contained no events, so the empty responses matched the source of truth rather than representing a false negative.

This verifies the intended chain:

```text
natural user request
 -> MCP client resolves requested time window
 -> get_calendar_events(start, end, primary, limit)
 -> Google Calendar API
 -> normalized result
 -> client explanation
```

Status: PASS.

## `find_free_time`

### Contract

Inputs:

```json
{
  "start": "RFC3339 timestamp with timezone",
  "end": "RFC3339 timestamp with timezone",
  "duration_minutes": "positive integer, default 30",
  "calendar_id": "optional string, default primary"
}
```

Rules:

- `end` must be later than `start`.
- `duration_minutes` must fit inside the requested range.
- `calendar_id` defaults to `primary`.
- validation happens before audit/provider access.

### Provider behavior

The workflow calls Google Calendar FreeBusy:

```text
POST https://www.googleapis.com/calendar/v3/freeBusy
```

A successful HTTP response is not automatically treated as a successful calendar lookup. The workflow checks `calendars[calendar_id].errors` because FreeBusy may report calendar-specific provider errors inside HTTP 200.

### Execution flow

```text
When Executed by Another Workflow
 -> Validate input
 -> Is input valid?
    -> false: Format invalid input error
    -> true: Audit start
             -> Get free busy
                -> Error: Format FreeBusy error
                          -> Audit failed
                          -> Return MCP error
                -> Success: Analyze free busy
                            -> Is FreeBusy valid?
                               -> false: Format FreeBusy error
                                         -> Audit failed
                                         -> Return MCP error
                               -> true: Calculate free time
                                        -> Audit success
                                        -> Return MCP response
```

### FF-01 — workflow publication

`MCP — Find Free Time` is active and published. Its `versionId` and `activeVersionId` both resolved to:

```text
efe02511-9b12-4274-9d1a-39e597d7fe3a
```

Status: PASS.

### FF-02 — natural-language MCP client acceptance

Natural user request through Claude:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

The MCP client generated:

```text
start:            2026-09-09T09:00:00+02:00
end:              2026-09-09T18:00:00+02:00
duration_minutes: 60
calendar_id:      primary
```

The connected primary calendar was empty for that window. Claude correctly reported that the whole 09:00–18:00 range was free and that a one-hour slot could be placed anywhere inside it.

Observed production chain:

```text
Claude
 -> MCP Server
 -> find_free_time
 -> MCP — Find Free Time
 -> Google Calendar FreeBusy
 -> Calculate free time
 -> Audit success
 -> Claude
```

Status: PASS.

### FF-03 — audit evidence

The real production audit row for the accepted request contained:

```text
tool_name:        find_free_time
status:           succeeded
duration_ms:      640
start:            2026-09-09T09:00:00+02:00
end:              2026-09-09T18:00:00+02:00
duration_minutes: 60
calendar_id:      primary
```

Status: PASS.

Detailed workflow-specific evidence is also stored in `docs/FIND_FREE_TIME_ACCEPTANCE.md`.

## Temporary smoke workflow cleanup

Low-level `get_calendar_events` success/error tests used a temporary manual-trigger clone so the production sub-workflow did not need test-only trigger changes. The temporary workflow was deactivated and archived after testing.

## Gateway regression discovered on 2026-09-08

After `find_free_time` E2E acceptance, direct production inspection showed that the current published `MCP — Server` contains `find_free_time` but no longer contains the previously accepted `get_calendar_events` node.

Current published MCP tool surface at inspection time:

```text
find_free_time
get_email_attachment
get_github_file
get_job_details
get_recent_jobs
read_drive_file
search_drive_files
search_emails
```

Therefore:

- `get_calendar_events` sub-workflow acceptance remains valid;
- `find_free_time` acceptance remains valid;
- the aggregate M2 gateway is not considered complete until both Calendar tools are restored in the same published MCP Server version and regression-tested together.

Recovery is documented in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

## Final status

Both read-only Calendar sub-workflows are individually implemented and accepted.

M2 Calendar gateway status: **recovery pending** because the current published `MCP — Server` must restore `get_calendar_events` alongside `find_free_time` before the milestone can be closed.
