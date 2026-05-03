# Design References — Captured Artifacts

Drop reference image files (screenshots, exports, specimens) under the two subfolders here. The companion index is [`../design-references.md`](../design-references.md).

## Folder split

| Folder | What goes here | Read by |
|--------|----------------|---------|
| [`product/`](product/) | Flow screenshots, state captures (empty / loading / error / success), interaction recordings, component-level patterns. UX/usability-focused. | `/ux-review` (consistency benchmark) |
| [`brand/`](brand/) | Typography specimens, color palettes, marketing-page captures, logo systems, ad creative, identity systems. Visual/brand-focused. | Marketing skills (`marketing-skills:copywriting`, `marketing-skills:image`, `marketing-skills:page-cro`, etc.) |

The split mirrors the two consumer modes — `/ux-review` cares about product flow and polish; marketing skills care about visual identity and brand voice. Either skill set can read across folders if useful, but the default scope per skill stays tight.

## Naming

Use a short, scannable convention so files are findable from the index:

- `<source>-<surface>-<state>.<ext>` — e.g., `linear-issue-detail-empty.png`, `stripe-pricing-hero.png`
- For multi-shot captures, append a numeric suffix: `things3-quick-entry-01.png`, `things3-quick-entry-02.png`

## Formats

- **Images**: PNG or JPG preferred; SVG for vector specimens. Keep originals — don't pre-compress to thumbnails.
- **PDFs**: fine for design-system exports.
- **Text snippets** (CSS values, type scales, tokens): drop into a `.md` file alongside the images, not loose `.txt` — keeps it readable in PR diffs.

## Don't put here

- Final or in-progress collateral for *this* product — that lives in [`../../marketing/`](../../marketing/).
- Source code or design tooling — use the relevant package directory.
- Anything sensitive (unreleased competitor leaks, NDA material).

## Linking from the index

When an artifact ties to a specific reference entry, link it inline in [`../design-references.md`](../design-references.md):

```markdown
- **Linear** (https://linear.app) — what to match: keyboard navigation;
  see [product/linear-issue-detail-cmd-k.png](design-references/product/linear-issue-detail-cmd-k.png)
```
