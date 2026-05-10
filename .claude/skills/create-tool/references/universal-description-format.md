# Universal Tool Description Format (Mini-Prompt)

Every tool description follows this structure. Inconsistent formats degrade tool-call quality across LLM providers.

## The structure

```
Use this tool to {one sentence — what the tool does in actionable terms, not what it "is"}.

# Required inputs:
- {input_name}: {description, constraints, and any shaping guidance}

# Optional inputs:
- {input_name}: {description, with "(include when X)" or "(required when operation=Y)" if conditional}

# What the tool outputs:
{One-line, high-level description of the result.}
```

**Required vs Optional is determined by what's required across all calls of the tool**, not by what's required for a particular operation. A field that's only required for one operation of a composite tool goes in the **Optional** list, with a parenthetical: `(required when operation="reply")`.

This keeps the description readable. Splitting required by operation produces a wall of conditional sections that's hard for the LLM to scan.

## Rules

- **First line is "Use this tool to ..."**. Imperative. Verb first. Don't say "This tool sends..."; say "Use this tool to send..."
- **One Required list, one Optional list**. Conditional requirements live as parentheticals on Optional fields, not as their own sections.
- **Every input gets a description.** State constraints (length, format), defaults, and any external references the agent should resolve.
- **Add shaping guidance for fields where authoring matters.** If there's a non-obvious norm that improves quality, say so right next to the field. Examples:
  - Email `body` → "Prefer HTML formatting (basic tags: <p>, <strong>, <ul>, <a>) for legibility."
  - SQL `query` → "Bias to `ILIKE '%term%'` for text matches over `=`; users rarely know exact stored values."
  - Search `query` → "Combine operators (from:, subject:, newer_than:) with AND/OR for precision."
  - File `path` → "Always absolute. Relative paths are interpreted relative to the tenant root."
  - Channel `name` → "Resolve human-readable names like '#general' via the list-channels tool first."
- **Output section is one line.** High-level — "returns the sent message details" or "returns matching records." Don't enumerate per-operation output shapes; the structured `data` field tells the agent what's there.
- **Keep under 2000 characters total.** Trim verbose constraints, not field descriptions.
- **No marketing language.** The audience is a model deciding when to call this tool, not a human evaluating a feature.

## Concrete example

```
Use this tool to send a message to a Slack channel or user.

# Required inputs:
- channel: The Slack channel ID (starts with 'C') or user ID (starts with 'U'). If you only have a name like "#general" or "@sarah", resolve it via slack_list_channels first.
- text: The message content. Use Slack mrkdwn for emphasis (*bold*, _italic_, `code`). Keep professional and concise unless the surrounding context suggests otherwise.

# Optional inputs:
- blocks: Slack Block Kit blocks for rich formatting (include only when you need buttons, images, or structured layouts — not for plain text).
- thread_ts: Parent message timestamp (include to reply in-thread; omit for top-level posts).

# What the tool outputs:
Returns the sent message details, including the message timestamp you can use to reply in-thread or update later.
```

## Composite tool example (single Required + parentheticals)

```
Use this tool to send, read, or reply to Gmail emails.

# Required inputs:
- operation: One of "send", "read", "reply".

# Optional inputs:
- to: Recipient email(s), comma-separated (required when operation="send").
- subject: Email subject line (required when operation="send").
- body: Plain-text or HTML email body — prefer simple HTML (<p>, <strong>, <ul>, <a>) for legibility (required when operation="send" or "reply").
- query: Gmail search query like "from:alice unread" or "subject:invoice newer_than:7d" (required when operation="read" unless message_id is given). Combine operators with AND/OR.
- message_id: A specific Gmail message ID (required when operation="reply"; for operation="read" provide either this or query).
- cc, bcc: Comma-separated addresses (send/reply only).
- max_results: How many messages to fetch for read-by-query (default 10, max 50; lower is faster).
- include_body: Whether to fetch full message bodies for read-by-query (default true; set false for header-only listings to save tokens).
- quote_original: Prepend the original message as a quote in the reply body (default false).

# What the tool outputs:
For send/reply, returns the new message and thread IDs. For read, returns one or more messages with subject, sender, date, and (optionally) body.
```

Note how `to`, `subject`, `body`, `query`, `message_id` are all in the Optional list with parentheticals — that's the pattern. The agent reads it once and learns the conditional structure.

## Where this string is used

The same description string is the:
- LangChain `StructuredTool` `description=`
- MCP `Tool.description` returned in `list_tools`
- Top-level `__doc__` on the exposed callable

Generate it once, store as `DESCRIPTION` in `tool.py`, import everywhere else.

## Composite/agentic notes

The description describes the *outer* tool the consumer sees, not the internal operations.

- For composite tools, describe the unified behavior. The `operation` field is just another input — describe what each value means in its line under Required.
- For agentic tools, describe the goal the consumer can express. The consumer doesn't need to know an LLM is embedded.
- For pipelines, describe the end-to-end behavior, not the steps.
