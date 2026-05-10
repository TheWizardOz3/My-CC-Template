# My-CC-Template Marketing Restructure Plan

> Companion to [RESTRUCTURE_PLAN.md](RESTRUCTURE_PLAN.md). Working document for layering marketing capabilities onto this template — paired with the existing dev-skill stack — so the same repo can build an app *and* produce marketing collateral / host a marketing site rooted in that app's actual code and product context. Built for piece-by-piece execution across multiple sessions.

**Status:** Plan only. No code or doc changes yet.
**Last updated:** 2026-05-02

---

## Reference repos (read these for comparison)

| Path | What to look at |
|------|-----------------|
| `/Users/derekosgood/Documents/0_Git Repos/marketingskills/` | Source of truth for the 39 marketing skills, the `tools/` registry (CLIs + integration guides), the `.claude-plugin/marketplace.json` manifest, and the cross-agent `.agents/skills/` install convention |
| `/Users/derekosgood/Documents/0_Git Repos/marketingskills/skills/product-marketing-context/SKILL.md` | The foundational context skill every other marketing skill reads first. Writes `.agents/product-marketing-context.md`. We wrap this with our own bridge skill (see §3 below). |
| `/Users/derekosgood/Documents/0_Git Repos/marketingskills/AGENTS.md` | Their cross-agent guidelines. Notes the `.agents/` install convention, the `!`command`` Claude-Code-specific dynamic context injection trick (useful for our bridge skill), and the per-session update-check pattern. |
| `/Users/derekosgood/Documents/0_Git Repos/marketingskills/README.md` | Skill catalog (39 skills) grouped by category — informs §13 routing-table additions to AGENTS.md. |
| `/Users/derekosgood/Documents/0_Git Repos/My-CC-Template/RESTRUCTURE_PLAN.md` | The original dev-side restructure. This plan layers on top — does not modify any decision made there. |
| `/Users/derekosgood/Documents/0_Git Repos/My-CC-Template/AGENTS.md` | Where the new §13 routing-table section and Doc Map updates land. |

---

## Goal

Extend this template from "build the app" to "build the app *and* its marketing." Marketing skills must be context-aware of the app being built (read product_spec, architecture, src/ for component-level grounding) so that the marketing collateral and marketing website produced in the same repo are rooted in the actual product, not a generic restatement.

The template ships scaffolding and bridge skills. The marketing playbooks themselves come from the upstream `marketingskills` repo via Claude Code's plugin install — shared globally, applied per-project.

## Constraints / non-negotiables

1. **Don't break the dev-side restructure.** Everything from RESTRUCTURE_PLAN.md stays. This plan is purely additive.
2. **Plugin-first install.** Marketing skills come from the upstream plugin marketplace, not vendored into this repo. Avoids 39 duplicated files in every app repo spawned from this template.
3. **Multi-repo by design.** Each app cloned from this template has its own marketing context, collateral, and (optionally) marketing site. The plugin is shared infrastructure; per-project content lives in each repo.
4. **Customization via project-level override.** When the user disagrees with an upstream skill, they copy that skill into their project's `.claude/skills/` and edit it. Project skills override plugin skills (verify in Phase M1).
5. **Bridge dev context to marketing context.** A wrapper skill (`marketing-context`) derives `.agents/product-marketing-context.md` from `docs/product_spec.md`, `docs/architecture.md`, and `src/` so the user doesn't re-enter what the dev side already captured.
6. **Cross-tool compatibility preserved.** Marketing skills already follow the cross-agent Skills spec. Our bridge skill lives in `.claude/skills/` (CC-only) but the context file it produces (`.agents/product-marketing-context.md`) is at the cross-agent location so any tool can read it.
7. **No premature commitment to a marketing-site stack.** Don't pick Next.js / Astro / etc. up front. `apps/marketing/` is created lazily when the user actually starts the site.

---

## Target Architecture

### Multi-repo model

