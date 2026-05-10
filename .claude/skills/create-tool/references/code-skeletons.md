# Code Skeletons (Per Pattern)

Concrete Python skeletons. Adapt the names and bodies to the user's tool, but keep the structure. Each tool dir is self-contained — no imports from outside `tools/<slug>/`.

---

## Shared building blocks (every `tool.py` has these)

Inlined into each tool file — duplication is the price of portability.

### Envelope helpers

```python
import uuid
from typing import Any

def _redact(d: dict[str, Any]) -> dict[str, Any]:
    """Best-effort redaction for the error envelope."""
    sensitive = ("key", "token", "password", "secret", "auth", "bearer")
    out: dict[str, Any] = {}
    for k, v in d.items():
        if any(s in k.lower() for s in sensitive):
            out[k] = "***REDACTED***"
        elif isinstance(v, str) and len(v) > 200:
            out[k] = v[:100] + "..."
        else:
            out[k] = v
    return out

def _ok(*, action: str, integration: str, data: dict, message: str,
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

def _err(*, action: str, integration: str, code: str, message: str,
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
        "context": {"attempted_inputs": _redact(attempted_inputs)},
        "remediation": remediation,
    }
```

### HTTP helper (httpx with timeout + retry)

```python
import os, time, httpx, logging

log = logging.getLogger(__name__)

INTEGRATION = "<integration_slug>"  # set by code generator
BASE_URL = os.environ.get("<INTEGRATION>_BASE_URL", "<default>")
TIMEOUT_SECONDS = float(os.environ.get("<INTEGRATION>_TIMEOUT", "30"))

def _auth_headers() -> dict[str, str]:
    """Build auth headers from env vars. Adapt per auth scheme."""
    key = os.environ.get("<INTEGRATION>_API_KEY")
    if not key:
        raise RuntimeError("<INTEGRATION>_API_KEY env var is required")
    return {"Authorization": f"Bearer {key}"}

def _request(method: str, path: str, *,
             params: dict | None = None,
             json_body: dict | None = None) -> httpx.Response:
    url = f"{BASE_URL}{path}"
    with httpx.Client(timeout=TIMEOUT_SECONDS) as client:
        return client.request(method, url, params=params, json=json_body,
                              headers=_auth_headers())
```

### Schema flatness assertion (run at import time)

```python
import json
def _assert_flat(schema_dict: dict) -> None:
    s = json.dumps(schema_dict)
    for forbidden in ("$ref", "oneOf", "anyOf", "allOf", "definitions", "$defs"):
        assert forbidden not in s, f"Input schema contains forbidden key: {forbidden}"

_assert_flat(InputModel.model_json_schema())
```

---

## Pattern 1 — Simple tool

`tools/<slug>/tool.py`:

