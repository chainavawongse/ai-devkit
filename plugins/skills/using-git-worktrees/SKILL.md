---
name: using-git-worktrees
description: Use when starting feature work that needs isolation from current workspace or before executing implementation plans - creates isolated git worktrees with smart directory selection and safety verification
---

# Using Git Worktrees

## Overview

Git worktrees create isolated workspaces sharing the same repository, allowing work on multiple branches simultaneously without switching.

**Core principle:** Systematic directory selection + safety verification = reliable isolation.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

**Branch Naming Format:** `<type>/<ticket>-<description>` (e.g., `feature/PAS-123-add-user-auth`)

See `docs/git-conventions.md` for complete branching, commit, and PR conventions.

## Directory Selection Process

**plugin Standard: Use `~/worktrees/` directory for parallel execution**

All git worktrees are created in `~/worktrees/<repo-name>/` to enable:

- Consistent location across all projects
- Parallel execution of multiple repositories
- Easy to manage and clean up
- No repository .gitignore needed

**First time setup - Confirm with user:**

```
Worktrees will be created in: ~/worktrees/<repo-name>/<branch-name>

Is this location acceptable?
- Yes (recommended)
- Specify different location
```

**If user specifies different location:** Use that for the session, suggest adding to project config

### Check if ~/worktrees/ exists

```bash
ls -d ~/worktrees 2>/dev/null
```

**If not found:** Create it during setup:

```bash
mkdir -p ~/worktrees
```

## Safety Verification

**MUST create ~/worktrees/<repo-name>/ directory before creating worktree:**

```bash
# Get repository name
REPO_NAME=$(basename $(git rev-parse --show-toplevel))

# Create worktree parent directory
mkdir -p ~/worktrees/$REPO_NAME
```

**Why this location:**

- Outside repository (no .gitignore concerns)
- Parallel execution safe (multiple repos can work simultaneously)
- Easy cleanup (rm -rf ~/worktrees when done)
- Consistent across all plugin workflows

## Creation Steps

### 1. Create Worktree

```bash
# Get repository name and create parent directory
REPO_NAME=$(basename $(git rev-parse --show-toplevel))
WORKTREE_ROOT=~/worktrees/$REPO_NAME
mkdir -p "$WORKTREE_ROOT"

# Create worktree with new branch
path="$WORKTREE_ROOT/$BRANCH_NAME"
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

### 2. Run Project Setup

Use the project's justfile for consistent setup:

```bash
# All projects should have a justfile with install recipe
just install
```

**What `just install` does:**

- Installs all dependencies (npm install, cargo build, pip install, etc.)
- Configures environment if needed
- Project-specific setup steps
- **Repository defines what's needed**, workflow stays consistent

**If no justfile exists:**

Suggest running `/setup` to create one:

```markdown
⚠️ No justfile found in repository.

Run `/setup` to create a justfile with standard recipes:
- just install: Install dependencies
- just test: Run tests
- just lint: Run linter
- just format: Format code
- just build: Build project

Would you like me to run /setup now?
```

### 3. Verify Clean Baseline

Use the project's justfile for consistent testing:

```bash
# All projects should have a justfile with test recipe
just test
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

### 4. Report Location

```
Worktree ready at ~/worktrees/<repo-name>/<branch-name>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| First time using worktrees | Ask user to confirm location (~/worktrees/ default) |
| `~/worktrees/` directory missing | Create with `mkdir -p ~/worktrees/$REPO_NAME` |
| No justfile | Suggest running `/setup` to create one |
| Tests fail during baseline | Report failures + ask |

## Common Mistakes

**Not confirming worktree location first time**

- **Problem:** User may prefer different location
- **Fix:** Always ask on first use, remember for session

**Using different directory locations**

- **Problem:** Creates inconsistency across projects
- **Fix:** Always use `~/worktrees/<repo-name>/` - this is the plugin standard

**Proceeding with failing tests**

- **Problem:** Can't distinguish new bugs from pre-existing issues
- **Fix:** Report failures, get explicit permission to proceed

**Hardcoding setup commands**

- **Problem:** Breaks on projects using different tools
- **Fix:** Use `just install` - repository defines what's needed

## Example Workflow

```
You: I'm using the using-git-worktrees skill to set up an isolated workspace.

[First time: Ask user] "Worktrees will be created in ~/worktrees/my-project/. Is this acceptable?"
User: "Yes"

[Create directory: mkdir -p ~/worktrees/my-project]
[Create worktree: git worktree add ~/worktrees/my-project/feature-auth -b feature/auth]
[cd ~/worktrees/my-project/feature-auth]
[Run just install]
[Run just test - 47 passing]

Worktree ready at ~/worktrees/my-project/feature-auth
Tests passing (47 tests, 0 failures)
Ready to implement auth feature
```

## Red Flags

**Never:**

- Create worktree without confirming location (first time)
- Skip baseline test verification
- Proceed with failing tests without asking
- Use directory locations other than `~/worktrees/<repo-name>/`

**Always:**

- Confirm worktree location on first use (default: `~/worktrees/`)
- Use `~/worktrees/<repo-name>/` directory (plugin standard)
- Create `~/worktrees/<repo-name>/` directory if missing
- Use `just install` for setup (repository-agnostic)
- Use `just test` for baseline verification
- Suggest `/setup` if no justfile exists

## Integration

**Called by:**

- **executing-plans** - REQUIRED at start of execution for parallel task isolation
- Any skill needing isolated workspace

**Pairs with:**

- **cleaning-up-git-worktrees** - REQUIRED for cleanup after work complete
- **executing-plans** - Parallel tasks execute in this worktree
