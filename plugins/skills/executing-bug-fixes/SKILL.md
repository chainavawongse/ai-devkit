---
name: executing-bug-fixes
description: Execute bug fixes using systematic debugging and TDD workflow with code review - dispatched by executing-plans for tickets labeled 'bug'
when_to_use: when fixing reported bugs that affect existing behavior
version: 2.1.0
---

# Executing Bug Fixes

Systematically investigate, reproduce, fix, and verify bugs using TDD methodology and root cause analysis.

**Core principle:** Investigation first, reproduce with test, minimal fix, review, commit.

**Commit Format:** `fix(<ticket>): <description>` (e.g., `fix(PAS-123): handle session expiry`)

See `docs/git-conventions.md` for complete branching, commit, and PR conventions.

**Context:** This skill is dispatched by `executing-plans` for sub-tickets labeled `bug`.

## Overview

This skill fixes bugs following rigorous methodology:

1. Load bug context from PM ticket
2. Root cause investigation (systematic-debugging)
3. Reproduce with failing test (TDD)
4. Implement minimal fix (TDD GREEN)
5. Request code review
6. Apply feedback
7. Commit with root cause documentation
8. Update ticket status
9. Report completion

## The Process

### Step 1: Load Bug Context

**First, check CLAUDE.md for PM system configuration:**
- Look for `## Project Management` section
- Identify system: `Jira` or `Notion`

**Read ticket from PM system:**

```python
# For Jira:
ticket = mcp__atlassian__get_issue(id=ticket_id)
# OR fallback:
ticket = mcp__jira__get_issue(issue_key=ticket_id)

# For Notion:
ticket = mcp__notion__notion-fetch(id=ticket_id)

# Extract bug details (same for both systems)
bug_description = extract_section(ticket.description, "## Bug Description")
expected_behavior = extract_section(ticket.description, "## Expected Behavior")
actual_behavior = extract_section(ticket.description, "## Actual Behavior")

# Verify ticket has `bug` label/type
# For Jira: check ticket.labels
# For Notion: check ticket.properties.Type
if 'bug' not in ticket.labels:  # or ticket.properties.Type != 'bug' for Notion
    ERROR: "This skill is for bug tickets only. Wrong skill called."
    SUGGEST: "Use executing-tasks for feature label, executing-chores for chore label"
    STOP
```

### Step 1.5: Documentation Context (Pre-loaded)

**Documentation is automatically injected by `executing-plans` before this skill is invoked.**

When dispatched via `/execute`, relevant documentation based on file patterns is pre-loaded into your context. You do NOT need to manually load docs.

**What's pre-loaded (based on bug description and affected areas):**

| File Pattern | Documentation Injected |
|--------------|----------------------|
| `.tsx`, `.jsx`, `.ts` in `components/`, `hooks/`, `stores/` | `docs/frontend/DEVELOPMENT.md` |
| `.cs` in `Controllers/`, `Services/`, `Handlers/` | `docs/backend-dotnet/DEVELOPMENT.md` |
| `.py` in `api/`, `services/`, `models/` | `docs/backend-python/DEVELOPMENT.md` |
| `Migrations/` (.NET) | `docs/backend-dotnet/api/data/entity-framework.md` |
| `migrations/` (Python) | `docs/backend-python/api/data/alembic.md` |
| `.spec.ts`, `.test.ts` in `e2e/`, `playwright/` | `docs/frontend/testing/e2e-testing.md` |

**On-demand loading:** During root cause investigation, if you discover the bug is in a different area than predicted, load additional relevant docs before proceeding with the fix.

### Step 2: Root Cause Investigation

**REQUIRED SUB-SKILL:** Use `devkit:systematic-debugging` (Phase 1)

**Investigation steps:**

1. **Read error messages carefully** - They often contain exact solutions
2. **Reproduce consistently** - Can you trigger it reliably?
3. **Check recent changes** - What changed that could cause this?
4. **Gather evidence** - Add diagnostic logging if multi-component system
5. **Trace data flow** - Where does bad value originate? (use `devkit:root-cause-tracing` if deep)

**Document findings:**

```markdown
## Investigation Results

**Root Cause:** <identified cause>

**Evidence:**
- <observation 1>
- <observation 2>

**Location:** <file>:<line>
```