```python
"""<Tool Name> — Simple tool wrapping <integration>.<endpoint>."""
import json, time, logging
from typing import Literal
from pydantic import BaseModel, Field
# ... include _ok, _err, _redact, _request, _auth_headers from "Shared building blocks" above ...

ACTION = "<integration>_<verb>"     # e.g. "slack_send_message"
INTEGRATION = "<integration>"

DESCRIPTION = """\
Use this tool to <verb> a <resource> in <integration>.

# Required inputs:
- <field>: <description with constraints>

# Optional inputs (include when <condition>):
- <field>: <description>

# What the tool outputs:
<Description of returned shape, named key fields the agent can use to follow up.>
"""

class InputModel(BaseModel):
    field_a: str = Field(..., description="...")
    field_b: int = Field(0, description="...", ge=0)

# Run flatness check at import time
_assert_flat(InputModel.model_json_schema())

def execute(payload: dict) -> dict:
    parsed = InputModel.model_validate(payload)
    started = time.perf_counter()
    try:
        resp = _request("POST", "/<endpoint>", json_body=parsed.model_dump(exclude_none=True))
    except httpx.HTTPError as e:
        return _err(
            action=ACTION, integration=INTEGRATION,
            code="UPSTREAM_TIMEOUT" if isinstance(e, httpx.TimeoutException) else "UPSTREAM_ERROR",
            message=f"<integration> request failed: {e!s}",
            details={"exception": type(e).__name__},
            attempted_inputs=parsed.model_dump(),
            remediation=("## How to fix:\n"
                         "1. Verify <integration> is reachable.\n"
                         "2. Retry once after a short delay.\n"
                         "## If retried and still failing:\n"
                         "Skip this step and report the upstream issue."),
            retryable=True, retry_after_ms=2000,
            resolution_action="retry",
            resolution_description="Transient upstream failure — retry once.",
        )
    latency_ms = int((time.perf_counter() - started) * 1000)

    if resp.status_code >= 400:
        body = resp.json() if resp.headers.get("content-type", "").startswith("application/json") else {"raw": resp.text}
        return _err(
            action=ACTION, integration=INTEGRATION,
            code=f"UPSTREAM_{resp.status_code}",
            message=f"<integration> returned {resp.status_code}",
            details=body,
            attempted_inputs=parsed.model_dump(),
            remediation="<one-paragraph remediation specific to this endpoint's common failures>",
            retryable=resp.status_code >= 500 or resp.status_code == 429,
            retry_after_ms=int(resp.headers.get("Retry-After", "0")) * 1000 or None,
        )

    data = resp.json()
    return _ok(
        action=ACTION, integration=INTEGRATION,
        data=data,
        message=f"<one-line success summary using fields from data>",
        next_steps=("## In your response:\n"
                    "- <what the agent should say to the user>\n\n"
                    "## You can:\n"
                    "- <follow-on actions using returned IDs/timestamps>"),
        latency_ms=latency_ms,
    )
```

---

## Pattern 2 — Composite (rule-based)

Same imports + helpers as Simple. Differences:

```python
ACTION = "<integration>_<verb>"
INTEGRATION = "<integration>"

class UnifiedInput(BaseModel):
    """Superset of all child operation inputs."""
    target: str = Field(..., description="Target identifier")
    text: str | None = Field(None, description="Plain text body")
    blocks: list[dict] | None = Field(None, description="Structured blocks for rich content")
    # ... etc

_assert_flat(UnifiedInput.model_json_schema())

# Per-operation: (slug, method, path, mapping_fn, priority)
def _map_send_text(p: UnifiedInput) -> dict:
    return {"channel": p.target, "text": p.text}
def _map_send_rich(p: UnifiedInput) -> dict:
    return {"channel": p.target, "blocks": p.blocks}

OPERATIONS = {
    "send-text": ("POST", "/messages", _map_send_text),
    "send-rich": ("POST", "/messages", _map_send_rich),
}

# Routing rules: (condition_type, field, value, target_slug, priority)
RULES = [
    ("equals", "blocks_present", "true", "send-rich", 0),  # higher-priority first
]
DEFAULT_OP = "send-text"

def _eval_rule(cond: str, field_value, target_value: str, case_sensitive: bool = False) -> bool:
    if field_value is None:
        return False
    fv = str(field_value) if case_sensitive else str(field_value).lower()
    tv = target_value if case_sensitive else target_value.lower()
    if cond == "equals":     return fv == tv
    if cond == "contains":   return tv in fv
    if cond == "starts_with":return fv.startswith(tv)
    if cond == "ends_with":  return fv.endswith(tv)
    if cond == "matches":
        import re
        return re.search(target_value, str(field_value)) is not None
    return False

def _resolve_field(p: UnifiedInput, field: str):
    # Synthetic fields: 'blocks_present' → 'true'/'false'
    if field == "blocks_present":
        return "true" if p.blocks else "false"
    return getattr(p, field, None)

def _route(p: UnifiedInput) -> str:
    for cond, field, val, target, _prio in sorted(RULES, key=lambda r: r[4]):
        if _eval_rule(cond, _resolve_field(p, field), val):
            return target
    return DEFAULT_OP

def execute(payload: dict) -> dict:
    parsed = UnifiedInput.model_validate(payload)
    op = _route(parsed)
    method, path, mapper = OPERATIONS[op]
    body = mapper(parsed)
    # ...same HTTP call + envelope wrapping as Simple, including the chosen 'op' in next_steps...
```