```
~/.claude/plugins/marketing-skills/         # installed ONCE, shared across every project
└── skills/                                 # 39 playbooks (page-cro, copywriting, seo-audit, ...)
└── tools/                                  # 51 zero-dep Node CLIs + integration guides

~/Documents/AppA/                           # Repo A — first app spawned from this template
├── .claude/
│   ├── skills/                             # dev skills + bridge + any custom overrides
│   │   ├── (existing 12 dev skills)
│   │   ├── marketing-context/SKILL.md      # NEW — bridge skill
│   │   └── (optional: copies of plugin skills you've customized)
│   └── settings.json                       # may add `disabledSkills` if overriding
├── .agents/
│   └── product-marketing-context.md        # AppA's positioning (cross-agent location)
├── docs/
│   ├── product_spec.md                     # AppA's product spec (dev-side, existing)
│   ├── marketing-strategy.md               # NEW — rolling marketing notes
│   └── (existing dev docs)
├── marketing/                              # AppA's marketing collateral
│   ├── copy/
│   ├── emails/
│   ├── ads/
│   ├── assets/
│   └── README.md
├── apps/
│   ├── web/                                # AppA's product
│   └── marketing/                          # AppA's marketing site (created lazily)
└── src/                                    # AppA's code

~/Documents/AppB/                           # Repo B — second app, identical structure
├── .agents/product-marketing-context.md    # AppB's positioning (different content)
├── marketing/                              # AppB's collateral (different content)
└── ...                                     # same shape, different content
```

### Key invariants

- The plugin lives outside any repo. `cd` into a repo determines which app's context the skills operate on.
- Skills only read project-relative paths (`./`, `.agents/`, never `~/`). Confirmed by inspecting `product-marketing-context` and `page-cro` source.
- `.agents/product-marketing-context.md` is the contract between dev and marketing. Our bridge generates it; upstream skills consume it.
- The marketing site, when it exists, lives at `apps/marketing/` alongside the product app at `apps/web/` (or wherever the dev side put it). Architecture decision deferred until first use.

---

## Install model: plugin-first, override per-skill, fork later

| Pattern | When to use | Notes |
|---------|-------------|-------|
| **Plugin install (default)** | Always — start here | One-time `/plugin marketplace add coreyhaines31/marketingskills` + `/plugin install marketing-skills`. All 39 skills + tools available with namespace prefix (e.g., `marketing-skills:page-cro`). Shared across every repo on the machine. Updates via `/plugin update`. |
| **Project-level override** | When you want to customize a specific skill but keep the rest | Copy `~/.claude/plugins/marketing-skills/skills/<name>/` into `.claude/skills/<name>/`, edit. Project skill should win over plugin skill — **verify in Phase M1.** If conflict resolution doesn't favor project, rename the local copy and add the plugin version to `disabledSkills` in `.claude/settings.json`. |
| **Fork upstream** | When overrides accumulate to ~5+ skills | Fork `coreyhaines31/marketingskills`, install your fork as the marketplace instead. Pull upstream changes with `git pull upstream main` periodically. Single source of customization. |
| **Vendor / copy** | Don't | Defeats the multi-repo benefit. Skip unless you specifically want offline-only operation. |

---

## The bridge: `marketing-context` wrapper skill

The single most important new skill. Without it, the user re-enters product information they already gave the dev side.

### Behavior

1. Read `docs/product_spec.md`, `docs/architecture.md`, `README.md`, and (optionally) sample components from `src/` for naming/copy
2. Draft `.agents/product-marketing-context.md` pre-populated with:
   - Product overview (from product_spec)
   - Tech stack signals (from architecture) — informs "for technical buyers" framing
   - UI element / component names (from src/) — gives marketing skills concrete things to reference in copy/diagrams
   - Anything else derivable from the existing repo
3. Ask the user *only* for the marketing-specific gaps the dev side never captured:
   - Personas (B2B) / Jobs to be Done
   - Brand voice + tone
   - Verbatim customer language
   - Competitive landscape
   - Proof points / testimonials
   - Pricing positioning
