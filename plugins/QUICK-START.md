# plugin Quick Start

Get started with the AI Development Lifecycle.

> **First time?** Complete the [Installation Guide](../INSTALLATION.md) before continuing.

## The Workflow

plugin provides a spec-driven pipeline from idea to production:

```
/refine → /plan → /breakdown → /execute → /pr → /address-feedback
```

## Commands

### `/refine` - Create Specifications

Transforms rough ideas into validated specifications (WHAT to build).

```bash
/refine "Add user authentication with email and password"
/refine TEAM-123  # Refine existing issue
```

Uses Socratic questioning to explore requirements, documents user stories and success criteria.

### `/plan` - Create Technical Plans

Creates implementation approach from specifications (HOW to build).

```bash
/plan TEAM-123
```

Analyzes codebase patterns, designs architecture, documents technical decisions.

### `/breakdown` - Create Sub-Issues

Breaks technical plans into executable tasks with dependencies.

```bash
/breakdown TEAM-123
```

Creates sub-issues labeled `feature`, `chore`, or `bug` with TDD checklists.

### `/execute` - Implement

Executes sub-issues sequentially in isolated worktrees.

```bash
/execute TEAM-123
```

- Creates worktree at `<parent>/worktrees/<repo>/<branch>/`
- Follows TDD (RED → GREEN → REFACTOR)
- Runs tests and linters after each task
- Updates JIRA status in real-time

### `/pr` - Create Pull Request

Creates comprehensive PR with diagrams and documentation.

```bash
/pr
```

### `/address-feedback` - Handle Reviews

Implements PR review feedback automatically.

```bash
/address-feedback <pr-number>
```

Categorizes feedback by severity, creates tracking issues, implements changes using TDD.

### `/clean-worktrees` - Cleanup

Removes worktrees for merged branches.

```bash
/clean-worktrees
```

### `/setup` - Configure Repository

Sets up a repository for the plugin with documentation and tooling.

```bash
/setup
```

Generates `CLAUDE.md`, configures `justfile`, sets up pre-commit hooks.

### `/bug-fix` - Quick Bug Fix

Shortcut workflow for fixing bugs without full planning cycle.

```bash
/bug-fix TEAM-123
```

### `/chore` - Quick Chore

Shortcut workflow for chores (refactoring, dependencies, etc.).

```bash
/chore TEAM-123
```

## Example Session

```bash
# Start with an idea
/refine "Add real-time notifications"
# → Interactive refinement, creates NOTIF-45 with Specification
# → "Ready to create technical plan?" > yes

# Automatic chaining to planning
# → Analyzes codebase, creates Technical Plan
# → "Ready to break this down?" > yes

# Automatic chaining to breakdown
# → Creates 12 sub-issues with dependencies
# → "Ready to execute?" > yes

# Automatic chaining to execution
# → Creates worktree /Projects/worktrees/myapp/notif-45/
# → Executes tasks sequentially with TDD
# → "Create pull request?" > yes

# Automatic chaining to PR
# → Creates PR with diagrams and documentation

# Later, after code review
/address-feedback 89
# → Implements all review feedback
# → Updates PR

# After merge
/clean-worktrees
# → Removes merged worktree
```

## Key Concepts

**Spec-Driven Development**
- Specification (WHAT) comes before Technical Plan (HOW)
- Requirements drive design, design drives implementation

**Test-Driven Development**
- Every task follows RED → GREEN → REFACTOR
- Tests and implementation are never split

**Isolated Worktrees**
- Execution happens in `<parent>/worktrees/`, not your main workspace
- Work on multiple features simultaneously

**Resumable Execution**
- Interrupted? Just re-run `/execute`
- Completed tasks are skipped automatically

## Recommended Tools

For optimal plugin performance, install in your target repositories:

```bash
brew install just ripgrep fd gh  # macOS
```

Create a `justfile` with these recipes:

```justfile
test:
    npm test  # or pytest, cargo test, etc.

lint:
    npm run lint

format:
    npm run format

build:
    npm run build
```

## Troubleshooting

**"Issue missing Specification section"**
→ Run `/refine <issue-id>` first

**"Issue missing Technical Plan section"**
→ Run `/plan <issue-id>` first

**"No sub-issues found"**
→ Run `/breakdown <issue-id>` first

**Tests failing during execute**
→ Subagent retries automatically; fix manually if needed and re-run

**Execution interrupted**
→ Re-run `/execute <issue-id>` — completed tasks are skipped

## Next Steps

- [Full Documentation](README.md) - Complete reference
- [Development Guide](CLAUDE.md) - Contributing to plugin
