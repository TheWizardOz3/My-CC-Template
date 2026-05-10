# Prompt Templating ({{variable}})

Used by **agentic patterns** (parameter interpreter and autonomous agent) and **pipeline reasoning steps**. Not used by Simple or Composite patterns — they have no internal LLM.

## Convention

`{{variable_name}}` — double braces, lowercase snake_case identifier inside.

The variable name must match `[a-zA-Z_][a-zA-Z0-9_]*`. No spaces, no hyphens, no nested braces.

## Canonical placeholders

These names are reserved — use them rather than inventing alternatives, so consumers and operators have a stable vocabulary.

| Variable | Used by | Contents |
|---|---|---|
| `{{user_input}}` | All agentic patterns | The natural-language task the consumer passed in |
| `{{integration_schema}}` | Parameter interpreter | Description of tables/fields/types the LLM should target (often a flattened schema dump) |
| `{{reference_data}}` | Param interpreter, autonomous | Valid values, options, IDs, allowed enum values |
| `{{available_tools}}` | Autonomous agent | Formatted list of inner tools with descriptions, for the LLM to choose from |
| `{{prior_step_output}}` | Pipeline reasoning | Output from the previous step (or any prior step by name) |
| `{{step_<N>_output}}` | Pipeline reasoning | Specific step's full output. Same convention as input mappings. |

For pipeline input mappings (not prompts), the same `{{...}}` convention is used to reference step outputs:
- `{{input.<field>}}` — pipeline input
- `{{step_<slug>.output.<field>}}` — output of an earlier step

## Substitution rules

1. **Missing variables** are replaced with empty strings, but the missing name is logged. Don't crash — agents tolerate gaps.
2. **No partial substitution**. If `{{user_input}}` appears 5 times, all 5 get replaced atomically.
3. **No nested expansion**. After substitution, any `{{` in the substituted value is left as-is.
4. **Order independence**. Substitutions don't depend on each other.

## System prompt structure (for agentic tools)

A good system prompt has four parts, in this order:

```
# Role
You are a {role} that helps with {scope}.

# Available context
{{integration_schema}}

{{reference_data}}

# Task
The user has requested: {{user_input}}

# Output requirements
Produce a JSON object matching this schema:
{
  "param_a": "string — description",
  "param_b": "number — description"
}
Return ONLY the JSON. No prose, no fences, no commentary.
```

For autonomous agents, replace "Output requirements" with:
```
# Available tools
{{available_tools}}

Use these tools to accomplish the task. Stop when you have enough information to answer, or when you've made {{max_tool_calls}} tool calls.
Return your final answer as a JSON object: { "result": <your answer>, "summary": "<one-line summary of what you did>" }.
```

## Reasoning prompt structure (for pipeline reasoning steps)

Reasoning steps run *between* tool calls inside a pipeline. The LLM produces a structured JSON decision the next step uses.

```
# Role
You are a routing decider for the {pipeline_name} pipeline.

# Prior step output
{{step_<previous_slug>_output}}

# Decision required
{describe what the LLM must decide — e.g. "Pick the next category to investigate"}

# Output schema
Return JSON matching:
{
  "decision": "string — one of: a, b, c",
  "rationale": "string — one-sentence reason"
}
Return ONLY the JSON.
```

Always specify the output schema explicitly. Reasoning steps are LLM-as-JSON-producer, not chat — strict format is the contract.

## What NOT to use

- ❌ `{variable}` (single brace) — collides with Python f-strings
- ❌ `${variable}` — collides with shell
- ❌ `<<variable>>` — non-standard
- ❌ `{{ variable }}` (with spaces) — accept it on input but emit without spaces

The substitution regex is `\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}` — strict, no whitespace inside the braces.

## Storing the prompt

In the generated tool, the system prompt lives as a multi-line string constant in `tool.py`:

```python
SYSTEM_PROMPT = """\
# Role
You are a SQL writer for the analytics warehouse.

# Available context
{{integration_schema}}

# Task
The user has requested: {{user_input}}

# Output requirements
Produce a JSON object: { "sql": "...", "params": {...} }
Return ONLY the JSON.
"""
```

The substitution helper lives next to it and is called per invocation.
