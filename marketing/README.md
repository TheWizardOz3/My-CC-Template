# marketing/

Output directory for marketing collateral produced by the marketing skills (installed via the `coreyhaines31/marketingskills` plugin) and the project-side `/marketing-context` bridge skill.

This is for **produced artifacts**, not strategy docs. Strategy/notes belong in [`../docs/marketing-strategy.md`](../docs/marketing-strategy.md). Positioning belongs in [`../.agents/product-marketing-context.md`](../.agents/product-marketing-context.md).

## Layout

| Subfolder | What goes here | Example skills that write here |
|-----------|----------------|--------------------------------|
| `copy/` | Page copy, headlines, value props, taglines, landing-page drafts | `marketing-skills:copywriting`, `marketing-skills:page-cro`, `marketing-skills:copy-editing` |
| `emails/` | Email sequences, drip campaigns, cold outreach, lifecycle flows | `marketing-skills:email-sequence`, `marketing-skills:cold-email` |
| `ads/` | Ad creative variations, headlines, primary text, descriptions | `marketing-skills:ad-creative`, `marketing-skills:paid-ads` |
| `assets/` | Generated/edited images, OG images, social graphics, video scripts | `marketing-skills:image`, `marketing-skills:video`, `marketing-skills:social-content` |

## Conventions

- Skills create files under the appropriate subfolder. If a skill is unsure, it should default to `copy/` and note the location.
- One artifact per file. Use descriptive names: `homepage-hero-v2.md`, `welcome-sequence-day1.md`, `google-rsa-headlines-2026-05.md`.
- Drafts are fine here — this directory is a workspace, not a publication target.
- The marketing site (when it exists) lives at `../apps/marketing/` and pulls finalized copy from this directory as needed.

## Related

- [`../.agents/product-marketing-context.md`](../.agents/product-marketing-context.md) — positioning input read by every marketing skill
- [`../docs/marketing-strategy.md`](../docs/marketing-strategy.md) — rolling marketing notes and roadmap
- [`../AGENTS.md`](../AGENTS.md) §13 — full skill routing table
