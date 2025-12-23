---
name: executing-plans
description: Execute sub-issues from parent issue (with Specification + Technical Plan), dispatching subagents with full context
when_to_use: when parent issue has Specification, Technical Plan, and sub-issues ready for implementation
version: 2.0.0
---

# Executing Plans

## Overview

Execute sub-issues systematically. Each subagent receives Specification (WHAT) + Technical Plan (HOW) from parent issue, plus TDD checklist from their sub-issue.

**Core principle:** Subagents get full context, follow TDD checklist in task.

**Critical:** Plans live in parent issue (PM system), not separate files.

## The Process

### Step 0: Confirm PR Creation

Before starting execution, ask user:

```markdown
After completing all tasks, would you like to automatically create a pull request?

The PR will include:
- Comprehensive description with diagrams
- Links to implemented issues
- Test coverage summary
- Visual overview of changes

Create PR at end? (yes/no/ask-later)
```

Store response for Step 6.

### Step 0.5: Worktree & Branch Setup (Stage Gate)

**Before execution, ensure isolated workspace:**

```bash
# Check current workspace
git worktree list
git branch --show-current
```

**If NOT in worktree OR on main/master branch:**

```markdown
⚠️  Development requires isolated worktree for safety and workspace isolation.

Current state:
- Branch: {current_branch}
- Location: {current_directory}

Setting up isolated workspace...
```

**Use `Skill('devkit:using-git-worktrees')` to:**

1. Create worktree at `~/worktrees/{repo}/{branch}/`
2. Change to worktree directory
3. Create feature branch from parent issue ID (e.g., `feature/TEAM-123`)
4. Verify clean baseline

**Verify stage gate success:**

```bash
# Confirm in worktree
pwd  # Should be ~/worktrees/{repo}/{branch}/
git branch --show-current  # Should be feature branch
git status  # Should be clean
```

**Only proceed to Step 1 after successful worktree setup.**

### Step 1: Load Context from Parent Issue

```python
# JIRA:
parent = mcp__atlassian__get_issue(id=parent_id)
# OR JIRA:
parent = mcp__jira__get_issue(issue_key=parent_id)

# Extract sections
specification = extract_section(parent.description, "## Specification")
technical_plan = extract_section(parent.description, "## Technical Plan")

if not specification or not technical_plan:
    ERROR: Missing required sections
    STOP
```

### Step 2: Load Sub-Issues

```python
# JIRA:
sub_issues = mcp__atlassian__list_issues(parentId=parent_id)
# OR JIRA:
sub_issues = mcp__jira__list_issues(parent=parent_id)

# Filter by status
completed_tasks = [task for task in sub_issues if task.state in ['Done', 'Completed']]
remaining_tasks = [task for task in sub_issues if task.state not in ['Done', 'Completed']]

# Build execution plan from remaining tasks
ready_tasks = [task for task in remaining_tasks if no_blockers(task, completed_tasks)]
blocked_tasks = [task for task in remaining_tasks if has_blockers(task, completed_tasks)]
```

**Report status:**

```markdown
Loaded {total} sub-issues:
✓ {completed_count} already complete
→ {ready_count} ready to start
🔒 {blocked_count} blocked by dependencies

Starting with {ready_count} ready tasks...
```

**Key feature:** Already-completed sub-issues are respected. Their completion unblocks dependent tasks. This allows:

- Resuming interrupted executions
- Addressing feedback (some sub-issues from original implementation, some from feedback)
- Manual fixes mixed with automated execution

### Step 3: Execute Tasks Sequentially

Implement tasks one at a time, respecting dependencies:

**1. Process tasks sequentially:**

```python
while remaining_tasks:
    # Get all ready tasks (no blocking dependencies)
    ready_tasks = [task for task in remaining_tasks
                   if no_blockers(task, completed_tasks)]

    if not ready_tasks:
        break  # All remaining tasks are blocked

    # Execute ONLY the first ready task
    current_task = ready_tasks[0]

    # Route to appropriate skill based on label
    execute_single_task(current_task)

    # Wait for completion, then continue with next task
```

**Skill selection based on task label:**

- `feature` → `Skill('devkit:executing-tasks')` - Full TDD workflow
- `chore` → `Skill('devkit:executing-chores')` - Verification-focused
- `bug` → `Skill('devkit:executing-bug-fixes')` - Reproduction + TDD fix

**Each agent will:**

1. Load task details from PM system (JIRA)
2. Extract Specification and Technical Plan context from parent issue
3. Follow TDD checklist from sub-issue
4. Run verification from justfile directory (`cd <module> && just test`)
5. Update task status in PM system (JIRA)
6. Report completion

**After each task completes:**

1. Update completed tasks list
2. Check for newly unblocked tasks
3. Continue with next task if any remain
4. Proceed to Step 4 when all tasks complete

### Step 4: Context Provided to Subagents

**Each subagent receives via Task prompt:**

```
Use Skill('devkit:executing-{type}') for issue {ticket_id}
```

**The execution skill will load:**

- Task description with TDD checklist from sub-issue
- Specification context (WHAT) from parent issue
- Technical Plan guidance (HOW) from parent issue

**Subagent responsibilities:**

1. Follow TDD checklist in sub-issue
2. Use test-driven-development skill
3. Reference patterns from Technical Plan
4. Verify with `just test` and `just lint`
5. Update JIRA status
6. Report completion

### Step 5: Continue Until Complete

Loop until all tasks done or blocked by circular dependency.

After each task:

1. Refresh sub-issue list
2. Check for newly unblocked tasks
3. Dispatch next agent if ready tasks exist
4. Stop if all remaining tasks are blocked

### Step 6: Finish

When all tasks complete:

```python
# If user confirmed PR creation in Step 0
if create_pr_confirmed:
    # Use creating-pull-requests skill
    Skill(devkit:creating-pull-requests)
elif create_pr_response == "ask-later":
    ASK: "All tasks complete! Create pull request now? (yes/no)"
    if yes:
        Skill(devkit:creating-pull-requests)
else:
    # User declined, just report completion
    print("All tasks complete. No PR created.")
    print("To create PR later: /pr")
```

## Remember

- Plans in PM system (not files)
- Both WHAT and HOW to subagents
- TDD checklist in sub-issue
- Tests + implementation together
- Stop when blocked
- Create PR at end (with confirmation)
