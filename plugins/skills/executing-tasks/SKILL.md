---
name: executing-tasks
description: Execute feature implementation tasks using TDD workflow with code review - dispatched by executing-plans for tickets labeled 'feature'
when_to_use: when implementing a new feature or behavior change that requires test-driven development
version: 1.1.0
---

# Executing Tasks (Feature Implementation)

Execute feature implementation using strict TDD workflow with integrated code review.

**Core principle:** Test-first, minimal implementation, refactor, review, commit.

**Commit Format:** `feat(<ticket>): <description>` (e.g., `feat(PAS-123): add login endpoint`)

See `docs/git-conventions.md` for complete branching, commit, and PR conventions.

**Context:** This skill is dispatched by `executing-plans` for sub-tickets labeled `feature`.

## Overview

This skill implements new features following rigorous TDD:

1. Load task context from PM ticket
2. Follow TDD cycle (RED → GREEN → REFACTOR)
3. Request code review from code-reviewer subagent
4. Apply feedback
5. Commit with proper message
6. Update ticket status
7. Report completion

## The Process

### Step 0: Validate CLAUDE.md Configuration

**REQUIRED:** Validate configuration before any PM operations.

```python
# Validate CLAUDE.md exists and has required configuration
Skill('devkit:validating-claude-md')

# If validation fails, skill will STOP with clear error message
# pointing user to run /setup
```

### Step 1: Load Task Context

**Using validated PM configuration from Step 0:**

**Read ticket from PM system:**

```python
# For Jira:
ticket = mcp__atlassian__get_issue(id=ticket_id)
# OR fallback:
ticket = mcp__jira__get_issue(issue_key=ticket_id)

# For Notion:
ticket = mcp__notion__notion-fetch(id=ticket_id)

# Extract required sections (same for both systems)
specification_context = extract_section(ticket.description, "## Specification Context")
technical_plan = extract_section(ticket.description, "## Technical Plan Guidance")
tdd_checklist = extract_section(ticket.description, "## TDD Implementation Checklist")
acceptance_criteria = extract_section(ticket.description, "## Acceptance Criteria")

if not specification_context or not technical_plan:
    ERROR: "Ticket missing required context sections"
    STOP
```

**Verify ticket has `feature` label:**

```python
if 'feature' not in ticket.labels:
    ERROR: "This skill is for feature tickets only. Wrong skill called."
    SUGGEST: "Use executing-chores for chore label, executing-bug-fixes for bug label"
    STOP
```

### Step 1.5: Documentation Context (Pre-loaded)

**Documentation is automatically injected by `executing-plans` before this skill is invoked.**

When dispatched via `/execute`, relevant documentation based on file patterns is pre-loaded into your context. You do NOT need to manually load docs.

**What's pre-loaded (based on "Files to Touch" in ticket):**

| File Pattern | Documentation Injected |
|--------------|----------------------|
| `.tsx`, `.jsx`, `.ts` in `components/`, `hooks/`, `stores/` | `docs/frontend/DEVELOPMENT.md` |
| `.cs` in `Controllers/`, `Services/`, `Handlers/` | `docs/backend-dotnet/DEVELOPMENT.md` |
| `.py` in `api/`, `services/`, `models/` | `docs/backend-python/DEVELOPMENT.md` |
| `Migrations/` (.NET) | `docs/backend-dotnet/api/data/entity-framework.md` |
| `migrations/` (Python) | `docs/backend-python/api/data/alembic.md` |
| `.spec.ts`, `.test.ts` in `e2e/`, `playwright/` | `docs/frontend/testing/e2e-testing.md` |

**On-demand loading:** If you encounter file types not covered by pre-loaded docs, load additional docs as needed before working on those files.

### Step 2: TDD Implementation

**REQUIRED SUB-SKILL:** Route based on file type:

| File Pattern | TDD Skill to Use |
|--------------|------------------|
| `.tsx`, `.jsx`, `.ts` in `components/`, `hooks/`, `stores/`, `pages/`, `features/` | `devkit:test-driven-development-frontend` |
| All other files | `devkit:test-driven-development` |

