---
name: breakdown-planning
description: Create implementation sub-issues from Specification and Technical Plan, with each task being a complete feature/behavior implemented via TDD
when_to_use: when Specification and Technical Plan are complete and you need to break down work into executable sub-issues
version: 3.1.0
---

# Breakdown Planning

## Overview

Break down Specification + Technical Plan into executable sub-issues. Each task is a complete, independent feature/behavior implemented with TDD (tests + implementation together, never split).

**Core principle:** Use Technical Plan phases as structure. Each sub-issue = one complete feature with full TDD workflow (write tests, make pass, refactor).

**Critical:** NEVER create separate "write tests" and "implement" tasks. Each task includes BOTH.

**Announce at start:** "I'm using the breakdown-planning skill to create the implementation breakdown."

## Quick Reference

| Phase | Key Activities | Tool Usage | Output |
|-------|---------------|------------|--------|
| **1. Load Context** | Retrieve Specification + Technical Plan | PM System MCP | Full context loaded |
| **2. Extract Phases** | Parse Technical Plan phases | — | Phase structure identified |
| **3. Create Tasks** | Break phases into features | TodoWrite | Independent tasks with TDD |
| **4. Create Sub-Issues** | Write to PM system | PM System MCP | Sub-issues with full context |
| **5. Map Dependencies** | Link blocking relationships | PM System MCP | Dependency graph complete |

## The Process

Copy this checklist to track progress:

```
Breakdown Progress:
- [ ] Phase 1: Load Context (Specification + Technical Plan retrieved)
- [ ] Phase 2: Extract Phases (Technical Plan phases identified)
- [ ] Phase 3: Create Tasks (independent features with TDD defined)
- [ ] Phase 4: Create Sub-Issues (sub-issues created with full context)
- [ ] Phase 5: Map Dependencies (blocking relationships documented)
```

### Phase 1: Load Context

**First, check CLAUDE.md for PM system configuration:**
- Look for `## Project Management` section
- Identify system: `Jira` or `Notion`

**Retrieve parent issue:**

**For Jira:**
- `mcp__atlassian__get_issue(id=parent_id)` (primary)
- OR `mcp__jira__get_issue(issue_key=parent_id)` (fallback)

**For Notion:**
- `mcp__notion__notion-fetch(id=parent_id)`

- Extract: Title, Specification section, Technical Plan section

**Verify required sections:**

```python
if "## Specification" not in issue.description:
    ERROR: Missing Specification - run `/refine` first
    STOP

if "## Technical Plan" not in issue.description:
    ERROR: Missing Technical Plan - run `/plan` first
    STOP
```

**Extract context:**

- From Specification: User stories, expected behaviors, success criteria
- From Technical Plan: Components, phases, dependencies, patterns

### Phase 2: Extract Phases

**Parse Technical Plan structure:**

```python
# Technical Plan already defines logical phases
phases = parse_technical_plan_phases(issue.description)

# Example phases:
# Phase 1: Foundation (data models)
# Phase 2: Core Services (business logic)
# Phase 3: API Layer (endpoints)
# Phase 4: Integration (middleware)
# Phase 5: E2E Validation

# Each phase lists components with:
# - Responsibilities
# - Dependencies
# - Patterns to follow
# - Files to touch
```

**Identify components per phase:**

- Parse component descriptions from Technical Plan
- Note dependencies between components
- Identify which can be implemented in parallel

**No granularity heuristics needed:**
Technical Plan phases already provide the right structure

### Phase 3: Create Tasks

**CRITICAL RULE: One task = one complete feature with TDD**

Each component from Technical Plan becomes ONE task that includes:

1. Write tests first (RED phase)
2. Implement to make tests pass (GREEN phase)
3. Refactor for quality (REFACTOR phase)

**NEVER split tests and implementation into separate tasks.**

**NEVER do this (BAD):**

```
Task 1: Write tests for UserAuthService
Task 2: Implement UserAuthService
```

**ALWAYS do this (GOOD):**

```
Task 1: Implement UserAuthService (includes writing tests first via TDD)
```

**Good task examples:**

- Implement user authentication with JWT tokens
- Add email validation to registration form
- Create calculation engine for tax computation
- Build API endpoint for fetching user profiles

**Bad task examples:**

- "Write tests for user service" (testing separate from functionality)
- "Implement entire user management system" (too broad)
- "Fix stuff in authentication" (too vague)
- "Add test coverage" (testing as afterthought)

**For detailed rules, examples, and anti-patterns, see:** [resources/task-structure-guide.md](resources/task-structure-guide.md)

**Task description includes:**

- Specification context (WHAT): User stories and behaviors this enables
- Technical Plan guidance (HOW): Architecture, patterns, dependencies
- TDD Checklist: Write tests → implement → refactor (use base checklist format below)
- Acceptance criteria: Tests pass, follows patterns, code reviewed
- Justfile commands: Use `just test`, `just lint`, `just format`, `just build` (stack-agnostic)

**Base TDD Checklist Format (include in every feature/bug task):**

