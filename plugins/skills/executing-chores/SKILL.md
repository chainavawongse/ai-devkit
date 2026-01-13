---
name: executing-chores
description: Execute maintenance tasks with comprehensive quality verification without TDD requirement
when_to_use: when handling maintenance tasks (dependency upgrades, refactoring, cleanup) that don't require TDD but still need comprehensive quality verification
version: 1.1.0
---

# Executing Chores

## Overview

Execute maintenance tasks without TDD requirement, but with comprehensive quality verification.

**Core principle:** No test-first, but all tests must pass + build must succeed.

**Commit Format:** `chore(<ticket>): <description>` or `refactor(<ticket>): <description>`

See `docs/git-conventions.md` for complete branching, commit, and PR conventions.

**Announce at start:** "I'm using the executing-chores skill to handle this maintenance task."

## When to Use

**Use for:**

- Dependency upgrades
- Refactoring existing code
- Code cleanup and organization
- Configuration changes
- Documentation updates
- Removing deprecated code

**Don't use for:**

- New features (use TDD via executing-plans)
- Bug fixes affecting behavior (use TDD)
- Adding new functionality

## The Process

### Step 0: Pre-flight Checks

**Verify clean environment:**

```bash
# Check working directory
git status --porcelain

if not empty:
    ERROR: "Working directory has uncommitted changes"
    SUGGEST: "Commit changes or use git worktree"
    STOP

# Check for justfile (recommended)
if [ ! -f justfile ]; then
    WARNING: "No justfile found for automated verification"
    ASK: "Continue without automated checks?"
    if no: STOP
fi

# Verify justfile has required recipes
just --list | grep -E "test|lint|format|build"

if missing critical recipes:
    WARNING: "Missing test/lint/build recipes. Manual verification needed."
fi
```

### Step 0.5: Validate CLAUDE.md Configuration

**REQUIRED if loading from PM system:** Validate configuration before any PM operations.

```python
# Validate CLAUDE.md exists and has required configuration
Skill('devkit:validating-claude-md')

# If validation fails, skill will STOP with clear error message
# pointing user to run /setup
```

### Step 1: Load Chore Details

**From user description:**

```
Chore: "Upgrade all npm dependencies to latest compatible versions"
```

**From PM system issue (optional):**

**Using validated PM configuration from Step 0.5:**

```bash
# For Jira:
issue = mcp__atlassian__get_issue(id)
# OR fallback:
issue = mcp__jira__get_issue(issue_key)

# For Notion:
issue = mcp__notion__notion-fetch(id=issue_id)

chore_title = issue.title  # or issue.properties.Name for Notion
chore_description = issue.description  # or issue.content for Notion

# Verify ticket has `chore` label
# For Jira: check issue.labels
# For Notion: check issue.properties.Type
if 'chore' not in issue.labels:  # or issue.properties.Type != 'chore' for Notion
    ERROR: "This skill is for chore tickets only. Wrong skill called."
    SUGGEST: "Use executing-tasks for feature label, executing-bug-fixes for bug label"
    STOP
```

**Present plan:**

```markdown
Loaded chore: "<title>"

## Details
<description>

## Approach
1. Implement the changes
2. Verify all tests still pass
3. Check lint and format
4. Ensure build succeeds
5. Fix any issues
6. Commit when clean

Ready to proceed?
```

### Step 1.5: Documentation Context (Pre-loaded)

**Documentation is automatically injected by `executing-plans` before this skill is invoked.**

When dispatched via `/execute`, relevant documentation based on file patterns is pre-loaded into your context. You do NOT need to manually load docs.

**What's pre-loaded (based on chore description and files involved):**

| File Pattern | Documentation Injected |
|--------------|----------------------|
| `.tsx`, `.jsx`, `.ts` in `components/`, `hooks/`, `stores/` | `docs/frontend/DEVELOPMENT.md` |
| `.cs` in `Controllers/`, `Services/`, `Handlers/` | `docs/backend-dotnet/DEVELOPMENT.md` |
| `.py` in `api/`, `services/`, `models/` | `docs/backend-python/DEVELOPMENT.md` |
| `Migrations/` (.NET) | `docs/backend-dotnet/api/data/entity-framework.md` |
| `migrations/` (Python) | `docs/backend-python/api/data/alembic.md` |
| `.spec.ts`, `.test.ts` in `e2e/`, `playwright/` | `docs/frontend/testing/e2e-testing.md` |