**Frontend files (`.tsx`, `.jsx`) MUST use frontend TDD skill** which enforces:
- React Testing Library with proper query priority (`getByRole` > `getByTestId`)
- `userEvent` over `fireEvent`
- MSW for API mocking (never mock fetch/axios directly)
- Vitest + jest-dom assertions

Follow strict TDD cycle:

**RED Phase - Write Failing Tests:**

1. Review Specification Context (expected behaviors)
2. Review Technical Plan Guidance (patterns to follow)
3. Write tests for each behavior specified
4. Run tests and capture failure output:
   ```bash
   just test path/to/test.test.ts 2>&1 | tee .tdd-red-phase.log
   ```
5. Confirm each test fails because feature is missing (not typos/errors)

**⚠️ RED PHASE CHECKPOINT (MANDATORY - Cannot skip):**

Before proceeding to GREEN, you MUST document the RED phase completion:

```markdown
## RED Phase Complete ✓

**Test file:** path/to/test.test.ts
**Test name:** "should do expected behavior"
**Failure output:**
```
FAIL path/to/test.test.ts
  ✗ should do expected behavior
    Expected: <expected value>
    Received: undefined
```
**Failure reason:** Feature not implemented yet
```

**STOP if:**
- Tests pass immediately (wrong test - fix it)
- Tests error instead of fail (fix syntax/imports first)
- Cannot capture failure output (something is wrong)

**GREEN Phase - Minimal Implementation:**

1. Write simplest code to pass first test
2. Run tests - verify first test passes
3. Repeat for each test
4. Verify all tests passing
5. No premature optimization or extra features

**REFACTOR Phase - Clean Up:**

1. Check for code smells (see REFACTORING.md in TDD skill)
2. Extract duplicated logic
3. Improve naming
4. Simplify complex conditionals
5. Run tests after each refactoring
6. Ensure all tests stay green

### Step 3: Verification

**Run comprehensive checks:**

```bash
# Run full test suite
just test          # All tests
just lint          # Code quality
just format        # Formatting
just build         # Build succeeds, if applicable
```

**All checks must pass before proceeding.**

**If any check fails:**

- Fix the issue
- Re-run verification
- Do not proceed until all pass

### Step 4: Request Code Review

**REQUIRED SUB-SKILL:** Use `devkit:requesting-code-review`

**Prepare change summary for review:**

```markdown
**Changes Made:**
- Created: [list new files]
- Modified: [list changed files with brief description]
- Tests added: [test files and what they cover]

**Implementation Summary:**
[Brief description of what was built and how]

**Files Changed:**
[List all files with their changes]
```

**Dispatch code-reviewer subagent:**

Use Task tool with code-reviewer type:

```
WHAT_WAS_IMPLEMENTED: [Detailed summary of implementation - what features/behaviors added, which files changed, what tests were written]
PLAN_OR_REQUIREMENTS: [Ticket: {ticket_id} - Include full Specification Context + Technical Plan from ticket]
CHANGES_SUMMARY: [Detailed list of all file changes made]
DESCRIPTION: [Brief summary of implementation]

Note: Review based on change summary, not git commits
```

**Code reviewer returns:**

- Strengths: What was done well
- Issues: Categorized by severity (Critical/Important/Minor)
- Assessment: Ready to proceed or needs fixes

### Step 5: Apply Review Feedback

**REQUIRED SUB-SKILL:** Use `devkit:receiving-code-review`

**If issues found:**

- **Critical issues:** Fix immediately, re-run tests, request re-review
- **Important issues:** Fix before proceeding, verify with tests
- **Minor issues:** Note for potential follow-up (or fix if quick)

**Verification after fixes:**

```bash
# Re-run all checks
just test
just lint
just build
```

**If 3+ fix attempts fail:**

- STOP and report to executing-plans orchestrator
- May indicate architectural issue or unclear requirements