---

## Pattern 3 — Composite (agent-driven)

Differs from rule-based only by adding an `operation` field to the unified schema and replacing the rule evaluator with a direct lookup:

```python
class UnifiedInput(BaseModel):
    operation: Literal["send-text", "send-rich"] = Field(
        ..., description="Which operation to run. 'send-text' for plain text. 'send-rich' for structured blocks."
    )
    target: str = Field(..., description="Target identifier")
    text: str | None = Field(None, description="Plain text body, required for send-text")
    blocks: list[dict] | None = Field(None, description="Block array, required for send-rich")

def execute(payload: dict) -> dict:
    parsed = UnifiedInput.model_validate(payload)
    method, path, mapper = OPERATIONS[parsed.operation]
    body = mapper(parsed)
    # ...same HTTP + envelope...
```

The DESCRIPTION should call out the `operation` field and what each value means.

---

## Pattern 4 — Agentic (parameter interpreter)

Embeds an LLM call to translate NL → params for a target action.

```python
import os, json, time
from anthropic import Anthropic  # or openai / google.genai per provider

# ... shared helpers ...

ACTION = "<integration>_query"
INTEGRATION = "<integration>"

EMBEDDED_LLM = {
    "provider": "anthropic",      # "anthropic" | "openai" | "google"
    "model": "claude-sonnet-4-6",
    "temperature": 0.2,
    "max_tokens": 4000,
}

SAFETY_LIMITS = {
    "max_total_cost_usd": 1.0,
    "timeout_seconds": 300,
}

SYSTEM_PROMPT = """\
# Role
You translate natural-language requests into <integration> API parameters.

# Available context
{{integration_schema}}

{{reference_data}}

# Task
The user has requested: {{user_input}}

# Output requirements
Produce a JSON object matching this schema:
{
  "<param>": "<type> — <description>"
}
Return ONLY the JSON. No prose, no fences.
"""

class InputModel(BaseModel):
    task: str = Field(..., description="Natural-language description of what to do")
    # Optional: include any structured fields the consumer might pass through directly

_assert_flat(InputModel.model_json_schema())

def _substitute(template: str, ctx: dict[str, str]) -> str:
    import re
    pattern = re.compile(r"\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}")
    return pattern.sub(lambda m: ctx.get(m.group(1), ""), template)

def _call_llm(system: str, user: str) -> str:
    if EMBEDDED_LLM["provider"] == "anthropic":
        client = Anthropic()
        resp = client.messages.create(
            model=EMBEDDED_LLM["model"],
            max_tokens=EMBEDDED_LLM["max_tokens"],
            temperature=EMBEDDED_LLM["temperature"],
            system=system,
            messages=[{"role": "user", "content": user}],
        )
        return resp.content[0].text
    # Add openai / google branches as needed
    raise NotImplementedError(EMBEDDED_LLM["provider"])

INTEGRATION_SCHEMA = """\
<flattened schema dump — tables, fields, types — generated at tool-creation time>
"""

def execute(payload: dict) -> dict:
    parsed = InputModel.model_validate(payload)
    started = time.perf_counter()

    prompt = _substitute(SYSTEM_PROMPT, {
        "user_input": parsed.task,
        "integration_schema": INTEGRATION_SCHEMA,
        "reference_data": "",  # populate from cached reference data if available
    })
    raw = _call_llm(prompt, parsed.task)

    try:
        params = json.loads(raw)
    except json.JSONDecodeError as e:
        return _err(
            action=ACTION, integration=INTEGRATION,
            code="LLM_PARSE_ERROR",
            message="Embedded LLM returned non-JSON output",
            details={"raw": raw[:500], "error": str(e)},
            attempted_inputs=parsed.model_dump(),
            remediation="Retry with a clearer task description.",
            retryable=True, retry_after_ms=0,
        )

    # Now call the target action with the LLM-produced params
    resp = _request("POST", "/<endpoint>", json_body=params)
    latency_ms = int((time.perf_counter() - started) * 1000)
    # ... wrap in _ok / _err same as Simple ...
```

