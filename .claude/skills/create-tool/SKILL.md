---
name: create-tool
description: "Build a deployable AI tool from an API integration. Output is portable Python under tools/<slug>/ — works as a LangChain StructuredTool (LangGraph-compatible) and runs as an MCP server. Picks one of five patterns (Simple, Composite rule-based, Composite agent-driven, Agentic, Pipeline) based on the integration shape and the user's goal. Triggers on 'create a tool', 'build a tool from this API', 'wrap this endpoint as a tool', 'make a tool for X', '/create-tool', or when a user describes a goal that needs an LLM-callable function backed by HTTP API(s). Do NOT use for non-tool features (use /build) or for editing existing tools (just edit the file)."
user-invocable: true
---

# Create AI Tool

Turn an API integration into a deployable AI tool. The output is a self-contained Python package under `tools/<slug>/` that:

- Imports as a LangChain `StructuredTool` (works in LangGraph agents)
- Runs as an MCP server (`python -m tools.<slug>.mcp_server`)
- Has zero imports outside its own folder — copy the dir into another repo, install its `requirements.txt`, done

**One invocation = one tool.** A single tool may internally wrap multiple API endpoints (composite/agentic/pipeline) — but the output is one folder under `tools/`.

---

## The five patterns

All five compile to the same external shape (one tool the consumer calls). They differ in what runs inside.

| Pattern | Internal behavior | Pick when |
|---|---|---|
| **Simple** | One API call, deterministic | One endpoint maps cleanly to one tool |
| **Composite rule-based** | Picks one of N actions via deterministic rules on input | 2–N related endpoints; routing expressible in code |
| **Composite agent-driven** | Picks one of N actions via an `operation` arg the agent fills in | 2–N related endpoints; the agent should choose |
| **Agentic (parameter interpreter)** | Embedded LLM translates NL → API params → calls one action | Consumer can't realistically construct precise params (SQL, GraphQL, complex filters) |
| **Agentic (autonomous agent)** | Embedded LLM loops over a tool set until done | Goal-oriented work ("find competitor pricing") that needs internal multi-step reasoning |
| **Pipeline** | Sequential steps with optional LLM reasoning between them | Multi-step workflow with deterministic ordering |

Full criteria + what each pattern needs to gather: [references/tool-patterns.md](references/tool-patterns.md).

---

## Phases

### Phase 1 — Intake

The user opens with a request. Capture it verbatim, then gather what you need. **Do not invent endpoints, params, or schema fields. If you don't know, ask.**

Required:
1. **Goal** — one or two sentences. What should this tool do for a calling agent?
2. **Integration name + base URL** (e.g. "Slack", `https://slack.com/api`)
3. **Auth scheme** — `bearer`, `api_key_header` (which header?), `basic`, `oauth2`, or `none`
4. **Endpoint(s) in scope** — accept any of:
   - Path to an OpenAPI/Swagger file (use Read)
   - URL to API docs (use WebFetch)
   - Inline list: method + path + brief description
   - User describes endpoints in prose
5. **Anything load-bearing not in docs** — rate limits, default values, gotchas

Ask focused clarifying questions before proceeding. Don't pile up assumptions.

### Phase 2 — Pattern recommendation

Pick ONE pattern. Tell the user which, in 2–3 sentences why, and name the closest alternative in case they want to redirect. Wait for confirmation.

Default biases:
- One endpoint → **Simple**
- N endpoints, all the same resource type, branching is "if input contains X call A, else call B" → **Composite rule-based**
- N endpoints, branching is "the agent knows which to use" → **Composite agent-driven**
- One endpoint but param construction is a translation problem (NL→SQL, NL→search query) → **Agentic parameter interpreter**
- Open-ended goal across multiple tools → **Agentic autonomous**
- Fixed multi-step recipe → **Pipeline**

When in doubt, prefer simpler. Composite < Agentic < Pipeline in implementation cost and per-call latency/cost.

### Phase 3 — Detailed spec

For the chosen pattern, gather pattern-specific detail. See [references/tool-patterns.md](references/tool-patterns.md) for the full per-pattern checklist. Briefly:

- **Simple**: input fields (name/type/desc/required), endpoint template, output shape
- **Composite rule-based**: per-operation routing rule (`contains | equals | matches | starts_with | ends_with` on a unified input field), priorities, default operation
- **Composite agent-driven**: the `operation` enum + per-operation parameter mapping
- **Agentic (param interpreter)**: system prompt with `{{variable}}` placeholders, embedded LLM config, target action(s)
- **Agentic (autonomous)**: system prompt + safety limits (`max_tool_calls`, `timeout_seconds`, `max_total_cost_usd`)
- **Pipeline**: ordered steps with input mappings (`{{step1.output.field}}`) and optional reasoning prompts

