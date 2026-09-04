# Use Cases

## 1. Accounting lookup from Gmail

Prompt:

```text
Find the latest email about ZUS for August and tell me the amount and due date.
```

Tool path:

```text
search_emails
```

The tool searches Gmail, fetches full matching messages, and provides the body to the model for evidence-based extraction.

## 2. Diagnose a production job

Prompt:

```text
Why did the latest content job fail?
```

Tool path:

```text
get_recent_jobs
 -> get_job_details
```

This demonstrates multi-tool reasoning: first identify the relevant failed job, then request detailed evidence for that specific job.

## 3. Read repository state

Prompt:

```text
Read docs/CURRENT_STATE.md and summarize the current production state.
```

Tool path:

```text
get_github_file
```

## 4. Cross-system business question — target state

Prompt:

```text
Find the latest email from customer X, check their CRM record, and tell me whether they have a meeting this week.
```

Target tool path:

```text
search_emails
 -> search_customers
 -> get_calendar_events
```

This is the central portfolio goal: multiple independently authorized systems exposed through one MCP gateway with predictable tool contracts.
