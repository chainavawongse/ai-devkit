---
description: Perform code review on current changes - supports quick inline review or deep agent-based review
---

# Code Review

Perform a thorough code review of changes made in this session or staged git changes.

## Usage

```bash
/review              # Quick inline review of current changes
/review --deep       # Dispatch code-reviewer agent for comprehensive review
/review --staged     # Review only staged changes
/review <file>       # Review specific file
```

## Process

### Step 1: Gather Changes

```bash
# Check for staged changes first
git diff --staged

# If no staged changes, check unstaged
git diff

# If no git changes, review files modified in this session
```

### Step 2: Choose Review Mode

**Quick Review (default):** Inline review in current context - fast, good for small changes.

**Deep Review (`--deep`):** Dispatch `code-reviewer` agent for comprehensive analysis including:
- Security scoring (A-F)
- Architecture impact assessment
- SOLID principle compliance
- Pattern consistency checks
- Detailed action checklist

### Step 3: Review Criteria

**Correctness:**
- Logic errors, edge cases, off-by-one errors
- Null/undefined checks
- Promise rejection handling

**Security:**
- Input validation
- SQL injection, XSS, CSRF
- Authentication/authorization
- Hardcoded secrets or API keys

**Performance:**
- Algorithmic complexity
- N+1 queries
- Memory leaks
- Unnecessary loops

**Maintainability:**
- Code style consistency
- Naming conventions
- Function/method size
- Documentation

**Testing:**
- Tests for new functionality
- Edge case coverage
- Test determinism

**Architecture:**
- Follows existing patterns
- Proper module boundaries
- Dependency direction
- Appropriate abstraction level

### Step 4: Run Automated Checks

```bash
# If justfile exists
just lint
just test

# Check for common issues
grep -r "TODO\|FIXME\|console\.log\|debugger" --include="*.ts" --include="*.js"
```

### Step 5: Provide Feedback

**Quick Review Format:**

```markdown
## Code Review Summary

### Good practices observed:
- [Positive finding]

### Suggestions for improvement:
- `file:line` - [Issue and suggested fix]

### Critical issues (must fix):
- `file:line` - [Blocking issue]

### Questions:
- [Clarification needed]
```

**Deep Review Format:** (from code-reviewer agent)

```markdown
# Code Review – <branch> (<date>)

## Executive Summary
| Metric | Result |
|--------|--------|
| Overall Assessment | Excellent / Good / Needs Work / Major Issues |
| Security Score     | A-F |
| Maintainability    | A-F |
| Architecture Impact | High / Medium / Low |
| Pattern Compliance | Pass / Issues Found |

## Critical Issues
...

## Major Issues
...

## Minor Suggestions
...

## Architecture & Patterns
...

## Positive Highlights
...

## Action Checklist
...
```

## Deep Review Mode

When `--deep` is specified, dispatch the `code-reviewer` agent:

```bash
# Get commit range
BASE_SHA=$(git merge-base HEAD origin/main)
HEAD_SHA=$(git rev-parse HEAD)

# Dispatch code-reviewer agent with:
# - What changed (diff summary)
# - Base and head commits
# - Any requirements or plan context
```

The code-reviewer agent provides:
- Severity-tagged issues (Critical/Major/Minor)
- SOLID principle analysis
- Dependency direction checks
- Concrete fix suggestions with file:line references
- Security and performance scoring

## Review Checklist

- [ ] No obvious bugs or logic errors
- [ ] Proper error handling
- [ ] No security vulnerabilities
- [ ] Follows project conventions
- [ ] Adequate test coverage
- [ ] No leftover debug code
- [ ] Performance is acceptable
- [ ] Documentation updated if needed

## Integration

**Uses:**
- `code-reviewer` agent (for `--deep` mode)
- `just lint` and `just test` (if available)
- Git diff commands

**Related skills:**
- `requesting-code-review` - For dispatching reviews during task execution
- `receiving-code-review` - For processing review feedback

## Best Practices

- Be constructive and specific
- Provide examples of how to fix issues
- Acknowledge good practices
- Focus on the most important issues first
- Use `--deep` for PRs or significant changes
- Use quick mode for small iterations
