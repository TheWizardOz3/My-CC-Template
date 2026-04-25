---
name: test
description: "Feature-level testing pass: run existing tests, write new ones for what just shipped, browser-verify UI changes. Triggers on 'test the X feature', 'write tests for X', 'verify X', or /test. Runs after /implement is done for all tasks in a feature, before /ship. Do NOT use for unit-test-as-you-go (that belongs in /implement only when explicitly requested)."
user-invocable: true
---

# Test

Single testing pass for a completed feature. Write new tests, run all tests, browser-verify if there's UI. No commits, no doc updates.

**Input:** feature name. Infer from `docs/project_status.md` (in-progress feature) if not given.

---

## Step 1: Read the feature doc

Read `docs/Features/<feature-name>.md`. Note:
- Acceptance criteria (§2.3)
- Test plan (if present)
- Implementation tasks (what was built)

Skim `docs/standards/testing.md` for project test conventions (location, framework, naming).

---

## Step 2: Identify what to test

For each acceptance criterion + implementation task, decide:

| Layer | When to add a test |
|---|---|
| **Unit** | New business logic, calculations, transformations, validation, error paths |
| **Integration** | New API endpoint, new DB query, anything that crosses a service boundary |
| **E2E** | New critical user journey (sparingly — they're slow and brittle) |

Don't test third-party internals, simple getters, or framework behavior. Test behavior, not implementation.

---

## Step 3: Run existing tests

Run the project's full test command first. Anything red here is a regression caused by this feature — fix before writing new tests.

---

## Step 4: Write new tests

- Place tests next to the convention used in the project (colocated `*.test.ts` next to source, or in a parallel `tests/` tree).
- One assertion per test where possible. Independent (no shared state across tests).
- Cover the acceptance criteria explicitly — at least one test per criterion.
- Cover edge cases: empty input, null, boundary values, error paths.
- Re-run the full suite. All green.

---

## Step 5: Browser verification (UI features only)

If the feature has a UI surface and `agent-browser` is available, drive a real browser through the happy path and the most important edge case.

**Cost guard:** if any path triggers a paid API (LLM call, paid scraper, payment processor), STOP and ask before proceeding.

If `agent-browser` is not yet installed (Phase 7), skip this step and note it in the report — the user can verify manually.

---

## Step 6: Report

End with a clear status:

> Testing complete.
> - Existing tests: <pass/fail count>
> - New tests added: <count> in `<paths>`
> - Coverage: <criteria covered / criteria total>
> - Browser check: <pass / N/A / skipped>
> Ready to `/ship`?

---

## Constraints

- **No commits.** Don't `git add` or `git commit`.
- **No doc updates.** `/ship` handles changelog/project_status/decision_log.
- **No code changes outside tests** unless a regression forces a fix — and if so, surface that fix explicitly in the report. The feature was supposed to be done.
- If acceptance criteria can't be tested as written (ambiguous, untestable), say so — don't fake a passing test.
