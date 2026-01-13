---
name: using-git-worktrees
description: Create isolated git worktrees for feature work without affecting current workspace
when_to_use: when starting feature work that needs isolation from current workspace or before executing implementation plans
version: 1.1.0
---

# Using Git Worktrees

## Overview

Git worktrees create isolated workspaces sharing the same repository, allowing work on multiple branches simultaneously without switching.

**Core principle:** Systematic directory selection + safety verification = reliable isolation.

**Announce at start:** "I'm using the using-git-worktrees skill to set up an isolated workspace."

**Branch Naming Format:** `<type>/<ticket>-<description>` (e.g., `feature/PAS-123-add-user-auth`)

See `docs/git-conventions.md` for complete branching, commit, and PR conventions.

## Directory Selection Process

**plugin Standard: Use sibling `worktrees/` directory for parallel execution**

All git worktrees are created as a sibling to the repository under a `worktrees/` folder:

```
<parent-folder>/
├── <repo-name>/              # The main repository
└── worktrees/
    └── <repo-name>/          # Project-specific worktrees folder
        └── <branch-name>/    # Individual worktree
```

**Example:** If your repo is at `/Projects/MyNewProject`, worktrees go to `/Projects/worktrees/MyNewProject/<branch-name>`

**Benefits:**

- Worktrees stay close to the project
- Organized by project within the worktrees folder
- Easy to find and manage
- No repository .gitignore needed

**First time setup - Confirm with user:**

```
Worktrees will be created in: <parent>/worktrees/<repo-name>/<branch-name>
(e.g., /Projects/worktrees/MyNewProject/feature-auth)

Is this location acceptable?
- Yes (recommended)
- Specify different location
```

**If user specifies different location:** Use that for the session, suggest adding to project config

### Determine worktree base path

```bash
# Get repository root and name
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
PARENT_DIR=$(dirname "$REPO_ROOT")

# Worktree base is sibling to repo
WORKTREE_BASE="$PARENT_DIR/worktrees"
```

### Check if worktrees folder exists

```bash
ls -d "$WORKTREE_BASE" 2>/dev/null
```

**If not found:** Create it during setup:

```bash
mkdir -p "$WORKTREE_BASE/$REPO_NAME"
```

## Safety Verification

**MUST create worktrees directory before creating worktree:**

```bash
# Get repository info
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
PARENT_DIR=$(dirname "$REPO_ROOT")
WORKTREE_BASE="$PARENT_DIR/worktrees"

# Create worktree parent directory
mkdir -p "$WORKTREE_BASE/$REPO_NAME"
```

**Why this location:**

- Close to project (easy to find and navigate)
- Outside repository (no .gitignore concerns)
- Parallel execution safe (multiple repos can work simultaneously)
- Easy cleanup (rm -rf <parent>/worktrees when done)
- Organized by project within worktrees folder

## Creation Steps

### 1. Create Worktree

```bash
# Get repository info and create parent directory
REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
PARENT_DIR=$(dirname "$REPO_ROOT")
WORKTREE_BASE="$PARENT_DIR/worktrees/$REPO_NAME"
mkdir -p "$WORKTREE_BASE"

# Create worktree with new branch
path="$WORKTREE_BASE/$BRANCH_NAME"
git worktree add "$path" -b "$BRANCH_NAME"
cd "$path"
```

### 2. Symlink User Settings

User-specific settings (like autonomy configuration) should be symlinked from the main repo:

```bash
# Symlink .claude/settings.local.json if it exists in main repo
# This step is optional - skipped silently if no settings file exists
MAIN_SETTINGS="$REPO_ROOT/.claude/settings.local.json"
if [ -f "$MAIN_SETTINGS" ]; then
    mkdir -p "$path/.claude"
    ln -sf "$MAIN_SETTINGS" "$path/.claude/settings.local.json"
    echo "Symlinked autonomy settings from main repo"
fi
# No error if file doesn't exist - user may not have configured autonomy yet
```

**Why symlink (not copy):**

- User autonomy settings are personal preferences
- Symlink ensures changes in main repo propagate to all worktrees
- No drift between worktrees and main repo

### 3. Run Project Setup

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

### 4. Verify Clean Baseline

Use the project's justfile for consistent testing:

```bash
# All projects should have a justfile with test recipe
just test
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

**If tests pass:** Report ready.

### 5. Report Location

```
Worktree ready at <parent>/worktrees/<repo-name>/<branch-name>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| First time using worktrees | Ask user to confirm location (<parent>/worktrees/ default) |
| Worktrees directory missing | Create with `mkdir -p "$PARENT_DIR/worktrees/$REPO_NAME"` |
| Main repo has `.claude/settings.local.json` | Symlink to worktree for autonomy settings |
| No justfile | Suggest running `/setup` to create one |
| Tests fail during baseline | Report failures + ask |

## Common Mistakes

**Not confirming worktree location first time**

- **Problem:** User may prefer different location
- **Fix:** Always ask on first use, remember for session

**Using different directory locations**

- **Problem:** Creates inconsistency across projects
- **Fix:** Always use `<parent>/worktrees/<repo-name>/` - this is the plugin standard

**Proceeding with failing tests**

- **Problem:** Can't distinguish new bugs from pre-existing issues
- **Fix:** Report failures, get explicit permission to proceed

**Hardcoding setup commands**

- **Problem:** Breaks on projects using different tools
- **Fix:** Use `just install` - repository defines what's needed

## Example Workflow

```
You: I'm using the using-git-worktrees skill to set up an isolated workspace.

[First time: Ask user] "Worktrees will be created in /Projects/worktrees/my-project/. Is this acceptable?"
User: "Yes"

[Create directory: mkdir -p /Projects/worktrees/my-project]
[Create worktree: git worktree add /Projects/worktrees/my-project/feature-auth -b feature/auth]
[cd /Projects/worktrees/my-project/feature-auth]
[Symlink settings: ln -sf /Projects/my-project/.claude/settings.local.json .claude/settings.local.json]
[Run just install]
[Run just test - 47 passing]

Worktree ready at /Projects/worktrees/my-project/feature-auth
Autonomy settings: symlinked from main repo
Tests passing (47 tests, 0 failures)
Ready to implement auth feature
```

## Red Flags

**Never:**

- Create worktree without confirming location (first time)
- Skip baseline test verification
- Proceed with failing tests without asking
- Use directory locations other than `<parent>/worktrees/<repo-name>/`

**Always:**

- Confirm worktree location on first use (default: `<parent>/worktrees/`)
- Use `<parent>/worktrees/<repo-name>/` directory (plugin standard)
- Create `<parent>/worktrees/<repo-name>/` directory if missing
- Symlink `.claude/settings.local.json` if it exists (user autonomy settings)
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
