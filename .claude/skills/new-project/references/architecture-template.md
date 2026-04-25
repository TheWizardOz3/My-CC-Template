# Architecture Template (used by /new-project Phase 2)

Question bank + section structure. The skill asks each question via `AskUserQuestion`, then writes the filled-in architecture to `docs/architecture.md`. Also updates AGENTS.md §1 + §12 placeholders.

---

## Sections to fill

### Tech stack (the headline)
**Ask sequentially with multiple-choice options:**

| Question | Options |
|---|---|
| Frontend framework? | React (Next.js / Vite) · Vue · Svelte · None (CLI/server-only) · Other |
| Backend framework? | Node (Express/Fastify/Hono) · Python (FastAPI/Django) · Go · Rust · Serverless functions · None |
| Database? | Postgres · SQLite · MongoDB · None · Other |
| Hosting? | Vercel · Cloudflare · AWS · Fly.io · Self-hosted · Other |
| Auth? | Clerk · Auth0 · Supabase Auth · NextAuth · Roll-your-own · None |

Skip questions that don't apply (e.g., no frontend → skip frontend question).

### System architecture diagram
Draw a simple ASCII diagram from the answers. Example pattern:
```
Frontend (React) → Backend (Node) → Database (Postgres)
                          ↓
                       Cache (Redis)
```
**Don't over-elaborate.** 3–5 boxes max for MVP. Detail accrues as the project grows.

### Data models
Leave as `{{TODO: derive from feature implementation}}` placeholder unless the user has explicit schema in mind. The first `/plan` call for a data-model feature will fill this in.

### API design
Same — placeholder unless user has it in mind.

### Tech stack with rationale (table)
For each chosen technology, write **one line** of rationale. "Postgres because we need relational queries and ACID" — not a paragraph.

### Security considerations
**Ask:** "PII, payments, HIPAA, SOC2, anything?"
- If yes → enumerate the constraint and the mitigation (encryption, audit logging, etc.).
- If no → write "Standard web app threat model. See `docs/standards/security.md`."

### Infrastructure & deployment
One paragraph from the hosting answer. Skip CI/CD details unless the user volunteers them.

---

## AGENTS.md updates (after writing architecture)

Update **only**:
- **§1 Project Identity**:
  - `{{Brief description...}}` ← one-line summary from product_spec
  - `{{PRIMARY/SECONDARY/TERTIARY_OBJECTIVE}}` ← top 3 from product_spec MVP scope
  - `{{FRONTEND_FRAMEWORK}} / {{BACKEND_FRAMEWORK}} / {{DATABASE}} / {{HOSTING}}` ← tech stack answers
  - `{{SIMPLIFIED ARCHITECTURE DIAGRAM}}` ← the diagram drawn above
  - `{{PRINCIPLE_1..3}}` ← 3 design principles from product_spec
- **§12 Quick Reference Commands**:
  - Replace each `{{COMMAND}}` placeholder with the actual command for the chosen stack (e.g., `pnpm dev`, `pnpm build`, `pnpm lint`, `pnpm test`).
- **§15 Project-Specific Guidelines** — leave alone unless the user has a specific convention to capture.

**Do NOT** modify §2–§11 (universal cross-tool rulebook) or §13–§14 (tool-specific routing/cross-tool sections).

---

## Writing rules

- Default to **simplest viable** stack. Don't recommend Kubernetes for a 100-user MVP.
- Don't fabricate scale targets. "Internal-only" is a valid answer.
- Where the user is unsure, surface the tradeoff and ask — don't pick silently.
- Confirm with the user before saving.