---

## Pattern 5 — Agentic (autonomous agent)

Same envelope + embedded LLM helpers as parameter interpreter, plus a tool-use loop. Reference Anthropic's tool-use API for the loop pattern; key elements:

```python
SAFETY_LIMITS = {
    "max_tool_calls": 10,
    "timeout_seconds": 300,
    "max_total_cost_usd": 1.0,
}

# Available inner tools the LLM may call
INNER_TOOLS = [
    {
        "name": "search_<resource>",
        "description": "<one-paragraph mini-prompt>",
        "input_schema": {"type": "object", "properties": {...}, "required": [...]},
    },
    # ...
]

def _run_inner_tool(name: str, args: dict) -> dict:
    """Dispatch to the actual API call for the named inner tool."""
    if name == "search_<resource>":
        resp = _request("GET", "/search", params=args)
        return resp.json()
    raise ValueError(f"unknown inner tool: {name}")

def execute(payload: dict) -> dict:
    parsed = InputModel.model_validate(payload)
    started = time.perf_counter()
    deadline = started + SAFETY_LIMITS["timeout_seconds"]

    client = Anthropic()
    messages = [{"role": "user", "content": parsed.task}]
    tool_calls_made = 0

    while True:
        if tool_calls_made >= SAFETY_LIMITS["max_tool_calls"]:
            return _err(action=ACTION, integration=INTEGRATION,
                        code="SAFETY_TOOL_CALL_LIMIT",
                        message=f"Hit max_tool_calls={SAFETY_LIMITS['max_tool_calls']}",
                        details={"tool_calls_made": tool_calls_made},
                        attempted_inputs=parsed.model_dump(),
                        remediation="Refine the task to be narrower, or raise the safety limit.")
        if time.perf_counter() > deadline:
            return _err(action=ACTION, integration=INTEGRATION,
                        code="SAFETY_TIMEOUT", message="Hit timeout", details={},
                        attempted_inputs=parsed.model_dump(),
                        remediation="Refine the task or raise timeout_seconds.")

        resp = client.messages.create(
            model=EMBEDDED_LLM["model"],
            max_tokens=EMBEDDED_LLM["max_tokens"],
            temperature=EMBEDDED_LLM["temperature"],
            system=SYSTEM_PROMPT,  # may contain {{user_input}}, {{available_tools}} substituted
            tools=INNER_TOOLS,
            messages=messages,
        )

        if resp.stop_reason == "end_turn":
            # Extract final answer from resp.content text blocks
            final_text = "".join(b.text for b in resp.content if b.type == "text")
            return _ok(
                action=ACTION, integration=INTEGRATION,
                data={"answer": final_text, "tool_calls_made": tool_calls_made},
                message=final_text[:200],
                next_steps="## In your response:\n- Relay the answer to the user.",
                latency_ms=int((time.perf_counter() - started) * 1000),
            )

        if resp.stop_reason == "tool_use":
            messages.append({"role": "assistant", "content": resp.content})
            tool_results = []
            for block in resp.content:
                if block.type == "tool_use":
                    tool_calls_made += 1
                    try:
                        result = _run_inner_tool(block.name, block.input)
                        tool_results.append({
                            "type": "tool_result", "tool_use_id": block.id,
                            "content": json.dumps(result),
                        })
                    except Exception as e:
                        tool_results.append({
                            "type": "tool_result", "tool_use_id": block.id,
                            "content": f"error: {e!s}", "is_error": True,
                        })
            messages.append({"role": "user", "content": tool_results})
            continue

        # Unexpected stop reason
        return _err(action=ACTION, integration=INTEGRATION,
                    code="LLM_UNEXPECTED_STOP",
                    message=f"Unexpected LLM stop reason: {resp.stop_reason}",
                    details={"stop_reason": resp.stop_reason},
                    attempted_inputs=parsed.model_dump(),
                    remediation="File a bug.")
```

---

## Pattern 6 — Pipeline

