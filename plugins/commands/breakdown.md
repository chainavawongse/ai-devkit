---
description: Break down refined and planned issues into implementation sub-issues with dependencies
---

# Breakdown - Implementation Task Creation Command

Transform refined specification and technical plan into executable sub-issues with dependencies.

## Usage

```bash
/breakdown <issue-id>       # Break down issue into sub-issues
```

## Overview

This command uses the `breakdown-planning` skill to:

1. Load issue and verify Specification + Technical Plan exist
2. Break Technical Plan phases into independent, implementable tasks
3. Each task is a complete feature/behavior (TDD: tests + implementation together)
4. Create sub-issues in configured PM system with full context
5. Map dependencies between tasks
6. Optionally chain to `/execute`

## Requirements

**The parent issue MUST have:**

- "Specification" section (from `/refine` - defines WHAT)
- "Technical Plan" section (from `/plan` - defines HOW)

**If missing:** Suggests running `/refine` and/or `/plan` first.

## How It Works

### Step 1: Verify Prerequisites

**Read PM configuration from CLAUDE.md** and load issue via `pm-operations`:

```bash
# Load issue using configured PM system
issue = pm_operations.get_issue(id)

# If no PM system configured:
if not pm_configured:
  ERROR: No PM system configured
  SUGGEST: Run `/setup` first

# Verify sections
if "## Specification" not in issue.description:
    ERROR: Run `/refine <issue-id>` first
    STOP
if "## Technical Plan" not in issue.description:
    ERROR: Run `/plan <issue-id>` first
    STOP
```

### Step 2: Run Breakdown-Planning Skill

```bash
Skill(devkit:breakdown-planning)
```

The skill handles:

- Analyzing Technical Plan phases
- Creating task structure (one task = one complete feature/behavior)
- Each task includes full TDD workflow (tests + implementation)
- Creating sub-issues with Specification context + Technical Plan guidance
- Mapping dependencies from Technical Plan

### Step 3: Offer Next Step

```markdown
✓ Breakdown complete: 18 sub-issues created

Ready to begin execution? Run `/execute <issue-id>`
```

**If user agrees, chain to `/execute`**

## Error Handling

### No PM System

```markdown
ERROR: No project management system configured

Run `/setup` to configure your PM system (Jira, Notion, or GitHub Issues).
```

### Missing Sections

```markdown
ERROR: Issue missing required sections

Run in order:
1. `/refine <issue-id>` - Create Specification (WHAT)
2. `/plan <issue-id>` - Create Technical Plan (HOW)
3. `/breakdown <issue-id>` - Create tasks

Missing: [Specification | Technical Plan | Both]
```

### Already Has Sub-Issues

```markdown
WARNING: Issue already has sub-issues

Options:
1. Skip (use existing)
2. Add more (append)
3. Replace (delete and recreate)
```

## Examples

### Example: Successful Breakdown

```bash
/breakdown AUTH-123
```

Output:

```
Loaded AUTH-123: "User authentication"
✓ Specification found
✓ Technical Plan found

Using breakdown-planning skill...

Created 18 sub-issues:
- 6 foundation tasks (data models, utilities)
- 8 service tasks (business logic)
- 4 API tasks (endpoints)

Ready to execute? Run `/execute AUTH-123`
```

### Example: Missing Plan

```bash
/breakdown FEAT-45
```

Output:

```
Loaded FEAT-45: "Notifications"
✓ Specification found
✗ Technical Plan missing

ERROR: Run `/plan FEAT-45` first to create technical plan
```

## Integration

**Requires:**

- PM system configured (via `/setup`)
- Issue with Specification + Technical Plan
- `breakdown-planning` skill

**Chains to:**

- `/execute` (optional)

## Remember

- Use `breakdown-planning` skill for all breakdown work
- Each sub-issue = complete feature with TDD (not split into test/implementation tasks)
- Sub-issues include both WHAT (spec) and HOW (technical plan) context
- Dependencies follow Technical Plan phases
- Offer `/execute` but don't force