```markdown
## TDD Implementation Checklist

**RED Phase:**
- [ ] Write test for [behavior 1] - verify it fails
- [ ] Write test for [behavior 2] - verify it fails
- [ ] Write test for [edge case] - verify it fails

**GREEN Phase:**
- [ ] Implement minimal code to pass [behavior 1] test
- [ ] Implement minimal code to pass [behavior 2] test
- [ ] Implement minimal code to pass [edge case] test
- [ ] All tests passing

**REFACTOR Phase:**
- [ ] Check for code smells (see REFACTORING.md)
- [ ] Refactor while keeping tests green
- [ ] Final verification: all tests still passing
```

**Identify dependencies from Technical Plan:**

- **Blocks:** Other components that depend on this one
- **Blocked by:** Components this one depends on (from Technical Plan)
- **Parallel:** Components in same phase with no interdependencies

**Use TodoWrite to track sub-issue creation:**

```
Sub-Issue Creation Progress:
- [ ] Phase 1: User model (no dependencies)
- [ ] Phase 1: Session model (no dependencies)
- [ ] Phase 2: PasswordHasher (blocked by User model)
- [ ] Phase 2: TokenService (blocked by Session model)
...
```

### Phase 4: Create Sub-Tickets

**REQUIRED SUB-SKILL:** Use `devkit:creating-tickets` for all ticket creation

**For each task, create one sub-ticket in the PM system:**

**Critical:** Every sub-ticket MUST have exactly ONE label: `feature`, `chore`, or `bug`

**Determine ticket type:**

- New functionality or behavior change? → `feature` label
- Maintenance, refactoring, docs? → `chore` label
- Fixing broken behavior? → `bug` label

**Sub-ticket structure:**

Each sub-ticket should include three main sections:

**1. Relevant Context from Parent (WHAT and WHY)**

Extract and include the specific portions from parent Specification and Technical Plan that are relevant to this task:

- **From Specification**: User stories, expected behaviors, success criteria, edge cases that this component addresses
- **From Technical Plan**: Architecture decisions, technology choices, patterns, and design rationale that apply to this component

**Purpose**: Give the implementing agent the WHAT (requirements) and WHY (design decisions) without requiring them to parse the entire parent issue.

**2. Implementation Guide (HOW - Key Ideas)**

Provide specific implementation guidance. This section should be tailored to the task but may include:

**Key ideas to consider:**

- **Module (justfile location)**: Which justfile directory this task uses for verification
  - Example: `frontend/` (runs `cd frontend && just test`)
  - Example: `backend/api/` (runs `cd backend/api && just test`)
  - **Critical**: This determines parallel vs sequential execution
  - Tasks sharing the same justfile MUST run sequentially
  - Tasks with different justfiles CAN run in parallel
  - Reference module CLAUDE.md files from `/setup` for justfile locations
- **Behaviors to implement**: Specific, testable behaviors this component must exhibit
- **Test cases to cover**: Happy path, validation, error handling, edge cases, integration points
- **File locations**: Where to create/modify code, test files, reference patterns to follow
- **Data structures**: Relevant models, types, schemas, API contracts
- **Integration points**: Dependencies (what to import), consumers (what will use this)
- **Error handling**: How errors should be handled per Technical Plan
- **Performance considerations**: Any specific requirements or constraints
- **Security considerations**: Authentication, authorization, input validation
- **Code patterns**: Reference to similar implementations with file paths and line numbers

**Note**: Not every task needs all these elements. Include what's relevant for the specific component.

**Important**: The "Module (justfile location)" field is REQUIRED for all tasks as it determines execution scheduling during `/execute`.

**3. TDD Implementation Checklist**

For features and bugs, include the standard TDD checklist:

```markdown
## TDD Implementation Checklist

Follow test-driven-development skill (devkit:test-driven-development):

**RED Phase:**
- [ ] Write test for [specific behavior] - verify it fails
- [ ] Write test for [specific behavior] - verify it fails
- [ ] Write test for [error case] - verify it fails

**GREEN Phase:**
- [ ] Implement minimal code to pass tests
- [ ] All tests passing

**REFACTOR Phase:**
- [ ] Refactor while keeping tests green
- [ ] Final verification: all tests still passing
```

**For chores**, replace TDD checklist with verification checklist (build, lint, test, etc.)

**CRITICAL: Each sub-ticket is self-contained**

- Agent should NOT need to read parent issue to implement the task
- All relevant context extracted and included
- Implementation guidance specific to this component
- Clear acceptance criteria
- Tests and implementation in ONE task (TDD for features/bugs)
- Proper label (feature/chore/bug) determines execution workflow

**After each sub-issue created:**

- Record the issue ID
- Map dependencies using PM system's relationship features

**Dependency linking:**

**For Jira:**
- Use `mcp__atlassian__create_dependency(from, to, type="blocks")` (primary)
- OR `mcp__jira__create_link(inward_issue, outward_issue, link_type="Blocks")` (fallback)

**For Notion:**
- Update the "Blocks" relation property on the blocking issue:
  ```
  mcp__notion__notion-update-page({
    data: {
      page_id: blocking_issue_id,
      command: "update_properties",
      properties: { Blocks: [...existing_blocks, blocked_issue_id] }
    }
  })
  ```
