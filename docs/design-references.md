# Design References

> Visual + UX consistency benchmark for this project. Read by [`/ux-review`](../.claude/skills/ux-review/SKILL.md) (product flows, polish) and marketing skills (brand, voice, visual identity). Filled during [`/new-project`](../.claude/skills/new-project/SKILL.md) Phase 5; updateable any time taste evolves.

**Last Updated**: {{YYYY-MM-DD}}

---

## References

Apps/sites whose design quality this project aims to match. Pair each with a one-line note on *what specifically* you admire — generic praise ("clean", "minimal") doesn't help reviewers anchor.

- **{{APP_1}}** ({{URL}}) — what to match: {{one-liner — e.g., "Linear's keyboard navigation"}}
- **{{APP_2}}** ({{URL}}) — what to match: {{one-liner — e.g., "Stripe Dashboard's typography hierarchy"}}
- **{{APP_3}}** ({{URL}}) — what to match: {{one-liner — e.g., "Things 3's empty states"}}

## Anti-references

Patterns or products to actively avoid.

- **{{APP_OR_PATTERN}}** — what to avoid: {{one-liner}}

## Notes

{{Cross-cutting preferences not tied to a specific reference — density, motion philosophy, voice, color discipline, etc.}}

---

## Captured artifacts

Reference images, screenshots, exports, and design-system specimens live under [`design-references/`](design-references/), split by lens:

- [`design-references/product/`](design-references/product/) — flow screenshots, empty/loading/error/success states, interaction captures, component patterns. Consumed by `/ux-review` when reviewing product surfaces.
- [`design-references/brand/`](design-references/brand/) — typography specimens, color systems, logo systems, marketing-page captures, ad creative. Consumed by marketing skills (`marketing-skills:copywriting`, `marketing-skills:image`, `marketing-skills:page-cro`, etc.) for brand-aligned output.

See [`design-references/README.md`](design-references/README.md) for the naming convention and what does/doesn't belong.

When an artifact is tied to a specific reference above, link it inline in that entry — e.g.:

```
- **Linear** (https://linear.app) — what to match: keyboard navigation;
  see [product/linear-issue-detail-cmd-k.png](design-references/product/linear-issue-detail-cmd-k.png)
```
