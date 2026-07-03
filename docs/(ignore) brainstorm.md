# Brainstorm: The Waygate Ecosystem — Platform Primitives Catalog

> **What this file is:** Seed material for `/new-project` (its Phase 0 reads this file automatically). It contains the full ecosystem plan for a family of Waygate-shaped platform primitives, plus the process for spinning up each repo as its own project from this template. Commit this file to the template repo so every clone carries the catalog.

---

## How to start a new repo (do this first, every time)

Primitives group into **repos** — see the Repo map below; several primitives share a repo. Each repo is bootstrapped from this template. Do NOT build these inside Waygate or inside this template repo.

### Bootstrap prompt (run from a Claude Code session in THIS template repo)

One paste does the whole mechanical setup — clone, detach from template history, create the GitHub repo, push — and ends by handing you the kickoff prompt for the new project. Swap `<repo-name>` (e.g. `rune`, `aegis`) and paste:

```
Bootstrap a new Waygate-ecosystem platform repo named <repo-name> from this
template, then hand me the onboarding kickoff prompt.

1. Pre-flight: confirm docs/(ignore) brainstorm.md is committed (a clone only
   carries committed state) and that `jq` and `gh` (authenticated) are
   available — the template's hooks fail closed without jq. Stop and tell me
   if anything is off.
2. Clone this repo into a sibling directory: `git clone . ../<repo-name>`
3. Detach it from template history: in ../<repo-name>, remove the .git
   directory, `git init`, then commit everything as
   "chore: bootstrap from My-CC-Template".
4. Create the private GitHub repo and push:
   `gh repo create <repo-name> --private --source=../<repo-name> --push`
5. Do NOT run /new-project from this session — it must run in a fresh session
   inside the new project so its skills, hooks, and docs resolve there. Finish
   by printing the "Kickoff prompt" from docs/(ignore) brainstorm.md with
   <repo-name> filled in, and remind me to open a new Claude Code session in
   ../<repo-name> and paste it there.
```

### Kickoff prompt (pasted into the fresh session in the new repo)

`/new-project` runs once per project and fills in `docs/product_spec.md`, `docs/architecture.md`, `.env.example`, `docs/project_status.md`, and `docs/design-references.md`. The bootstrap prompt above prints this with the repo name filled in:

```
/new-project

We're building **<REPO>** (e.g. aegis), one of the platform repos from the
Waygate ecosystem plan in docs/(ignore) brainstorm.md. Read that file first —
especially the "Waygate-shaped DNA" section, the Repo map entry for this repo
(it may bundle several primitives), and the catalog entries it covers — and use
them to pre-fill your answers where possible; only ask me about genuine gaps.

Context you should carry into every phase:
- This is a headless, API-first [svc]/[lib] primitive, NOT a full app with its
  own dashboard (unless the catalog entry says [app]).
- It must follow the Waygate DNA: typed + Zod-validated API, the shared
  success/error/suggestedResolution error envelope, multi-tenant via app keys,
  and it must ship an MCP server + tool definitions and self-register into
  Waygate as an integration.
- MVP scope = the smallest version another app of mine could actually consume.
  Explicit non-goal: dashboards/UI beyond a minimal health/config surface.

After onboarding completes, suggest the first /plan milestone.
```

### After onboarding