- The "Blocked By" property is auto-populated via dual relation

### Phase 5: Document Patterns

**For each sub-issue, enrich with relevant patterns:**

Based on the task type, add pattern references:

```markdown
## Relevant Patterns

**For backend tasks:**
- TDD: Follow RED-GREEN-REFACTOR cycle
- Error handling: Use Result type pattern
- Validation: Input validation at API boundary

**For frontend tasks:**
- Component testing: Test user interactions
- State management: Use [StatePattern] from codebase
- Accessibility: WCAG 2.1 AA compliance

**For integration tasks:**
- Contract testing: Verify API contracts
- Data consistency: Transaction boundaries
- Retry logic: Exponential backoff pattern
```

**Update each sub-issue:**

**For Jira:**
- `mcp__atlassian__update_issue(id, description=updated_description)` (primary)
- OR `mcp__jira__update_issue(issue_key, description=updated_description)` (fallback)

**For Notion:**
- Append patterns to page content:
  ```
  mcp__notion__notion-update-page({
    data: {
      page_id: issue_id,
      command: "insert_content_after",
      selection_with_ellipsis: "...last content...",
      new_str: pattern_documentation
    }
  })
  ```

**After all sub-issues created, update parent issue with phase label:**

**For Jira:**
```python
# Add phase:broken-down label to parent
mcp__atlassian__update_issue(
    id=parent_id,
    labels=['refined', 'planned', 'phase:refined', 'phase:planned', 'phase:broken-down']
)
# OR fallback:
mcp__jira__update_issue(
    issue_key=parent_id,
    labels=['refined', 'planned', 'phase:refined', 'phase:planned', 'phase:broken-down']
)
```

**For Notion:**
```python
# Add 'broken-down' to Phase multi-select property
mcp__notion__notion-update-page({
    data: {
        page_id: parent_id,
        command: "update_properties",
        properties: {
            Phase: "refined, planned, broken-down"  # Multi-select accumulates
        }
    }
})
```

### Phase 6: Summary Report

**Present breakdown summary:**

```markdown
# Breakdown Complete

## Summary
- Created [N] sub-issues in [Team]
- Granularity: [Fine/Medium] ([reason])
- Parallel tracks: [N] (tasks with no dependencies)
- Critical path: [N] tasks

## Sub-Issues Created
1. [ISSUE-ID] [Title] - [Status] - Deps: [None/IDs]
2. [ISSUE-ID] [Title] - [Status] - Deps: [IDs]
...

## Dependency Graph
```

ISSUE-1 (tests)
  └─> ISSUE-2 (implementation)
       └─> ISSUE-4 (integration)

ISSUE-3 (parallel component)
  └─> ISSUE-5 (integration)

```

## Ready to Execute
[N] tasks are ready to start (no dependencies): [ISSUE-IDs]

Ready to begin execution?
```

**Offer handoff to `/execute`**

## Granularity Decision Framework

**For detailed examples of different project types, see:** [resources/granularity-examples.md](resources/granularity-examples.md)

**For common dependency patterns, see:** [resources/dependency-patterns.md](resources/dependency-patterns.md)

## Key Principles

| Principle | Application |
|-----------|-------------|
| **Lean fine-grained** | Default to smaller tasks unless clear reason for larger |
| **TDD structure** | Tasks follow test-first pattern |
| **Clear dependencies** | Every dependency explicitly mapped |
| **Parallel-friendly** | Maximize tasks that can start immediately |
| **Pattern documentation** | Each task references relevant patterns |
| **Testability** | Every task has clear acceptance criteria |

## Red Flags - STOP and Ask

- Parent issue has no design section → Run `/refine` first
- Cannot identify any components → Design too vague
- All tasks depend on single blocking task → Refactor breakdown
- Sub-issue has no clear acceptance criteria → Clarify requirements
- Granularity seems wrong → Ask user before proceeding

## Integration with Other Skills

**Requires completed:**

- `refining-issues` skill (via `/refine` command) - Must have validated Specification
- `technical-planning` skill (via `/plan` command) - Must have Technical Plan

**Uses during breakdown:**

- `creating-tickets` skill - REQUIRED for all sub-ticket creation (ensures proper labeling)

**Hands off to:**

- `executing-plans` skill (via `/execute` command) - Executes the breakdown with parallel task orchestration

**May reference during breakdown:**

- `test-driven-development` - Pattern for implementation tasks
- `systematic-debugging` - Pattern for bug fix tasks
- `using-git-worktrees` - If parallel development needed

## Remember

- Always analyze complexity before deciding granularity
- Lean towards fine-grained when uncertain
- Map all dependencies (blocks, blocked-by, related)
- Document relevant patterns in each sub-issue
- Create TodoWrite todos for tracking sub-issue creation
- Verify parent issue has design before starting
- Offer handoff to `/execute` when complete

## Additional Resources

- [Task Structure Guide](resources/task-structure-guide.md) - Detailed task breakdown rules and anti-patterns
- [Granularity Examples](resources/granularity-examples.md) - Decision examples for different project types
- [Dependency Patterns](resources/dependency-patterns.md) - Common dependency graph patterns
