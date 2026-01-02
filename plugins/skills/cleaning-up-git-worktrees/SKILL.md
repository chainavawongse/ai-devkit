---
name: cleaning-up-git-worktrees
description: Clean up git worktrees that are related to merged branches - reviews worktrees, identifies merged branches, and prompts user for confirmation before removal
when_to_use: when worktrees accumulate after completing features, or when disk space is needed - identifies and removes worktrees for merged branches
version: 1.0.0
---

# Cleaning Up Git Worktrees

## Overview

Removes git worktrees associated with branches that have been merged, keeping your workspace clean and freeing up disk space.

**Core principle:** Identify merged branches + user confirmation = safe cleanup.

**Announce at start:** "I'm using the cleaning-up-git-worktrees skill to clean up merged worktrees."

## Process

### Step 1: List All Worktrees

```bash
git worktree list --porcelain
```

Parse output to get:

- Worktree path
- Branch name
- HEAD commit

### Step 2: Identify Merged Branches

For each worktree branch:

```bash
# Check if branch is merged into main (or default branch)
git branch --merged main | grep "$BRANCH_NAME"

# Also check merge status for other common main branches
git branch --merged master | grep "$BRANCH_NAME"
git branch --merged develop | grep "$BRANCH_NAME"
```

**Branch is merged if:**

- Appears in `git branch --merged <default-branch>` output
- OR remote branch is deleted AND local commits are in default branch

### Step 3: Check for Uncommitted Changes

For each worktree identified as merged:

```bash
cd "$WORKTREE_PATH"
git status --porcelain
```

**If uncommitted changes exist:**

- Mark worktree as "Has uncommitted changes"
- User must decide whether to remove (data loss warning)

### Step 4: Present Summary to User

Display categorized list:

```markdown
## Merged Worktrees (Safe to Remove)

1. /Projects/worktrees/my-repo/feature-auth
   Branch: feature/auth
   Status: Merged into main
   Clean: Yes

2. /Projects/worktrees/my-repo/fix-login-bug
   Branch: fix/login-bug
   Status: Merged into main
   Clean: Yes

## Merged Worktrees with Uncommitted Changes (⚠️ Data Loss Warning)

3. /Projects/worktrees/my-repo/feature-dashboard
   Branch: feature/dashboard
   Status: Merged into main
   Clean: No - 3 files modified
   Warning: Removing will delete uncommitted changes

## Unmerged Worktrees (Keep)

4. /Projects/worktrees/my-repo/feature-new-feature
   Branch: feature/new-feature
   Status: Not merged
   Reason: Active development

5. /Projects/worktrees/my-repo/experiment-refactor
   Branch: experiment/refactor
   Status: Not merged
   Reason: Branch exists on remote
```

### Step 5: Get User Confirmation

**Present options:**

```markdown
Found 3 worktrees that can be removed (2 clean, 1 with uncommitted changes)

Would you like to:
1. Remove all 2 clean worktrees (safe)
2. Remove all 3 worktrees (⚠️ will lose uncommitted changes in #3)
3. Select specific worktrees to remove
4. Cancel - keep all worktrees

Your choice:
```

### Step 6: Remove Selected Worktrees

For each worktree to remove:

```bash
# Remove the worktree
git worktree remove "$WORKTREE_PATH"

# If force needed (uncommitted changes):
git worktree remove --force "$WORKTREE_PATH"

# Prune worktree references
git worktree prune
```

**Report each removal:**

```
✓ Removed /Projects/worktrees/my-repo/feature-auth (branch: feature/auth)
✓ Removed /Projects/worktrees/my-repo/fix-login-bug (branch: fix/login-bug)
```

### Step 7: Optional Branch Cleanup

After removing worktrees, ask:

```markdown
Worktrees removed. Would you also like to delete the merged local branches?

Branches to delete:
- feature/auth (merged)
- fix/login-bug (merged)

Delete these local branches? (yes/no)
```

If yes:

