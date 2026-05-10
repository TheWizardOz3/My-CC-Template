# Response Format

Every tool returns a structured envelope. Never the raw API response. The shape is identical across all five patterns.

## Success envelope

```python
{
    "success": True,
    "message": str,                    # Human/agent-readable summary, 1–3 sentences
    "data": dict,                      # The actual response payload (or filtered subset)
    "meta": {
        "action": str,                 # Tool/operation name, e.g. "slack_send_message"
        "integration": str,            # Integration slug, e.g. "slack"
        "request_id": str,             # UUID, generated per call
        "latency_ms": int,
    },
    "context": {
        "resolved_inputs": dict,       # Only fields where input was transformed
                                       # e.g. {"channel": {"original": "#general", "resolved": "C0123"}}
    },
    "next_steps": str,                 # Multi-line guidance for the consuming agent
}
```

`message` is a short summary. `data` is the full record of what happened. `next_steps` is for the agent — what to say and what it can do next.

### The visibility principle (most important rule for `data`)

**Tool calls are invisible to the calling agent except via this response.** The agent never sees the HTTP request body, the rendered email, the SQL it ran, or the file it wrote. If the agent needs to relay what happened to the user — or audit it later — the response is its only window.

So `data` must contain a complete record of the action, including any content the agent supplied as input. For write/send operations especially:

- Send an email → `data` includes `to`, `subject`, `body`, `cc`, `bcc` that were actually sent (post-normalization), not just `{message_id, thread_id}`.
- Write a row → `data` includes the full row that was written, not just the new ID.
- Run a SQL query → `data` includes the SQL string that was executed, not just the result rows.
- Post a Slack message → `data` includes the rendered text/blocks, not just the timestamp.

For read operations, `data` already contains the artifact the agent asked about — that's table stakes. The principle bites hardest on writes, where it's tempting to return just the new ID.

Redact secrets here too — same rules as `attempted_inputs` in errors.

### `next_steps` guidance

Two categories of content:

1. **What the agent should say in its reply** — written to work whether the user asked for this directly OR as part of a larger task.
2. **What the agent might do next** — using returned IDs, timestamps, etc.

The canonical "In your response" line:

> Confirm the {action} was completed and share what was done in full so the user can verify. If this was part of a larger task the user gave you, proceed with the next step as instructed.

"Share what was done in full" — not "share the recipient and subject" or "share the channel name." The agent should be able to relay the actual artifact (the email body, the message text, the row written) by reading `data`. Phrase `next_steps` to point at the full content, since that's the only way the user can sanity-check what an invisible action actually did.

Example:
```
## In your response:
Confirm the email was sent and share what was sent in full (to, subject, body, any cc/bcc) so the user can verify. If this was part of a larger task the user gave you, proceed with the next step as instructed.

## You can:
- Reply in-thread using thread_id: 18f3a2b1c4d5e6f7
- Update or delete this message using message_id: 18f3a2b1c4d5e6f7
```

## Error envelope

```python
{
    "success": False,
    "message": str,                    # What went wrong, plain language
    "error": {
        "code": str,                   # SCREAMING_SNAKE_CASE, e.g. "CHANNEL_NOT_FOUND"
        "details": dict,               # Specific error details
        "suggested_resolution": {
            "action": str,             # short verb phrase, e.g. "verify channel name"
            "description": str,        # 1–2 sentences explaining
            "retryable": bool,         # whether retrying makes sense
            "retry_after_ms": int,     # required when retryable=True for rate limits, else null
        },
    },
    "meta": {
        "action": str,
        "integration": str,
        "request_id": str,
    },
    "context": {
        "attempted_inputs": dict,      # the inputs that were tried (redact secrets)
    },
    "remediation": str,                # Multi-line guidance for the agent
}
```

### `remediation` guidance

One short, plain-prose paragraph telling the agent what to do. No headings, no taxonomy, no separate "fix" vs "tell the user" modes — just one consolidated message.

**The one rule that matters: don't instruct the agent to do something it can't actually do.** Agents can retry, change inputs, pick different tools, and ask the user for help. Agents cannot refresh OAuth tokens, add themselves to channels, change permissions, wait an hour, or contact support. When the resolution requires a human, say so and tell the agent to skip the step and inform the user.

Mix retry advice and "tell the user" advice in the same paragraph as needed. Examples:

```
# AUTH_INVALID_TOKEN
This requires the user to re-authenticate Gmail — agents can't refresh tokens. Skip this step and tell the user the Gmail integration needs to be reconnected. Complete any other parts of their task that don't depend on Gmail.
```

```
# RESOURCE_NOT_FOUND on a message_id
The message_id may be a typo — verify it. If you don't have a known-good ID, run operation=read with a query first to find the right message. If you've already tried that and still see this error, the message may have been deleted; tell the user.
```

```
# RATE_LIMITED with retry_after_ms=2000
Wait 2 seconds and retry once. If it fails again, reduce max_results. If repeated retries keep failing, tell the user Gmail is rate-limiting and to try again shortly.
```

```
# VALIDATION_MISSING_FIELDS (subject, body)
Provide the missing fields and retry. If you don't have the values and can't reasonably infer them from the user's request, ask the user before retrying.
```

What never to write: "Refresh the access token" (agent can't), "Add the bot to the channel" (agent can't), "Wait an hour and retry" (agent's lifetime is shorter), "Contact support" (agent can't — but it can tell the user to).

## Error code conventions

- SCREAMING_SNAKE_CASE
- Prefix with the failure category when ambiguous: `AUTH_INVALID_KEY`, `RATE_LIMITED`, `RESOURCE_NOT_FOUND`, `VALIDATION_INVALID_FIELD`, `UPSTREAM_TIMEOUT`, `UPSTREAM_5XX`
- Make codes specific: `CHANNEL_NOT_FOUND` beats `NOT_FOUND` for the agent

## Implementation pattern

Build a small helper inside `tool.py`:

```python
import uuid, time
from typing import Any

def _ok(action: str, integration: str, data: dict, message: str,
        next_steps: str, latency_ms: int,
        resolved_inputs: dict | None = None) -> dict:
    return {
        "success": True,
        "message": message,
        "data": data,
        "meta": {
            "action": action,
            "integration": integration,
            "request_id": str(uuid.uuid4()),
            "latency_ms": latency_ms,
        },
        "context": {"resolved_inputs": resolved_inputs or {}},
        "next_steps": next_steps,
    }

def _err(action: str, integration: str, code: str, message: str,
         details: dict, attempted_inputs: dict, remediation: str,
         retryable: bool = False, retry_after_ms: int | None = None,
         resolution_action: str = "review error and adjust",
         resolution_description: str = "") -> dict:
    return {
        "success": False,
        "message": message,
        "error": {
            "code": code,
            "details": details,
            "suggested_resolution": {
                "action": resolution_action,
                "description": resolution_description,
                "retryable": retryable,
                "retry_after_ms": retry_after_ms,
            },
        },
        "meta": {
            "action": action,
            "integration": integration,
            "request_id": str(uuid.uuid4()),
        },
        "context": {"attempted_inputs": attempted_inputs},
        "remediation": remediation,
    }
```

Wrap every API call's success/failure paths in `_ok` / `_err`. Don't return partial envelopes.

## Secret redaction

Before putting `attempted_inputs` in the error envelope, redact:
- Anything that looks like an API key, token, or password (key contains `key`, `token`, `password`, `secret`, `auth`)
- Any value longer than 200 chars (truncate to first 100 + "...")

Don't trust the user to mark fields sensitive — pattern-match on key names defensively.