4. Write the merged result to `.agents/product-marketing-context.md`
5. Tell the user: "Marketing skills will now use this. Re-run `/marketing-context` anytime your product or positioning shifts."

### Why this skill is project-side, not in the plugin

It's hardcoded to *our* `docs/` structure. Putting it upstream would require generalizing across every possible template. It's also the only skill that needs to know about both worlds, so it has to live in the world that's aware of both — the project.

### Re-running

Idempotent. On second run: read existing `.agents/product-marketing-context.md`, diff against current `docs/`, propose updates section by section. Don't overwrite blindly.

### Optional: dynamic injection trick

Per upstream's `AGENTS.md`, Claude Code supports `` !`cmd` `` syntax to inject command output at skill-load time. Our bridge skill can use this to ensure freshness:

```markdown
Current product spec: !`cat docs/product_spec.md 2>/dev/null`
Current architecture: !`cat docs/architecture.md 2>/dev/null`
Current marketing context: !`cat .agents/product-marketing-context.md 2>/dev/null || echo "(none yet — will create)"`
```

This is CC-only, but the bridge skill is also CC-only, so no portability concern.

---

## AGENTS.md changes

### §2 Documentation Map — additions

| Document | Purpose | When to Reference |
|----------|---------|-------------------|
| `.agents/product-marketing-context.md` | Product positioning, audience, voice — read by every marketing skill | Any marketing task |
| `marketing/` | Output dir for marketing collateral (copy, emails, ads, assets) | When marketing skills produce artifacts |
| `apps/marketing/` | Marketing website source (created lazily) | When building/editing marketing site |
| `docs/marketing-strategy.md` | Rolling marketing notes, similar to project_status but marketing-focused | Mid-marketing-flow context |

### §13 Skill Routing Table — new "Marketing" sub-section

Group the 39 marketing skills under category headings, with the bridge listed first as foundational:

```
### Marketing skills (via plugin: coreyhaines31/marketingskills)

| Intent | Use | Type | Status |
|--------|-----|------|--------|
| Bridge dev context → marketing context | `/marketing-context` | project skill | available |
| ...
| Optimize a marketing page | `/marketing-skills:page-cro` | plugin | requires plugin install |
| Write or rewrite marketing copy | `/marketing-skills:copywriting` | plugin | requires plugin install |
| ... (37 more, grouped by: CRO, Copy, SEO, Paid, Measurement, Retention, Strategy, Sales/RevOps)
```

Don't enumerate all 39 inline — link to the plugin's own README for the full catalog and just list the foundational + most-used ones.

### NEW §16 Marketing Workflow

One-page section that sketches the end-to-end flow:

1. Build the app (existing dev workflow — `/new-project` → `/plan` → `/build` → `/ship`)
2. Install the plugin once: `/plugin marketplace add coreyhaines31/marketingskills` + `/plugin install marketing-skills`
3. Generate marketing context: `/marketing-context` (reads dev docs + src/, asks for marketing gaps, writes `.agents/product-marketing-context.md`)
4. Use marketing skills as needed: `/marketing-skills:page-cro`, `/marketing-skills:copywriting`, etc.
5. Optional: scaffold marketing site at `apps/marketing/` and use `/build` to develop it
6. Run `/ux-review` on marketing pages (already viewport-configurable)
7. `/ship` for marketing changes — `doc-updater` learns to update `docs/marketing-strategy.md`

### §14 Cross-Tool Compatibility — addendum

Note that:
- Marketing skills come from a cross-agent plugin and work in Cursor, Codex, Windsurf via the `.agents/skills/` convention if the user prefers another tool
- `.agents/product-marketing-context.md` is at the cross-agent location, so the same context is consumable by any tool
- The bridge skill (`marketing-context`) is CC-specific because it relies on the bridging conventions of our `docs/` setup; other tools would need an equivalent if used standalone

---

## Workflow stitching (how dev + marketing flows compose)

