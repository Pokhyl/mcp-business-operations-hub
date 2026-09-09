# Google Calendar Workflow Acceptance

Last verified: 2026-09-09.

Credential: `Google Calendar MCP readonly`

OAuth scope:

```text
https://www.googleapis.com/auth/calendar.readonly
```

Accepted read-only Calendar workflows:

- `get_calendar_events` -> `MCP — Calendar Events` (`IUpcFPRH3xOVbgEq`)
- `find_free_time` -> `MCP — Find Free Time` (`dDiqHH9C5clOrYOX`)

Both are exposed simultaneously through active `MCP — Server` version:

```text
07843872-4ab5-46f1-8df9-9a6bc8418673
```

## `get_calendar_events`

Inputs:

```json
{
  "start": "RFC3339 timestamp with timezone",
  "end": "RFC3339 timestamp with timezone",
  "calendar_id": "optional string, default primary",
  "limit": "optional integer, default 50, range 1..2500"
}
```

Errors use `INVALID_INPUT`, `NOT_FOUND`, or `UPSTREAM_ERROR`.

Execution flow:

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

Accepted cases:

- invalid input -> `INVALID_INPUT` before audit/provider access;
- valid primary-calendar window -> normalized success;
- nonexistent calendar -> provider 404 -> `NOT_FOUND`;
- succeeded and failed audit rows finalize with non-null duration;
- natural week, month, and year prompts through Claude;
- post-recovery natural-language regression request through the recovered aggregate MCP Server.

Final post-recovery request on 2026-09-09:

```text
Что у меня завтра в календаре?
```

Resolved arguments:

```text
start:       2026-09-10T00:00:00+02:00
end:         2026-09-11T00:00:00+02:00
calendar_id: primary
limit:       50
```

Claude reported no events. The real primary calendar was empty, so the response matched source of truth.

Audit evidence:

```text
tool_name:   get_calendar_events
status:      succeeded
duration_ms: 606
```

Status: PASS.

## `find_free_time`

Inputs:

```json
{
  "start": "RFC3339 timestamp with timezone",
  "end": "RFC3339 timestamp with timezone",
  "duration_minutes": "positive integer, default 30",
  "calendar_id": "optional string, default primary"
}
```

The workflow calls:

```text
POST https://www.googleapis.com/calendar/v3/freeBusy
```

It checks `calendars[calendar_id].errors` even on HTTP 200, merges overlapping/touching busy intervals, calculates maximal free windows, and filters out windows shorter than `duration_minutes`.

Execution flow:

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

Initial natural-language acceptance on 2026-09-08 passed for a 60-minute slot between 09:00 and 18:00; audit `succeeded`, `duration_ms=640`.

Final post-recovery request on 2026-09-09:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

Resolved arguments:

```text
start:            2026-09-10T09:00:00+02:00
end:              2026-09-10T18:00:00+02:00
duration_minutes: 60
calendar_id:      primary
```

Claude reported the full 09:00–18:00 range as available. The real primary calendar was empty, so the result matched source of truth.

Audit evidence:

```text
tool_name:   find_free_time
status:      succeeded
duration_ms: 450
```

Status: PASS.

Detailed workflow evidence is also stored in `docs/FIND_FREE_TIME_ACCEPTANCE.md`.

## Aggregate MCP Server regression

On 2026-09-08, after `find_free_time` was added, direct inspection found that `get_calendar_events` had disappeared from the aggregate MCP Server surface.

The issue was repaired by restoring `get_calendar_events`, republishing the server, and synchronizing `n8n/MCP_SERVER.json`.

Direct production inspection on 2026-09-09 confirmed both Calendar tools are present together and connected to `MCP Server Trigger`. The two post-recovery natural-language tests above both passed and produced completed successful audit rows.

The regression is closed in:

```text
docs/MCP_SERVER_REGRESSION_2026-09-08.md
```

## Final status

Google Calendar M2 acceptance is complete.

Both `get_calendar_events` and `find_free_time` are implemented, published, exposed simultaneously through the same active MCP Server version, audited, and verified through post-recovery natural-language E2E testing.
