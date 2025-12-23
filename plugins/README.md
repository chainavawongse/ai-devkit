# plugin - AI Development Lifecycle

**Version:** 1.0.0
**Plugin Type:** Claude Code Plugin for Development Workflow Automation

The AI DevKit plugin provides a complete workflow for taking ideas from concept to production-ready code, deeply integrated with JIRA project management.

## Overview

plugin transforms the software development lifecycle into a powerful command pipeline:

1. **`/refine`** - Refine rough ideas into validated Specifications (WHAT to build)
2. **`/plan`** - Create Technical Plans from Specifications (HOW to build)
3. **`/breakdown`** - Break plans into sub-tickets with dependencies and proper labels
4. **`/execute`** - **Sequential execution** of sub-tickets in isolated worktree with code review

Each command can run standalone or chain automatically to the next, creating a seamless workflow from idea to pull request with dependency-aware execution.

## Core Philosophy

**Spec-Driven Development:** Work flows from Specification (WHAT) → Technical Plan (HOW) → Implementation. Every technical decision traces back to user requirements.

**Test-Driven Development:** Features and bugs require test-first. Chores verify with full test suite. No implementation without tests.

**Just Command Abstraction:** All workflow steps use `just` commands (`just install`, `just test`, `just lint`, `just build`). The repository defines *what* these do; the workflow stays consistent. This makes plugin stack-agnostic - works with any language, framework, or tooling.

**Sequential Execution:** Sub-tickets execute one at a time in isolated git worktree. Dependencies are respected, ensuring proper execution order.

**Code Review at Every Level:** Per-task review (built into execution skills) + final branch review before merge. Catch issues early.

**Proper Classification:** Every ticket labeled as feature/chore/bug. Label determines execution workflow (TDD vs verification-only).

**Deep Integration:** JIRA tickets are the source of truth. All work tracked, context preserved, decisions documented in PM system.

## Complete Workflow Diagram

```
                              plugin Sequential Execution Workflow

  ┌──────────────────────────────────────────────────────────────────────────┐
  │                          SPECIFICATION PHASE                              │
  └──────────────────────────────────────────────────────────────────────────┘
                                       │
                    User idea or existing JIRA ticket
                                       │
                                       ▼
                              ┌─────────────────┐
                              │ /refine    │  Socratic questioning
                              │                 │  Focus on WHAT to build
                              └────────┬────────┘  Technology-agnostic
                                       │
                                       ▼
                         ┌──────────────────────────┐
                         │ Specification in ticket  │  User stories, behaviors
                         │ (WHAT to build)          │  Success criteria, edge cases
                         └────────────┬─────────────┘
                                      │
  ┌──────────────────────────────────────────────────────────────────────────┐
  │                       TECHNICAL PLANNING PHASE                            │
  └──────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                              ┌─────────────────┐
                              │  /plan     │  Analyze codebase
                              │                 │  Research options
                              └────────┬────────┘  Design architecture
                                       │
                                       ▼
                         ┌──────────────────────────┐
                         │ Technical Plan in ticket │  Components, patterns
                         │ (HOW to build)           │  Tech stack, phases
                         └────────────┬─────────────┘
                                      │
  ┌──────────────────────────────────────────────────────────────────────────┐
  │                          BREAKDOWN PHASE                                  │
  └──────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                              ┌─────────────────┐
                              │ /breakdown │  Extract phases
                              │                 │  Create sub-tickets
                              └────────┬────────┘  Label: feature/chore/bug
                                       │
                                       ▼
                    ┌─────────────────────────────────────┐
                    │  Sub-tickets with dependencies      │
                    │                                      │
                    │  CORE-46 (feature) ─┐               │
                    │  CORE-47 (feature)  │               │
                    │       ├─────────────┴─→ CORE-48 ─┐  │
                    │       │                           │  │
                    │       └─────────────→ CORE-49 ───┴─→ CORE-50 → CORE-51 │
                    │                                                    ↓     │
                    │                                              CORE-52    │
                    └────────────────────┬────────────────────────────────────┘
                                         │
  ┌──────────────────────────────────────────────────────────────────────────┐
  │                      SEQUENTIAL EXECUTION PHASE                           │
  └──────────────────────────────────────────────────────────────────────────┘
                                         │
                                         ▼
                              ┌─────────────────────┐
                              │  /execute      │  Create worktree
                              │                     │  ~/worktrees/<repo>/<ticket>
                              └──────────┬──────────┘
                                         │
                    ┌────────────────────┴────────────────────┐
                    │  Analyze dependencies & execute tasks   │
                    └──────────────────┬──────────────────────┘
                                       │
                        Sequential execution respecting dependencies
                                       │
                                       ▼
                              ┌─────────────────┐
                              │   Task 1: CORE-46│  (no dependencies)
                              └────────┬────────┘
                                       ▼
                              ┌─────────────────┐
                              │   Task 2: CORE-47│  (no dependencies)
                              └────────┬────────┘
                                       ▼
                              ┌─────────────────┐
                              │   Task 3: CORE-48│  (depends on 46,47)
                              └────────┬────────┘
                                       ▼
                              ┌─────────────────┐
                              │   Task 4: CORE-49│  (depends on 46,47)
                              └────────┬────────┘
                                       ▼
                              ┌─────────────────┐
                              │   Task 5: CORE-50│  (depends on 48,49)
                              └────────┬────────┘
                                       ▼
                              ┌─────────────────┐
                              │   Task 6: CORE-51│  (depends on 50)
                              └────────┬────────┘
                                       ▼
                              ┌─────────────────┐
                              │   Task 7: CORE-52│  (depends on 50)
                              └────────┬────────┘
                                       │
                       Each task executes with these steps:
                         • Load context from ticket
                         • Route to skill by label
                         • TDD (feature/bug) or verify (chore)
                         • Per-task code review
                         • Commit + update ticket
                         • Report completion
                                       │
                                       ▼
                        ┌──────────────────────────────┐
                        │  Final Branch Code Review    │
                        │  • All requirements met?     │
                        │  • Architecture consistent?  │
                        │  • No conflicts?             │
                        │  • Quality acceptable?       │
                        └──────────────┬───────────────┘
                                       │
                                       ▼
                        ┌──────────────────────────────┐
                        │   Merge/PR Options          │
                        │   1. Merge to main          │
                        │   2. Create PR              │
                        │   3. Keep as-is             │
                        │   4. Discard                │
                        └──────────────┬───────────────┘
                                       │
                                       ▼
                              ✅ Complete!
                           Worktree cleaned up
```