```python
class PipelineInput(BaseModel):
    query: str = Field(..., description="...")

_assert_flat(PipelineInput.model_json_schema())

# Each step: { name, slug, tool_fn (callable or None for reasoning),
#              input_mapping, on_error, retries, timeout_seconds,
#              condition (optional), reasoning_prompt (optional) }
STEPS = [
    {"name": "Search", "slug": "search", "step_number": 1,
     "tool_fn": _step_search, "input_mapping": {"q": "{{input.query}}"},
     "on_error": "fail_pipeline", "timeout_seconds": 60},
    {"name": "Fetch top result", "slug": "fetch", "step_number": 2,
     "tool_fn": _step_fetch, "input_mapping": {"url": "{{step_search.output.results.0.url}}"},
     "on_error": "skip_remaining", "timeout_seconds": 60},
]

OUTPUT_MAPPING = {
    "answer": "{{step_fetch.output.summary}}",
    "source_url": "{{step_search.output.results.0.url}}",
}

SAFETY_LIMITS = {"max_cost_usd": 5.0, "max_duration_seconds": 1800}

def _resolve_template(template_value, state: dict) -> any:
    """Resolve {{...}} references against pipeline state."""
    if not isinstance(template_value, str):
        return template_value
    import re
    pattern = re.compile(r"\{\{([^}]+)\}\}")
    def lookup(match):
        path = match.group(1).strip().split(".")
        cur = state
        for part in path:
            if part.isdigit():
                cur = cur[int(part)]
            else:
                cur = cur.get(part) if isinstance(cur, dict) else getattr(cur, part, None)
            if cur is None:
                return ""
        return str(cur) if not isinstance(cur, (dict, list)) else json.dumps(cur)
    # If the whole string IS a single {{...}}, return the raw value
    full_match = pattern.fullmatch(template_value)
    if full_match:
        path = full_match.group(1).strip().split(".")
        cur = state
        for part in path:
            cur = cur[int(part)] if part.isdigit() else (cur.get(part) if isinstance(cur, dict) else None)
        return cur
    return pattern.sub(lookup, template_value)

def execute(payload: dict) -> dict:
    parsed = PipelineInput.model_validate(payload)
    started = time.perf_counter()
    deadline = started + SAFETY_LIMITS["max_duration_seconds"]
    state: dict = {"input": parsed.model_dump()}

    for step in STEPS:
        if time.perf_counter() > deadline:
            return _err(action=ACTION, integration=INTEGRATION,
                        code="PIPELINE_DURATION_EXCEEDED", message="Hit duration limit",
                        details={"completed_steps": list(state.keys())},
                        attempted_inputs=parsed.model_dump(),
                        remediation="Lower the work per step or raise max_duration_seconds.")

        resolved_input = {k: _resolve_template(v, state) for k, v in step["input_mapping"].items()}
        try:
            output = step["tool_fn"](resolved_input)
        except Exception as e:
            if step["on_error"] == "fail_pipeline":
                return _err(action=ACTION, integration=INTEGRATION,
                            code="PIPELINE_STEP_FAILED",
                            message=f"Step '{step['slug']}' failed: {e!s}",
                            details={"step": step["slug"], "exception": type(e).__name__},
                            attempted_inputs=parsed.model_dump(),
                            remediation=f"Investigate the {step['slug']} step.")
            elif step["on_error"] == "skip_remaining":
                break
            # 'continue' falls through

        state[f"step_{step['slug']}"] = {"output": output}

    output = {k: _resolve_template(v, state) for k, v in OUTPUT_MAPPING.items()}
    return _ok(
        action=ACTION, integration=INTEGRATION, data=output,
        message="Pipeline completed",
        next_steps="## In your response:\n- Relay the result.",
        latency_ms=int((time.perf_counter() - started) * 1000),
    )
```

For reasoning steps inside a pipeline, the `tool_fn` is an LLM call that returns a JSON object matching a declared output schema — the same pattern as the parameter interpreter, just running between deterministic steps.

---

## Adapter files (identical across all patterns)

### `tools/<slug>/__init__.py`

