# Find Free Time Acceptance

Last verified: 2026-09-08.

Workflow: `MCP — Find Free Time`

Workflow ID: `dDiqHH9C5clOrYOX`

Status: published and active.

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

- `start` and `end` must be RFC3339 timestamps with an explicit timezone or `Z`.
- `end` must be later than `start`.
- `duration_minutes` defaults to `30`, must be a positive integer, and must fit inside the requested time window.
- `calendar_id` defaults to `primary`.
- `INVALID_INPUT` is rejected before audit/provider access.

## Provider implementation

The workflow calls Google Calendar FreeBusy rather than loading full event objects:

```text
POST https://www.googleapis.com/calendar/v3/freeBusy
```

Request body:

```json
{
  "timeMin": "<start>",
  "timeMax": "<end>",
  "items": [
    { "id": "<calendar_id>" }
  ]
}
```

Google FreeBusy can report a calendar-specific error inside an HTTP 200 response, so the workflow checks `calendars[calendar_id].errors` before calculating free time.

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

1. parses and clips returned busy intervals to the requested search range;
2. sorts busy intervals by start time;
3. merges overlapping or touching busy intervals;
4. derives maximal free windows between merged busy intervals;
5. returns only free windows whose length is at least `duration_minutes`.

Successful response example:

```json
{
  "success": true,
  "data": [
    {
      "start": "2026-09-09T07:00:00.000Z",
      "end": "2026-09-09T16:00:00.000Z",
      "duration_minutes": 540
    }
  ],
  "meta": {
    "tool": "find_free_time",
    "count": 1,
    "calendar_id": "primary",
    "requested_duration_minutes": 60
  }
}
```

Errors use the standard MCP envelope with `INVALID_INPUT`, `NOT_FOUND`, or `UPSTREAM_ERROR`.

## Natural-language production acceptance

The tool was exposed through `MCP — Server` with all four inputs defined automatically by the MCP client.

Natural user request through Claude:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

Observed behavior:

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

Claude reported that 9 September 2026 was free from 09:00 to 18:00 and that any one-hour slot inside that range could be used. The connected primary calendar was actually empty, so this result matched the source of truth.

Database audit evidence:

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

## Export

The accepted workflow export is stored at:

```text
n8n/calendar/FIND_FREE_TIME.json
```

## Important MCP Server regression found during documentation

After the successful `find_free_time` E2E, production inspection showed that the currently published `MCP — Server` contains `find_free_time` but no longer contains the previously accepted `get_calendar_events` tool node.

This is a regression in the MCP gateway surface, not a failure of `find_free_time` itself. It is tracked separately in `docs/MCP_SERVER_REGRESSION_2026-09-08.md`.

M2 must not be marked complete until `get_calendar_events` is restored to the published MCP Server and both Calendar tools are regression-tested together.