**Key Features:**

- **Sequential execution:** Tasks execute one at a time in dependency order
- **Dependency-aware orchestration:** Process ready tasks, check for newly unblocked, repeat
- **Proper task ordering:** Respect blocking relationships, maintain execution order
- **Isolated environment:** All work in `~/worktrees/<repo>/<ticket>/`
- **Dual code review:** Per-task reviews (in execution skills) + final branch review
- **Error handling:** Retry (3x) → skip → continue with independent tickets
- **Proper routing:** Ticket labels (feature/chore/bug) determine execution workflow

## Commands

### `/refine <issue-id | description>`

Transform rough feature descriptions into validated Specifications through Socratic questioning.

**Accepts:**

- Existing JIRA issue ID: `/refine TEAM-123`
- Free text description: `/refine "Add user authentication with email and password"`

**Process:**

1. Loads or creates issue in JIRA
2. Asks clarifying questions about WHAT to build (user needs, behaviors, success criteria)
3. Presents Specification incrementally for validation
4. Writes validated Specification to issue
5. Offers to proceed to `/plan`

**Output:** Issue with complete Specification section (WHAT), ready for technical planning.

**Focus:** WHAT to build, not HOW. Technology-agnostic requirements.

**Example:**

```bash
/refine CORE-45

# Interactive dialogue:
# - "How long should sessions remain active?" (behavioral question)
# - "What should happen when X fails?" (error scenario)
# - Specification presentation in sections
# - Validation checkpoints

✓ Specification written to issue CORE-45
Ready to create technical plan?
```

---

### `/plan <issue-id>`

Create comprehensive Technical Plan translating Specification (WHAT) into implementation guidance (HOW).

**Requires:** Parent ticket with Specification section (from `/refine`)

**Process:**

1. Loads Specification from parent ticket
2. Analyzes codebase for existing patterns
3. Researches technology options (with rationale)
4. Designs architecture and components
5. Defines data models and API contracts
6. Plans testing strategy per level
7. Phases implementation with dependencies
8. Writes Technical Plan to parent ticket
9. Offers to proceed to `/breakdown`

**Output:** Ticket with Specification + Technical Plan, ready for breakdown.

**Focus:** HOW to build - architecture, tech stack, patterns, phases.

