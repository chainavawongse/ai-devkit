---
description: Execute implementation by processing sub-issues with TDD, code review, and automatic status updates
---

# Execute - Implementation Execution Command

Process sub-issues systematically with TDD workflow, automatic checks, and code review.

## Usage

```bash
/execute <issue-id>         # Execute implementation for parent issue
```

## Overview

Orchestrates the `executing-plans` skill to:

1. Verify prerequisites (Specification + Technical Plan + sub-issues exist)
2. Execute tasks with full context (WHAT + HOW + TDD checklist)
3. Automatic checks, code review, status updates
4. Create PR when complete (with user confirmation)

## Requirements

**Parent issue MUST have:**

- Specification section (from `/refine`)
- Technical Plan section (from `/plan`)
- Sub-issues (from `/breakdown`)

**Repository MUST have:**

- Clean working directory or git worktree
- Justfile with test/lint/format (recommended)

## Workflow

```mermaid
graph TB
    A["Start execute"] --> B{Verify Prerequisites}
    B -->|Missing Spec| C["ERROR: Run /refine"]
    B -->|Missing Plan| D["ERROR: Run /plan"]
    B -->|Missing Sub-issues| E["ERROR: Run /breakdown"]
    B -->|Clean Git| F{PR at end?}
    B -->|Dirty Git| G["ERROR: Commit or worktree"]

    F --> H[Invoke executing-plans skill]
    H --> I[Load Spec + Plan + Sub-issues]
    I --> J[Execute sequentially]
    J --> K[Task 1: First ready task]
    K --> L[Task 2: Next ready task]
    L --> M[Task N: Final task]
    M --> N{Create PR?}
    N -->|Yes| O[Create PR with diagrams]
    N -->|No| P[Complete]
    O --> P

    style A fill:#e3f2fd
    style H fill:#fff3e0
    style K fill:#e8f5e9
    style L fill:#e8f5e9
    style M fill:#e8f5e9
    style O fill:#fff9c4
    style P fill:#4caf50,color:#fff
    style C fill:#ffebee
    style D fill:#ffebee
    style E fill:#ffebee
    style G fill:#ffebee
```

## How It Works

### Step 1: Verify Prerequisites

**Read PM configuration from CLAUDE.md** and use `pm-operations` for all PM interactions:

```bash
# Check working directory
git_status = git status --porcelain
if git_status not empty:
    ERROR: Uncommitted changes
    SUGGEST: Commit, stash, or use git worktree

# Load parent issue using configured PM system
parent = pm_operations.get_issue(id)

# Verify sections
if "## Specification" not in parent.description:
    ERROR: Run `/refine <issue-id>` first
if "## Technical Plan" not in parent.description:
    ERROR: Run `/plan <issue-id>` first

# Load sub-issues
sub_issues = pm_operations.list_children(parentId: parent.id)
if len(sub_issues) == 0:
    ERROR: Run `/breakdown <issue-id>` first
```

### Step 2: Invoke Executing-Plans Skill

```bash
Skill(devkit:executing-plans)
```

The skill handles PR confirmation, context extraction, subagent dispatch, checks, review, status updates, and PR creation. Respects already-completed sub-issues (allows resuming executions).

### Step 3: Subagent Context Template

Each subagent receives task description + relevant Specification excerpts (WHAT) + relevant Technical Plan guidance (HOW) + TDD checklist from sub-issue. They follow RED-GREEN-REFACTOR cycle, run checks, commit, and report.

## Error Handling

**Missing Prerequisites:** Run `/refine`, `/plan`, `/breakdown` in order before `/execute`.

**Dirty Working Directory:** Commit, stash, or use git worktree before executing.

**No Sub-Issues:** Run `/breakdown <issue-id>` to create implementation tasks first.

## Example

```bash
/execute AUTH-123

# Output:
# Loaded AUTH-123: "User authentication"
# ✓ Specification found
# ✓ Technical Plan found
# ✓ 18 sub-issues found
# Ready to start: 4 tasks (no dependencies)
# Using executing-plans skill...
# [Implementation with subagents]
# ✓ All 18 tasks complete
# ✓ 110 tests passing
# Create PR now? (yes/no)
# > yes
# ✓ PR created: https://github.com/org/repo/pull/145
```

## Integration

**Requires:** PM system configured (via `/setup`), parent issue with Specification + Technical Plan + sub-issues, `executing-plans` skill, `creating-pull-requests` skill, GitHub CLI authenticated.

**Uses:** Subagents for implementation, code review per task, automatic status updates, PR creation with diagrams.

## Remember

- Command verifies prerequisites, skill does execution
- Subagents get full context (WHAT + HOW + TDD checklist)
- Tests and implementation together (not split)
- Clean working directory required
- Respects completed sub-issues (resumable)
