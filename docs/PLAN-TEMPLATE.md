# {Project Name} Implementation Plan

**Version:** 1.0
**Date:** {YYYY-MM-DD}
**Status:** Planning
**Branch:** `main`
**Source:** {Link to design docs, PRD, spec, or requirements}
**Estimated total effort:** {range, e.g. "8-12 hours (4-6 sessions)"}
**Dependencies:** {build tools, runtimes, SDKs}

---

## How to Use This Document

This plan is designed for execution by an **orchestrator agent** that
delegates implementation to specialized agents (`@code-writer`,
`@code-review`, `@docs-writer`) while maintaining full project context.

The orchestrator NEVER writes implementation code directly. Every line of
code is delegated. The orchestrator's job is to sequence work, provide
context, verify output, enforce quality gates, and maintain this plan.

### Orchestrator Workflow

For **every task**, follow this exact sequence:

```
1. DELEGATE  ->  @code-writer (with detailed prompt from this plan)
2. BUILD     ->  Verify: {build command} passes with zero warnings
3. TEST      ->  Smoke test the relevant functionality
4. LOOK      ->  (if UI changed) Visual verification
5. REVIEW    ->  @code-review (with review criteria)
6. FIX       ->  @code-writer (with specific review findings)
7. RE-REVIEW ->  (if fixes were substantial: >3 files or logic changes)
8. COMMIT    ->  Only after zero blockers from review
9. UPDATE    ->  Mark status table done, record commit SHA
```

**No exceptions.** Even trivial tasks get reviewed. Early reviews catch
architectural issues before they compound. The cost of a review is minutes;
the cost of a missed bug is hours.

### Context Window Strategy

- **Load all design docs at session start** before delegating any work.
- **Never compact mid-project** — retain full context across all tasks.
- **Include all necessary context in delegation prompts** — delegated
  agents have no prior context. Include file paths, API signatures,
  data model details, and relevant design doc sections.
- **Carry cumulative knowledge forward** — later tasks reference earlier
  implementations. Include file paths and API signatures from prior
  tasks in delegation prompts for dependent tasks.

### Resuming Mid-Plan

An agent resuming mid-plan should:

1. Read this entire document
2. Read all design/spec docs listed in Authoritative References
3. Check the per-task status tables for the first incomplete step
4. Run `git log --oneline -20` and `git status` to orient
5. Read source files created by completed tasks to rebuild context
6. Resume from the first incomplete step

### Authoritative References

| Document | Purpose       |
| -------- | ------------- |
| {path}   | {description} |

### Validation Commands

```bash
# Build (must pass before every commit)
{build command, e.g. "make clean && make all"}

# Lint (if separate from build)
{lint command}

# Test (if applicable)
{test command}

# Smoke test
{manual verification command}
```

---

## Plan Maintenance Protocol

This document is a living artifact. Keep it accurate:

1. **Status tables** — update **immediately** after completing each step
   (not in batches). Valid states: `pending`, `in progress`, `done`,
   `blocked`, `skipped`.
2. **Notes column** — record:
   - Commit SHA after committing (e.g., `a1b2c3d`)
   - Review outcomes (e.g., "1 blocker, 2 issues — fixed")
   - Design deviations from the original spec
3. **Decision log** — if a task reveals a design decision not already
   recorded, add a row to the Decision Log **before** implementing.
4. **Plan version** — bump the Version field when making structural
   changes to the plan itself.

---

## Decision Log

Record every non-obvious design decision. If it's not in the spec, it
goes here before implementation.

| #   | Topic | Decision | Rationale |
| --- | ----- | -------- | --------- |
| 1   |       |          |           |

---

## DRY Invariants

Define the project's DRY rules upfront. Each invariant gets a grep
check in the verification checklist.

**Invariant pattern:** "{Thing X} only lives in {File Y}. No other file
should {do Z}."

| #   | Invariant                       | Canonical location | Grep check                                         |
| --- | ------------------------------- | ------------------ | -------------------------------------------------- |
| 1   | {e.g., "All database queries"}  | {e.g., "src/db/"}  | `grep -rn "{pattern}" src/ \| grep -v {canonical}` |
| 2   | {e.g., "All API keys/secrets"}  | {e.g., ".env"}     | `grep -rn "API_KEY\|SECRET" src/ \| grep -v .env`  |
| 3   | No force-unwrapping             | Everywhere         | `grep -rn 'as!' src/*.{ext}`                       |
| 4   | No TODO/FIXME in committed code | Everywhere         | `grep -rn 'TODO\|FIXME\|HACK\|XXX' src/`           |