### Step 6: Commit Changes

**Generate conventional commit message:**

```bash
git add .

git commit -m "$(cat <<'EOF'
feat(<ticket-id>): <concise description>

Implements <what was built>.

Changes:
- <change 1>
- <change 2>

Testing:
- <test coverage added>
- All tests passing (<N> tests)

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Step 7: Update Ticket Status

**Mark ticket as complete in PM system:**

```python
# Prepare completion comment:
completion_comment = f"""✅ Feature implemented

**Implementation:**
- {summary_of_changes}

**Testing:**
- Tests: {N} passing
- Coverage: {coverage_info}

**Code Review:**
- Strengths: {strengths}
- Issues addressed: {issues_fixed}

**Commit:** {commit_sha} "{commit_message}"

**Files changed:** {file_list}
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

### Step 8: Report Completion

**Return summary to executing-plans orchestrator:**

```markdown
## Task Complete: {ticket_id}

**Skill Used:** `devkit:executing-tasks` (feature implementation)

**Implemented:** {summary}

**Tests Added:**
- {test_file_1}: {test_count} tests
- {test_file_2}: {test_count} tests

**Verification:**
- ✅ All tests passing ({total} tests, 0 failures)
- ✅ Lint checks passing
- ✅ Build successful
- ✅ Code reviewed and approved

**Commit:** {sha}

**Files Changed:**
- {file1}
- {file2}

**Ready:** Task complete, ticket closed, no blockers

---
📋 Skill Signature: `executing-tasks v1.1.0` | Label: `feature`
```

## Error Handling

**If tests fail after implementation:**

- Review TDD process - did you write tests first?
- Check test expectations vs implementation
- Verify no regressions in existing tests
- Fix and re-run, do not skip

**If code review finds Critical issues:**

- Fix immediately
- Request re-review
- Do not mark task complete until reviewer approves

**If cannot complete after 3 attempts:**

- Document what's blocking
- Report to orchestrator with details
- Orchestrator decides: retry, skip, or escalate to user

## Integration with Other Skills

**Required workflow:**

- **test-driven-development** - REQUIRED for backend RED-GREEN-REFACTOR cycle
- **test-driven-development-frontend** - REQUIRED for frontend (React/TS) TDD with RTL, userEvent, MSW
- **requesting-code-review** - REQUIRED after implementation
- **receiving-code-review** - REQUIRED for handling feedback

**Called by:**

- **executing-plans** - Dispatches this skill for tickets labeled `feature`

**Reports back to:**

- **executing-plans** - Summary of completion or failure

## Checklist

Before reporting completion:

- [ ] Loaded ticket context (Specification + Technical Plan)
- [ ] Verified ticket has `feature` label
- [ ] Used correct TDD skill (frontend-tdd for `.tsx`/`.jsx`, standard TDD otherwise)
- [ ] Followed TDD cycle (tests first, watched fail, implemented, refactored)
- [ ] All tests passing (no failures, no skipped)
- [ ] **Frontend specific:** Used `getByRole`/`getByLabelText` (not `getByTestId` as first choice)
- [ ] **Frontend specific:** Used `userEvent` (not `fireEvent`)
- [ ] **Frontend specific:** API calls mocked with MSW (not fetch/axios mocks)
- [ ] Lint and format checks passing
- [ ] Build successful
- [ ] Code review requested and passed
- [ ] Review feedback applied
- [ ] Committed with conventional commit message
- [ ] Run final verification in affected module: `just lint format test`
- [ ] Ticket status updated to Done (Jira or Notion)
- [ ] Completion summary provided

## Remember

- **TDD is mandatory** - no implementation before tests
- **Code review is mandatory** - no completion without review approval
- **All checks must pass** - tests, lint, format, build
- **Proper labeling matters** - this skill only for `feature` labeled tickets
- **Report back clearly** - orchestrator needs summary to track progress
- **Handle errors gracefully** - retry or report, don't fail silently
