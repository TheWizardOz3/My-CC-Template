# AI Assistant Instructions: {{PROJECT_NAME}}

> Master instructions for AI coding assistants. This file governs behavior, coding standards, and guardrails. Universal across tools (Claude Code, Cursor, Codex). See §14 for cross-tool notes.

---

## 1. Project Identity

**One-Line Summary:** {{Brief description of what this product does}}

**Core Objectives:**
1. {{PRIMARY_OBJECTIVE}}
2. {{SECONDARY_OBJECTIVE}}
3. {{TERTIARY_OBJECTIVE}}

**Tech Stack (Quick Ref):** {{FRONTEND_FRAMEWORK}} / {{BACKEND_FRAMEWORK}} / {{DATABASE}} / {{HOSTING}}

**System Architecture:**
```
{{SIMPLIFIED ARCHITECTURE DIAGRAM}}

Example:
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   Frontend   │ ──── │   Backend    │ ──── │   Database   │
│   (React)    │ HTTP │   (Node)     │      │  (Postgres)  │
└──────────────┘      └──────┬───────┘      └──────────────┘
                             │
                      ┌──────┴───────┐
                      │    Cache     │
                      │   (Redis)    │
                      └──────────────┘
```

**Design Principles:**
- **{{PRINCIPLE_1}}:** {{Brief description}}
- **{{PRINCIPLE_2}}:** {{Brief description}}
- **{{PRINCIPLE_3}}:** {{Brief description}}

---

## 2. Documentation Map

| Document | Purpose | When to Reference |
|----------|---------|-------------------|
| `docs/product_spec.md` | Requirements, features, UX specs | New features, understanding "what" to build |
| `docs/architecture.md` | Tech stack, system design, patterns | Implementation decisions, "how" to build |
| `docs/decision_log.md` | Architecture decisions & rationale | Before proposing major changes |
| `docs/project_status.md` | Current progress, blockers, next steps | Session start, understanding context |
| `docs/changelog.md` | Version history, recent changes | Understanding recent modifications |
| `docs/Features/` | Individual feature specifications | Detailed feature work |
| `docs/standards/` | Detailed coding/error/security/testing/performance standards | On demand when writing or reviewing code |

> **⚠️ CRITICAL:** Documentation must be kept in sync with code changes. See §11 for mandatory update triggers.

---

## 3. Critical Constraints (Non-Negotiables)

**Security:** Never commit secrets — use env vars. Never log sensitive data (passwords, tokens, PII). Validate all user input server-side. Use parameterized queries. Encrypt credentials at rest. → `docs/standards/security.md`

**Data Integrity:** Migrations must be reversible. Prefer soft deletes for business data. Enforce tenant isolation. Audit destructive operations. No manual DB edits — always migrations.

**Code Quality:** Lint and type-check pass before commit. Avoid `any` in TypeScript. No disabled lint rules without justification. No TODO/FIXME without ticket. → `docs/standards/coding.md`

**Reliability:** External API calls require timeout + retry + error handling. Async operations handle failure. List endpoints are paginated. Background jobs are idempotent. → `docs/standards/errors.md`

**Deployment:** PR review required before merge to main. CI must pass. Staging verification before prod. Feature flags for risky changes.

---

## 4. Development Workflow

### 4.1 Git Standards

**Branches:** `feat|fix|chore|docs|hotfix/{{ticket-id}}-short-description`

