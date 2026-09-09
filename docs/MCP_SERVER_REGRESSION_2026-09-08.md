# MCP Server Calendar Regression — 2026-09-08

Status: CLOSED on 2026-09-09.

## Summary

During post-acceptance inspection for `find_free_time`, the published production `MCP — Server` was found to contain `find_free_time` but to have lost the previously accepted `get_calendar_events` tool node.

This was an aggregate MCP gateway regression, not a failure of either Calendar sub-workflow.

## Recovery

The missing `get_calendar_events` tool node was restored with its previously accepted configuration and `MCP — Server` was republished.

Recovered production MCP Server:

```text
workflow: MCP — Server
workflow_id: dSohghXnQp078EZm
active: true
version_id: 07843872-4ab5-46f1-8df9-9a6bc8418673
active_version_id: 07843872-4ab5-46f1-8df9-9a6bc8418673
```

The published Calendar surface now contains both:

```text
get_calendar_events
find_free_time
```

Direct production inspection verified both tool nodes are connected to `MCP Server Trigger`.

`n8n/MCP_SERVER.json` was synchronized with this recovered published production surface.

## Post-recovery regression acceptance

Final natural-language checks were run through Claude against the recovered aggregate MCP Server on 2026-09-09.

### `get_calendar_events`

Natural request:

```text
Что у меня завтра в календаре?
```

Claude invoked the MCP integration and reported that 2026-09-10 contained no events. This matched the real primary calendar.

Production audit evidence:

```text
tool_name:   get_calendar_events
status:      succeeded
duration_ms: 606
start:       2026-09-10T00:00:00+02:00
end:         2026-09-11T00:00:00+02:00
calendar_id: primary
limit:       50
```

Status: PASS.

### `find_free_time`

Natural request:

```text
Найди мне завтра свободное окно на 60 минут с 9:00 до 18:00.
```

Claude invoked `find_free_time` and reported that the full 09:00–18:00 window was free. This matched the real empty primary calendar.

Production audit evidence:

```text
tool_name:        find_free_time
status:           succeeded
duration_ms:      450
start:            2026-09-10T09:00:00+02:00
end:              2026-09-10T18:00:00+02:00
calendar_id:      primary
duration_minutes: 60
```

Status: PASS.

## Closure

The original regression condition is no longer present:

- both Calendar tools exist simultaneously in the same active published MCP Server version;
- both are connected to the MCP trigger;
- the production export is synchronized in GitHub;
- both natural-language post-recovery regression tests passed;
- both calls created successful completed audit rows.

This regression is closed. M2 — Google Workspace expansion is complete.