**Example:**

```bash
/plan CORE-45

# Codebase analysis
Found existing patterns: Service layer, Repository pattern, JWT auth

# Technology decisions
- Authentication: JWT tokens (rationale: stateless, existing pattern)
- Storage: Redis for session blacklist (rationale: fast, existing infra)

# Architecture
Components: UserAuthService, AuthController, User model, Session model

# Technical Plan written to CORE-45
Ready to break this down into sub-tickets?
```

---

### `/breakdown <issue-id>`

Break down Specification + Technical Plan into sub-tickets with proper labels and dependencies.

**Requires:** Parent ticket with Specification + Technical Plan (from `/plan`)

**Process:**

1. Loads Specification + Technical Plan from parent ticket
2. Extracts phases from Technical Plan
3. Creates one sub-ticket per component (tests + implementation together)
4. **Labels each ticket:** feature, chore, or bug (REQUIRED for routing)
5. Maps dependencies between tickets
6. Uses `creating-tickets` skill for consistent structure
7. Offers to proceed to `/execute`

**Output:** Sub-tickets with proper labels and dependencies, ready for sequential execution.

**Ticket Classification:**

- **feature:** New functionality or behavior change → TDD required
- **chore:** Maintenance, refactoring, docs → Verification required
- **bug:** Fixing broken behavior → Systematic debugging + TDD required

**Example:**

```bash
/breakdown CORE-45

# From Technical Plan Phases
Phase 1: Foundation (2 components)
Phase 2: Core Services (3 components)
Phase 3: API Layer (2 components)

Created 7 sub-tickets:
- CORE-46 (feature): User model - ready
- CORE-47 (feature): Session model - ready
- CORE-48 (feature): PasswordHasher - blocked by CORE-46
- CORE-49 (feature): TokenService - blocked by CORE-47
- CORE-50 (feature): UserAuthService - blocked by CORE-48, CORE-49
- CORE-51 (feature): AuthController - blocked by CORE-50
- CORE-52 (chore): API documentation - blocked by CORE-51

Dependency graph created. Ready to execute sequentially?
```

---

### `/execute <ticket-id>`

**PRIMARY ENTRY POINT:** Sequential orchestration of sub-tickets in isolated git worktree.

**Requires:** Parent ticket with Specification + Technical Plan + labeled sub-tickets (from `/breakdown`)

**Process:**

1. **Verify:** Checks parent ticket has all required sections and sub-tickets
2. **Isolate:** Creates git worktree at `~/worktrees/<repo>/<ticket>/` (asks user first time)
3. **Analyze:** Loads sub-tickets and builds dependency graph
4. **Dispatch:** Sequential Task() calls for ready tickets (one task at a time)
5. **Route:** Each ticket routed by label:
   - `feature` → `executing-tasks` (TDD required)
   - `chore` → `executing-chores` (verification required)
   - `bug` → `executing-bug-fixes` (systematic debugging + TDD)
6. **Monitor:** Tracks completion, handles errors, dispatches newly unblocked tickets
7. **Review:** Final full-branch code review after all tickets complete
8. **Complete:** Present merge/PR options, cleanup worktree

**Output:** Complete implementation with sequential execution, all tickets done, PR ready.

**Error Handling:** Retry up to 3x → skip failed ticket → continue with independent tickets

**Example:**

```bash
/execute CORE-45

✓ Parent ticket verified (Specification + Technical Plan present)
✓ Found 7 sub-tickets, all properly labeled

Creating isolated worktree at ~/worktrees/myproject/CORE-45...
✓ Worktree ready, baseline tests passing

Dependency analysis:
- Ready to start: CORE-46, CORE-47 (no dependencies)
- Blocked: 5 tickets waiting on dependencies

Executing Task 1: CORE-46...
✅ CORE-46 complete (User model, 5 tests passing, reviewed)

Executing Task 2: CORE-47...
✅ CORE-47 complete (Session model, 4 tests passing, reviewed)

Executing Task 3: CORE-48 (now unblocked)...
✅ CORE-48 complete (PasswordHasher, 6 tests passing, reviewed)

Executing Task 4: CORE-49 (now unblocked)...
✅ CORE-49 complete (TokenService, 8 tests passing, reviewed)

Executing Task 5: CORE-50 (now unblocked)...
✅ CORE-50 complete (UserAuthService, 12 tests passing, reviewed)
✅ CORE-51 complete (AuthController, 7 tests passing, reviewed)
✅ CORE-52 complete (API docs updated, reviewed)

All 7 tickets complete!

Running final branch review...
✅ Final review: All requirements met, architecture consistent, ready to merge

Options:
1. Merge to main locally
2. Push and create PR
3. Keep branch as-is
4. Discard work

> 2

✓ PR created: https://github.com/org/repo/pull/123
✓ Worktree cleaned up

🎉 Implementation complete!
```

