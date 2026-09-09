# Find Free Time Acceptance

Last verified: 2026-09-09.

Workflow: `MCP — Find Free Time`

Workflow ID: `dDiqHH9C5clOrYOX`

Status: published, active, exposed through `MCP — Server`, and accepted end to end.

Credential: `Google Calendar MCP readonly`

OAuth scope:

```text
https://www.googleapis.com/auth/calendar.readonly
```

## Public contract

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

- `start` and `end` require an explicit timezone or `Z`.
- `end` must be later than `start`.
- `duration_minutes` defaults to `30`, must be a positive integer, and must fit inside the requested window.
- `calendar_id` defaults to `primary`.
- `INVALID_INPUT` is rejected before audit/provider access.

## Provider implementation

The workflow calls Google Calendar FreeBusy:

```text
POST https://www.googleapis.com/calendar/v3/freeBusy
```

Google FreeBusy can report calendar-specific errors inside an HTTP 200 response, so the workflow checks `calendars[calendar_id].errors` before calculating free time.

## Execution flow

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

`arguments_json` is supplied only on `Audit start`. `Audit success` and `Audit failed` omit it.

## Free-window calculation

The workflow:

1. clips busy intervals to the requested range;
2. sorts them by start time;
3. merges overlapping/touching intervals;
4. derives maximal free windows;
5. returns only windows at least `duration_minutes` long.

## Initial natural-language acceptance — 2026-09-08

Natural request through Claude:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

Resolved arguments:

```text
start:            2026-09-09T09:00:00+02:00
end:              2026-09-09T18:00:00+02:00
duration_minutes: 60
calendar_id:      primary
```

The primary calendar was empty, so the full 09:00–18:00 interval was returned as free.

Audit evidence:

```text
tool_name:   find_free_time
status:      succeeded
duration_ms: 640
```

Status: PASS.

## Post-recovery gateway regression acceptance — 2026-09-09

After the aggregate MCP Server regression was repaired, the same natural-language intent was tested again through Claude against the recovered MCP Server version `07843872-4ab5-46f1-8df9-9a6bc8418673`.

Natural request:

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

Claude reported the full 09:00–18:00 range as available. The real primary calendar was empty, so the response matched source of truth.

Production audit evidence:

```text
tool_name:   find_free_time
status:      succeeded
duration_ms: 450
```

Status: PASS.

## Export

Accepted workflow export:

```text
n8n/calendar/FIND_FREE_TIME.json
```

## Final status

`find_free_time` is fully accepted for M2: workflow publication, provider behavior, free-window calculation, audit lifecycle, MCP Server exposure, and post-recovery natural-language client behavior are verified.

The aggregate Calendar gateway regression is closed in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.
