---
description: Process PR review feedback and automatically implement all changes
---

# Address Feedback - PR Review Processing Command

Process GitHub PR review comments, add sub-issues to parent, and automatically implement all feedback.

## Usage

```bash
/address-feedback <pr-number>              # Process PR in current repo
/address-feedback <owner/repo> <pr-number> # Process PR in specific repo
```

## Overview

This command uses the `addressing-pr-feedback` skill to:

1. Find parent issue from PR (must be referenced in PR)
2. Find and switch to PR's git worktree (automatic)
3. Fetch all review comments from GitHub
4. Categorize feedback by severity
5. Add new sub-issues to existing parent issue
6. Update parent with feedback summary

Then automatically calls `/execute <parent-id>` to implement all feedback.

## Requirements

**PR must have:**

- Parent issue reference in description (added by `/pr`)
- Format: "Closes TEAM-123" or "Implements TEAM-123" (Jira), or equivalent for other PM systems

**GitHub CLI:**

- Installed and authenticated

**PM System:**

- PM system configured (via `/setup`)

**Git Worktrees:**

- Original work in `<parent>/worktrees/<repo-name>/`

## How It Works

### Step 1: Run Addressing-PR-Feedback Skill

```bash
Skill(devkit:addressing-pr-feedback)
```

Skill handles:

- Finding parent issue from PR
- Switching to PR's worktree
- Fetching review comments
- Categorizing feedback
- Creating sub-issues under existing parent
- Answering reviewer questions

### Step 2: Auto-Execute

Command automatically calls:

```bash
/execute <parent-issue-id>
```

Execution handles:

- Implementing all feedback items with TDD
- Code review after each fix
- PM system status updates
- Updating PR at end

## Example

```bash
/address-feedback 145

# Addressing-PR-Feedback Skill:
Processing PR #145...
✓ Found parent issue: TEAM-123 (from PR)
✓ Found worktree: /Projects/worktrees/my-repo/feature-auth
✓ Switched to worktree
✓ Fetched 10 review comments

Categorized:
- Critical: 2
- Important: 3
- Minor: 5

✓ Added 10 sub-issues to TEAM-123
✓ Updated parent with feedback summary

# Command automatically calls /execute TEAM-123
Loaded 25 sub-issues:
✓ 15 already complete (original implementation)
→ 10 ready to start (feedback items)

Start implementation? (yes/no)
> yes

✓ All 10 feedback items implemented
✓ PR #145 updated
✓ Ready for re-review

💡 After PR is merged: /post-merged-clean-up
```

## Integration

**Uses:**

- `addressing-pr-feedback` skill - Preparation
- `/execute` command - Implementation

**Workflow:**

1. Skill processes feedback → Returns parent ID
2. Command calls `/execute <parent-id>`
3. Execute picks up where it left off (skips completed tasks)

## Remember

- Command is simple orchestrator (skill → execute)
- Skill adds sub-issues to EXISTING parent (not new)
- Parent issue found from PR reference
- `/execute` handles partial completion automatically
- Works in PR's original worktree
