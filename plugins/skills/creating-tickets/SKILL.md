---
name: creating-tickets
description: Standardized process for creating PM tickets with proper classification (feature/chore/bug) and required metadata
when_to_use: when creating sub-tickets during breakdown planning, or creating any ticket that will be executed through plugin workflows
version: 1.0.0
---

# Creating Tickets

Standardized process for creating project management tickets with proper classification and metadata.

**Core principle:** Every ticket must be classified as feature, chore, or bug. This classification determines which execution workflow is used.

## Ticket Type Classification

**CRITICAL: All tickets MUST have exactly ONE of these labels:**

### Feature

**Definition:** Any desired behavior change that adds or modifies functionality

**Examples:**

- New API endpoint
- New UI component
- Enhanced validation logic
- Modified business rule
- New integration

**Label:** `feature` or `Feature`

**Execution workflow:** Uses `executing-tasks` skill (TDD required)

### Chore

**Definition:** Maintenance work that doesn't change user-facing behavior

**Examples:**

- Documentation updates
- Scaffolding and project setup
- Refactoring (no behavior change)
- Test coverage improvements
- Dependency upgrades
- Code cleanup and organization
- Configuration changes

**Label:** `chore` or `Chore`

**Execution workflow:** Uses `executing-chores` skill (no TDD requirement, but full test suite must pass)

### Bug

**Definition:** Existing behavior is not working as expected or specified

**Examples:**

- Function returns wrong value
- Error handling missing
- Race condition causing failures
- Performance regression
- Incorrect validation logic

**Label:** `bug` or `Bug`

**Execution workflow:** Uses `executing-bug-fixes` skill (TDD required: reproduce with test first)

## Classification Decision Tree

```
Is this changing user-facing or system behavior?
├─ YES → Is it fixing broken behavior?
│         ├─ YES → BUG
│         └─ NO  → FEATURE
└─ NO  → CHORE
```

**Examples:**

- "Add login endpoint" → FEATURE (new behavior)
- "Fix login endpoint returning 500" → BUG (broken behavior)
- "Refactor login logic to service layer" → CHORE (no behavior change)
- "Document login endpoint" → CHORE (no behavior change)
- "Add tests for login endpoint" → CHORE (improving coverage, no behavior change)

## Required Fields

**All tickets must include:**

1. **Title** - Clear, concise description
2. **Description** - Detailed context (see templates below)
3. **Team** - Team ID or name
4. **Type** - Exactly ONE of: feature, chore, bug (execution workflow)
5. **Parent** - Parent ticket ID (for sub-tickets)
6. **State** - Usually "Todo" for new sub-tickets

**For Notion only (additional required field):**

7. **Level** - Scope hierarchy: Feature, User Story, or Task
   - Determined by classification heuristics (see pm-operations skill)
   - Follows strict hierarchy: Feature → User Story → Task

**Optional but recommended:**

- **Priority** - Only set if explicitly specified
- **Estimate** - Complexity points (if team uses)
- **Assignee** - Usually left unassigned for sub-tickets

## Ticket Description Templates

### Standard Jira Ticket Template (Parent Issues)

**Use this template when creating or updating parent Jira tickets** (before breakdown into sub-issues):

```markdown
### Summary
*[One-line description of the feature]*

### Context & Purpose
**What:** Brief description of what we're building
**Why:** Business value or problem this solves

### Requirements
- [ ] Requirement 1
- [ ] Requirement 2
- [ ] Requirement 3

### Acceptance Criteria
- [ ] User can...
- [ ] System displays...
- [ ] Error handling for...

### Non-Functional Requirements *(optional)*
- Performance:
- Security:
- Accessibility:

### Out of Scope *(optional)*
- Items explicitly not included in this ticket

### Technical Notes *(optional)*
- Implementation hints, API endpoints affected, relevant files

### Links
- Design:
- Related tickets:
```

**Template guidelines:**
- **Summary:** Keep concise (fits in Jira title)
- **Requirements vs Acceptance Criteria:** Requirements = *what* to build; Acceptance Criteria = *how we know it's done*
- **Optional sections:** Only include if they add value - don't pad with empty sections
- **Links:** Always link related tickets for traceability
- **Note:** This template is for initial tickets. After `/refine` and `/plan`, the ticket will have Specification and Technical Plan sections added.

---

### Feature Sub-Ticket Template

