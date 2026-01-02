---
name: executing-plans
description: Execute sub-issues from parent issue (with Specification + Technical Plan), dispatching subagents with full context
when_to_use: when parent issue has Specification, Technical Plan, and sub-issues ready for implementation
version: 2.2.0
---

# Executing Plans

> **⛔ MANDATORY:** All execution MUST happen in an isolated git worktree, never on main/master.
> This is enforced by a HARD GATE in Step 0.5 and a Pre-Task Guard before every task.

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

### Step 0.1: Validate CLAUDE.md Configuration

**REQUIRED:** Call validation skill before any PM operations.

```python
# Validate CLAUDE.md exists and has required configuration
Skill('devkit:validating-claude-md')

# If validation fails, skill will STOP with clear error message
# pointing user to run /setup

# On success, proceed with validated PM configuration
```

### Step 0.25: Phase Validation (Stage Gate)

**Before execution, verify the parent issue has completed all required phases:**

**Using validated PM configuration from Step 0.1:**

**Load parent issue and check phase labels:**

```python
# For Jira:
parent = mcp__atlassian__get_issue(id=parent_id)
# OR fallback:
parent = mcp__jira__get_issue(issue_key=parent_id)
labels = parent.labels

# For Notion:
parent = mcp__notion__notion-fetch(id=parent_id)
phase_property = parent.properties.Phase  # Multi-select

# Check for phase labels
has_refined = 'phase:refined' in labels  # Jira
            or 'refined' in phase_property  # Notion
has_planned = 'phase:planned' in labels  # Jira
            or 'planned' in phase_property  # Notion
has_broken_down = 'phase:broken-down' in labels  # Jira
                or 'broken-down' in phase_property  # Notion
```

**Validation with fallback:**

```python
# If phase labels missing, fall back to section check (for existing tickets)
if not has_refined:
    has_refined = "## Specification" in parent.description
if not has_planned:
    has_planned = "## Technical Plan" in parent.description
if not has_broken_down:
    # Check if sub-issues exist
    sub_issues = list_children(parent_id)
    has_broken_down = len(sub_issues) > 0

# Block if any phase is missing
missing_phases = []
if not has_refined:
    missing_phases.append("refined (run /refine first)")
if not has_planned:
    missing_phases.append("planned (run /plan first)")
if not has_broken_down:
    missing_phases.append("broken-down (run /breakdown first)")

if missing_phases:
    ERROR: f"Cannot execute - missing required phases: {', '.join(missing_phases)}"
    SUGGEST: "Complete the spec-driven development workflow in order:"
    SUGGEST: "  1. /refine {parent_id} - Define WHAT to build"
    SUGGEST: "  2. /plan {parent_id} - Define HOW to build it"
    SUGGEST: "  3. /breakdown {parent_id} - Create sub-issues"
    SUGGEST: "  4. /execute {parent_id} - Execute the plan"
    STOP
```

**Report validation success:**

```markdown
✓ Phase validation passed:
  - Refined: {has_refined} (Specification defined)
  - Planned: {has_planned} (Technical Plan created)
  - Broken down: {has_broken_down} ({N} sub-issues found)

Proceeding with execution...
```

### Step 0.5: Worktree & Branch Setup (HARD GATE - BLOCKING)

**⛔ THIS IS A BLOCKING GATE - EXECUTION CANNOT PROCEED WITHOUT PASSING**

All implementation work MUST happen in an isolated git worktree. This protects main/master
from accidental commits and enables clean rollback if something goes wrong.

**Check current git state:**

```bash
# Get current branch and location
current_branch=$(git branch --show-current)
current_dir=$(pwd)
repo_root=$(git rev-parse --show-toplevel)
```

**HARD BLOCK: If on main or master branch, STOP IMMEDIATELY:**

