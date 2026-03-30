# {Project Name} Implementation Plan

**Version:** 0.1
**Date:** {YYYY-MM-DD}
**Status:** Planning
**Branch:** `main`
**Source:** {Link to primary design doc or spec — enumerate individual docs in Authoritative References below}
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
2. BUILD     ->  Verify: {build command, e.g. "make clean && make all"} passes with zero warnings
3. TEST      ->  Smoke test the relevant functionality
4. LOOK      ->  (if UI changed) Visual verification
5. REVIEW    ->  @code-review (with review criteria from the task definition)
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
   **Record decisions BEFORE implementing, not after.** Post-hoc
   decisions are rationalizations, not decisions.
4. **Plan version** — bump the Version field when making structural
   changes to the plan itself. Bump to 1.0 when execution begins.

---

## Decision Log

Record every non-obvious design decision. If it's not in the spec, it
goes here **before** implementation — never after.

| #   | Topic | Decision | Rationale |
| --- | ----- | -------- | --------- |
| 1   |       |          |           |

---

## DRY Invariants

Define the project's DRY rules upfront. Each invariant gets a grep
check in the verification checklist.

**Invariant pattern:** "{Thing X} only lives in {File Y}. No other file
should {do Z}."

| #   | Invariant                                             | Canonical location | Grep check                                                |
| --- | ----------------------------------------------------- | ------------------ | --------------------------------------------------------- |
| 1   | {e.g., "All database queries"}                        | {e.g., "src/db/"}  | `grep -rn "{pattern}" src/ \| grep -v {canonical}`        |
| 2   | {e.g., "All API keys/secrets"}                        | {e.g., ".env"}     | `grep -rn "API_KEY\|SECRET" src/ \| grep -v .env`         |
| 3   | {e.g., "No unsafe casts/unwraps"}                     | {everywhere}       | `{language-specific grep, e.g. grep -rn 'as!' for Swift}` |
| 4   | No TODO/FIXME in committed code (recommended default) | Everywhere         | `grep -rn 'TODO\|FIXME\|HACK\|XXX' src/`                  |

Replace the examples above with your project's actual invariants. Keep
invariant 4 (TODO/FIXME) as a default — it prevents accidental
placeholder leakage into commits. Add project-specific invariants as
they emerge during implementation.

**Run the full checklist** at the midpoint of the project and before
the final commit.

---

## DRY Verification Checklist

```bash
# Run after midpoint task and before final commit.
# Every check should produce zero output (violations).
# Mirror the invariants table above — one check per invariant.

# Invariant 1: {description}
{grep command}

# Invariant 2: {description}
{grep command}

# Invariant 3: {description}
{grep command}

# Invariant 4: No TODO/FIXME (recommended default — keep this)
grep -rn 'TODO\|FIXME\|HACK\|XXX' src/
```

---

## Execution Sequence

Bird's-eye view of all phases and tasks. Use this to orient before
diving into individual task definitions. Update as tasks complete.

```
Phase 1: {Name}
  {TASK-01} -> build -> review -> commit
  {TASK-02} -> build -> review -> commit
  {TASK-03} -> build -> review -> commit

Phase 2: {Name}
  {TASK-04} -> build -> review -> commit
  {TASK-05} -> build -> LOOK -> review -> commit
  {TASK-06} -> build -> LOOK -> review -> commit
```

Use a short prefix + sequential number for task IDs (e.g., `WEB-01`,
`API-01`, `FE-01`). Use different prefixes for different phases if
it helps distinguish the work.

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
**References:** {design doc paths and specific sections, e.g., "docs/architecture.md (component X), docs/flows.md (F-02)"}
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
- {e.g., "Build compiles with zero warnings"}

**Status:**

| Step                        | Status  | Notes |
| --------------------------- | ------- | ----- |
| Delegate to @code-writer    | pending |       |
| Build verification          | pending |       |
| Smoke test                  | pending |       |
| Visual verification (if UI) | pending |       |
| Delegate to @code-review    | pending |       |
| Fix review findings         | pending |       |
| Commit                      | pending | SHA:  |
| Plan updated                | pending |       |

---

<!-- Repeat ### TASK-ID blocks for each task in this phase -->

---

### Phase 2: {Name}

**Goal:** {What's true when this phase is done}

<!-- Tasks... -->

---

## Adding Post-Ship Fix Phases

When testing after initial completion reveals architectural issues,
**don't patch existing tasks**. Instead, add a new phase:

1. **Background** — root cause analysis explaining what went wrong
   and why
2. **Decision Log Additions** — new rows for the design decisions
   needed to fix the issue
3. **FIX-NN task IDs** — new tasks following the same task template
   (delegation prompt, review criteria, acceptance criteria, status
   table)
4. **Final verification task** — DRY checklist, smoke tests, full
   code review of changed files

This pattern was essential in the Trampoline project: Phase 4 (claim
architecture fix) was added after Phase 3 was "complete" when
end-to-end testing revealed that the claim API triggered 85 macOS
dialogs. The structured fix phase prevented ad-hoc patching and
maintained review discipline.

---

## Validation Protocol

The per-task validation sequence is defined in the
[Orchestrator Workflow](#orchestrator-workflow) above (steps 1-9).
This section provides a quick reference:

1. **Build** — must pass with zero warnings
2. **Lint** — included in build or run separately
3. **Smoke test** — run the relevant functionality manually
4. **LOOK checkpoint** (if UI changed) — visual verification
5. **Code review** — `@code-review` with criteria from the task.
   Fix-review loop until zero blockers.
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
- Commit at natural sub-task checkpoints within larger tasks
  (especially for tasks estimated at >2 hours) to avoid losing work
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

- [ ] `{build command, e.g. "make clean && make all"}` builds cleanly on a fresh checkout
- [ ] All smoke tests pass
- [ ] DRY verification checklist passes (all invariants hold)
- [ ] No TODO/FIXME comments in source
- [ ] `@code-review` returns zero blockers on final codebase
- [ ] All status tables in this plan are marked done with commit SHAs
- [ ] README/documentation is current