**Commits:** Use [Conventional Commits](https://conventionalcommits.org) — `type(scope): subject`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`
- Atomic commits (one logical change), present tense imperative, ≤72 char subject
- Reference ticket in footer: `Refs: #123`

### 4.2 Pre-Commit Requirements

- [ ] Builds without errors
- [ ] Linter and formatter pass
- [ ] Tests pass
- [ ] No debug statements, commented code, or hardcoded secrets
- [ ] New dependencies documented

**Never commit:** broken builds, failing tests, incomplete refactors

---

## 5. Coding Standards

### 5.1 General Principles

- **Readability over cleverness:** Write code for humans first
- **DRY (Don't Repeat Yourself):** Extract shared logic, but avoid premature abstraction
- **YAGNI (You Aren't Gonna Need It):** Don't build for hypothetical future requirements
- **Single Responsibility:** Functions/classes do one thing well
- **Explicit over implicit:** Favor clarity over magic
- **Fail fast:** Validate early, surface errors immediately

> Naming conventions, code organization, function rules, comment policy, and TypeScript specifics live in [`docs/standards/coding.md`](docs/standards/coding.md). Load on demand.

---

## 6. Error Handling

### 6.1 Principles

- Never swallow errors silently
- Log errors with context (what operation, what input)
- Provide user-friendly messages (hide technical details from users)
- Use typed errors when possible
- Fail fast on invalid state

> Error class patterns, frontend boundary patterns, and logging-level standards live in [`docs/standards/errors.md`](docs/standards/errors.md).

---

## 7. Security Guidelines

### 7.1 Data Handling

- **Never log:** passwords, tokens, API keys, PII, credit card numbers
- **Never commit:** secrets, credentials, environment files (.env)
- **Always sanitize:** user input before display (prevent XSS)
- **Always parameterize:** database queries (prevent SQL injection)
- **Always validate:** input on both client AND server

### 7.2 Authentication & Authorization

- Store tokens securely (httpOnly cookies preferred over localStorage)
- Implement token refresh before expiration
- Check authorization on every protected operation (server-side)
- Use principle of least privilege
- Invalidate sessions on password change/logout

> Full security checklist (CSRF, rate limiting, headers, encryption-at-rest, audit logging) lives in [`docs/standards/security.md`](docs/standards/security.md).

---

## 8. Testing Requirements

### 8.1 Coverage Expectations

| Test Type | Requirement |
|-----------|-------------|
| Unit Tests | All business logic, utilities, helpers |
| Integration Tests | API endpoints, database operations |
| E2E Tests | Critical user journeys only |

### 8.2 What to Test

**Always Test:** business logic and calculations, data transformations, validation logic, error handling paths, edge cases (empty arrays, null values, boundaries).

**Don't Over-Test:** third-party library internals, simple getters/setters, framework behavior, implementation details (test behavior, not implementation).

> Test quality standards (independence, determinism, naming, AAA structure) live in [`docs/standards/testing.md`](docs/standards/testing.md).

---

## 9. Performance Guidelines

Optimize for the bottleneck that matters: paginate list endpoints, index frequently-queried fields, lazy-load heavy frontend modules, debounce expensive operations, and avoid N+1 queries. Don't pre-optimize without evidence.

> Frontend, backend, and anti-pattern checklists live in [`docs/standards/performance.md`](docs/standards/performance.md).

---

## 10. AI Assistant Behavior

### 10.1 Before Making Changes

1. **Read `AGENTS.md`** first to understand core instructions
2. **Read `project_status.md`** first to understand current context and priorities
3. **Read relevant files** before proposing edits — don't assume
4. **Understand context** — check related files, existing patterns
5. **Review `architecture.md`** for established patterns
6. **Check `decision_log.md`** for prior decisions on similar topics

### 10.2 When Writing Code

- Follow existing patterns in the codebase — match style of surrounding code
- **Search for existing utilities/helpers before creating new ones** — avoid duplication
- **Check for existing similar components/functions** — extend rather than recreate
- Prefer editing existing files over creating new ones
- Keep changes minimal and focused on the task
- Verify imports resolve correctly after adding/moving code

### 10.3 What NOT to Do

- Don't add features beyond what's requested
- Don't refactor unrelated code *in the same commit* (separate refactors into their own commits)
- Don't add "nice to have" error handling for impossible cases
- Don't create abstractions for one-time operations
- Don't add dependencies without explicit approval
- Don't generate placeholder content or TODO implementations
- Don't modify configuration files without explaining why
- Don't delete tests or reduce test coverage
- **Don't create duplicate functions/variables** — reuse existing code
- **Don't shadow variable names** — use distinct, descriptive names
- Don't leave unused imports, variables, or dead code
- **Don't skip documentation updates** — always update relevant docs after making changes
- **Don't leave `project_status.md` stale** — update it at session end

### 10.4 After Making Changes

> **⚠️ MANDATORY:** Always update documentation after completing work. This is not optional.

1. **Update `changelog.md`** with what was added, changed, or fixed
2. **Update `project_status.md`** to reflect current progress
3. **Add to `decision_log.md`** if any architectural decisions were made
4. **Update `architecture.md`** if tech stack, schema, or API changed
5. **Create/update feature docs** in `docs/Features/` for feature work

**Never leave documentation stale.** Documentation updates are part of completing the work, not a separate task.

### 10.5 Communication

- Explain significant architectural decisions
- Flag potential issues or concerns proactively
- Ask clarifying questions when requirements are ambiguous
- Summarize changes made at the end of significant work
- Confirm which documentation was updated after completing work

---

## 11. Documentation Maintenance

> **⚠️ MANDATORY:** AI assistants MUST automatically update relevant documentation after completing key actions.

### 11.1 Automatic Documentation Update Triggers

| Trigger Event | Required Documentation Updates |
|---------------|-------------------------------|
| **Feature completed (all tasks)** | `changelog.md` (Added), `project_status.md` (move to Completed) |
| **Bug fixed** | `changelog.md` (Fixed), `project_status.md` (update Known Issues if applicable) |
| **New dependency added** | `architecture.md` (tech stack), `changelog.md` (Dependencies) |
| **Database schema changed** | `architecture.md`, `decision_log.md` (if significant), `changelog.md` |
| **API endpoint added/changed** | `architecture.md`, `changelog.md` |
| **Tech stack decision made** | `decision_log.md`, `architecture.md` |
| **Breaking change introduced** | `changelog.md` (Breaking + migration), `decision_log.md` |
| **Work session started** | Read `project_status.md` first |
| **Work session ended** | `project_status.md` (progress, blockers, next steps) |
| **Milestone completed** | `project_status.md`, `changelog.md`, possibly version tag |
| **Error pattern resolved** | `decision_log.md` (with AI Instructions for future prevention) |
| **New feature planned** | Create `docs/Features/{{feature_name}}.md` |

### 11.2 Documentation Standards

- Keep docs up-to-date with code changes — never stale
- Date entries in changelog and decision log (YYYY-MM-DD)
- Link related documents using relative paths
- For decision_log entries: always include `AI Instructions` section to guide future AI behavior

### 11.3 Post-Action Checklist

After completing significant work, verify:
- [ ] `changelog.md` reflects what changed
- [ ] `project_status.md` reflects current state
- [ ] `decision_log.md` captures any architectural decisions made
- [ ] `architecture.md` updated if tech stack or structure changed
- [ ] Feature docs created/updated for feature work

---

## 12. Quick Reference Commands

```bash
# Development
{{DEV_START_COMMAND}}           # Start development server
{{BUILD_COMMAND}}               # Build for production
{{LINT_COMMAND}}                # Run linter
{{FORMAT_COMMAND}}              # Run formatter

# Testing
{{TEST_COMMAND}}                # Run all tests
{{TEST_WATCH_COMMAND}}          # Run tests in watch mode
{{TEST_COVERAGE_COMMAND}}       # Run tests with coverage

# Database
{{DB_MIGRATE_COMMAND}}          # Run migrations
{{DB_SEED_COMMAND}}             # Seed database
{{DB_RESET_COMMAND}}            # Reset database

# Other
{{TYPE_CHECK_COMMAND}}          # TypeScript type check
{{GEN_TYPES_COMMAND}}           # Generate types from schema
```

---

## 13. Skill Routing Table

> Maps user intent to skills. Project-specific skills live in `.claude/skills/`. Built-ins ship with the harness — invoke them, don't reinvent. Populated as skills land in later phases.

| Intent | Use | Type | Status |
|--------|-----|------|--------|
| Plan a feature or milestone | `/plan` | project skill | available |
| Implement one atomic task | `/implement` | project skill | available |
| End-to-end orchestrated build (plan → implement → test via subagents) | `/build` | project skill | available |
| Run/write tests for a feature | `/test` | project skill | available |
| Finalize a feature (lint, simplify, security review, docs, commit) | `/ship` | project skill | available |
| Wrap up a session (housekeeping, ensure docs current) | `/end-session` | project skill | available |
| Bootstrap a new project (interactive onboarding) | `/new-project` | project skill | available |
| Drive a real browser (UI testing, interactions) | `/agent-browser` | project skill | available |
| Root-cause an actual bug (4-phase methodology) | `/debug` | project skill | available |
| Evaluate UI for usability + polish + design-reference consistency | `/ux-review` | project skill | available |
| Create or evolve a skill | `/skill-creator` | project skill | available |
| Review code for reuse, quality, efficiency | `/simplify` | built-in | available |
| Security review pending changes | `/security-review` | built-in | available |
| Review a PR | `/review` | built-in | available |
| Bootstrap CLAUDE.md in a downstream project | `/init` | built-in | available |
| Codebase exploration (search, locate code) | `Explore` agent | built-in | available |
| Architect a feature implementation | `feature-dev:code-architect` | built-in | available |
| Trace existing feature internals | `feature-dev:code-explorer` | built-in | available |
| Independent code review pass | `feature-dev:code-reviewer` | built-in | available |
| Apply brief doc updates from a diff (changelog, project_status, decision_log) | `doc-updater` | project agent | available |

---

## 14. Cross-Tool Compatibility

This template supports multiple AI coding tools. The split:

- **`AGENTS.md` (this file)** — universal rulebook. Read by Claude Code, Cursor, Codex, and any other tool that follows the AGENTS.md convention.
- **`docs/standards/*`** — universal reference material. Plain markdown, no tool-specific syntax. Loadable by any tool on demand.
- **`CLAUDE.md`** — Claude Code overlay. Imports `AGENTS.md` via `@AGENTS.md`, then adds Claude-Code-specific notes (skill paths, hook wiring).
- **`.claude/`** — Claude Code-only. Hooks, skills, agents, settings. Other tools ignore this directory.

When adding new guidance: principles and standards go in `AGENTS.md` or `docs/standards/`. Tool-specific behavior (hooks, slash commands, skill descriptions) goes in `.claude/`.

---

## 15. Project-Specific Guidelines

{{Add any project-specific conventions, patterns, or rules that don't fit the categories above}}

---

*Last Updated: {{DATE}}*