```python
if current_branch in ['main', 'master']:
    ERROR: """
    ⛔ BLOCKED: Cannot execute on {current_branch} branch

    You are currently on the {current_branch} branch at:
    {current_dir}

    All execution MUST happen in an isolated git worktree to:
    - Protect main/master from accidental commits
    - Enable clean rollback if something goes wrong
    - Allow parallel feature development

    Setting up worktree now...
    """

    # MUST invoke worktree skill - do not proceed without it
    Skill('devkit:using-git-worktrees')

    # After worktree setup, RE-VERIFY we're no longer on main/master
    new_branch = run("git branch --show-current")
    if new_branch in ['main', 'master']:
        FATAL: "Worktree setup failed - still on {new_branch}. Cannot proceed."
        STOP
```

**Use `Skill('devkit:using-git-worktrees')` to:**

1. Create worktree at `<parent>/worktrees/{repo}/{branch}/`
2. Change to worktree directory
3. Create feature branch from parent issue ID (e.g., `feature/TEAM-123`)
4. Run `just install` if available
5. Verify clean baseline with `just test`

**Verify stage gate success (REQUIRED before proceeding):**

```bash
# These checks MUST all pass before continuing
current_branch=$(git branch --show-current)
current_dir=$(pwd)

# Verify NOT on main/master
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    echo "FATAL: Still on protected branch. Cannot proceed."
    exit 1
fi

# Verify in worktree directory (should contain /worktrees/)
if [[ "$current_dir" != *"/worktrees/"* ]]; then
    echo "WARNING: Not in worktrees directory. Verify isolation."
fi

# Verify clean state
git status --porcelain
```

**Report gate status:**

```markdown
✅ Worktree Gate PASSED
- Branch: {current_branch} (not main/master)
- Location: {current_dir}
- Git status: clean

Proceeding with execution...
```

**Only proceed to Step 1 after ALL checks pass.**

### Step 1: Load Context from Parent Issue

**First, check CLAUDE.md for PM system configuration:**
- Look for `## Project Management` section
- Identify system: `Jira` or `Notion`

```python
# For Jira:
parent = mcp__atlassian__get_issue(id=parent_id)
# OR fallback:
parent = mcp__jira__get_issue(issue_key=parent_id)

# For Notion:
parent = mcp__notion__notion-fetch(id=parent_id)

# Extract sections (same for both systems)
specification = extract_section(parent.description, "## Specification")
technical_plan = extract_section(parent.description, "## Technical Plan")

if not specification or not technical_plan:
    ERROR: Missing required sections
    STOP
```

### Step 2: Load Sub-Issues

