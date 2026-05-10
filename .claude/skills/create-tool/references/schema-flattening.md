# Schema Flattening (Flat JSON Schema for LLM Consumption)

**Rule**: input schemas exposed to LLMs must be flat. No `$ref`, no `oneOf`/`anyOf`/`allOf`, no `definitions`/`$defs`. Every property has explicit `type` and `description`.

This applies to:
- The Pydantic model that defines the tool's input
- The JSON Schema generated from it (LangChain's `args_schema`, MCP's `inputSchema`)

LLMs handle flat schemas reliably. Nested unions and references degrade tool-call quality across all major providers.

## What "flat" means

✅ Allowed:
- `type: string | number | integer | boolean | array | object`
- `description` (required on every property)
- `enum: [...]` (for constrained string/number values)
- `default: <value>`
- `items: { type, description? }` for arrays of primitives or simple objects
- `properties: { ... }` and `required: [...]` for nested objects (one level deep is fine)

❌ Forbidden:
- `$ref` of any kind
- `oneOf`, `anyOf`, `allOf`
- `discriminator` (for OpenAPI-style polymorphism)
- `definitions`, `$defs`
- `not`, `if/then/else`
- Untyped properties (every property has explicit `type`)

## How to flatten

If you're starting from an OpenAPI spec or a complex Pydantic model:

1. **Resolve `$ref`** — inline the referenced schema directly.
2. **Collapse `oneOf` / `anyOf`** — pick the most common variant and add the others as optional fields. If the variants are radically different, that's a sign you should split into multiple tools (or a composite tool with an `operation` field).
3. **Collapse `allOf`** — merge all branches into one flat object.
4. **Lift unions to enums** — if the union is over literal values, turn it into `enum: [...]`.
5. **Strip `discriminator`** — replace with an explicit `enum` field the agent fills in.

## Pydantic patterns that produce flat schemas

```python
from pydantic import BaseModel, Field
from typing import Literal

# ✅ Good — flat, every field has a description
class SendMessageInput(BaseModel):
    channel: str = Field(..., description="Channel ID (starts with C) or user ID (starts with U)")
    text: str = Field(..., description="Message body, supports mrkdwn", max_length=40000)
    thread_ts: str | None = Field(None, description="Parent message timestamp to reply in-thread")
    priority: Literal["low", "normal", "high"] = Field("normal", description="Message priority")

# ❌ Bad — Union produces oneOf in the JSON Schema
class BadInput(BaseModel):
    target: str | int  # generates oneOf — flatten to one type
```

If you genuinely need polymorphic input, lift the discriminator to its own field:

```python
# ❌ Don't:
content: ImageContent | TextContent | LinkContent

# ✅ Do:
content_type: Literal["image", "text", "link"] = Field(..., description="Content type")
content_value: str = Field(..., description="The actual content. For 'image': URL. For 'text': raw text. For 'link': URL with optional preview.")
```

## Verifying flatness

After defining the Pydantic model, dump its schema and grep for forbidden keys:

```python
import json
schema = SendMessageInput.model_json_schema()
flat = json.dumps(schema)
for forbidden in ['$ref', 'oneOf', 'anyOf', 'allOf', 'definitions', '$defs']:
    assert forbidden not in flat, f"Schema contains {forbidden}"
```

Add this assertion as a sanity check at module import time in `tool.py`. It catches accidental regressions when someone adds a new field.

## Description coverage

Every property must have a non-empty `description`. The LLM uses these to choose values. Pydantic's `Field(..., description=...)` syntax enforces this.

If a description would just restate the field name ("the channel field"), it's not pulling weight — write a real one or drop the field.

## Length

- Property descriptions: ≤ 200 chars each
- Top-level tool description: ≤ 2000 chars (see `universal-description-format.md`)
- Total schema (serialized JSON): aim under 5KB for fast tool-call latency

If you can't fit, split into multiple tools.