| Touch point | Change | Why |
|---|---|---|
| `/new-project` | Final step — ask "set up marketing now or later?" Default: later. Whichever way, write a one-line reminder into `docs/project_status.md`. | Don't force marketing setup on day one; most users want to build first. |
| `/marketing-context` | NEW skill (see §3 above). | The bridge. |
| `/build` orchestrator | No code change. Already generic enough to handle marketing-site work (it's just plan→implement→test). | Composition wins. |
| `/ux-review` | No code change. Already viewport-configurable; works on marketing pages. Update its README to mention `docs/design-references.md` doubles as marketing brand reference. | Reuse, don't duplicate. |
| `/ship` | Tweak `doc-updater` agent prompt: also update `docs/marketing-strategy.md` when changes touch `marketing/` or `apps/marketing/`. | Keeps marketing docs in sync the same way dev docs are. |
| `doc-sync-check.sh` hook | Extend the "src/ touched but no doc updates" check to also watch `marketing/` and `apps/marketing/` → remind to update `docs/marketing-strategy.md`. Keep anti-nag rules. | Same enforcement model, broader scope. |
| `safety-guard.sh` | No change. | No new risky operations. |

---

## Marketing site hosting (deferred decisions)

When the user actually starts the marketing site:
- **Location:** `apps/marketing/` (alongside `apps/web/` or whatever the dev app is called)
- **Stack:** decide at that point. Likely candidates: Next.js (familiar), Astro (content-heavy + fast), plain HTML (simplest). Capture the decision in `docs/decision_log.md` per existing convention.
- **Sharing components with the product app:** if the marketing site needs product UI screenshots or actual components (e.g., embedded demo), set up a shared package (`packages/ui/` monorepo pattern) and import from both. Capture in `docs/architecture.md`.
- **Build/deploy:** out of scope for the template. Document the chosen stack's deploy path in `docs/architecture.md`.

This decision is intentionally deferred — the template doesn't pre-commit you to a stack you may not want.

---

## CLIs and tools registry

The upstream plugin includes 51 zero-dep Node.js CLIs at `~/.claude/plugins/marketing-skills/tools/clis/` plus integration guides at `tools/integrations/`.

**Setup user needs to do:**
- Node 18+ (`brew install node` if missing)
- API keys for whichever services they use (GA4, Stripe, Resend, etc.) in their project's `.env`

**Updates:** automatic via `/plugin update` — same mechanism as the skills.

**Tools registry awareness:** the marketing skills already reference these CLIs by relative path within the plugin. Nothing for us to wire up — works as soon as the plugin is installed.

Document the Node + API-key prerequisite in our README under a "Marketing prerequisites" subsection.

---

## Hooks updates

| Hook | Change | Why |
|---|---|---|
| `safety-guard.sh` | None | No new risky operations introduced |
| `session-start.sh` | None | git pull behavior unchanged |
| `notify-input.sh` | None | Notification logic unchanged |
| `doc-sync-check.sh` | Extend the "watched dirs" list to include `marketing/` and `apps/marketing/`. If those changed but `docs/marketing-strategy.md` didn't, remind once per session. Same anti-nag rules. | Apply the same doc-discipline mechanism to marketing changes. |

---

## Migration Phases

Each phase self-contained, executable in its own session.

### Phase M1 — Verify plugin override semantics ✅ Done 2026-05-02
- [x] Install the plugin: `/plugin marketplace add coreyhaines31/marketingskills` then `/plugin install marketing-skills@marketingskills`
- [x] Verify a sample plugin skill (e.g., `page-cro`) is invokable — confirmed in fresh session (mid-session installs do not load until restart)
- [x] Test override: created `.claude/skills/page-cro/SKILL.md` with sentinel `SENTINEL_PROJECT_OVERRIDE_M1_a7f3b2c9`; `/page-cro` printed sentinel → project wins on name collision, no extra config required
- [x] No `disabledSkills` fallback needed
- [x] Findings captured below

### Verified Plugin Behavior (Phase M1 results)

**Install + skill loading.** `/plugin marketplace add coreyhaines31/marketingskills` followed by `/plugin install marketing-skills@marketingskills` succeeds. Plugin lands at `~/.claude/plugins/cache/marketingskills/marketing-skills/<version>/`. The 40 skills under `skills/` load cleanly — no manifest fixup needed (the plugin's `"skills": "./skills"` field in `plugin.json` and `metadata: { version: ... }` blocks in SKILL.md frontmatter are tolerated by Claude Code's loader).

**Mid-session installs require a restart.** Skills installed during an active Claude Code session do not appear until the session is restarted. `/marketing-skills:page-cro` returning "Unknown command" in a stale session is expected; close + reopen and it's available.

**Override resolution: project wins, no config needed.** A SKILL.md placed at `.claude/skills/<name>/SKILL.md` takes precedence over a plugin skill of the same name when invoked via the unprefixed slash form (`/<name>`). Verified by sentinel test: project's `page-cro` printed `SENTINEL_PROJECT_OVERRIDE_M1_a7f3b2c9` instead of running CRO analysis. No `disabledSkills` entry, no rename, no settings change required.

**Slash-command exposure of namespaced plugin skills is limited.** `/marketing-skills:page-cro` typed manually as a slash command is **not** invokable in the VS Code extension's slash menu — the namespaced form does not appear and "Unknown command" is returned when typed. The plugin's skills are still loaded and available to Claude (which invokes them contextually based on description matching), but the routing table in AGENTS.md should describe them as **contextually-triggered** rather than as user-typeable slash commands. Plain plugin slash commands like `/feature-dev:feature-dev` (which come from a plugin's `commands/` dir, not `skills/`) do appear in the menu — that's a different mechanism.

**Slash menu shows one entry per name.** With both project and plugin versions of `page-cro` loaded, only one `page-cro` appears in the slash menu — the project version. The plugin version is hidden from the menu but remains contextually available to Claude.

**Implications for downstream phases.**
- AGENTS.md §13 routing-table additions should phrase plugin skills as "Claude invokes contextually when the user describes X," not "type `/marketing-skills:page-cro`." (Phase M4)
- The override-by-copy pattern works exactly as the plan assumed — no fallback needed. (Phase M3 onward)
- `.claude/skills/marketing-context/` (the bridge skill) will live alongside plugin skills with no naming/loading conflict, since its name is unique. (Phase M3)

### Phase M2 — Scaffolding (template-side) ✅ Done 2026-05-02
- [x] Create `marketing/` directory with subfolders (`copy/`, `emails/`, `ads/`, `assets/`) and a README explaining what goes where
- [x] Create `.agents/.gitkeep` so the directory exists in fresh clones (file itself written by `/marketing-context` later)
- [x] Create `docs/marketing-strategy.md` with placeholder structure (similar shape to `project_status.md`: in-progress, completed, ideas, blockers)
- [x] Update `.gitignore` if needed — no change needed; `.agents/` is not gitignored, so `product-marketing-context.md` will be committed by default. Existing `(ignore) *` convention in `docs/` covers ad-hoc marketing scratchpads.

### Phase M3 — Bridge skill ✅ Done 2026-05-02
- [x] Wrote [`.claude/skills/marketing-context/SKILL.md`](.claude/skills/marketing-context/SKILL.md) per the spec in §3
- [x] Auto-load via `` !`cmd` `` for `docs/product_spec.md`, `docs/architecture.md`, current `.agents/product-marketing-context.md`, top-of-`README.md`, and a sampled list of UI component filenames from `src/`
- [x] Gap-filling questions (Step 2) ask only for the marketing-only fields the dev side never captures: personas, competitors, customer language, brand voice, words to use/avoid, proof points, pricing positioning, JTBD four forces, anti-persona
- [x] Idempotent re-run (Step 4): diff existing context against current dev docs, surface drift section by section, preserve user-supplied marketing-only fields unless rebuild is explicitly requested
- [x] Output schema mirrors the upstream `marketing-skills:product-marketing-context` exactly (verified against [its SKILL.md](/Users/derekosgood/Documents/0_Git%20Repos/marketingskills/skills/product-marketing-context/SKILL.md) Step-3 template) — downstream skills consume the same field names
- [x] Skill registered: appeared in the available-skills list immediately after write (no session restart needed for project-side skills)
- [ ] **Deferred to first real project use:** end-to-end run of `/marketing-context` followed by `/marketing-skills:page-cro` — can't be verified here because (a) this template's `docs/product_spec.md` is itself a placeholder, (b) running the bridge would write template-y content into the canonical `.agents/product-marketing-context.md` for the template repo. Test in the first downstream project that adopts this template.

### Phase M4 — AGENTS.md updates ✅ Done 2026-05-02
- [x] §2 Documentation Map — added four new entries
- [x] §13 Skill Routing Table — added Marketing sub-section; bridge skill first, 5 most-used plugin skills inline, link to upstream README for the full catalog. Plugin skills described as **contextually triggered** per Phase M1 finding (namespaced slash form not invokable from menu).
- [x] §14 Cross-Tool Compatibility — added marketing-skills addendum
- [x] NEW §16 Marketing Workflow — wrote 7-step end-to-end flow
- [x] Renumbered §15 Project-Specific Guidelines → §17 (§15 left as a reserved gap, per plan's literal wording)
- [x] Line count: 388 (under the ~400 target)

### Phase M5 — Workflow integration ✅ Done 2026-05-02
- [x] `/new-project` skill — added Phase 6 ("Marketing setup (optional)") asking later/now; either path writes a one-line marker under "Upcoming Work" in `docs/project_status.md`. Phase 0's count and the Wrap summary updated; old "Wrap" became Phase 7.
- [x] `doc-updater` agent — added `docs/marketing-strategy.md` as conditional in-scope (Step 6, runs only when diff touches `marketing/` or `apps/marketing/`); same brevity rules as `project_status.md`. Frontmatter description, classification table, brevity hard limits, final-report template, and constraints all updated. `/ship` Step 4 enumeration also updated to match. `.agents/product-marketing-context.md` explicitly listed as out of scope (it's a positioning doc, not a status doc).
- [x] `doc-sync-check.sh` — restructured to two independent checks combined into one reminder: dev-side (3+ source files vs `changelog.md`/`project_status.md`) and marketing-side (1+ files under `marketing/` or `apps/marketing/` vs `marketing-strategy.md`). Source-side regex extended to also exclude `^marketing/` and `^apps/marketing/` so marketing artifacts don't double-count toward the dev threshold. `marketing/README.md` and `.gitkeep` files filtered out of the marketing trigger to avoid scaffolding-induced noise. Single per-session flag, same `/plan` / `/end-session` skip, `bash -n` clean. `.claude/hooks/README.md` updated to describe both checks.
- [x] `/ux-review` SKILL.md — added a callout in Step 1 noting `docs/design-references.md` doubles as the marketing brand visual reference, and that the same skill applies to marketing pages under `apps/marketing/` (no separate `references/` README to update — this skill is single-file).

### Phase M6 — Documentation ✅ Done 2026-05-02
- [x] README.md — added "Marketing capabilities" section (prerequisites, what you get, workflow, customization), updated file tree to show `.agents/` + `marketing/` + `docs/marketing-strategy.md`, bumped skill count to 12, added `/marketing-context` row to skills table
- [x] CLAUDE.md — bumped skill count to twelve, added bullet noting marketing skills come from the upstream plugin and the bridge lives at `.claude/skills/marketing-context/`

### Phase M7 — Marketing site (deferred — done per-project, not in template)
- [ ] When the user actually starts a marketing site for an app: scaffold `apps/marketing/`, pick a stack, capture decision in `docs/decision_log.md`, update `docs/architecture.md`
- [ ] Decide on shared-component pattern (monorepo `packages/ui/` or copy-paste) at that point

---

## Key Decisions Made (with rationale)

| Decision | Rationale |
|----------|-----------|
| **Plugin install (not vendor / submodule / copy)** | Solves three problems at once: install simplicity, automatic namespacing (`marketing-skills:<name>`), automatic updates. Multi-repo benefits multiply: one install, every app repo benefits. |
| **Project-level override for customization, fork only if overrides pile up** | Lightest path to "I disagree with this one skill" without forking. Fork is escape hatch when overrides accumulate. |
| **Bridge skill (`marketing-context`) lives in the project, not the plugin** | It's hardcoded to *our* `docs/` structure. Generalization belongs upstream only if other templates adopt the same pattern. |
| **Marketing context file at `.agents/product-marketing-context.md`, not in `docs/`** | Forced by upstream — the marketing skills hardcode that path. Side benefit: cross-agent location means any tool (Cursor/Codex) can read it. |
| **Marketing collateral at `marketing/`, not `docs/marketing/`** | `docs/` is for human-written reference docs; `marketing/` is for produced artifacts. Mirrors how `src/` and `apps/` are kept distinct from `docs/`. |
| **Marketing site at `apps/marketing/`, alongside the product app** | Monorepo pattern. Same repo means marketing skills can directly import or reference product components — the original goal. |
| **Don't enumerate all 39 skills in AGENTS.md routing table** | Bloat. Link to upstream README for the catalog; list bridge + most-used ones inline. |
| **Defer marketing-site stack decision** | Picking Next.js vs. Astro vs. plain HTML is project-specific. Template stays neutral. |
| **`/build`, `/ship`, `/ux-review` reused for marketing tasks** | They're already generic. Composition over duplication. Only `doc-updater` and `doc-sync-check.sh` learn about marketing dirs. |
| **Commit `.agents/product-marketing-context.md` (don't gitignore)** | It's positioning, not secrets. Should be reviewable in PRs and tracked over time. |

---

## Open Questions

| Q | Status |
|---|--------|
| Does Claude Code resolve project-vs-plugin skill name collisions in the project's favor? | ✅ **Verified Phase M1** — yes, project wins on the unprefixed slash form. No `disabledSkills` fallback needed. |
| Should `.agents/product-marketing-context.md` be committed? | **Confirmed (M2):** yes — `.agents/` is not gitignored. Positioning is reviewable in PRs and tracked over time. |
| Where should ad-hoc marketing experiments / drafts go that aren't yet collateral? | **Confirmed (M2):** use the existing `docs/(ignore) *.md` convention — e.g., `docs/(ignore) marketing-scratchpad.md`. Files matching `(ignore) *` are user scratch space and not picked up by skills. |
| Should the bridge skill auto-run as part of `/new-project`, or strictly user-invoked? | Tentatively: ask at end of `/new-project`, default to "run later." Re-evaluate after Phase M3. |
| What about marketing-skill versions / update fatigue? Upstream prompts to check for updates per session. | Keep upstream's behavior. Don't suppress it. If it gets noisy, revisit. |
| Should the template ship with a sample `apps/marketing/` skeleton (e.g., a starter Astro project) or stay empty? | Stay empty. Decision deferred to first user project. |

---

## What this plan does NOT change

- Anything from RESTRUCTURE_PLAN.md — every dev-side decision stands
- Existing dev skills (the 12 in `.claude/skills/`)
- The `doc-updater` agent's core behavior (only the prompt expands to include `marketing-strategy.md`)
- Hooks beyond the doc-sync watched-dirs list
- AGENTS.md sections 1, 3–12 — only Doc Map (§2), Routing (§13), Cross-Tool (§14), and the new §16 are touched
- `docs/product_spec.md`, `docs/architecture.md`, `docs/decision_log.md`, `docs/project_status.md`, `docs/changelog.md` — all preserved
- Cross-tool compatibility at the principles layer — `AGENTS.md` and `docs/standards/` stay universal
