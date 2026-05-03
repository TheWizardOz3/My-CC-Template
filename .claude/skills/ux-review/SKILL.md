---
name: ux-review
description: "Evaluate a UI surface for usability, design polish, and consistency with the project's design references. Drives a real browser via /agent-browser. Triggers on 'ux review', 'design review', 'review the UX of X', 'how does X look', or /ux-review. Default desktop viewport, project-configurable. Do NOT use as an accessibility audit (that's a separate concern). Do NOT use for code review (use /review or /simplify)."
user-invocable: true
---

# UX Review

Evaluate a UI for **usability**, **design polish**, and **consistency** — in that order. Drives a real browser via `/agent-browser`. Reads `docs/design-references.md` for the consistency benchmark.

**Not an accessibility audit.** WCAG checks are valuable but they're a separate review pass. This skill optimizes for "does this feel like a tasteful, well-considered product?", not "does this pass screen-reader checks."

**Default viewport: desktop (1440×900).** Project can override in `docs/architecture.md` or via the user passing a viewport with the invocation.

---

## Step 0: Inputs

Confirm:
1. **What surface to review** — URL, route, component, or "the whole product." Don't assume.
2. **Viewport** — desktop default; ask if mobile or tablet matters.
3. **Auth state** — logged-in vs. logged-out. If logged-in, the user provides credentials or pre-existing session.

If `agent-browser` skill is not yet installed, stop and surface that — manual review by the user is the fallback.

---

## Step 1: Load the consistency benchmark

Read `docs/design-references.md` (filled during `/new-project` Phase 5; ships as a skeleton).

If the file still contains `{{PLACEHOLDER}}` strings or has no real entries, ask the user for 1–3 reference apps before proceeding. Without a benchmark, "consistency" has no meaning — don't make one up.

Keep the references in working memory: name + what specifically is admired (e.g., "Linear: keyboard navigation", "Stripe Dashboard: typography hierarchy").

**Load captured artifacts.** Check `docs/design-references/product/` for image files (PNG/JPG/SVG/PDF). If any exist, read them — they're concrete exemplars to match against, not just names. Cross-reference each artifact with the matching entry in `design-references.md` (entries link to artifacts inline). Treat unmatched files as additional context.

> **Marketing reuse:** `docs/design-references.md` and the `design-references/brand/` subfolder double as the brand visual reference for marketing skills. When `/ux-review` runs against a marketing page (anything under `apps/marketing/`), also load `docs/design-references/brand/` artifacts — additions made there flow into both product and marketing review automatically.

---

## Step 2: Drive the browser

Use `/agent-browser` to:

1. Navigate to the surface.
2. Capture the **initial state** — full-page screenshot.
3. Walk the **happy path** of the primary flow. Screenshot each key state.
4. Trigger 2–3 **edge states** that reveal polish (or its absence):
   - Empty state (no data)
   - Loading state (slow network simulation if available)
   - Error state (force a validation error or 500)
   - Long-content overflow (paste a very long string into a text field)
5. Try 1–2 **alternate paths** — secondary flows, modal closes, back navigation.

**Cost guard:** if any path triggers a paid API (LLM, payment, paid scraper), STOP and confirm before running it. The same rule as `/test`.

---

## Step 3: Evaluate (three lenses, in order)

### Lens 1: Usability (does the flow make sense?)

Ask of each captured state:

- **Affordances** — is it obvious what to click? Are interactive elements distinguishable from static ones?
- **Feedback** — when the user clicks something, do they know it worked? Loading states present? Errors visible?
- **Hierarchy** — is the most important action the most visible action? Or does a primary CTA blend with secondary noise?
- **Friction** — count clicks/keystrokes for the primary task. Anything that feels like 2 clicks too many?
- **Mental model** — does the UI behave the way a user would predict? (E.g., does Esc close modals? Does the back button work?)

### Lens 2: Polish (does it feel tasteful?)

- **Typography** — is the type scale consistent? Are line-heights comfortable? Are headlines distinguishable from body?
- **Spacing** — consistent rhythm or ad-hoc gaps? Density appropriate to the content?
- **Color** — limited palette or kitchen-sink? Sufficient contrast for primary text? Brand color used sparingly enough to mean something?
- **Motion** — present or absent? If present, does it inform (state change, position) or distract (decorative bouncing)?
- **Empty states** — designed, or just blank? "No items yet" with an action beats white space.
- **Edge cases** — long names truncated cleanly? Numbers don't break layout at large values? Imagery scales?

### Lens 3: Consistency (matches references + matches itself)

- **External consistency** — does this match the *spirit* of the reference apps captured in `docs/design-references.md`? Don't clone them — match the *quality bar* and *philosophy*.
- **Internal consistency** — does this surface match other surfaces of the same product? Same buttons? Same spacing? Same vocabulary in copy?
- **Anti-references** — does anything in the captured screens resemble a noted anti-reference? Flag it.

---

## Step 4: Report

Structure the output as a prioritized list. **Lead with what's working** (briefly), then issues by severity:

```markdown
## UX Review: <surface>
**Viewport:** <viewport> · **Captured:** <N> screenshots · **Reference benchmark:** <reference apps>

### Working well
- <one-liner about what's tasteful or effective>
- <one-liner>

### High priority
- **[Usability]** <one-liner — what's broken, what's the impact, where it is>
  - Suggested fix: <one-liner>
  - Screenshot: <path>
- **[Polish]** ...

### Medium priority
- ...

### Nits
- ...

### Out of scope (flagged but not addressed)
- Accessibility — this review didn't check screen-reader / keyboard-nav / contrast ratios. Run a separate a11y pass if needed.
- Performance — load time, bundle size, INP/CLS not measured here.
```

**Severity rubric:**
- **High** — blocks or significantly slows the primary flow; obviously wrong (clipped text, broken layout, illegible contrast).
- **Medium** — feels off; fixable; user would notice on second use.
- **Nit** — optional; would polish but isn't load-bearing.

---

## Step 5: Hand off

End with:

> Reviewed `<surface>`.
> Findings: <N high>, <N medium>, <N nit>.
> Screenshots saved to `<dir>` (or "in conversation").
> Want me to `/implement` fixes for the High-priority items, or open a feature doc to triage?

**Do not auto-fix.** Recommendations only — fixes belong in `/implement` with explicit user direction.

---

## Constraints

- **Three lenses, in order.** Usability before polish before consistency. A polished UI that confuses users isn't a win.
- **Reference-anchored consistency.** Don't make up "best practices." Match what `docs/design-references.md` says.
- **Cost guard always on.** Paid APIs require explicit user approval per click.
- **Screenshots are evidence.** Findings without a screenshot are weaker — capture before flagging.
- **Don't lecture about a11y.** Note it's out of scope; don't spend the review explaining why.
- **Don't ship code.** Recommendations only. `/implement` is a separate, human-gated step.
