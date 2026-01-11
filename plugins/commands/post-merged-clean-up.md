---
description: Clean up after PR merge - removes worktree, deletes branches, syncs main, updates tickets
---

# Post-Merged Clean-Up - Complete Post-Merge Cleanup

Performs complete cleanup after a PR has been merged: removes worktree and branches, syncs main, and updates PM tickets to Done.

## Usage

```bash
/post-merged-clean-up              # Run from the worktree/branch that was merged
/post-merged-clean-up <branch>     # Specify branch name explicitly
/post-merged-clean-up <pr-url>     # Provide PR URL for verification
```

## Overview

This command uses the `post-merged-cleanup` skill to perform systematic cleanup after a PR merge.

**Process:**

1. Verify PR was actually merged (not just closed)
2. Confirm cleanup plan with user
3. Delete worktree folder
4. Delete local branch
5. Delete remote branch (if not auto-deleted)
6. Switch to main repo and pull latest
7. Prune stale remote references
8. Update PM system tickets to Done
9. Print summary

## When to Use

**Run this command after:**

- Your PR has been merged on GitHub
- You've completed `/address-feedback` and PR was approved
- You want to clean up and prepare for the next task

**Workflow position:**

```
/refine → /plan → /breakdown → /execute → /pr → /address-feedback → /post-merged-clean-up
```

## Requirements

**Git repository with:**

- Merged PR (will verify before cleanup)
- Worktree created for the feature branch
- PM system configured in CLAUDE.md (for ticket updates)

**Current state:**

- Can run from worktree or main repo
- Branch name or PR URL helps with verification

## Safety Features

**Verification first:**

- Confirms PR was merged, not just closed
- Checks merge status via git and/or GitHub API

**User confirmation:**

- Shows complete cleanup plan before executing
- Lists all actions that will be performed
- Warns about any uncommitted changes

**Graceful handling:**

- Skips already-deleted branches
- Notes if GitHub auto-deleted remote branch
- Continues with other steps if one fails

## Command Execution

When you invoke this command, Claude will:

1. **Announce skill usage:**
   "I'm using the post-merged-cleanup skill to clean up after the merged PR."

2. **Detect context:**
   - Current directory and branch
   - Whether in worktree or main repo
   - Main repo location
   - Default branch name

3. **Verify merge status:**

   ```bash
   git fetch origin
   git branch -r --merged origin/main | grep "origin/$BRANCH"
   ```

4. **Present cleanup plan:**

   ```markdown
   ## Post-Merge Cleanup Plan

   **Branch:** feature/TEAM-123-add-auth
   **PR Status:** Merged into main

   **Actions to perform:**

   1. Delete worktree: /Projects/worktrees/my-repo/feature-auth
   2. Delete local branch: feature/TEAM-123-add-auth
   3. Delete remote branch: origin/feature/TEAM-123-add-auth
   4. Switch to: /Projects/my-repo
   5. Pull latest main
   6. Update tickets to Done: TEAM-123

   Proceed with cleanup? (yes/no)
   ```

5. **Execute cleanup:**

   ```bash
   cd /Projects/my-repo
   git worktree remove /Projects/worktrees/my-repo/feature-auth
   git branch -d feature/TEAM-123-add-auth
   git push origin --delete feature/TEAM-123-add-auth
   git checkout main
   git pull origin main
   git fetch --prune
   ```

6. **Update PM tickets:**

   - Jira: Update issue status to Done
   - Notion: Update page Status property to Done

7. **Print summary:**

   ```markdown
   ## Cleanup Complete

   **Branch:** feature/TEAM-123-add-auth
   **PR:** Merged into main

   **Actions completed:**

   - [x] Worktree removed
   - [x] Local branch deleted
   - [x] Remote branch deleted
   - [x] Main repo synced
   - [x] Tickets updated: TEAM-123 → Done

   **Current location:** /Projects/my-repo (on main)

   Ready for next task!
   ```

## Examples

### Standard Cleanup (from worktree)

```bash
# Currently in: /Projects/worktrees/my-repo/feature-auth
/post-merged-clean-up
```

**Output:**

```
Verifying PR merge status...
Branch feature/TEAM-123-add-auth is merged into main.

## Cleanup Plan
[... plan details ...]

Proceed? yes

Cleaning up...
✓ Worktree removed: /Projects/worktrees/my-repo/feature-auth
✓ Local branch deleted: feature/TEAM-123-add-auth
✓ Remote branch already deleted by GitHub
✓ Switched to /Projects/my-repo
✓ Main branch updated
✓ Ticket TEAM-123 updated to Done

Cleanup complete! Ready for next task.
```

### With Explicit Branch

```bash
# From main repo, specify branch
/post-merged-clean-up feature/TEAM-456-fix-bug
```

### With PR URL Verification

```bash
/post-merged-clean-up https://github.com/org/repo/pull/123
```

## Error Scenarios

### PR Not Merged

```
The branch does not appear to be merged into main.

Options:
1. Provide PR URL to verify
2. Cancel cleanup

Your choice:
```

### Uncommitted Changes in Worktree

```
Worktree has uncommitted changes:
- 2 modified files
- 1 untracked file

Options:
1. Commit changes first
2. Force remove (⚠️ will lose changes)
3. Cancel cleanup

Your choice:
```

### PM System Unavailable

```
Git cleanup completed successfully.

⚠️ Could not update PM tickets:
- Jira MCP server not available

Please update ticket TEAM-123 manually to Done.
```

## Integration

**Uses:**

- `post-merged-cleanup` skill for cleanup logic
- `pm-operations` skill patterns for ticket updates

**Pairs with:**

- `/pr` command - Creates PRs
- `/address-feedback` - Handles PR feedback
- `/execute` - Creates worktrees during execution
- `/clean-worktrees` - Alternative for batch cleanup

**Completes workflow:**

```
/refine → /plan → /breakdown → /execute → /pr → /address-feedback → /post-merged-clean-up
                                                                              ↑
                                                                        (You are here)
```

## Best Practices

1. **Run immediately after merge** - Clean up while context is fresh
2. **Verify merge first** - Command does this automatically
3. **Check for uncommitted work** - Don't lose any stashed experiments
4. **Update tickets** - Keep PM system in sync
5. **Pull latest** - Start next task with up-to-date main

## Comparison with /clean-worktrees

| Aspect | /post-merged-clean-up | /clean-worktrees |
|--------|----------------------|------------------|
| **Scope** | Single PR/branch | All merged worktrees |
| **When** | Right after PR merge | Periodic cleanup |
| **Tickets** | Updates PM tickets | Does not update tickets |
| **Focus** | Complete workflow closure | Disk space recovery |

**Use /post-merged-clean-up** immediately after each PR merge.
**Use /clean-worktrees** for periodic bulk cleanup.