```markdown
## Objective
Implement [Component/Feature] with full TDD workflow (tests first, then implementation).

## Specification Context (WHAT we're building)
From parent ticket Specification section:
- User story: [relevant user story from spec]
- Expected behavior: [relevant behavior from spec]
- Success criteria: [relevant criteria from spec]

## Technical Plan Guidance (HOW to build it)
From parent ticket Technical Plan section:
- Component: [Component name and location]
- Responsibilities: [What this component does]
- Dependencies: [What it depends on]
- Pattern: [Reference to existing code to follow]
- Error handling: [How errors should be handled]

## TDD Implementation Checklist
Follow test-driven-development skill (devkit:test-driven-development):

**RED Phase:**
- [ ] Write test for [behavior 1] - verify it fails
- [ ] Write test for [behavior 2] - verify it fails
- [ ] Write test for [edge case] - verify it fails

**GREEN Phase:**
- [ ] Implement minimal code to pass tests
- [ ] All tests passing

**REFACTOR Phase:**
- [ ] Check for code smells
- [ ] Refactor while keeping tests green
- [ ] Final verification: all tests still passing

## Acceptance Criteria
- [ ] All tests written and passing
- [ ] Follows pattern from [reference file]
- [ ] Error handling implemented per Technical Plan
- [ ] Code reviewed and approved
- [ ] Committed with clear message

## Files to Touch
- Create/Modify: [file paths]
- Reference: [similar code to follow]
```

### Chore Ticket Template

```markdown
## Objective
[Description of maintenance task]

## Context
[Why this chore is needed]

## Approach
[How to accomplish this]

## Verification Checklist
- [ ] Changes implemented
- [ ] All existing tests still pass
- [ ] Lint/format checks pass
- [ ] Build succeeds
- [ ] No regressions introduced

## Acceptance Criteria
- [ ] Task completed as specified
- [ ] No behavioral changes
- [ ] All quality checks passing
- [ ] Committed with clear message

## Files to Touch
- Modify: [file paths]
```

### Bug Ticket Template

```markdown
## Bug Description
[What is broken and how it manifests]

## Expected Behavior
[What should happen]

## Actual Behavior
[What currently happens]

## Root Cause Investigation
[To be filled during execution - see systematic-debugging skill]

## Fix Checklist
Follow systematic-debugging and test-driven-development skills:

**Phase 1: Root Cause Investigation**
- [ ] Reproduce bug consistently
- [ ] Identify root cause
- [ ] Document findings

**Phase 2: Reproduce with Test**
- [ ] Write failing test that reproduces bug
- [ ] Verify test fails for correct reason

**Phase 3: Fix**
- [ ] Implement minimal fix
- [ ] Verify reproducing test now passes
- [ ] Run full test suite (no regressions)

**Phase 4: Review**
- [ ] Code review confirms fix
- [ ] Root cause documented

## Acceptance Criteria
- [ ] Root cause identified and documented
- [ ] Bug reproduced with failing test
- [ ] Fix implemented (minimal change)
- [ ] All tests passing
- [ ] No regressions introduced
- [ ] Code reviewed and approved
```

## Creating Tickets in PM System

**Check CLAUDE.md for configured PM system, then use appropriate MCP tools:**

### If Jira (Atlassian MCP):

```python
ticket = mcp__atlassian__create_issue({
    'title': '[Clear, concise title]',
    'description': '[Use appropriate template above]',
    'team': '[Team name or ID from CLAUDE.md]',
    'parentId': '[Parent ticket ID for sub-tickets]',
    'labels': ['feature' or 'chore' or 'bug'],  # REQUIRED
    'state': 'Todo',
    'priority': '[Only if explicitly specified]'
})
```

### If Jira (Alternative MCP):

```python
ticket = mcp__jira__create_issue({
    'summary': '[Clear, concise title]',
    'description': '[Use appropriate template above]',
    'project': '[Project key from CLAUDE.md]',
    'parent': '[Parent ticket key for sub-tasks]',
    'issuetype': '[Task/Story/Bug]',
    'labels': ['feature' or 'chore' or 'bug'],  # REQUIRED
})
```

### If Notion:

