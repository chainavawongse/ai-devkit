---
description: Refine feature ideas into specifications focusing on WHAT to build not HOW
---

# Refine - Issue Refinement Command

Transform rough ideas into validated specifications (WHAT to build), ready for technical planning.

## Usage

```bash
/refine <issue-id>          # Refine existing issue (Jira/Notion/GitHub)
/refine <free text>         # Create new issue and refine it
```

## Overview

This command uses the `refining-issues` skill to:

1. Load or create issue in configured PM system
2. **Assess if requirements are already sufficient** (may short-circuit to `/plan` or `/breakdown`)
3. Ask questions about user needs (WHAT, not HOW)
4. Explore expected behaviors and edge cases
5. Present specification for validation
6. Write specification to issue
7. Offer to chain to `/plan`

**Focus:** Requirements, behaviors, success criteria (NOT technology or architecture)

**Short-circuit:** If the ticket already has clear requirements, offers to skip directly to `/plan` or `/breakdown`

## How It Works

### Step 1: Load or Create Issue

**Read PM configuration from CLAUDE.md** to determine which system to use (Jira, Notion, or GitHub Issues).

**Existing issue:**

Use PM operations from `pm-operations` skill:

- Jira: `mcp__atlassian__get_issue(id)` or `mcp__jira__get_issue(issue_key)`
- Notion: `mcp__notion__notion-fetch(id)`
- GitHub: `gh issue view <number>`

**New issue from text:**

Create via configured PM system using `pm-operations` abstraction.

### Step 2: Run Refining-Issues Skill

```bash
Skill(devkit:refining-issues)
```

The skill handles:

- Understanding user needs
- Exploring behaviors and edge cases
- Presenting specification
- Writing to issue with "Specification" section

### Step 3: Offer Next Step

```markdown
✓ Specification written to issue <ISSUE-ID>

Ready to create technical plan? Run `/plan <ISSUE-ID>`
```

**If user agrees, chain to `/plan`**

## Error Handling

### No PM System

```markdown
ERROR: No project management system configured

Run `/setup` to configure your PM system (Jira, Notion, or GitHub Issues).

See INSTALLATION.md for MCP server setup instructions.
```

### Issue Not Found

```markdown
ERROR: Issue <ISSUE-ID> not found

Check issue ID format:
- Jira: TEAM-123
- Notion: Page URL or UUID
- GitHub: Issue number (e.g., 42)

Or create new: `/refine "your feature description"`
```

## Integration

**Requires:**

- PM system configured (via `/setup`)
- `refining-issues` skill

**Chains to:**

- `/plan` (optional)

## Remember

- Use `refining-issues` skill for all refinement work
- Focus on WHAT not HOW
- Specification drives tests later
- Chain to `/plan` (not `/breakdown`)
- All in PM system (no separate files)
