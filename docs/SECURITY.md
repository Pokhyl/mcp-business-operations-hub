# Security

## Threat model

The MCP client is intentionally not given direct credentials for Gmail, GitHub, PostgreSQL, Drive, Calendar, or CRM systems. It can only call explicitly exposed tools.

## Principles

### 1. Least privilege

Each integration uses a credential scoped to the minimum required permissions.

Current examples:

- PostgreSQL MCP role: read-only access for the required tables.
- Gmail MCP capability: message search/read only at the workflow layer.
- GitHub tool: file read operation only.

### 2. Credentials are not source code

n8n workflow exports may contain credential references/names, but credential secrets themselves must never be committed.

The repository must never contain:

- OAuth client secrets
- OAuth refresh/access tokens
- GitHub personal access tokens
- database passwords
- n8n encryption keys
- API keys

### 3. Read/write separation

Read tools and state-changing tools are separate MCP tools.

Write tools must not be added by extending a read tool with hidden side effects.

### 4. Explicit approval for mutations

Future tools that modify external state require explicit user approval at the MCP client boundary.

Examples:

- sending email
- creating or deleting calendar events
- updating CRM records
- writing files

### 5. Input validation

Tool inputs must be validated before they reach external APIs or SQL.

Database tools use parameterized queries. User-provided values must never be concatenated into SQL strings.

### 6. Auditability

Every production tool call should record:

- tool name
- sanitized arguments
- source/client identifier where available
- start timestamp
- completion timestamp
- success/failure status
- execution duration
- normalized error code

Sensitive values should be redacted before audit storage.

## Error model target

Normalized error codes:

```text
AUTH_ERROR
INVALID_INPUT
NOT_FOUND
RATE_LIMIT
TIMEOUT
UPSTREAM_ERROR
INTERNAL_ERROR
```

Provider-specific stack traces should remain in internal logs and not be exposed blindly to the MCP client.
