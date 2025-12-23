# Plugin - AI Development Guide

**Version:** 1.0.0
**Last Updated:** 2025-11-02

## Purpose

This document captures the core principles, architecture decisions, and working practices for the AI DevKit plugin. It guides both human developers and AI agents working in this codebase.

## Core Philosophy

### 0. Repository Foundation (`/setup`)

**The foundation of all plugin workflows:**

Before any development work begins, `/setup` establishes the repository foundation that enables agents to work effectively and self-verify their work:

**What `/setup` establishes:**

1. **Comprehensive Documentation (`CLAUDE.md`):**
   - Repository structure and architecture
   - Technology stack and tooling discovery
   - Module-level documentation with complete tooling context
   - Patterns and conventions for agents to follow

2. **Consistent Verification Patterns:**
   - Standardized `justfile` with `lint`, `format`, `test`, `build` recipes
   - Pre-commit hooks for automated quality checks
   - Conventional commit standards
   - Stack-appropriate linting and formatting tools

3. **Self-Verification Context:**
   - Agents can independently verify their work using documented tools
   - Consistent command interface across all modules
   - Clear quality standards and verification steps
   - No manual intervention needed for standard checks

**Why this is critical:**

- **Consistency:** Every agent uses the same patterns and tools
- **Independence:** Agents can self-verify without human intervention
- **Quality:** Standards are documented and automatically enforced
- **Context:** Full repository understanding enables better decisions

**When to run `/setup`:**

- First time using the plugin in a repository
- When onboarding to a new project
- After major tooling or architecture changes
- When documentation becomes outdated

**Result:** A repository ready for autonomous agent collaboration with consistent patterns, comprehensive context, and self-verification capabilities.

### 1. Spec-Driven Development

**Separation of WHAT from HOW:**

- **Specification (WHAT):** User requirements, behaviors, success criteria - technology agnostic
- **Technical Plan (HOW):** Architecture, patterns, implementation approach - technical decisions
- **Implementation:** Code that satisfies both WHAT and HOW

```
/setup → Repository Foundation
   ↓
Idea → /refine → Specification → /plan → Technical Plan → /breakdown → Sub-issues → /execute → Code
```

**Why:** Requirements should drive design. Design should drive implementation. Never conflate them.

### 2. Test-Driven Development (TDD)

**Iron Law:** NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST

```
RED (write failing test) → GREEN (minimal implementation) → REFACTOR (clean up)
```

**Critical:** Tests and implementation are NEVER split into separate tasks. Each sub-issue includes both.

**Why:** If you didn't watch the test fail, you don't know if it tests the right thing.

### 3. Just Command Abstraction

**All workflows use `just` commands:**

- `just install` - Install dependencies
- `just test` - Run tests
- `just lint` - Run linters
- `just format` - Format code
- `just build` - Build artifacts

**Why:** Makes plugin stack-agnostic. Repository defines implementation; workflow stays consistent across any language/framework.

### 4. Sequential Execution with Isolation

**Git worktrees at `~/worktrees/<repo>/<branch>/`:**

- Each execution runs in isolated worktree outside main workspace
- Sub-issues execute sequentially, one at a time
- Dependencies respected; execution order preserved

**Why:** Better debugging, predictable execution flow, no main workspace pollution.

### 5. Code Review at Every Level

**Dual review gates:**

1. **Per-task review:** Built into execution skills (feature/chore/bug workflows)
2. **Final branch review:** Before merge, comprehensive architectural review

**Why:** Catch issues early. Verify architectural consistency at branch level.

### 6. Deep PM System Integration

**JIRA as source of truth:**

- All context in tickets (Specification, Technical Plan, task descriptions)
- Real-time status updates during execution
- Dependencies tracked in PM system
- No separate files for plans

**Why:** Context preservation, team visibility, single source of truth.

## Architecture Principles

### Commands Orchestrate, Skills Guide

**Commands** (`/setup`, `/refine`, `/plan`, `/breakdown`, `/execute`, `/pr`, `/address-feedback`):

- Entry points for workflows
- Orchestrate multiple skills
- Handle user interaction
- Should be < 250 lines (orchestration only)

**Skills** (in `skills/` directory):

