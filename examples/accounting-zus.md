# Example — Find ZUS payment from Gmail

## Prompt

```text
Find the latest email about ZUS for August and tell me the amount and due date.
```

## Expected tool behavior

1. Claude chooses `search_emails`.
2. Tool receives a Gmail-compatible query and a small result limit.
3. n8n searches matching messages.
4. n8n fetches each complete message.
5. Workflow returns normalized plain text.
6. Claude extracts the requested amount/date from the evidence.

## What this demonstrates

- natural-language-to-tool translation
- OAuth2-backed Gmail access
- full message retrieval rather than truncated snippets
- response normalization
- source-grounded business reasoning
