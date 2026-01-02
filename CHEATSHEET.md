# AI DevKit Plugin Cheatsheet

Quick reference for the spec-driven development workflow.

## Quick Start

```bash
# Install plugin
git clone https://github.com/chainavawongse/ai-devkit.git
cd ai-devkit && just install-plugin

# First time in any repo
/setup
```

---

## The Pipeline

```
/refine → /plan → /breakdown → /execute → /pr
   ↓         ↓          ↓           ↓        ↓
  WHAT      HOW      TASKS      BUILD    SHIP
```

---

## Commands at a Glance

| Command | Purpose | Input | Output |
|---------|---------|-------|--------|
| `/setup` | Initialize repo | - | CLAUDE.md, justfile, PM config |
| `/refine` | Define WHAT to build | idea or issue ID | Specification in ticket |
| `/plan` | Define HOW to build | issue ID | Technical Plan in ticket |
| `/breakdown` | Create tasks | issue ID | Sub-issues with dependencies |
| `/execute` | Build it | issue ID | Working code + PR |
| `/chore` | Maintenance task | description or issue ID | Verified changes |
| `/bug-fix` | Fix a bug | description or issue ID | TDD fix + PR |
| `/pr` | Create pull request | - | PR with diagrams |
| `/address-feedback` | Handle PR comments | PR number | Implemented fixes |

---

## Command Details

### `/setup`
**Run first in any new repo**

```bash
/setup
```

Creates:
- `CLAUDE.md` - repo documentation for agents
- `justfile` - standardized commands (test, lint, format, build)
- PM system configuration (Jira/Notion/GitHub Issues)

---

### `/refine <idea or issue-id>`
**Define WHAT to build (not HOW)**

```bash
/refine "Add user authentication with OAuth"
/refine TEAM-123
```

**Requires:** PM system configured
**Creates:** Issue with `## Specification` section
**Next:** `/plan`

---

### `/plan <issue-id>`
**Define HOW to build it**

```bash
/plan TEAM-123
```

**Requires:** Issue with Specification
**Creates:** `## Technical Plan` section in issue
**Next:** `/breakdown`

---

### `/breakdown <issue-id>`
**Create implementation tasks**

```bash
/breakdown TEAM-123
```

**Requires:** Issue with Specification + Technical Plan
**Creates:** Labeled sub-issues (feature/chore/bug) with dependencies
**Next:** `/execute`

---

### `/execute <issue-id>`
**Build everything**

```bash
/execute TEAM-123
```

**Requires:** Issue with sub-issues from `/breakdown`
**Does:**
- Creates worktree at `<parent>/worktrees/<repo>/<ticket>/`
- Executes tasks sequentially (respects dependencies)
- TDD for features/bugs, verification for chores
- Code review after each task
- Final branch review

**Next:** Merge or `/pr`

---

### `/chore <description or issue-id>`
**Maintenance without TDD**

```bash
/chore "Upgrade React to v18"
/chore MAINT-42
```

**Requires:** Clean git state
**Does:** Implement → Verify (test, lint, build) → Commit
**Next:** `/pr`

---

### `/bug-fix <description or issue-id>`
**Fix bugs with TDD**

```bash
/bug-fix "Login fails with valid credentials"
/bug-fix BUG-89
```

**Requires:** PM system configured
**Does:** Investigate → Reproduce (failing test) → Fix → Verify
**Next:** `/pr`

---

### `/pr`
**Create pull request**

```bash
/pr
/pr --draft
/pr --base develop
```

**Requires:** Commits on branch, `gh` CLI authenticated
**Creates:** PR with description, diagrams, linked issues

---

### `/address-feedback <pr-number>`
**Implement PR review comments**

```bash
/address-feedback 145
```

**Requires:** PR with review comments, parent issue linked
**Does:** Creates sub-issues for feedback → Executes all → Updates PR

---

## PM System Formats

| System | Issue ID Format | Setup |
|--------|-----------------|-------|
| Jira | `TEAM-123` | Atlassian MCP |
| Notion | Page URL or UUID | Notion MCP |
| GitHub | `42` (issue number) | `gh` CLI |

---

## Common Workflows

### New Feature (Full Pipeline)
```bash
/refine "Add real-time notifications"
/plan NOTIF-45
/breakdown NOTIF-45
/execute NOTIF-45
```

### Quick Maintenance
```bash
/chore "Update all npm dependencies"
/pr
```

### Bug Fix
```bash
/bug-fix BUG-123
/pr
```

### Resume Interrupted Work
```bash
# Just re-run - it skips completed tasks
/execute TEAM-123
```

### Handle PR Feedback
```bash
/address-feedback 145
# Automatically implements all feedback
```

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| "No PM system configured" | Run `/setup` |
| "Missing Specification" | Run `/refine <issue-id>` first |
| "Missing Technical Plan" | Run `/plan <issue-id>` first |
| "No sub-issues" | Run `/breakdown <issue-id>` first |
| "Uncommitted changes" | Commit or use worktree |
| "Circular dependency" | Fix dependencies in PM system |

---

## Validation

```bash
just validate          # All validations
just validate-skills   # Skill frontmatter
just validate-references  # Skill references
just validate-pm       # PM abstraction usage
```

---

## Key Principles

1. **Spec-driven:** WHAT (Specification) → HOW (Technical Plan) → Code
2. **TDD required:** Features and bugs require test-first
3. **Just abstraction:** All commands via `just` (test, lint, format, build)
4. **Sequential execution:** One task at a time, dependencies respected
5. **PM is source of truth:** All context lives in tickets, not files

---

## Links

- [Full Documentation](plugins/README.md)
- [Testing Guide](TESTING.md)
- [Installation](INSTALLATION.md)
- [PM Operations](plugins/skills/pm-operations/SKILL.md)
