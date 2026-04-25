---
name: plan
description: "Plan a milestone or a single feature. Altitude-aware — detects scope from input. Triggers on 'plan the X feature', 'plan the X milestone', 'plan out X', 'lay out the work for X', or /plan. Writes to project_status.md (milestone) or docs/Features/<feature>.md (feature). Do NOT use for atomic task implementation — that's /implement."
user-invocable: true
---

# Plan

Plan work at the right altitude. One skill, two outputs.

**Inputs:** the user's description of what to plan (a milestone like "v0.2 launch" or a feature like "dark mode toggle").

**Outputs:**
- **Milestone scope:** updated `docs/project_status.md` with feature build order.
- **Feature scope:** new `docs/Features/<feature-name>.md` filled from the template, plus a one-line in-progress entry in `docs/project_status.md`.

---

## Step 0: Detect altitude

Decide milestone vs. feature from the input. If unclear, ask.

| Signal | Altitude |
|---|---|
| Names a release, version, sprint, or quarter ("v0.2", "Q1 launch", "MVP") | **milestone** |
| Lists multiple features or capabilities | **milestone** |
| Names a single capability ("dark mode toggle", "stripe checkout") | **feature** |
| References an existing entry in `docs/Features/` | **feature** |

---

## Step 1: Read context

Read in this order, stopping early if scope is obvious:

1. `docs/project_status.md` — current state, what's already in flight
2. `docs/product_spec.md` — what we're building overall
3. `docs/architecture.md` — how it's built
4. `docs/decision_log.md` — prior calls that constrain this work
5. Any feature docs in `docs/Features/` that overlap

Don't read standards files (`docs/standards/*`) at plan time — they apply at implement/ship.

---

## Step 2A: Milestone planning

1. List the features that compose the milestone.
2. Order them by **dependency** (what must exist first), then **priority**. Don't break into phases — the goal is just sequencing.
3. Update `docs/project_status.md` with the build order. Keep it lightweight — names + one-line rationale per feature, not full specs. Each feature gets its own `/plan` pass later.
4. **Stop.** Do not create feature docs, do not update other files. Confirm with: "Milestone planned. Run `/plan <feature>` for the first feature when ready."

---

## Step 2B: Feature planning

1. Break the feature into **atomic implementation tasks** (~30–60 min each).
   - One task = one logical change to one or two files.
   - Do NOT include unit/integration tests as tasks — those run as a single `/test` pass after implementation.
   - You may include a separate "Test plan" section in the feature doc.
2. Create `docs/Features/<feature-name>.md` from `references/feature-template.md`. Fill in the sections that are knowable now; leave others as `{{TODO}}` placeholders.
3. Append the implementation task list to the feature doc as a checklist:
   ```markdown
   ## Implementation Tasks
   - [ ] Task 1: <action> in `<file>`
   - [ ] Task 2: <action> in `<file>`
   ```
4. Update `docs/project_status.md` with **one line** marking this feature in-progress. Keep it context-light.
5. **Stop.** Do not implement, do not touch other docs. Confirm with: "Feature planned at `docs/Features/<feature-name>.md`. Run `/implement` for task 1 when ready."

---

## Constraints

- Don't over-engineer. A feature plan is a checklist, not a design doc.
- Don't update `changelog.md`, `decision_log.md`, or `architecture.md` here — those happen at `/ship`.
- Don't create the feature doc if the user is asking for milestone planning. Be explicit about which mode you're in.
