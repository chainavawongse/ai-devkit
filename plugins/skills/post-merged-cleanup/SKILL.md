---
name: post-merged-cleanup
description: Complete cleanup after PR merge - removes worktree, deletes branches, updates main, and closes PM tickets
when_to_use: after a PR has been merged - cleans up worktree, branches, syncs main, and updates issue status
version: 1.0.0
---

# Post-Merged Cleanup

## Overview

Performs complete cleanup after a PR has been merged: removes worktree, deletes local/remote branches, syncs main branch, and updates PM system tickets to Done.

**Core principle:** Verify merge first, then clean up systematically with user confirmation.

**Announce at start:** "I'm using the post-merged-cleanup skill to clean up after the merged PR."

## Prerequisites

- PR has been merged (not just closed)
- Currently in worktree or know the branch name
- PM system configured (for ticket updates)

## Process

### Step 0: Detect Current Context

```bash
# Get current directory and branch
CURRENT_DIR=$(pwd)
CURRENT_BRANCH=$(git branch --show-current)

# Check if we're in a worktree
WORKTREE_INFO=$(git worktree list --porcelain | grep -A2 "worktree $CURRENT_DIR")

# Get main repo directory (for worktrees, this is the main worktree)
MAIN_REPO=$(git worktree list | head -1 | awk '{print $1}')

# Detect default branch
DEFAULT_BRANCH=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
```

### Step 1: Verify PR is Merged

**Critical:** Only proceed if PR was actually merged (not just closed).

```bash
# Check if branch exists on remote
git fetch origin

# Check if branch was merged into default branch
git log origin/$DEFAULT_BRANCH --oneline | head -20

# Check merge status
MERGED=$(git branch -r --merged origin/$DEFAULT_BRANCH | grep "origin/$CURRENT_BRANCH" || echo "")

# Alternative: Check if remote branch was deleted (GitHub auto-deletes on merge)
REMOTE_EXISTS=$(git ls-remote --heads origin $CURRENT_BRANCH | wc -l)
```

**If not merged:**

```markdown
The branch `$CURRENT_BRANCH` does not appear to be merged into `$DEFAULT_BRANCH`.

Current status:
- Remote branch exists: [yes/no]
- Merged into $DEFAULT_BRANCH: [yes/no]

Options:
1. Verify the PR URL and check if it was merged
2. Cancel cleanup (branch may still be in progress)

Would you like to provide the PR URL to verify?
```

### Step 2: Confirm Cleanup with User

Present cleanup plan:

```markdown
## Post-Merge Cleanup Plan

**Branch:** $CURRENT_BRANCH
**PR Status:** Merged into $DEFAULT_BRANCH

**Actions to perform:**

1. Delete worktree: $CURRENT_DIR
2. Delete local branch: $CURRENT_BRANCH
3. Delete remote branch: origin/$CURRENT_BRANCH (if exists)
4. Switch to main repo: $MAIN_REPO
5. Pull latest $DEFAULT_BRANCH
6. Update ticket status to Done

**Tickets to update:** [list extracted from branch name or PR]

Proceed with cleanup? (yes/no)
```

### Step 3: Extract Ticket IDs

Parse ticket IDs from branch name or PR:

```bash
# Common patterns: feature/TEAM-123-description, TEAM-123/feature, fix-TEAM-123
BRANCH_NAME=$CURRENT_BRANCH

# Extract ticket IDs (adjust pattern for your PM system)
# Jira pattern: PROJECT-123
JIRA_TICKETS=$(echo "$BRANCH_NAME" | grep -oE '[A-Z]+-[0-9]+' || echo "")

# Notion: might use different identifiers
# Extract from PR description if available
```

### Step 4: Navigate Away from Worktree

If currently in worktree, must leave before deletion:

```bash
# Move to main repo first
cd "$MAIN_REPO"
```

### Step 5: Delete Worktree

```bash
# Check if worktree exists
if git worktree list | grep -q "$CURRENT_DIR"; then
    # Remove the worktree
    git worktree remove "$CURRENT_DIR"

    # Prune worktree references
    git worktree prune

    echo "Removed worktree: $CURRENT_DIR"
fi
```

**If worktree has uncommitted changes:**

```bash
# Force removal (after user confirmation)
git worktree remove --force "$CURRENT_DIR"
git worktree prune
```

### Step 6: Delete Local Branch

```bash
# Delete local branch (use -D if not fully merged due to squash/rebase)
git branch -d "$CURRENT_BRANCH" 2>/dev/null || git branch -D "$CURRENT_BRANCH"

echo "Deleted local branch: $CURRENT_BRANCH"
```

### Step 7: Delete Remote Branch

```bash
# Check if remote branch still exists
if git ls-remote --heads origin "$CURRENT_BRANCH" | grep -q "$CURRENT_BRANCH"; then
    git push origin --delete "$CURRENT_BRANCH"
    echo "Deleted remote branch: origin/$CURRENT_BRANCH"
else
    echo "Remote branch already deleted (likely by GitHub auto-delete)"
fi
```

### Step 8: Sync Main Branch

```bash
# Ensure we're on default branch
git checkout "$DEFAULT_BRANCH"

# Pull latest changes
git pull origin "$DEFAULT_BRANCH"

# Prune stale remote-tracking references
git fetch --prune

echo "Main branch updated and synced"
```