---

### `/chore <description | issue-id>`

Handle maintenance tasks and chores with comprehensive quality verification, without requiring TDD.

**Accepts:**

- Description: `/chore "Upgrade React from v17 to v18"`
- JIRA issue ID: `/chore MAINT-42`

**Process:**

1. Loads chore details from description or issue
2. Implements the maintenance task directly (no TDD)
3. Runs comprehensive verification (all tests, lint, format, build)
4. Fixes any issues found
5. Commits with proper message
6. Optionally creates PR

**Output:** Completed maintenance task with all quality checks passing.

**Use cases:**

- Dependency upgrades
- Refactoring existing code
- Code cleanup and organization
- Removing deprecated code
- Configuration changes

**Key differences from `/execute`:**

- No TDD requirement (maintenance tasks don't benefit from test-first)
- No sub-issues (single task focus)
- Still ensures all existing tests pass and build succeeds
- Direct implementation with verification gates

**Example:**

```bash
/chore "Upgrade all npm dependencies to latest versions"

Implementing upgrade...
✓ Updated 23 dependencies

Running verification...
✓ Tests: 124/124 passing
✓ Lint: No errors
✓ Format: Passed
✓ Build: Succeeded

All quality checks passed!

Committed: abc123 "chore(deps): upgrade npm dependencies"

Chore complete! Would you like me to create a pull request?
### `/bug-fix <issue-id | description>`

Systematically investigate, fix, and validate bugs using TDD and root cause analysis.

**Accepts:**
- Existing bug issue ID: `/bug-fix TEAM-123`
- Bug description: `/bug-fix "Login fails with valid credentials"`

**Process:**
1. Loads or creates bug issue in JIRA
2. Investigates root cause systematically
3. Writes failing test that reproduces bug
4. Implements fix following TDD
5. Verifies fix with automatic checks
6. Runs code review
7. Updates issue status and documents fix

**Output:** Bug fixed, tests passing, issue documented.

**Example:**
```bash
/bug-fix TEAM-456

# Investigation
Root cause: JWT secret not loaded from environment

# Reproduction
✓ Test reproduces bug (fails with 401 error)

# Fix
✓ Load JWT secret from environment
✓ Test now passes

# Verification
✓ All tests passing (57 tests)
✓ Manual testing confirms fix
✓ Code review approved

🎉 Bug fix complete!
Ready to push and create PR?
```

## Skills

Commands leverage these skills for detailed guidance:

### Core Skills

- **`refining-issues`** - Socratic refinement process for issue design
- **`breakdown-planning`** - Complexity analysis and sub-issue creation
- **`executing-plans`** - Execution pattern with review gates
- **`executing-chores`** - Maintenance task execution with quality verification
- **`executing-bug-fixes`** - Systematic bug investigation and TDD-based fixing

### Supporting Skills

- **`test-driven-development`** - RED-GREEN-REFACTOR cycle enforcement
- **`requesting-code-review`** - Code review process and feedback
- **`systematic-debugging`** - Debugging methodology when issues arise
- **`using-git-worktrees`** - Isolated workspace setup
- **`writing-justfiles`** - Automatic check configuration

## Workflow Examples

### Full Workflow: Idea to PR

```bash
# 1. Refine the idea
/refine "Add real-time notifications when users receive messages"
# ... Socratic dialogue ...
# ✓ Created issue NOTIF-45 with validated design

# 2. Break down into tasks
/breakdown NOTIF-45
# ✓ Created 12 sub-issues with dependencies

# 3. Execute implementation
/execute NOTIF-45
# ✓ All 12 tasks implemented
# ✓ PR created and ready for review
```

### Refine Existing Issue

```bash
# Issue CORE-78 exists but is vague
/refine CORE-78

# ... refinement process ...
# ✓ Design added to CORE-78

/breakdown CORE-78
# ✓ 8 sub-issues created

/execute CORE-78
# ✓ Implementation complete
```

### Manual Control

```bash
# Refine without proceeding
/refine FEAT-23
# ✓ Design complete
> "Let me review the design first"

# Later, after review...
/breakdown FEAT-23
# ✓ Sub-issues created
> "I'll implement this myself"

# Or use /execute for specific sub-issues manually
```

### Maintenance Tasks (Chores)

```bash
# Upgrade dependencies
/chore "Upgrade all npm dependencies to latest versions"
# ✓ Dependencies upgraded
# ✓ All tests passing
# ✓ Build successful
# ✓ PR created

# Refactoring from JIRA issue
/chore MAINT-56
# JIRA issue: "Extract validation logic into utility functions"
# ✓ Refactoring complete
# ✓ All tests passing
# ✓ Committed and PR created
### Bug Fix Workflow

```bash
# Fix a reported bug
/bug-fix BUG-89

# Investigation
# Root cause: Missing null check in payment processing

# Reproduction
# ✓ Test reproduces bug

# Fix
# ✓ Added null check
# ✓ Test passes

# Verification
# ✓ All tests passing
# ✓ Code review approved

# ✓ Bug fix complete
# ✓ PR created
```

## Integration Requirements

### Required MCP Integration

**IMPORTANT:** The plugin does NOT install MCP servers. You must install and configure them separately in your Claude Code settings.

**JIRA (via Atlassian Rovo MCP Server):**

Atlassian provides an official, centrally-hosted MCP server. Install via Claude Code CLI:

```bash
# Add Atlassian MCP server
claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse
```

**Authentication:**

1. Start a new chat in Claude and open the "Search & Tools" menu
2. Select "Connect Atlassian Account"
3. Follow the OAuth prompts to log in to your Atlassian account
4. Grant access to your JIRA site during the OAuth flow
5. Enable JIRA tools in Claude

**Note:** No Node.js or proxy configuration required—Claude communicates directly with the Atlassian-hosted server.

- Tools needed: `mcp__atlassian__*`
- Verify: Run `/setup` to check if MCP server is available

For detailed setup instructions, see: [Atlassian MCP Server Setup](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/setting-up-claude-ai/)

### Optional But Recommended

**Justfile:**

- Create `justfile` in repository root
- Required recipes: `test`, `lint`, `format`
- Used for automatic checks during `/execute`

**Git Worktrees:**

- Recommended for isolated execution
- Prevents conflicts with current work
- Setup: `git worktree add ../feature-branch`

## Configuration

### Optional CLAUDE.md Metadata

Add project management context to your CLAUDE.md:

```markdown
## Project Management

- System: JIRA
- Default Team: CORE
- Default Project: core-platform
- Epic: Onboarding Improvements (CORE-100)
```

This helps commands determine where to create issues automatically.

### Hooks Integration

plugin can integrate with Claude Code hooks for automatic enforcement:

**`tool-use-post.sh` example:**

```bash
#!/bin/bash
# After any tool use, run checks if implementation happened

if [[ "$TOOL_NAME" == "Write" ]] || [[ "$TOOL_NAME" == "Edit" ]]; then
    # Run tests
    just test || exit 1

    # Run linter
    just lint || exit 1
fi
```

## Advanced Features

### Sequential Execution

`/execute` runs tasks one at a time, respecting dependencies:

```bash
/execute FEAT-67

# Detected 6 tasks with dependencies
# Will execute sequentially. Proceed?
> yes

# Executes tasks one-by-one in dependency order
# Each task completes before next begins
```

### Granularity Control

`/breakdown` analyzes complexity and chooses granularity:

- **Fine-grained:** Many small tasks (high component count, unfamiliar stack)
- **Medium-grained:** Balanced tasks (moderate complexity, familiar stack)
- **Coarse-grained:** Few large tasks (low complexity, very familiar)

Default: Lean towards fine-grained for better tracking and testability.

### Dependency Management

`/breakdown` automatically:

- Maps all blocking relationships
- Identifies task execution order
- Calculates critical path
- Documents dependencies in JIRA

`/execute` respects these dependencies:

- Only runs tasks with no blockers
- Checks for newly unblocked tasks after each completion
- Prevents circular dependencies

### Commit Management

`/execute` creates clean history:

**During execution:**

- Commits after each task with issue reference
- Commits fixes separately
- Commits code review feedback

**After execution:**

- Interactive rebase to squash related commits
- Result: 1 clean commit per sub-issue
- Maintains traceability to original commits

## Best Practices

### 1. Always Refine First

Don't break down vague issues. Refinement ensures:

- Requirements are clear
- Approach is validated
- Success criteria are defined

### 2. Trust the Complexity Analysis

The breakdown skill analyzes multiple factors. If it suggests fine-grained, there's a reason (high complexity, many integrations, unfamiliar stack).

### 3. Review Before Executing

After `/breakdown`, review the sub-issues in JIRA:

- Check dependencies make sense
- Verify task descriptions are clear
- Adjust granularity if needed

Then proceed with `/execute`.

### 4. Use Git Worktrees

For large implementations:

```bash
git worktree add ../feature-branch main
cd ../feature-branch
/execute FEAT-45
```

Keeps execution isolated from your current work.

### 5. Address Review Feedback

Code review happens after every task. Critical and Important issues MUST be fixed before proceeding. Don't skip this step.

### 6. Keep JIRA Updated

Status updates provide visibility to your team. `/execute` handles this automatically, but if you implement manually, update JIRA regularly.

## Troubleshooting

### "No project management MCP configured"

**IMPORTANT:** MCP servers must be installed separately by the user.

Install and configure JIRA MCP server (Atlassian Rovo):

```bash
# Add Atlassian MCP server via CLI
claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse

# Authenticate: Start a new chat and open "Search & Tools" menu
# Select "Connect Atlassian Account" and follow OAuth prompts
```

For detailed setup instructions, see: [Atlassian MCP Server Setup](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/setting-up-claude-ai/)

Verify tools are available with `/setup`

The plugin does NOT install MCP servers automatically.

### "Issue missing design section"

The issue needs refinement first:

```bash
/refine <issue-id>
```

### "No sub-issues found"

The issue needs breakdown first:

```bash
/breakdown <issue-id>
```

### "Circular dependency detected"

Review sub-issue dependencies in JIRA. One task is blocking another that blocks it back. Fix the dependency chain and re-run `/execute`.

### "Working directory has uncommitted changes"

Commit your current work or use a git worktree:

```bash
git worktree add ../feature-branch main
cd ../feature-branch
/execute <issue-id>
```

## Architecture

### Command Structure

```
commands/
├── refine.md       - Issue refinement orchestration
├── breakdown.md    - Sub-issue creation orchestration
├── execute.md      - Implementation execution orchestration
├── bug-fix.md      - Bug investigation and fixing orchestration
└── setup.md - Repository setup (existing)
```

### Skill Structure

```
skills/
├── refining-issues/        - Socratic refinement process
│   └── SKILL.md
├── breakdown-planning/     - Complexity analysis + sub-issue creation
│   └── SKILL.md
├── executing-plans/        - Execution with review gates
│   └── SKILL.md
└── executing-bug-fixes/    - Systematic bug investigation and TDD fixing
    └── SKILL.md
```

### Workflow Flow

```
User Input
    ↓
/refine
    ├─> refining-issues skill
    ├─> Creates/updates JIRA issue
    └─> Offers /breakdown
        ↓
/breakdown
    ├─> breakdown-planning skill
    ├─> Creates sub-issues in JIRA
    └─> Offers /execute
        ↓
/execute
    ├─> executing-plans pattern
    ├─> For each sub-issue:
    │   ├─> Implementation subagent (uses TDD skill)
    │   ├─> Automatic checks (justfile)
    │   ├─> Code review subagent
    │   └─> Update JIRA status
    ├─> Interactive rebase
    └─> Create PR
```

## Extending plugin

### Add New Skills

Skills are reusable instructions. To add a new skill:

1. Create skill directory: `plugins/skills/my-skill/`
2. Write `SKILL.md` with frontmatter and content
3. Reference from commands: `Skill(devkit:my-skill)`

### Add New Commands

Commands orchestrate workflows. To add a new command:

1. Create command file: `plugins/commands/my-command.md`
2. Add frontmatter with description
3. Reference relevant skills
4. Test the command

### Customize for Your Stack

Edit skills to match your stack:

- **TDD skill:** Adapt test frameworks and patterns
- **Breakdown skill:** Adjust granularity factors
- **Code review skill:** Add stack-specific checks

## Version History

**1.0.0** - Initial release

- `/refine`, `/breakdown`, `/execute` commands
- `refining-issues`, `breakdown-planning` skills
- JIRA deep integration
- Subagent-driven development pattern
- TDD enforcement
- Automatic code review