- `/plan` the MVP milestone, then `/build` or `/plan` → `/implement` → `/test` → `/ship` per feature.
- When the primitive is consumable, register it in Waygate and (once it exists) in **Codex**, the meta-registry (#18).
- Prune this brainstorm file in the new repo down to the entry you're building, or delete it once the product spec captures everything — `/new-project` will suggest this at wrap-up.

---

## The organizing idea

Waygate is one noun in the platform: **Integrations** — "reach out and take an action in someone else's API." Every app needs a handful of other nouns too — Identity, Memory, Money, Messages, Files, Events, People. Right now those get rebuilt per project. The ecosystem move is to make each one its own Waygate-shaped primitive.

### Waygate-shaped DNA (every primitive copies this, so they compose instead of sprawl)

- **API-first, typed, Zod-validated**, same LLM-friendly error envelope (`success` / `error` / `suggestedResolution`).
- **Multi-tenant by default** — every primitive takes a tenant/app key, like Waygate does.
- **Agent-native** — each ships an MCP server + tool definitions and **self-registers into Waygate as an integration**. That's the flywheel: the moment "Herald" (notifications) exists, agents can call it through the same gateway used for Slack and Stripe. Waygate becomes the front door to your own services, not just third-party ones.

These aren't 21 random side projects — they're the rest of the standard library, each discoverable through Waygate.

---

## The catalog

Form-factor tags: `[svc]` plug-and-play service · `[lib]` primitive/SDK · `[app]` has its own UI · `[cli]` script/tool.

### Tier 1 — the substrate every app needs (build these first)

| # | Name | Form | What it is | Why it's not already Waygate |
|---|------|------|------------|------------------------------|
| 1 | **Aegis** | [svc] | End-user identity: authentication (signup/login/sessions/OAuth-as-IdP), orgs/teams, app-domain RBAC | Waygate already has more here than it looks: app API keys (`App.apiKeyHash`, bcrypt + SHA-256 index), a user *directory* (`AppUser` keyed by `externalId`), per-user integration credentials + connect flow, and roles — but only over Waygate's own invokable targets (tool-invocation governance). What's missing is the thing in front: nothing *authenticates* the user or answers app-domain questions ("can they see the billing page"). Aegis issues the identity; its user ID becomes Waygate's `AppUser.externalId`. Reuse Waygate's key pattern (hash + index, revoke-don't-delete). |
| 2 | **Grimoire** | [svc] | Memory & knowledge: vector store + RAG + document ingestion + retrieval API | Waygate's architecture explicitly says "no vector DB." Pairs with existing Firecrawl scraping to turn any docs into recallable memory. |
| 3 | **Sigil** | [svc][cli] | Secrets, config & feature flags — one source of truth across all projects, with kill switches | Env vars are managed per-project today. Centralize it; flags let you ship risky things dark. |
| 4 | **Tollgate** | [svc] | Billing & entitlements: Stripe wrapper, plans, metering, `can(user, feature)` checks | Founder need. Build the paywall/entitlement logic once, reuse on every product. |
| 5 | **Herald** | [svc] | Unified notifications: email/SMS/Slack/push/in-app with templates, user preferences, dedup | Sits on top of Waygate's send actions — adds the templating/prefs/throttling layer Waygate deliberately doesn't. |

### Tier 2 — orchestration & intelligence

| # | Name | Form | What it is | Note |
|---|------|------|------------|------|
| 6 | **Loom** | [svc] | Durable workflow engine — cron/event-triggered, each step calls Waygate tools | This is "Zapier for myself," which the Waygate spec says Waygate explicitly is not. The natural consumer of the tool registry. |
| 7 | **Oracle** | [svc] | Agent runtime — runs LLM loops given Waygate tools + Grimoire memory, with traces/evals/replay | Waygate defines tools; Oracle runs the agent that uses them. Closes the loop. |
| 8 | **Gatekeeper** | [svc] | Inbound webhook receiver/router → normalizes and fans out to Loom/Waygate | The inbound twin of Waygate's outbound calls. Already on the Waygate V2.3 roadmap — pull it out as its own primitive. |
| 9 | **Scry** | [svc][lib] | Event capture + product analytics + funnels + attribution | Founder + marketer instrument-everything layer. |
| 21 | **Mana** | [svc] | LLM gateway/router — the **inference plane** to Waygate's action plane: one typed API over all providers, model routing + fallback chains (cheap-fast tier vs. frontier tier), per-tenant/app token metering + budgets, caching, rate limits, prompt/completion logging | Extraction seed already inside Waygate (`PlatformAiKey`, `PlatformAiConfig`, model registry, tracing adapters) — pull it out like Gatekeeper; Waygate's AI features then route through it. Oracle *consumes* Mana, doesn't contain it — Grimoire (embeddings) and Quill (generation) need inference without an agent runtime. Feeds Tollgate (billing), Scry (analytics), Oracle (evals); keys from Sigil, kill switches via Sigil flags. **Don't rebuild LiteLLM** — v1 is a thin Waygate-DNA wrapper around LiteLLM/OpenRouter; the differentiated part is metering/routing/policy, not provider adapters. |

### Tier 3 — founder/marketer leverage

| # | Name | Form | What it is |
|---|------|------|------------|
| 10 | **Ledger** | [svc] | People/contacts/CRM primitive — unified person store, audiences, segments (feeds Herald + Scry) |
| 11 | **Quill** | [svc][app] | AI marketing content engine — landing copy, email sequences, SEO, repurposing |
| 12 | **Scribe** | [svc] | Document & asset pipeline — file storage, PDF/doc generation, image transforms, OG-image rendering |
| 13 | **Intake** | [app][svc] | Schema-driven forms → routes submissions into Ledger/Loom |
| 14 | **Atlas** | [svc] | Search as a service — full-text + semantic over any app's data (shares Grimoire's embeddings) |
| 15 | **Tracer** | [svc] | Link shortener + UTM + attribution (marketer staple; feeds Scry) |

### Tier 4 — the glue that makes it an ecosystem (small, high-leverage)

| # | Name | Form | What it is |
|---|------|------|------------|
| 16 | **Rune** | [lib] | One typed TypeScript SDK every app imports to talk to all the above — shared error envelope, retries, auth. The thing that makes them feel like one platform. |
| 17 | **Portal** | [cli] | Project scaffolder — `npx portal new` spins up a Next.js app pre-wired to Waygate + Aegis + Sigil + Rune. Kills the blank-page tax. |
| 18 | **Codex** | [svc] | Meta-registry — a registry of your own services (discovery, docs, "which app depends on what"). Waygate's action registry, but for your microservices. |
| 19 | **Beacon** | [svc][cli] | Uptime/health + cron-heartbeat monitor across everything you run |
| 20 | **Chronicle** | [lib][svc] | Drop-in audit log + activity feed — append-only, queryable, satisfies the "audit logging" constraint in AGENTS.md. Partial seed in Waygate (`GovernanceAuditEvent`, `RequestLog`) — internal-only today, not consumable by other apps |

---

## Repo map (concepts ≠ repos)

**Rule:** a repo boundary is a **deployment-lifecycle** boundary, not a concept boundary. Merge primitives that share a data domain, a consumer, and a release cadence. The DNA (multi-tenant, API-first, own MCP surface per primitive) makes merges cheap to undo — splitting later is a repo move, not a rewrite. The one thing never to share across primitives is a **database**, except where the data genuinely is one domain (embeddings, events).

21 primitives → **6 active repos + Waygate**:

| Repo | Contains | Rationale |
|------|----------|-----------|
| `rune` (platform-core monorepo) | `packages/*`: **Rune** SDK (#16), **Portal** CLI (#17), shared contracts (error envelope, Zod schemas, MCP self-registration helper), typed clients for every service, **Chronicle** lib (#20). `apps/keep`: the **Keep** control-plane service — **Sigil** (#3 secrets/config/flags), **Codex** (#18 service registry), **Beacon** (#19 health), Chronicle svc | The platform itself: contract layer + control plane, everything that must exist before any product. Standard pnpm/turborepo shape — `packages/*` publish to npm, `apps/keep` deploys. Service clients and the Codex registry schema stay in lockstep by construction. |
| `aegis` | **Aegis** (#1) | Security-sensitive, big enough alone. |
| `herald` | **Herald** (#5) | Standalone. |
| `oracle` | **Mana** (#21) + **Oracle** (#7) | One agent-building experience — model routing and agent loops get iterated together. Guardrail: Mana stays its own deployable + API surface inside the repo, so Grimoire/Quill/Waygate can consume inference without importing the runtime. |
| `grimoire` | **Grimoire** (#2) + **Atlas** (#14) | Search and RAG retrieval are the same embedding index with two query surfaces. Atlas is a feature, not a repo. |
| `loom` | **Loom** (#6) + **Gatekeeper** (#8) | Gatekeeper is Loom's ingestion edge. Split only if the always-up/dumb/fast webhook profile diverges from the stateful engine. |
| *(demand-pulled)* | **Tollgate** (#4) and **Scribe** (#12) get own repos when built. **Scry** (#9) + **Tracer** (#15) share one (Tracer is an event-capture front door with a redirect). **Intake** (#13) starts as a **Ledger** (#10) module. **Quill** (#11) is likely not a repo at all — a composition of Loom workflows + Oracle prompts + Scribe rendering | Let demand pull them. |

**Trade-offs accepted deliberately:**
- `rune` mixes npm packages with a deployed secrets service. Fine solo; keep the npm-publish and deploy pipelines separate in CI. Split trigger: Rune gets open-sourced or a second contributor arrives — Keep (Sigil first) moves out then.
- `oracle` couples the inference plane to its heaviest consumer. Acceptable while Mana is a thin LiteLLM wrapper; split if a second heavy consumer makes Mana's release cadence diverge.

---

## Build order (sequenced for leverage, not completeness)

1. **`rune` platform core** (#16, #17, #3, #18, #19). Boring, but the multiplier — SDK + scaffold + a minimal Keep (Sigil config/flags first; Codex and Beacon can start as stubs). Every repo after this is cheaper and more consistent.
2. **Aegis + Herald** (#1, #5). These unblock shipping any real product. Stop rebuilding login and "send the user an email" every time.
3. **Mana** (#21) the moment anything needs inference, then **Loom + Grimoire** (#6, #2), then **Oracle** (#7). Where the Waygate composition gets exciting — durable workflows driving the tool registry, with memory and a metered inference plane. The part nobody else's stack gives you off the shelf.
4. **Tollgate, Scry, Ledger** — pull in as actual products demand them. Don't pre-build CRM and billing before there's a thing to bill for.

**Skeptical of building early:** Quill, Forge-style admin generators, Atlas — real, but "nice when you have 5 apps," not "needed to ship app #1." Let demand pull them.

## Standing opinion: resist the dashboard tax

Resist making each of these a full `[app]` with its own UI. The win is that they're `[svc]`/`[lib]` — headless, API-first, agent-callable — and the **one** UI is a thin console (could live inside Waygate's config UI) that reads from Codex. Otherwise "rebuild auth per project" gets traded for "maintain 20 dashboards."

---

## Progress tracker

| Repo | Primitives | Remote | Status |
|------|------------|--------|--------|
| `rune` | Rune #16, Portal #17, Keep (Sigil #3, Codex #18, Beacon #19, Chronicle #20) | — | not started |
| `aegis` | Aegis #1 | — | not started |
| `herald` | Herald #5 | — | not started |
| `oracle` | Mana #21, Oracle #7 | — | not started |
| `grimoire` | Grimoire #2, Atlas #14 | — | not started |
| `loom` | Loom #6, Gatekeeper #8 | — | not started |
| *(demand-pulled)* | Tollgate #4, Scry #9 + Tracer #15, Ledger #10 + Intake #13, Scribe #12, Quill #11 (likely a composition, not a repo) | — | — |