- Reusable workflow units
- Contain **succinct, focused** process guidance
- Can be invoked by multiple commands
- Single responsibility
- **Target: <500 lines** (longer than this means too much explanation)
- **Focus on WHAT to do**, not WHY (LLMs don't need convincing)
- Avoid redundant examples (LLM already knows language syntax)

**Agents** (in `agents/` directory):

- Specialized subagent definitions
- Invoked via Task() tool
- Get fresh context, execute independently
- Report back when complete

### Sequential Task Execution

**Dependency-aware sequential processing:**

```python
# Pseudo-code from executing-plans skill
while remaining_tasks:
    ready_tasks = [t for t in remaining if no_blockers(t)]

    if not ready_tasks:
        break  # All remaining tasks are blocked

    # Execute ONLY the first ready task
    current_task = ready_tasks[0]
    Task(subagent=route_by_label(current_task))

    # Wait for completion
    # Mark current task as completed
    # Update completed list
    # Check for newly unblocked tasks
    # Continue with next task
```

**Why:** Predictable execution order, easier debugging, simpler mental model.

### Label-Based Routing

**Every sub-issue has exactly ONE label:**

- `feature` → `executing-tasks` skill (full TDD workflow)
- `chore` → `executing-chores` skill (verification-focused)
- `bug` → `executing-bug-fixes` skill (reproduction + TDD fix)

**Why:** Clear routing, consistent execution, proper workflow for each task type.

## Working Practices

### 1. Plans Live in PM System

**Never create separate plan files.**

- Specification: In parent issue description under `## Specification`
- Technical Plan: In parent issue description under `## Technical Plan`
- Task context: In sub-issue descriptions with TDD checklists

**Why:** Single source of truth, team visibility, no file synchronization issues.

### 2. Worktree Standard Location

**Always use:** `~/worktrees/<repo-name>/<branch-name>/`

- Outside repository (no .gitignore needed)
- Parallel-execution safe
- Easy cleanup: `rm -rf ~/worktrees` when done
- Consistent across all workflows

### 3. Completed Tasks Respected

**executing-plans skill respects already-completed sub-issues:**

```python
completed = [t for t in sub_issues if t.state in ['Done', 'Completed']]
remaining = [t for t in sub_issues if t.state not in ['Done', 'Completed']]
```

**Enables:**

- Resuming interrupted executions
- Mixing manual fixes with automated execution
- Addressing feedback (some original, some new sub-issues)

### 4. Error Resilience

**Retry → Skip → Continue:**

```
Task fails → Retry (up to 3x)
Still failing → Skip with warning
Independent tasks → Continue execution
```

**Why:** One failing task shouldn't block all independent work.

### 5. Comprehensive PR Descriptions

**Auto-generated PRs include:**

- Executive summary with Mermaid diagrams
- Architectural changes diagram
- Sequence diagram for workflows
- Test coverage summary
- Links to implemented issues

**Why:** Context for reviewers, documentation for posterity.

### 6. Feedback Categorization

**All PR feedback categorized by severity:**

- 🔴 **Critical:** Security, data loss, broken functionality
- 🟡 **Important:** Architecture, patterns, maintainability
- 🟢 **Minor:** Style, naming, documentation

**Auto-implementation priorities Critical → Important → Minor**

## Code Quality Standards

### Security

- No hardcoded secrets
- Input validation everywhere
- Proper authn/authz flows
- OWASP Top 10 awareness

### Maintainability

- Single Responsibility Principle
- Functions < 50 lines
- Clear naming (no abbreviations)
- Comments explain WHY, not WHAT

### Testing

- Test behavior, not implementation
- AAA pattern (Arrange, Act, Assert)
- Deterministic tests only
- No test-only methods in production code

### Architecture

- SOLID principles
- No circular dependencies
- Dependency direction: UI → Service → Data
- Appropriate abstraction (not over/under-engineered)

## File Organization

```
plugins/
├── commands/              # Slash commands (entry points)
│   ├── setup.md
│   ├── refine.md
│   ├── plan.md
│   ├── breakdown.md
│   ├── execute.md
│   ├── pr.md
│   └── address-feedback.md
├── skills/                # Reusable workflow units
│   ├── generating-agent-documentation/
│   ├── setting-up-pre-commit/
│   ├── writing-justfiles/
│   ├── refining-issues/
│   ├── technical-planning/
│   ├── breakdown-planning/
│   ├── executing-plans/
│   ├── executing-tasks/
│   ├── executing-chores/
│   ├── executing-bug-fixes/
│   ├── test-driven-development/
│   ├── using-git-worktrees/
│   ├── creating-pull-requests/
│   └── addressing-pr-feedback/
├── agents/                # Subagent definitions
│   ├── code-reviewer.md
│   ├── api-architect.md
│   ├── backend-engineer.md
│   └── ...
├── docs/                  # Reference documentation
├── README.md              # User-facing documentation
├── WORKFLOW.md            # Visual workflow diagram
├── QUICK-START.md         # Getting started guide
└── CLAUDE.md              # This file (AI/dev guide)
```

## Common Patterns

### Pattern: Repository Initialization

```bash
# First time in a repository
/setup
# → Discovers repository structure
# → Generates comprehensive CLAUDE.md
# → Sets up justfile with verification recipes
# → Configures pre-commit hooks
# → Establishes conventional commit standards
# → Result: Repository ready for autonomous development
```

**Now all subsequent workflows can rely on:**

- Documented architecture and patterns
- Consistent verification commands (`just lint`, `just test`)
- Self-verification capabilities for all agents
- Complete context about tooling and conventions

### Pattern: Command Chaining

```bash
/refine TEAM-123
# → Asks: "Ready to create technical plan?"
/plan TEAM-123
# → Asks: "Ready to break down?"
/breakdown TEAM-123
# → Asks: "Ready to execute?"
/execute TEAM-123
```

**User can decline and run manually later.**

### Pattern: Resuming Execution

```bash
# Initial execution
/execute TEAM-123
# ... 10/15 tasks complete, then interruption ...

# Resume later - automatically picks up where it left off
/execute TEAM-123
# Completes remaining 5 tasks
```

### Pattern: Addressing Feedback

```bash
# After PR review
/address-feedback 123
# → Fetches all review comments
# → Categorizes by severity
# → Creates sub-issues for each
# → Auto-implements ALL feedback
# → Updates PR with new commits
```

### Pattern: Sequential Development

```bash
/execute TEAM-123
# → Analyzes dependencies
# → Identifies ready tasks (no blocking dependencies)
# → Executes tasks one at a time
# → Updates completed list after each task
# → Continues with next ready task
```

## Anti-Patterns to Avoid

### ❌ Splitting Tests and Implementation

**Bad:**

```
- TEAM-46: Write tests for user authentication
- TEAM-47: Implement user authentication
```

**Good:**

```
- TEAM-46: User authentication (TDD)
  - [ ] RED: Write failing tests
  - [ ] GREEN: Minimal implementation
  - [ ] REFACTOR: Clean up
```

### ❌ Creating Separate Plan Files

**Bad:**

```
# Creating plan.md or IMPLEMENTATION.md
```

**Good:**

```
# Write plan in JIRA issue description under ## Technical Plan
```

### ❌ Implementing Before Testing

**Bad:**

```python
# Write implementation first, then tests
def authenticate_user(credentials):
    # ... implementation ...
```

**Good:**

```python
# Write test first
def test_authenticate_user_with_valid_credentials():
    result = authenticate_user(valid_creds)
    assert result.success
    assert result.user_id is not None

# THEN implement (test should fail first)
def authenticate_user(credentials):
    # ... minimal implementation to pass test ...
```

### ❌ Manual Context Switching

**Bad:**

```bash
cd main-workspace
git checkout feature-branch
# ... work ...
git checkout main
# ... more work ...
```

**Good:**

```bash
# Use worktrees for isolation
# executing-plans skill creates worktree automatically
/execute TEAM-123
```

### ❌ Skipping Code Review

**Bad:**

```bash
# Push directly without review
git push origin feature-branch
```

**Good:**

```bash
# Code review is automatic
/execute TEAM-123
# → Per-task review after each task
# → Final branch review before PR creation
```

## Key Design Decisions

### Why Succinct Skills (200-400 Lines)?

**Problem with verbose skills:**

- Initial logging skill draft was 900+ lines
- Included language examples LLM already knows (Python, JS, Java, Go)
- Explanations of "why" that don't help LLM execute
- Redundant anti-pattern examples

**Benefits of succinct skills:**

- LLM focuses on actionable instructions, not theory
- Faster processing, less token usage
- Clear decision trees and checklists
- One focused example, not five language variations

**Rule of thumb:** If skill >400 lines, ask "Does LLM need this, or am I explaining why?"

### Why Specification Before Technical Plan?

**Rationale:** User requirements should drive technical decisions, not the reverse.

**Example:**

- Specification: "Users must be able to reset password via email within 15 minutes"
- Technical Plan: "Use Redis for token storage (15min TTL), SendGrid for email delivery"

If we started with Technical Plan, we might choose Redis without understanding the 15-minute requirement.

### Why No File-Based Plans?

**Problems with files:**

- Synchronization with PM system required
- No single source of truth
- Team members don't see updates
- File locations unclear

**Benefits of PM system:**

- Real-time updates
- Team visibility
- Historical context
- Searchable
- Linked to commits/PRs

### Why Sequential Task Execution?

**Alternative considered:** Parallel execution (faster but more complex)

**Why sequential:**

- Simpler mental model and debugging
- Predictable execution order
- Easier to trace failures
- Lower resource usage (one subagent at a time)
- Dependencies still respected

**Trade-off:** Slower execution time for large features with many independent tasks

### Why ~/worktrees/ Standard Location?

**Alternatives considered:**

1. `.worktrees/` in repo (original implementation)
2. `/tmp/worktrees/`
3. User-specified location

**Why ~/worktrees/:**

- Persistent across sessions (unlike /tmp)
- Outside repo (no .gitignore concerns)
- Isolation for clean workspace
- Easy cleanup
- Consistent across projects

### Why Label-Based Routing?

**Alternative considered:** Manual workflow selection

**Why labels:**

- Automatic routing (no user decision)
- Consistent execution (right workflow for task type)
- PM system enforces single label
- Clear semantics (feature vs chore vs bug)

**Example:** Feature requires full TDD. Chore requires verification only. Routing ensures correct workflow.

### Why Just Command Abstraction?

**Alternative considered:** Direct tool invocation (npm test, pytest, cargo test, etc.)

**Why just:**

- Stack-agnostic workflows
- Repository defines implementation
- Consistent interface
- Easy to change underlying tools
- Composable recipes

**Example:** `just test` might run unit + integration + e2e tests. Implementation details hidden from workflow.

## Integration Points

### JIRA MCP Servers

**Required for the plugin workflows:**

One of JIRA MCP server is **required** for most plugin workflows to function:

- `/refine` - Create/update issues with Specification
- `/plan` - Add Technical Plan to issues
- `/breakdown` - Create sub-issues with dependencies
- `/execute` - Read sub-issues, update status
- `/address-feedback` - Create feedback sub-issues

**Exception:** `/setup` does not require JIRA - it works standalone with any repository

**MCP Tools Used:**

- `get_issue` - Fetch issue details
- `list_issues` - Fetch sub-issues (filter by parentId)
- `create_issue` - Create new issues
- `update_issue` - Update descriptions, status
- `create_dependency` - Link blocking relationships

**Note:** Users must install MCP servers separately. plugin does not include them.

### Git Worktrees

**Required for:**

- `/execute` - Parallel execution isolation
- `/address-feedback` - Automatic worktree detection and switching

**Commands Used:**

- `git worktree add ~/worktrees/<repo>/<branch> -b <branch>`
- `git worktree list` - Enumerate existing worktrees
- `git worktree remove` - Cleanup after merge

### Just Task Runner

**Optional but recommended:**

- Provides consistent interface for test/lint/format/build
- Repository defines implementation
- plugin invokes via `just <recipe>`

**Fallback:** If no justfile, plugin uses stack-specific commands directly.

## Influences and References

**Review these periodically to stay aligned with industry best practices:**

### spec-kit (GitHub)

<https://github.com/github/spec-kit>

**Key ideas:**

- Specifications are living documents
- Separate WHAT from HOW
- Specs evolve with codebase
- Keep specs close to code

**How plugin applies this:**

- Specifications in JIRA (living, searchable)
- Clear Specification vs Technical Plan separation
- Specs updated during refinement
- Plans reference codebase files

### superpowers (obra)

<https://github.com/obra/superpowers>

**Key ideas:**

- AI agents as development workflow accelerators
- Skills-based architecture for reusability
- Human-in-the-loop for decisions
- Progressive automation

**How plugin applies this:**

- Skill-based architecture (skills/ directory)
- Commands orchestrate skills
- User confirmation at key decision points
- Automatic execution with manual override

## Version History

| Version | Date       | Changes                                      |
|---------|------------|----------------------------------------------|
| 1.0.0   | 2025-11-02 | Initial CLAUDE.md for plugin            |

## Next Steps for Contributors

### If You're an AI Agent

1. **Check for CLAUDE.md** - If none exists or it's outdated, suggest `/setup`
2. **Read this file completely** before making changes
3. **Follow the principles** - they're battle-tested
4. **Use verification tools** - Run `just lint`, `just test` to self-verify
5. **Preserve architecture** - don't introduce circular dependencies
6. **Write tests first** - TDD is non-negotiable
7. **Update this file** if you discover new patterns or anti-patterns

### If You're a Human Developer

1. **Start with `/setup`** - Establish repository foundation first
2. **Understand the philosophy** before diving into code
3. **Try the workflows** - run `/refine`, `/breakdown`, `/execute` on test issues
4. **Review CLAUDE.md** - Generated documentation shows repository structure
5. **Read the influences** - spec-kit and superpowers provide context
6. **Question decisions** - if something seems wrong, it might be (or this doc needs updating)
7. **Contribute patterns** - capture new workflows in this document

## Questions and Discussions

**When working on plugin:**

- "Does this follow spec-driven development?" (WHAT before HOW)
- "Is this testable via TDD?" (Test first)
- "Could this work with other stacks?" (Just abstraction)
- "Does this respect task dependencies?" (Sequential execution order)
- "Is context in the PM system?" (No separate files)

**If the answer is "no" to any question, reconsider the approach.**

---

**Remember:** This plugin exists to make development faster and more reliable through systematic workflows. Every design decision traces back to that goal.