**On-demand loading:** If you encounter file types not covered by pre-loaded docs, load additional docs as needed before working on those files.

### Step 2: Implement Chore

**No TDD - direct implementation:**

For each change:

1. Make the necessary modifications
2. Document what you're doing
3. Keep changes focused

**Example: Dependency Upgrade**

```bash
# Update package.json
npm update --save

# Update lock file
npm install

# Check for breaking changes
npm audit
```

**Example: Refactoring**

```bash
# Extract function
# Move code
# Rename for clarity
# No behavior changes
```

### Step 3: Run Comprehensive Verification

**MANDATORY: Full verification suite**

```bash
# 1. Run all tests
echo "Running full test suite..."
just test
test_exit=$?

# 2. Run linter
echo "Running linter..."
just lint
lint_exit=$?

# 3. Check formatting
echo "Checking code formatting..."
just format --check
format_exit=$?

# 4. Build
echo "Building project..."
just build
build_exit=$?
```

**Report results:**

```markdown
## Verification Results

Tests: <pass>/<total> passing
Lint: <errors> errors
Format: <status>
Build: <status>
```

### Step 4: Fix Issues

**If any verification fails:**

```markdown
Found issues that need fixing:
- Test failures: 3
- Lint errors: 5
- Build errors: 1

Fixing issues...
```

**Fix strategy:**

1. **Build errors first** (may fix other issues)
2. **Test failures second** (ensure no regressions)
3. **Lint errors third** (code quality)
4. **Format issues last** (cosmetic)

**Re-run verification after each fix:**

```bash
# Fix one category
# Re-run that verification
# If passing, move to next category
# Repeat until all pass
```

**Iterate until clean:**

```markdown
Attempt 1: 3 test failures
Fixed: Updated API calls for new dependency version
Re-ran tests: All passing

Attempt 2: 5 lint errors
Fixed: Updated import statements
Re-ran lint: Clean

All verification now passing!
```

### Step 5: Commit Changes

**Run formatting before commit (REQUIRED):**

```bash
# Run format to fix any remaining issues (not just check)
if just --list 2>/dev/null | grep -q "^  fmt"; then
    just fmt
elif just --list 2>/dev/null | grep -q "^  format"; then
    just format
fi
```

**Generate appropriate commit message:**

```bash
# Pattern: <type>(<scope>): <description>
#
# Types:
# - chore(deps): dependency updates
# - refactor: code restructuring
# - chore: general maintenance
# - docs: documentation only
# - style: formatting/style changes

# For dependency upgrade:
git commit -m "chore(<ticket-id>): upgrade dependencies to latest versions

- Updated <package> from v1 to v2
- Updated <package> from v3.1 to v3.2
- All tests passing after upgrade
- Build successful
- No breaking changes

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# For refactoring:
git commit -m "refactor(<ticket-id>): extract common utility functions

- Created utils/validation.ts
- Extracted email/phone validation
- Updated 15 files to use utilities
- No behavioral changes
- All tests passing

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Step 6: Update PM System (if applicable)

**If chore came from PM system issue:**

```bash
# Prepare completion comment:
completion_comment = """✅ Chore complete

**Changes:**
- <summary of changes>

**Verification:**
- Tests: <N> passed, 0 failed
- Lint: No errors
- Format: Passed
- Build: Succeeded

**Commit:** <sha> "<message>"

**Files changed:** <file list>
"""

# For Jira:
mcp__atlassian__update_issue(id=issue_id, state='Done')
mcp__atlassian__create_comment(issueId=issue_id, body=completion_comment)
# OR fallback:
mcp__jira__update_issue(issue_key=issue_id, status='Done')
mcp__jira__add_comment(issue_key=issue_id, comment=completion_comment)

# For Notion:
mcp__notion__notion-update-page({
  data: {
    page_id: issue_id,
    command: "update_properties",
    properties: { Status: "Done" }
  }
})
mcp__notion__notion-create-comment({
  parent: { page_id: issue_id },
  rich_text: [{ type: "text", text: { content: completion_comment } }]
})
```

### Step 7: Complete Development

**After verification passes and commit made:**

Report completion and remind about next steps:

```markdown
## Chore Complete: {ticket_id}

**Skill Used:** `devkit:executing-chores` (maintenance task)

**Changes Made:**
- {change_summary}

