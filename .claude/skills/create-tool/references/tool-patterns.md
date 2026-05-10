# Tool Patterns

Five patterns. All compile to the same external shape (one tool the consumer calls). They differ in what runs inside.

---

## 1. Simple

**Internal**: One API call. Input mapped directly to request, response wrapped in the standard envelope.

**Pick when**: One endpoint maps cleanly to one tool. No branching, no internal LLM.

**Gather**:
- Endpoint: HTTP method, path template (e.g. `POST /chat.postMessage`), required headers
- Input fields: name, type, description, required/optional, defaults, enum constraints
- Output shape: which fields the consuming agent will care about
- Auth scheme + env var name

---

## 2. Composite (rule-based)

**Internal**: Picks one of N actions via deterministic rules over the input. The decision is code, not an LLM.

**Pick when**: 2–N related endpoints, branching is "if input contains/equals/matches X, call A; else call B." The rules are stable and don't need judgment.

**Gather**:
- The unified input schema — superset of all child operations' inputs (anything not used by a given operation just passes through unmapped)
- For each child operation:
  - Operation slug (e.g. `send-text`, `send-rich`)
  - The underlying endpoint (method + path)
  - Per-field parameter mapping: `unified_field → operation_field`
  - Priority (lower runs first when multiple rules match)
- Routing rules: each is `(condition_type, field, value, case_sensitive?, priority?, target_operation)`
  - condition_type: one of `contains`, `equals`, `matches` (regex), `starts_with`, `ends_with`
- Default operation slug (used if no rule matches)

---

## 3. Composite (agent-driven)

**Internal**: The agent calling the tool fills in an `operation` field; the tool dispatches to that operation.

**Pick when**: 2–N related endpoints, the calling agent has the context to know which to use. Cheaper than agentic — no internal LLM call.

**Gather**:
- Same unified input schema as rule-based, plus a top-level field: `operation: Literal["op_a", "op_b", ...]` (required)
- For each operation: same as rule-based (slug, endpoint, parameter mapping)

---

## 4. Agentic (parameter interpreter)

**Internal**: Embedded LLM translates a natural-language `task` plus optional structured fields into precise API params. Then calls one target action.

**Pick when**: The consumer cannot reasonably construct the params themselves — SQL queries, GraphQL, complex search filters, domain-specific syntax. The translation is the value.

**Gather**:
- Target action(s): the underlying endpoint(s) the LLM may call. Usually one.
- Embedded LLM config:
  - `provider`: `anthropic` | `google` | `openai`
  - `model`: e.g. `claude-sonnet-4-6`, `gemini-2.5-pro`, `gpt-4o`
  - `temperature` (default 0.2 — low for translation)
  - `max_tokens` (default 4000)
  - `reasoning_level` (optional, where supported): `none` | `low` | `medium` | `high`
- System prompt with `{{variable}}` placeholders. Standard placeholders:
  - `{{user_input}}` — the NL task
  - `{{integration_schema}}` — table/field/type reference
  - `{{reference_data}}` — valid values, options
- Safety limits: `max_total_cost_usd` (default 1.0), `timeout_seconds` (default 300)

---

## 5. Agentic (autonomous agent)

**Internal**: Embedded LLM with a tool-use loop over a set of available actions. Runs until done or limits hit.

**Pick when**: Goal-oriented work — "find competitor pricing for top 3 competitors", "triage this incident across these systems." The internal LLM sequences tool calls.

**Gather**:
- Available tools: list of underlying actions, each with its own description (the inner LLM picks among these)
- Embedded LLM config (same as parameter interpreter)
- System prompt with `{{user_input}}`, `{{available_tools}}`, optionally `{{reference_data}}`
- Safety limits: `max_tool_calls` (default 10), `timeout_seconds` (default 300), `max_total_cost_usd` (default 1.0)
- Output shape: what the inner agent should ultimately return

---

## 6. Pipeline

**Internal**: Sequential ordered steps. Each step is a tool call; optionally an LLM-as-JSON-producer reasoning step runs between/before tool calls.

**Pick when**: A multi-step workflow with deterministic ordering. "Search, then for each result fetch, then summarize."

**Gather**:
- Pipeline input schema
- Steps in order (max ~20). Each step:
  - `name`, `slug`, `step_number`
  - `tool` — one of: a Simple/Composite/Agentic tool, or `null` for reasoning-only
  - `input_mapping` — template strings using `{{input.field}}` and `{{step1.output.field}}`
  - `condition` (optional): expression + `skip_when: truthy | falsy`
  - `on_error`: `fail_pipeline` | `continue` | `skip_remaining`
  - `retry_config`: `max_retries`, `backoff_ms`
  - `timeout_seconds`
  - For reasoning steps: `reasoning_prompt`, `reasoning_config` (LLM provider/model + expected output JSON schema)
- Output mapping — final pipeline output as `{ field: source }` where source references step outputs
- Safety limits: `max_cost_usd` (default 5), `max_duration_seconds` (default 1800)

---

## Decision flow

```
Is there an internal LLM?
├─ No
│  ├─ One endpoint? → Simple
│  └─ Multiple endpoints?
│     ├─ Branching expressible as rules? → Composite rule-based
│     ├─ Agent should pick? → Composite agent-driven
│     └─ Strict ordering with data flow? → Pipeline
└─ Yes
   ├─ Translate NL → params for ONE action? → Agentic (parameter interpreter)
   ├─ Goal-oriented across multiple tools? → Agentic (autonomous)
   └─ Reasoning between deterministic steps? → Pipeline (with reasoning steps)
```

When in doubt, prefer simpler — Simple < Composite < Agentic < Pipeline in cost, latency, and debugging difficulty.

---

## Cross-cutting requirements

These apply to every pattern:

- **Auth via env var**, never hard-coded
- **`httpx` with explicit timeout** for HTTP
- **Response envelope** wraps every result (success and error)
- **Mini-prompt description** required (see `universal-description-format.md`)
- **Flat input schema** (see `schema-flattening.md`)
- **Portability**: no imports outside `tools/<slug>/`