### Step 9: Update PM System Tickets

**Read PM configuration from CLAUDE.md:**

- Determine which PM system is configured (jira/notion)

**If Jira:**

```
# For each ticket ID extracted
for ticket_id in $JIRA_TICKETS:
    # Primary
    mcp__atlassian__update_issue(
        id=ticket_id,
        state="Done"
    )

    # Fallback
    mcp__jira__update_issue(
        issue_key=ticket_id,
        status="Done"
    )
```

**If Notion:**

```
# For each ticket ID
mcp__notion__notion-update-page({
    data: {
        page_id: ticket_id,
        command: "update_properties",
        properties: {
            Status: "Done"
        }
    }
})
```

### Step 10: Print Summary

```markdown
## Cleanup Complete

**Branch:** $CURRENT_BRANCH
**PR:** Merged into $DEFAULT_BRANCH

**Actions completed:**

- [x] Worktree removed: $CURRENT_DIR
- [x] Local branch deleted: $CURRENT_BRANCH
- [x] Remote branch deleted: origin/$CURRENT_BRANCH
- [x] Main repo synced: $MAIN_REPO
- [x] $DEFAULT_BRANCH updated to latest
- [x] Tickets updated to Done: $TICKET_LIST

**Current location:** $MAIN_REPO (on $DEFAULT_BRANCH)

Ready for next task!
```

## Error Handling

| Error | Resolution |
|-------|------------|
| PR not merged | Verify PR URL, confirm with user before proceeding |
| Worktree has uncommitted changes | Warn user, require explicit confirmation for force removal |
| Branch already deleted | Skip that step, continue with others |
| PM system unavailable | Complete git cleanup, note ticket update failed |
| Not in a worktree | Skip worktree deletion, proceed with branch cleanup |
| Permission denied on remote | Note failure, user may need to delete manually |

## Edge Cases

### Not in a Worktree

If running from main repo (not a worktree):

```bash
# Check if this is the main worktree
if [ "$CURRENT_DIR" = "$MAIN_REPO" ]; then
    echo "Running from main repo, skipping worktree deletion"
    # Skip to branch deletion step
fi
```

### Squash-Merged PR

Branch may not appear in `--merged` output:

```bash
# Check if branch commits exist in main (squash/rebase detection)
BRANCH_TIP=$(git rev-parse origin/$CURRENT_BRANCH 2>/dev/null || echo "")
if [ -n "$BRANCH_TIP" ]; then
    # Check if changes are in main even if commit isn't
    DIFF=$(git diff origin/$DEFAULT_BRANCH...origin/$CURRENT_BRANCH --stat)
    if [ -z "$DIFF" ]; then
        echo "Branch appears squash-merged (no diff with main)"
    fi
fi
```

### Multiple Tickets in Branch

```bash
# Handle multiple tickets: feature/TEAM-123-TEAM-456-combined
TICKETS=$(echo "$BRANCH_NAME" | grep -oE '[A-Z]+-[0-9]+' | tr '\n' ' ')
# Update each ticket
```

### Branch Name Mismatch

If branch name differs from PR branch:

```bash
# Ask user to provide correct branch name
echo "Could not determine branch from current context."
echo "Please provide the branch name that was merged:"
```

## Quick Reference

| Step | Action | Command |
|------|--------|---------|
| 1 | Verify merged | `git branch -r --merged origin/main` |
| 2 | Get confirmation | Present plan to user |
| 3 | Extract tickets | `grep -oE '[A-Z]+-[0-9]+'` |
| 4 | Leave worktree | `cd $MAIN_REPO` |
| 5 | Delete worktree | `git worktree remove $PATH` |
| 6 | Delete local branch | `git branch -d $BRANCH` |
| 7 | Delete remote branch | `git push origin --delete $BRANCH` |
| 8 | Sync main | `git checkout main && git pull && git fetch --prune` |
| 9 | Update tickets | PM-specific MCP calls |
| 10 | Print summary | Report all actions |

## Common Mistakes

**Deleting before verifying merge**

- **Problem:** Lose work if PR wasn't actually merged
- **Fix:** Always verify merge status first

**Not leaving worktree before deletion**

- **Problem:** Can't delete current directory
- **Fix:** cd to main repo before worktree removal

**Skipping remote branch deletion**

- **Problem:** Stale branches accumulate on remote
- **Fix:** Delete remote branch (or confirm GitHub auto-deleted it)

**Forgetting to update tickets**

- **Problem:** PM system shows outdated status
- **Fix:** Always update ticket status as final step

## Red Flags

**Never:**

- Delete worktree/branch without verifying PR was merged
- Force-delete without user confirmation about uncommitted changes
- Skip the main branch sync (leaves local out of date)
- Assume GitHub auto-deleted the remote branch

**Always:**

- Verify merge status before any cleanup
- Get user confirmation before destructive actions
- Update PM system tickets to Done
- Print summary of all actions taken

## Integration

**Called by:**

- `/post-merged-clean-up` command

**Pairs with:**

- **creating-pull-requests** - Creates PRs that this cleans up after
- **using-git-worktrees** - Creates worktrees that this removes
- **executing-plans** - Executes work that leads to PRs

**Completes workflow:**

```
/refine → /plan → /breakdown → /execute → /pr → /address-feedback → /post-merged-clean-up
```