**Verification:**
- ✅ All tests passing ({total} tests, 0 failures)
- ✅ Lint checks passing
- ✅ Format checks passing
- ✅ Build successful

**Commit:** {sha}

**Files Changed:**
- {file1}
- {file2}

**Next steps:**
1. Create PR: `/pr`
2. Or if part of larger work, continue with next task

---
📋 Skill Signature: `executing-chores v1.1.0` | Label: `chore`
```

## Checklist

Before reporting completion:

- [ ] Loaded chore details (from user or PM system)
- [ ] Implemented changes without altering behavior
- [ ] All existing tests passing (no failures, no skipped)
- [ ] No new lint errors
- [ ] Code properly formatted
- [ ] Build successful
- [ ] No regressions introduced
- [ ] Committed with conventional commit message
- [ ] Run final verification in affected module: `just lint format test`
- [ ] Ticket status updated to Done (Jira or Notion, if applicable)
- [ ] Completion summary provided

**If any check fails:**

- Fix the issue
- Re-run verification
- Repeat until passing
- NEVER commit with failing checks

## Example Workflows

### Example 1: Dependency Upgrade

```
You: I'm using the executing-chores skill to upgrade dependencies.

Chore: "Upgrade React from v17 to v18"

Implementing upgrade...
- Updated package.json: react@18.0.0
- Updated package-lock.json
- Updated type definitions: @types/react@18.0.0

Running verification...
Tests: 124/124 passing ✅
Lint: No errors ✅
Format: Passed ✅
Build: Succeeded ✅

All quality checks passed!

git commit -m "chore(PAS-123): upgrade React v17 to v18

- Updated react to 18.0.0
- Updated @types/react to 18.0.0
- All tests passing
- Build successful

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

Chore complete!
```

### Example 2: Refactoring

```
You: I'm using the executing-chores skill to refactor validation logic.

Chore: "Extract common validation into utilities"

Implementing refactoring...
- Created src/utils/validation.ts
- Extracted emailValidator
- Extracted phoneValidator
- Updated 15 files to use utilities

Running verification...
Tests: 156/156 passing ✅
Lint: No errors ✅
Format: Passed ✅
Build: Succeeded ✅

All quality checks passed!

git commit -m "refactor(PAS-456): extract common validation utilities

- Created utils/validation.ts
- Extracted email/phone validators
- Updated 15 files to use utilities
- No behavioral changes
- All tests passing

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

Chore complete!
```

### Example 3: With Failures to Fix

```
You: I'm using the executing-chores skill to upgrade dependencies.

Chore: "Upgrade all npm dependencies"

Implementing upgrade...
- Updated 23 dependencies

Running verification...
Tests: 118/121 passing ❌
  3 failures in api.test.ts
Lint: 5 errors ❌
Format: Passed ✅
Build: Failed ❌
  2 type errors

Found issues that need fixing.

Fixing build errors first...
- Fixed type error in api.ts (new axios types)
- Fixed type error in client.ts (new types)

Re-running build...
Build: Succeeded ✅

Fixing test failures...
- Updated API mocks for new axios behavior
- Fixed async handling in 3 tests

Re-running tests...
Tests: 121/121 passing ✅

Fixing lint errors...
- Removed unused imports from upgrade
- Fixed import ordering

Re-running lint...
Lint: No errors ✅

All verification now passing!

git commit... (as above)

Chore complete!
```

## Red Flags

**Never:**

- Skip verification steps
- Commit with failing tests
- Commit with build errors
- Ignore lint errors
- Proceed without fixing issues

**Always:**

- Run full test suite (not just affected tests)
- Ensure build succeeds
- Fix all lint errors
- Verify formatting
- Document what was changed

## Integration

**Optional follow-up:**

- **creating-pull-requests** - Create PR if chore is standalone change

**Does NOT require:**

- test-driven-development (no test-first for chores)
- requesting-code-review (simpler verification approach)
- Sub-issues (single task)

**Verification replaces code review:**

- Full test suite ensures no regressions
- Lint/format ensures code quality
- Build ensures no breaking changes

## Remember

- No TDD requirement (chores don't need test-first)
- All tests must still pass (no regressions allowed)
- Build must succeed (no broken code)
- Lint/format must pass (maintain code quality)
- Fix issues immediately (don't defer)
- Clear commit messages (explain what and why)
- Use justfile for consistent verification