```bash
git branch -d "$BRANCH_NAME"
```

## Edge Cases

### Worktree Directory Missing

If worktree directory doesn't exist but git still tracks it:

```bash
# Force remove the worktree reference
git worktree remove --force "$WORKTREE_PATH"
git worktree prune
```

### Branch Merged but Commits Diverged

If branch was merged via squash/rebase:

```bash
# Check if commits exist in main
git log main..branch_name

# If output is empty, branch content is in main (safe to remove)
# If output shows commits, branch has diverged (ask user)
```

### Current Worktree

Never remove the current worktree:

```bash
CURRENT_PATH=$(pwd)
if [[ "$WORKTREE_PATH" == "$CURRENT_PATH" ]]; then
    echo "Skipping current worktree"
    continue
fi
```

### Main Worktree

Never remove the main worktree (the original checkout):

```bash
if git worktree list | grep -q "^$(git rev-parse --show-toplevel).*bare"; then
    # Skip main worktree
    continue
fi
```

## Safety Checks

**Before removing any worktree:**

1. Verify branch is truly merged
2. Check for uncommitted changes
3. Confirm not current worktree
4. Confirm not main worktree
5. Get user confirmation

**Never automatically remove:**

- Current worktree
- Main worktree
- Worktrees with uncommitted changes (without force flag and user warning)
- Worktrees on unmerged branches

## Quick Reference

| Situation | Action |
|-----------|--------|
| Branch merged + clean worktree | Safe to remove with confirmation |
| Branch merged + uncommitted changes | Warn user about data loss |
| Branch not merged | Skip - keep worktree |
| Current worktree | Skip - never remove |
| Main worktree | Skip - never remove |
| Directory missing | Use `--force` to cleanup reference |

## Example Workflow

```
You: I'm using the cleaning-up-git-worktrees skill to clean up merged worktrees.

[List worktrees: 5 found]
[Check merge status for each]
[Identify: 2 merged clean, 1 merged with changes, 2 unmerged]

Found 3 worktrees related to merged branches:

Clean worktrees (safe to remove):
1. /Projects/worktrees/my-repo/feature-auth (merged into main)
2. /Projects/worktrees/my-repo/fix-bug-123 (merged into main)

Worktrees with uncommitted changes (⚠️):
3. /Projects/worktrees/my-repo/feature-dashboard (3 files modified)

Would you like to:
1. Remove 2 clean worktrees
2. Remove all 3 worktrees (⚠️ data loss)
3. Select specific worktrees
4. Cancel

User: 1

Removing clean worktrees...
✓ Removed /Projects/worktrees/my-repo/feature-auth
✓ Removed /Projects/worktrees/my-repo/fix-bug-123

Also delete local branches? (yes/no)
User: yes

✓ Deleted branch feature/auth
✓ Deleted branch fix/bug-123

Cleanup complete! Freed 450MB disk space.
```

## Common Mistakes

**Removing without checking merge status**

- **Problem:** Deletes active work
- **Fix:** Always verify branch is merged first

**Not checking for uncommitted changes**

- **Problem:** User loses work
- **Fix:** Run git status on each worktree before removal

**Removing current worktree**

- **Problem:** Git error, broken state
- **Fix:** Always skip current worktree

**No user confirmation**

- **Problem:** Unexpected deletions
- **Fix:** Always ask user to confirm list before removing

## Red Flags

**Never:**

- Remove worktree without user confirmation
- Remove worktree with uncommitted changes without explicit warning
- Remove current worktree
- Remove main worktree
- Assume branch is merged without verification

**Always:**

- List all worktrees with merge status
- Check for uncommitted changes
- Show clear summary before removal
- Get explicit user confirmation
- Report each removal action
- Offer to cleanup local branches after

## Integration

**Called by:**

- `/clean-worktrees` command

**Pairs with:**

- **using-git-worktrees** - Creates worktrees that this cleans up
- **creating-pull-requests** - After PR is merged, clean up the worktree