```python
# Get database ID from CLAUDE.md: ## Project Management > Data Source ID
database_id = "[data_source_id from CLAUDE.md]"

ticket = mcp__notion__notion-create-pages({
    'parent': { 'data_source_id': database_id },
    'pages': [{
        'properties': {
            'Name': '[Clear, concise title]',
            'Status': 'Todo',
            'Type': 'feature' or 'chore' or 'bug',  # REQUIRED - execution workflow
            'Level': 'Feature' or 'User Story' or 'Task',  # REQUIRED - scope hierarchy
            'Parent': '[Parent page ID for sub-tickets]',  # Relation property
            'Priority': '[Only if explicitly specified]'
        },
        'content': '[Use appropriate template above - markdown format]'
    }]
})

# For dependencies, update the Blocks relation:
if blocks_ids:
    mcp__notion__notion-update-page({
        'data': {
            'page_id': ticket.id,
            'command': 'update_properties',
            'properties': {
                'Blocks': blocks_ids  # Array of page IDs this ticket blocks
            }
        }
    })
```

### Property Mapping Reference

| Field | Jira | Notion |
|-------|------|--------|
| Title | `title` / `summary` | `Name` (title property) |
| Description | `description` | Page content (markdown) |
| Status | `state` / `status` | `Status` (select) |
| Type | `labels[]` | `Type` (select: feature/chore/bug) |
| Level | (uses issue types) | `Level` (select: Feature/User Story/Task) |
| Parent | `parentId` / `parent` | `Parent` (relation) |
| Dependencies | `blocks` relationship | `Blocks` (relation) |
| Priority | `priority` | `Priority` (select) |

## Validation Rules

**Before creating any ticket:**

1. **Classification check:**

   ```python
   if not any(label in ['feature', 'chore', 'bug'] for label in labels):
       ERROR: "Ticket must have feature, chore, or bug label"
       STOP
   ```

2. **Single classification:**

   ```python
   type_labels = [l for l in labels if l in ['feature', 'chore', 'bug']]
   if len(type_labels) > 1:
       ERROR: "Ticket can only have ONE type label"
       STOP
   ```

3. **Template usage:**

   ```python
   if label == 'feature' and 'TDD Implementation Checklist' not in description:
       WARNING: "Feature ticket should include TDD checklist"

   if label == 'bug' and 'Root Cause Investigation' not in description:
       WARNING: "Bug ticket should include investigation checklist"
   ```

4. **Level validation (Notion only):**

   ```python
   # For Notion, Level is required
   if pm_system == 'notion':
       if level not in ['Feature', 'User Story', 'Task']:
           ERROR: "Notion ticket must have Level: Feature, User Story, or Task"
           STOP

       # Validate hierarchy when creating sub-tickets
       if parent_id:
           parent = get_issue(parent_id)
           if parent.level == 'Feature' and level != 'User Story':
               ERROR: "Children of Feature must be User Story level"
               STOP
           if parent.level == 'User Story' and level != 'Task':
               ERROR: "Children of User Story must be Task level"
               STOP
           if parent.level == 'Task':
               ERROR: "Task level items cannot have children"
               STOP
   ```

## Quick Reference

| Type | Label | TDD Required | Workflow Skill | Example |
|------|-------|--------------|----------------|---------|
| **Feature** | `feature` | ✅ Yes | `executing-tasks` | Add login endpoint |
| **Chore** | `chore` | ❌ No | `executing-chores` | Update docs, refactor |
| **Bug** | `bug` | ✅ Yes | `executing-bug-fixes` | Fix login 500 error |

## Integration with Other Skills

**Used by:**

- `breakdown-planning` - REQUIRED: Creates all sub-tickets using this skill
- `addressing-pr-feedback` - Creates tasks from PR feedback
- Any skill that creates tickets

**Ensures:**

- Consistent ticket structure across all workflows
- Proper classification for routing to correct execution skill
- Required metadata for parallel execution orchestration

## Remember

- **Every ticket needs exactly ONE Type** (feature/chore/bug) - determines execution workflow
- **For Notion: Every ticket needs Level** (Feature/User Story/Task) - determines scope hierarchy
- **Type and Level are independent** - a bug can be at any Level; a Task can be any Type
- **Use appropriate template** for the ticket type
- **Validate before creating** (Type, Level, parent, team)
- **For sub-tickets:** Always include parent ticket ID
- **For Notion sub-tickets:** Enforce strict Level hierarchy (Feature→User Story→Task)
- **For features/bugs:** Always include TDD/investigation checklists