```python
# For Jira:
sub_issues = mcp__atlassian__list_issues(parentId=parent_id)
# OR fallback:
sub_issues = mcp__jira__list_issues(parent=parent_id)

# For Notion:
# Search within database for pages with Parent = parent_id
database_id = config.data_source_id  # From CLAUDE.md
results = mcp__notion__notion-search(query="", data_source_url="collection://" + database_id)
sub_issues = [page for page in results if page.properties.Parent == parent_id]

# Filter by status (same for both systems)
completed_tasks = [task for task in sub_issues if task.status in ['Done', 'Completed']]
remaining_tasks = [task for task in sub_issues if task.status not in ['Done', 'Completed']]

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

### Step 2.5: Prepare Documentation Context

**Before dispatching each subagent, load relevant documentation based on file patterns.**

This ensures agents have the right context without needing to remember to load docs themselves.

**File Pattern → Documentation Mapping:**

| File Pattern | Documentation to Load |
|--------------|----------------------|
| `.tsx`, `.jsx`, `.ts` in `components/`, `hooks/`, `stores/` | `docs/frontend/DEVELOPMENT.md` |
| `.cs` in `Controllers/`, `Services/`, `Handlers/` | `docs/backend-dotnet/DEVELOPMENT.md` |
| `.py` in `api/`, `services/`, `models/` | `docs/backend-python/DEVELOPMENT.md` |
| `Migrations/` directory (.NET) | `docs/backend-dotnet/api/data/entity-framework.md` |
| `migrations/` directory (Python/Alembic) | `docs/backend-python/api/data/alembic.md` |
| `.spec.ts`, `.test.ts` in `e2e/`, `playwright/` | `docs/frontend/testing/e2e-testing.md` |

**For each task, before dispatching:**

```python
def get_relevant_docs(task):
    """Analyze task and return list of docs to inject."""
    files_to_touch = extract_section(task.description, "## Files to Touch")
    implementation_guide = extract_section(task.description, "## Implementation Guide")
    content = files_to_touch + implementation_guide

    docs_to_load = []

    # Frontend patterns
    if matches_pattern(content, r'\.(tsx|jsx|ts)') and \
       matches_pattern(content, r'(components|hooks|stores)/'):
        docs_to_load.append("docs/frontend/DEVELOPMENT.md")

    # .NET backend patterns
    if matches_pattern(content, r'\.cs') and \
       matches_pattern(content, r'(Controllers|Services|Handlers)/'):
        docs_to_load.append("docs/backend-dotnet/DEVELOPMENT.md")

    # Python backend patterns
    if matches_pattern(content, r'\.py') and \
       matches_pattern(content, r'(api|services|models)/'):
        docs_to_load.append("docs/backend-python/DEVELOPMENT.md")

    # .NET migrations
    if matches_pattern(content, r'Migrations/'):
        docs_to_load.append("docs/backend-dotnet/api/data/entity-framework.md")

    # Python/Alembic migrations
    if matches_pattern(content, r'migrations/') and \
       matches_pattern(content, r'\.py'):
        docs_to_load.append("docs/backend-python/api/data/alembic.md")

    # E2E tests
    if matches_pattern(content, r'\.(spec|test)\.(ts|tsx)') and \
       matches_pattern(content, r'(e2e|playwright)/'):
        docs_to_load.append("docs/frontend/testing/e2e-testing.md")

    return docs_to_load

def load_doc_content(doc_paths):
    """Read and combine doc content for injection."""
    content = []
    for path in doc_paths:
        if file_exists(path):
            doc = Read(path)
            content.append(f"## Reference: {path}\n\n{doc}")
    return "\n\n---\n\n".join(content)
```

**Inject docs into subagent context:**

```python
# Before dispatching subagent
relevant_docs = get_relevant_docs(current_task)
doc_content = load_doc_content(relevant_docs)

# Include in Task prompt (see Step 4)
```

### Step 2.75: Pre-Task Guard (Session Resume Protection)

**⚠️ THIS CHECK RUNS BEFORE EVERY TASK - INCLUDING RESUMED SESSIONS**

When a session is resumed (e.g., after context overflow or user returns later), the original
worktree verification from Step 0.5 may not have run. This guard ensures safety is maintained.

**Before dispatching ANY task, verify git state:**

```python
def pre_task_guard():
    """
    Run before EVERY task dispatch to ensure execution safety.
    This catches:
    - Resumed sessions where Step 0.5 didn't run
    - Manual branch switches during execution
    - Corrupted or deleted worktrees

    NOTE: run(cmd) is pseudocode meaning "execute the shell command
          and return its stdout" (e.g., subprocess, Bash tool, etc.)
    """
    current_branch = run("git branch --show-current")
    current_dir = run("pwd")

    # BLOCK if on protected branch
    if current_branch in ['main', 'master']:
        ERROR: f"""
        ⛔ PRE-TASK GUARD FAILED

        Execution is on protected branch: {current_branch}
        Location: {current_dir}

        This can happen when:
        1. Session was resumed without re-running worktree setup
        2. Branch was manually switched during execution
        3. Worktree was deleted and execution continued in main repo

        REQUIRED ACTION: Set up isolated worktree before continuing.
        """

        # Invoke worktree skill to fix
        Skill('devkit:using-git-worktrees')

        # Re-check after fix attempt
        new_branch = run("git branch --show-current")
        if new_branch in ['main', 'master']:
            FATAL: "Could not establish safe workspace. Stopping execution."
            STOP

        print(f"✅ Pre-Task Guard: Now on {new_branch}, safe to proceed")

    # WARN if not in worktrees directory (might be okay for some setups)
    if "/worktrees/" not in current_dir:
        WARN: f"""
        ⚠️ Not in standard worktree location
        Current: {current_dir}
        Expected: <parent>/worktrees/{{repo}}/{{branch}}/

        Proceeding, but verify you're in an isolated workspace.
        """

    return True  # Safe to proceed

