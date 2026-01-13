# Git Conventions

Standards for branches, commits, and pull requests to ensure traceability to Jira tickets.

## Branch Naming

**Format:** `<type>/<ticket>-<description>`

```bash
feature/PAS-123-add-user-authentication
bugfix/PAS-456-fix-login-timeout
chore/PAS-789-upgrade-dependencies
```

### Branch Types

| Type | When to Use |
|------|-------------|
| `feature/` | New functionality or behavior changes |
| `bugfix/` | Fixing broken behavior |
| `chore/` | Maintenance, refactoring, dependencies |
| `hotfix/` | Urgent production fixes |

### Guidelines

- Always include the Jira ticket number
- Use lowercase with hyphens (kebab-case)
- Keep description brief but descriptive (3-5 words)
- Description should match the ticket title intent

**Examples:**

```bash
feature/PAS-123-add-user-authentication
feature/PAS-124-implement-password-reset
bugfix/PAS-456-fix-session-expiry
chore/PAS-789-upgrade-react-18
hotfix/PAS-999-patch-security-vulnerability
```

## Commit Messages

**Format:** `<type>(<ticket>): <description>`

```bash
feat(PAS-123): add login endpoint
fix(PAS-456): handle null user in session check
chore(PAS-789): upgrade React to v18
```

### Commit Types

| Type | Description |
|------|-------------|
| `feat` | New feature or functionality |
| `fix` | Bug fix |
| `chore` | Maintenance (deps, config, cleanup) |
| `refactor` | Code restructuring (no behavior change) |
| `docs` | Documentation only |
| `test` | Adding or updating tests |
| `style` | Formatting, whitespace (no code change) |

### Message Structure

```bash
<type>(<ticket>): <short description>

<optional body - what and why>

<optional footer>
```

**Short description:**

- Imperative mood ("add" not "added")
- No period at end
- Max 72 characters

**Body (when needed):**

- Explain what changed and why
- Wrap at 72 characters
- Separate from subject with blank line

**Examples:**

```bash
feat(PAS-123): add user authentication endpoint

Implements JWT-based authentication with refresh tokens.
Session duration configurable via environment variable.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

```bash
fix(PAS-456): handle session expiry during API calls

Root cause: Middleware wasn't checking token expiry before
processing requests, causing 500 errors instead of 401.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

```bash
chore(PAS-789): upgrade React from v17 to v18

- Updated react and react-dom to 18.2.0
- Migrated to createRoot API
- All tests passing

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Pull Request Titles

**Format:** `<ticket>: <description>`

```bash
PAS-123: Add user authentication
PAS-456: Fix session expiry handling
PAS-789: Upgrade React to v18
```

### Guidelines

- Ticket number first for Jira integration
- Description matches the ticket title or summarizes changes
- Use sentence case (capitalize first word only)
- No period at end

### PR Description

Include in the PR body:

- Summary of changes
- Link to Jira ticket (auto-linked if ticket number in title)
- Test plan or verification steps
- Any deployment considerations

## Quick Reference

| Element | Format | Example |
|---------|--------|---------|
| Branch | `<type>/<ticket>-<desc>` | `feature/PAS-123-add-auth` |
| Commit | `<type>(<ticket>): <desc>` | `feat(PAS-123): add login` |
| PR Title | `<ticket>: <desc>` | `PAS-123: Add authentication` |

## Integration with the plugin

These conventions are enforced throughout the plugin workflow:

- **`/execute`** - Commits follow the message format
- **`/pr`** - PR titles include ticket number
- **`using-git-worktrees`** skill - Branch names follow the pattern

## Why This Matters

1. **Traceability** - Every change links back to a Jira ticket
2. **Automation** - Jira auto-links commits and PRs to tickets
3. **History** - Easy to understand what changed and why
4. **Search** - Find all changes for a ticket via git log