### Step 3: Reproduce with Test

**REQUIRED SUB-SKILL:** Use `devkit:test-driven-development` (RED phase)

**Write failing test that reproduces bug:**

```typescript
describe('Bug fix: <ticket-id>', () => {
  it('should <expected behavior>', () => {
    // Setup: Create conditions that trigger bug
    const input = createBugConditions();

    // Execute: Run the buggy code
    const result = executeCode(input);

    // Assert: Expect correct behavior (will fail)
    expect(result).toBe(expectedBehavior);
  });
});
```

**Run test and capture failure output:**

```bash
just test <test-file> 2>&1 | tee .tdd-red-phase.log
# Must fail with same error as bug report
# Confirms test actually reproduces the bug
```

**⚠️ RED PHASE CHECKPOINT (MANDATORY - Cannot skip):**

Before proceeding to implement the fix, you MUST document the RED phase completion:

```markdown
## RED Phase Complete ✓

**Test file:** path/to/bug-fix.test.ts
**Test name:** "should <expected behavior>"
**Failure output:**
```
FAIL path/to/bug-fix.test.ts
  ✗ should <expected behavior>
    Expected: <correct behavior>
    Received: <buggy behavior matching bug report>
```
**Confirms bug reproduction:** Failure matches reported bug behavior
```

**STOP if:**
- Test passes immediately (bug already fixed or wrong test)
- Test fails for different reason than bug report (wrong reproduction)
- Cannot capture failure output (something is wrong)

### Step 4: Implement Fix

**REQUIRED SUB-SKILL:** Use `devkit:test-driven-development` (GREEN + REFACTOR phases)

**GREEN - Minimal fix:**

1. Fix only the identified root cause
2. Don't refactor unrelated code
3. Don't fix other bugs
4. Keep changes focused

**Verify reproducing test passes:**

```bash
just test <test-file>
# ✓ should <expected behavior>
```

**Run full test suite:**

```bash
just test
# Ensure no regressions
```

**REFACTOR (if needed):**

- Extract duplicated logic
- Improve naming
- Add helpful comments explaining why
- Run tests after each change

### Step 5: Comprehensive Verification

**Run all checks:**

```bash
just test          # All tests
just lint          # Code quality
just format        # Formatting
just build         # Build succeeds
```

**All checks must pass before proceeding.**

### Step 6: Request Code Review

**REQUIRED SUB-SKILL:** Use `devkit:requesting-code-review`

**Prepare change summary for review:**

```markdown
**Root Cause:** [Identified root cause]

**Fix Applied:**
- Modified: [list files changed]
- Added tests: [test files]

**Changes Made:**
[Detailed description of what was changed and why]

**Verification:**
- Reproducing test now passes
- Full test suite passing
```

**Dispatch code-reviewer subagent:**

```
WHAT_WAS_IMPLEMENTED: [Bug fix summary - root cause identified, what was changed, why this fixes it]
PLAN_OR_REQUIREMENTS: [Ticket: {ticket_id} - Bug description, expected vs actual behavior]
CHANGES_SUMMARY: [Detailed list of all file changes with explanations]
DESCRIPTION: [Brief summary of fix and root cause]

Note: Review based on change summary, not git commits (parallel execution in shared worktree)
```

**Code reviewer returns:**

- Strengths: What was done well
- Issues: Any concerns (should be minimal for well-tested bug fix)
- Assessment: Safe to deploy

**Apply feedback:**

- Fix any Critical or Important issues
- Verify tests still pass
- Re-request review if needed

### Step 7: Commit with Root Cause Documentation

**Document root cause in code:**

```typescript
// Bug fix: Filter out deleted records (<ticket-id>)
// Root cause: Query was missing deleted_at check, causing
// soft-deleted records to appear in results
const result = data.filter(item => item.active && !item.deleted_at);
```

**Commit with detailed message:**