```python
from .tool import execute, InputModel, DESCRIPTION, ACTION, INTEGRATION

__all__ = ["execute", "InputModel", "DESCRIPTION", "ACTION", "INTEGRATION"]
```

### `tools/<slug>/langchain_adapter.py`

```python
"""LangChain/LangGraph adapter — exposes the tool as a StructuredTool."""
from langchain_core.tools import StructuredTool
from .tool import execute, InputModel, DESCRIPTION, ACTION

def _run(**kwargs) -> dict:
    return execute(kwargs)

def get_tool() -> StructuredTool:
    return StructuredTool.from_function(
        name=ACTION,
        description=DESCRIPTION,
        args_schema=InputModel,
        func=_run,
    )
```

### `tools/<slug>/mcp_server.py`

```python
"""MCP server entry point — run as: python -m tools.<slug>.mcp_server"""
import asyncio, json
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent
from .tool import execute, InputModel, DESCRIPTION, ACTION

server = Server(ACTION)

@server.list_tools()
async def list_tools() -> list[Tool]:
    return [Tool(
        name=ACTION,
        description=DESCRIPTION,
        inputSchema=InputModel.model_json_schema(),
    )]

@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    if name != ACTION:
        return [TextContent(type="text", text=json.dumps({"success": False, "message": f"unknown tool: {name}"}))]
    result = execute(arguments)
    return [TextContent(type="text", text=json.dumps(result))]

async def main() -> None:
    async with stdio_server() as (read, write):
        await server.run(read, write, server.create_initialization_options())

if __name__ == "__main__":
    asyncio.run(main())
```

### `tools/<slug>/requirements.txt`

Per-pattern. Always includes the first three:

```
httpx>=0.27
pydantic>=2.0
langchain-core>=0.3
mcp>=1.0
```

Add per pattern:
- Agentic (anthropic): `anthropic>=0.40`
- Agentic (openai): `openai>=1.50`
- Agentic (google): `google-genai>=0.1`

### `tools/<slug>/README.md`

Short README — adapt for the specific tool:

```markdown
# <Tool Name>

<One-line summary>

## What it does

<Two-three sentences. Same content as DESCRIPTION's first line, expanded.>

## Required env vars

- `<INTEGRATION>_API_KEY` — <where to get it>
- `<INTEGRATION>_BASE_URL` — (optional) override default base URL
- For agentic patterns also:
  - `ANTHROPIC_API_KEY` (or `OPENAI_API_KEY` / `GOOGLE_API_KEY`)

## Install

```bash
pip install -r tools/<slug>/requirements.txt
```

## Use from LangGraph

```python
from tools.<slug>.langchain_adapter import get_tool
from langgraph.prebuilt import create_react_agent

agent = create_react_agent(model, [get_tool()])
```

## Run as MCP server

```bash
python -m tools.<slug>.mcp_server
```

For Claude Desktop:
```json
{
  "mcpServers": {
    "<slug>": {
      "command": "python",
      "args": ["-m", "tools.<slug>.mcp_server"],
      "env": {"<INTEGRATION>_API_KEY": "..."}
    }
  }
}
```

## Portability

This tool has zero imports outside `tools/<slug>/`. To move it into another repo:
1. Copy the entire directory.
2. `pip install -r requirements.txt`.
3. Set env vars.
```

---

## Per-pattern notes summary

| Pattern | tool.py size | requirements.txt extras | Special considerations |
|---|---|---|---|
| Simple | ~120 lines | none | Trivial. The default. |
| Composite rule-based | ~180 lines | none | Routing rules + per-op mapping fns |
| Composite agent-driven | ~150 lines | none | `operation` Literal field; direct dispatch |
| Agentic (param interp) | ~200 lines | LLM SDK | Substitute prompt vars; parse JSON; validate |
| Agentic (autonomous) | ~250 lines | LLM SDK | Tool-use loop; safety limits enforced inside loop |
| Pipeline | ~250 lines | LLM SDK if reasoning steps | Template resolver; per-step error handling |

Keep tool.py readable. If it's growing past these sizes, extract a private helper inside the same file — but never into a sibling module that breaks portability.