### Phase 4 — Write descriptions, response templates, prompts

Generate these inline (you are the LLM — write them yourself, no API call needed):

- **Tool description** in mini-prompt format → [references/universal-description-format.md](references/universal-description-format.md). Mandatory structure.
- **Success response template** → [references/response-format.md](references/response-format.md). Includes `next_steps` for the consuming agent.
- **Error response template** → same reference. Includes `remediation` and `suggested_resolution { action, description, retryable, retry_after_ms }`.
- **System prompt** (agentic patterns only) → [references/prompt-templating.md](references/prompt-templating.md). Uses `{{user_input}}`, `{{integration_schema}}`, `{{reference_data}}`, `{{available_tools}}`.

### Phase 5 — Generate files

Default output: `tools/<tool-slug>/`. Slug is lowercase, hyphenated, derived from the tool name. If `tools/` doesn't exist, create it.

Each tool dir contains:

```
tools/<slug>/
├── __init__.py            # exports: tool_callable, INPUT_SCHEMA, DESCRIPTION
├── tool.py                # Pydantic models + execute() + DESCRIPTION + response templates
├── langchain_adapter.py   # def get_tool() -> StructuredTool
├── mcp_server.py          # python -m tools.<slug>.mcp_server
├── requirements.txt       # ONLY this tool's deps
└── README.md              # what it does, how to use, how to copy elsewhere
```

Use the per-pattern code skeletons in [references/code-skeletons.md](references/code-skeletons.md). They are concrete and complete — adapt names and bodies to the user's tool, but keep the structure.

**Hard rules** (these degrade tool quality if violated):

- **Portability**: no imports from outside `tools/<slug>/`. Not from a `common/` dir, not from the host project. The folder is a copy-paste unit.
- **Flat schema**: input schema must have no `$ref`, `oneOf`, `anyOf`, or `allOf`. Every property has explicit `type` and `description`. See [references/schema-flattening.md](references/schema-flattening.md).
- **Response envelope is mandatory**: success and error both return the full structured shape (see response-format.md). Never return raw API output.
- **Embedded LLM config** (agentic patterns) must specify provider, model, temperature, max_tokens. Safety limits must be set with sensible defaults if user didn't specify (`max_total_cost_usd: 1.0`, `timeout_seconds: 300`, `max_tool_calls: 10`).
- **Composite unified schema** is the merger of all child operations' inputs. For agent-driven, add an `operation: Literal[...]` discriminator field.
- **Auth via env vars only**. Never hard-code keys. Read from `os.environ` with a clear var name like `<INTEGRATION>_API_KEY`.
- **HTTP client**: use `httpx` with explicit `timeout=`. Always.
- **No host-project conventions**: don't import the host's logger, error classes, or config. Use stdlib `logging` and raise the tool's own typed exception.

### Phase 6 — Verify and hand off

After writing files:

1. List every file written with paths.
2. Show a 5-line "use it" snippet:
   ```python
   # LangGraph
   from tools.<slug>.langchain_adapter import get_tool
   agent = create_react_agent(model, [get_tool()])

   # MCP (in another shell)
   # python -m tools.<slug>.mcp_server
   ```
3. Tell the user to `pip install -r tools/<slug>/requirements.txt` before first use.
4. Suggest a smoke test: `python -m tools.<slug>.mcp_server` (it should start and listen on stdio).
5. **Do not** update changelog/project_status — that's outside this skill's scope.

---

## When to stop and ask

- The user gave a goal but no endpoint → ask.
- An endpoint takes a complex object (nested arrays, polymorphic types) → ask the user to describe the canonical shape, don't guess.
- The user said "agentic" but the goal looks deterministic → propose Simple/Composite, explain the cost difference, let them choose.
- The integration uses an unusual auth flow (signed requests, mTLS) → ask before generating, since the auth helper isn't standard.

## Anti-patterns to avoid

- Don't generate a "facade" file in `tools/__init__.py` that imports every tool. Keep tools independent.
- Don't add a `common/` or `shared/` dir under `tools/`. Each tool duplicates the small amount of envelope/HTTP boilerplate it needs. That's the price of portability.
- Don't write integration tests against the live API in this skill — that's a separate concern. Note in the README that the user should add tests.
- Don't try to discover endpoints via the API itself. If the user can't tell you what endpoint to call, the tool spec isn't ready.