```bash
git commit -m "$(cat <<'EOF'
fix(<ticket-id>): <short description>

Root cause: <explain what was wrong>

The bug occurred because <deeper explanation>.

Changes:
- <change 1>
- <change 2>

Testing:
- Added test: <test file>
- All tests passing (<N> tests)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Step 8: Update Ticket Status

**Mark ticket as complete:**

```python
# Prepare completion comment:
completion_comment = f"""✅ Bug fixed

**Root Cause:** {root_cause}

**Solution:** {solution_summary}

**Tests Added:** {test_files}

**Verification:**
- ✅ Reproducing test passes
- ✅ All tests passing ({total} tests)
- ✅ No regressions

**Code Review:**
- Assessment: {assessment}

**Commit:** {sha}
"""

# For Jira:
mcp__atlassian__update_issue(id=ticket_id, state='Done')
mcp__atlassian__create_comment(issueId=ticket_id, body=completion_comment)
# OR fallback:
mcp__jira__update_issue(issue_key=ticket_id, status='Done')
mcp__jira__add_comment(issue_key=ticket_id, comment=completion_comment)

# For Notion:
mcp__notion__notion-update-page({
  data: {
    page_id: ticket_id,
    command: "update_properties",
    properties: { Status: "Done" }
  }
})
mcp__notion__notion-create-comment({
  parent: { page_id: ticket_id },
  rich_text: [{ type: "text", text: { content: completion_comment } }]
})
```

### Step 9: Report Completion

**Return summary to executing-plans orchestrator:**

```markdown
## Bug Fix Complete: {ticket_id}

**Skill Used:** `devkit:executing-bug-fixes` (bug fix with TDD)

**Root Cause:** {root_cause_summary}

**Fix:** {what_was_changed}

**Tests Added:**
- {test_file}: reproduces and verifies fix

**Verification:**
- ✅ Reproducing test passes
- ✅ All tests passing ({total} tests, 0 failures)
- ✅ Lint checks passing
- ✅ Build successful
- ✅ Code reviewed and approved

**Commit:** {sha}

**Files Changed:**
- {file1}
- {file2}

**Ready:** Bug fixed, ticket closed, no blockers

---
📋 Skill Signature: `executing-bug-fixes v2.1.0` | Label: `bug`
```

## Error Handling

**If cannot identify root cause:**

- Use `devkit:root-cause-tracing` for deep call stack issues
- Add more logging/instrumentation
- Report to orchestrator if blocked after investigation

**If fix fails after 3 attempts:**

- May indicate architectural issue (see systematic-debugging Phase 4.5)
- Report to orchestrator with details
- Orchestrator decides: architectural discussion or escalate

**If code review finds issues:**

- Fix Critical issues immediately
- Re-run tests and checks
- Request re-review

## Integration with Other Skills

**Required workflow:**

- **systematic-debugging** - REQUIRED for Phase 1 (root cause investigation)
- **test-driven-development** - REQUIRED for Phases 2-4 (reproduce, fix, refactor)
- **root-cause-tracing** - REQUIRED when error is deep in call stack
- **requesting-code-review** - REQUIRED after fix implemented
- **receiving-code-review** - REQUIRED for handling feedback

**Called by:**

- **executing-plans** - Dispatches this skill for tickets labeled `bug`

**Reports back to:**

- **executing-plans** - Summary of completion or failure

## Checklist

Before reporting completion:

- [ ] Loaded ticket context (bug description, expected vs actual behavior)
- [ ] Verified ticket has `bug` label
- [ ] Root cause identified (systematic investigation)
- [ ] Failing test reproduces bug
- [ ] Verified test fails for correct reason
- [ ] Minimal fix implemented
- [ ] Reproducing test now passes
- [ ] Full test suite passes (no regressions)
- [ ] Lint, format, build checks pass
- [ ] Code review requested and passed
- [ ] Review feedback applied
- [ ] Root cause documented in code and commit
- [ ] Run final verification in affected module: `just lint format test`
- [ ] Ticket status updated to Done (Jira or Notion)
- [ ] Completion summary provided

## Remember

- **Investigation first** - Never guess at fixes
- **Systematic debugging required** - Use the framework
- **Reproduce with test** - Failing test proves understanding
- **TDD for fix** - RED → GREEN → REFACTOR
- **Code review is mandatory** - No completion without review approval
- **Minimal changes** - Fix root cause, nothing else
- **Document root cause** - Code comments and commit message
- **Report back clearly** - Orchestrator needs summary