**Run the full checklist** at the midpoint of the project and before
the final commit. Add project-specific invariants as they emerge.

---

## DRY Verification Checklist

```bash
# Run after midpoint task and before final commit.
# Every check should produce zero output (violations).

# Invariant 1: {description}
{grep command}

# Invariant 2: {description}
{grep command}

# Invariant 3: No force-unwrapping
{grep command}

# Invariant 4: No TODO/FIXME
grep -rn 'TODO\|FIXME\|HACK\|XXX' src/
```

---

## Phases

Break the work into phases. Each phase is a logical milestone that
produces working, tested, committed code.

### Phase 1: {Name, e.g., "Foundation"}

**Goal:** {What's true when this phase is done}

---

### {TASK-ID}: {Task Title}

**Estimated effort:** {minutes/hours}
**Dependencies:** {other task IDs, or "None"}
**Files:** {files created or modified}

**Delegation prompt for `@code-writer`:**

> {Detailed implementation instructions. Include:
>
> - Exact file paths
> - API signatures and types
> - Data model details
> - Relevant design doc excerpts
> - Edge cases to handle
> - What NOT to do (anti-patterns)
>
> The code-writer has NO prior context. Everything it needs
> must be in this prompt.}

**Review criteria for `@code-review`:**

> {Specific things the reviewer should check:
>
> - Correctness criteria
> - DRY invariant adherence
> - Error handling expectations
> - Thread safety concerns
> - API usage correctness
> - Backward compatibility
> - Wireframe/spec conformance}

**Acceptance criteria:**

- {Criterion 1}
- {Criterion 2}
- Build compiles with zero warnings

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Build verification       | pending |       |
| Smoke test               | pending |       |
| Delegate to @code-review | pending |       |
| Fix review findings      | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

{Repeat ### TASK-ID blocks for each task}

---

### Phase 2: {Name}

**Goal:** {What's true when this phase is done}

{Tasks...}

---

## Validation Protocol

**Standard validation sequence (per task):**

1. **Build** — `{build command}` (must pass with zero warnings)
2. **Lint** — {lint description, or "included in build step"}
3. **Smoke test** — run the relevant functionality manually
4. **LOOK checkpoint** (if UI changed) — visual verification
5. **Code review** — `@code-review` delegation with criteria from the
   task definition. Fix-review loop until zero blockers.
6. **Commit** — only after steps 1-5 pass
7. **Plan update** — update status tables immediately after commit

---

## Commit Protocol

**Format:** Conventional Commits

```
<type>(scope): <summary>

<body>
```

- **type**: `feat`, `fix`, `refactor`, `docs`, `chore`, `build`, `test`
- **scope**: component or area name
- **summary**: imperative, specific, no trailing period
- **body**: bullet points of what changed, wrapped at 72 chars

**Rules:**

- Commit at the end of every completed task (after validation passes)
- Commit at natural sub-task checkpoints within larger tasks to avoid
  losing work
- Never commit code that doesn't build
- Never commit before code review passes
- Record the short SHA in the task's status table Notes column

**Commit-per-task mapping:**

| Task      | Commit Message               |
| --------- | ---------------------------- |
| {TASK-01} | `{type}({scope}): {summary}` |
| {TASK-02} | `{type}({scope}): {summary}` |

---

## File Impact Summary

| File   | Task(s)    | Purpose       |
| ------ | ---------- | ------------- |
| {path} | {task IDs} | {description} |

---

## Risk Register

| Risk          | Likelihood      | Impact          | Mitigation |
| ------------- | --------------- | --------------- | ---------- |
| {description} | Low/Medium/High | Low/Medium/High | {strategy} |

---

## Rollback Plan

Each task commits independently. To roll back:

| Task      | Rollback strategy                     |
| --------- | ------------------------------------- |
| {TASK-01} | {e.g., "git revert — self-contained"} |

---

## Out of Scope

| Item              | Rationale                          |
| ----------------- | ---------------------------------- |
| {feature/concern} | {why it's excluded from this plan} |

---

## Post-Completion Checklist

- [ ] `{build command}` builds cleanly on a fresh checkout
- [ ] All smoke tests pass
- [ ] DRY verification checklist passes (all invariants hold)
- [ ] No TODO/FIXME comments in source
- [ ] `@code-review` returns zero blockers on final codebase
- [ ] All status tables in this plan are marked done with commit SHAs
- [ ] README/documentation is current
