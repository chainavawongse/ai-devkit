---
description: Create technical implementation plan from refined specification - translates WHAT to HOW
---

# Plan - Technical Implementation Planning Command

Create technical plan from specification, defining HOW to build what's been specified.

## Usage

```bash
/plan <issue-id>          # Create technical plan for refined issue
```

## Overview

This command uses the `technical-planning` skill to:

1. Load issue and verify Specification exists
2. Create Technical Plan (architecture, patterns, phases)
3. Append Technical Plan to issue
4. Offer to chain to `/breakdown`

## How It Works

### Step 1: Verify Prerequisites

**Read PM configuration from CLAUDE.md** and load issue via `pm-operations`:

```bash
# Load issue using configured PM system
issue = pm_operations.get_issue(id)

# Verify Specification exists
if "## Specification" not in issue.description:
    ERROR: Run `/refine <issue-id>` first
    STOP

# Check if plan already exists
if "## Technical Plan" in issue.description:
    WARNING: Technical Plan already exists
    ASK: Replace or cancel?
```

### Step 2: Run Technical-Planning Skill

```bash
Skill(devkit:technical-planning)
```

The skill handles:

- Analyzing codebase for patterns
- Researching technology options
- Designing architecture
- Defining data models and APIs
- Planning testing strategy
- Phasing implementation
- Documenting patterns
- Writing Technical Plan to issue

### Step 3: Offer Next Step

```markdown
✓ Technical Plan written to issue <ISSUE-ID>

Ready to break this down into implementation tasks? Run `/breakdown <ISSUE-ID>`
```

**If user agrees, chain to `/breakdown`**

## Error Handling

### No PM System

```markdown
ERROR: No project management system configured

Run `/setup` to configure your PM system (Jira, Notion, or GitHub Issues).
```

### Missing Specification

```markdown
ERROR: Issue missing Specification section

Run `/refine <issue-id>` first to create specification (WHAT to build).
Then run `/plan <issue-id>` to create technical plan (HOW to build it).
```

### Plan Already Exists

```markdown
WARNING: Issue already has Technical Plan

Options:
1. Replace (destructive)
2. Update/extend (preserves content)
3. Cancel (keep existing)
```

## Examples

### Example: Create Plan

```bash
/plan AUTH-123
```

Output:

```
Loaded AUTH-123: "User authentication"
✓ Specification found

Using technical-planning skill...

✓ Technical Plan written
  - 4 components defined
  - 3 API endpoints specified
  - 5 implementation phases

Ready to break down into tasks?
```

### Example: Missing Spec

```bash
/plan FEAT-45
```

Output:

```
Loaded FEAT-45: "Notifications"
✗ Specification missing

ERROR: Run `/refine FEAT-45` first
```

## Integration

**Requires:**

- PM system configured (via `/setup`)
- Issue with Specification section
- `technical-planning` skill

**Chains to:**

- `/breakdown` (optional)

## Remember

- Use `technical-planning` skill for all planning work
- Requires Specification (from `/refine`)
- Creates Technical Plan (HOW)
- All in PM system (no separate files)
- Offer `/breakdown` but don't force