# Call before each task
pre_task_guard()
```

**When this guard fires (session resumption detected):**

```markdown
🔄 Session Resumption Detected

Previous session state may have been lost. Re-verifying workspace safety...

[Runs pre_task_guard checks]

If on main/master → Invokes worktree skill
If already safe → Proceeds with task
```

**This guard ensures that even if a session overflows or is resumed days later,
the execution will not accidentally commit to main/master.**

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

**Log skill dispatch for audit trail:**

```python
def dispatch_task(task):
    """Route task to appropriate skill and log dispatch."""
    label = get_task_label(task)  # feature, chore, or bug
    skill_map = {
        'feature': 'executing-tasks',
        'chore': 'executing-chores',
        'bug': 'executing-bug-fixes'
    }

    skill_name = skill_map.get(label)

    if not skill_name:
        ERROR: f"Task {task.id} has invalid/missing label: '{label}'"
        SUGGEST: "Add one of: feature, chore, bug"
        return None

    # Log dispatch for audit
    print(f"""
    ┌─────────────────────────────────────────────────────────────────
    │ DISPATCH LOG
    │ Task: {task.id} - {task.title}
    │ Label: {label}
    │ Skill: devkit:{skill_name}
    │ Time: {timestamp()}
    └─────────────────────────────────────────────────────────────────
    """)

    return skill_name
```

**Each agent will:**

1. Load task details from PM system (Jira or Notion)
2. Extract Specification and Technical Plan context from parent issue
3. Follow TDD checklist from sub-issue
4. Run verification from justfile directory (`cd <module> && just test`)
5. Update task status in PM system (Jira or Notion)
6. Report completion

**After each task completes:**

1. Update completed tasks list
2. Check for newly unblocked tasks
3. Continue with next task if any remain
4. Proceed to Step 4 when all tasks complete

### Step 4: Context Provided to Subagents

**Each subagent receives via Task prompt:**

```python
# Build comprehensive context for subagent
task_prompt = f"""
Use Skill('devkit:executing-{task_type}') for issue {ticket_id}

## Pre-loaded Documentation

The following documentation has been loaded based on the files you'll be working with.
Follow these patterns and conventions:

{doc_content}

---

Execute the task following the skill's workflow.
"""

Task(prompt=task_prompt, subagent_type="general-purpose")
```

**The subagent receives:**

- **Pre-loaded docs** - Relevant documentation injected by executing-plans (no need to load)
- **Task description** - With TDD checklist from sub-issue
- **Specification context** - (WHAT) from parent issue
- **Technical Plan guidance** - (HOW) from parent issue

**Subagent responsibilities:**

1. Follow TDD checklist in sub-issue
2. Use test-driven-development skill
3. Reference patterns from Technical Plan AND pre-loaded docs
4. Verify with `just test` and `just lint`
5. Update PM system status (Jira or Notion)
6. Report completion

**Note:** Subagents do NOT need to load documentation themselves - it's pre-injected.

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

- **NEVER execute on main/master** - Always use isolated worktree
- **Pre-Task Guard runs before EVERY task** - Catches resumed sessions
- Plans in PM system (not files)
- Both WHAT and HOW to subagents
- TDD checklist in sub-issue
- Tests + implementation together
- Stop when blocked
- Create PR at end (with confirmation)

## Red Flags

**NEVER:**

- Execute any task while on main or master branch
- Skip worktree setup, even if "just this once"
- Proceed after Pre-Task Guard fails
- Assume previous session state is preserved after context overflow

**ALWAYS:**

- Verify git branch before every task dispatch
- Use `<parent>/worktrees/{repo}/{branch}/` for isolation
- Re-run worktree setup if Pre-Task Guard fires
- Stop execution if unable to establish safe workspace
