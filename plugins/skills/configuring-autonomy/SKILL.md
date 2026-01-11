---
name: configuring-autonomy
description: Configure Claude Code for maximum safe autonomy by analyzing skills/commands and generating allowlist entries
when_to_use: when setting up a repository for autonomous Claude Code operation, or when adding new skills/commands that should be auto-allowed
version: 1.0.0
---

# Configuring Autonomy

## Overview

Analyzes plugin skills and commands to generate allowlist entries that enable Claude Code to run autonomously without requiring user approval for safe operations.

**Core principle:** Maximize autonomy while preserving safety. Read-only and reversible operations are auto-allowed; destructive and external mutations require approval.

## The Process

### Step 1: Discover Plugin Structure

```bash
# Find all skills
skills=$(find plugins/skills -name "SKILL.md" -exec dirname {} \;)

# Find all commands
commands=$(ls plugins/commands/*.md 2>/dev/null)

# Count for reporting
skill_count=$(echo "$skills" | wc -l)
command_count=$(echo "$commands" | wc -l)
```

Report discovery:

```markdown
Found {skill_count} skills and {command_count} commands to analyze.
```

### Step 2: Categorize by Risk Level

**Risk Categories:**

| Category | Description | Auto-Allow? |
|----------|-------------|-------------|
| `read-only` | Only reads/analyzes, no side effects | Yes |
| `local-reversible` | Local changes, easily undone via git | Yes |
| `external-read` | Reads from external systems (PM, GitHub) | Yes |
| `external-write` | Writes to external systems | Configurable |
| `destructive` | Deletes files/data, hard to undo | No |

**Categorization Rules:**

```python
def categorize_skill(skill_name, skill_content):
    """Categorize a skill based on its content and behavior."""

    # Read-only patterns (always safe)
    read_only_indicators = [
        'systematic-debugging',
        'root-cause-tracing',
        'writing-tests',        # Analysis phase
        'writing-code-comments',
        'writing-justfiles',    # Template generation
        'validating-claude-md',
        'receiving-code-review',
    ]

    # Local reversible patterns (safe with git)
    local_reversible_indicators = [
        'test-driven-development',
        'executing-tasks',
        'executing-chores',
        'executing-bug-fixes',
        'adding-logging',
        'setting-up-pre-commit',
    ]

    # External read patterns (safe)
    external_read_indicators = [
        'pm-operations' if 'get_issue' in skill_content else None,
    ]

    # External write patterns (configurable)
    external_write_indicators = [
        'refining-issues',
        'technical-planning',
        'breakdown-planning',
        'creating-tickets',
        'creating-pull-requests',
        'addressing-pr-feedback',
    ]

    # Destructive patterns (never auto-allow)
    destructive_indicators = [
        'cleaning-up-git-worktrees',  # Deletes directories
    ]

    # Match skill name against patterns
    if skill_name in destructive_indicators:
        return 'destructive'
    if skill_name in external_write_indicators:
        return 'external-write'
    if skill_name in local_reversible_indicators:
        return 'local-reversible'
    if skill_name in read_only_indicators:
        return 'read-only'

    # Default: check content for clues
    if 'delete' in skill_content.lower() or 'remove' in skill_content.lower():
        return 'destructive'
    if 'create_issue' in skill_content or 'update_issue' in skill_content:
        return 'external-write'
    if 'mcp__' in skill_content:
        return 'external-read'

    return 'local-reversible'  # Default to safe
```

### Step 3: Generate Allowlist Entries

**Generate skill allowlist:**

```python
def generate_skill_allowlist(categorized_skills, include_external_writes=False):
    """Generate allowlist entries for skills."""
    entries = []

    for skill_name, category in categorized_skills.items():
        if category in ['read-only', 'local-reversible', 'external-read']:
            entries.append(f"Skill(devkit:{skill_name})")
        elif category == 'external-write' and include_external_writes:
            entries.append(f"Skill(devkit:{skill_name})")
        # destructive: never include

    return entries
```

**Generate common bash allowlist:**

```python
def generate_bash_allowlist():
    """Generate allowlist for common safe bash patterns."""
    return [
        # Git operations (local, reversible)
        "Bash(git add:*)",
        "Bash(git commit:*)",
        "Bash(git checkout:*)",
        "Bash(git worktree:*)",
        "Bash(git branch:*)",
        "Bash(git status)",
        "Bash(git diff:*)",
        "Bash(git log:*)",
        "Bash(git fetch:*)",
        "Bash(git merge:*)",
        "Bash(git symbolic-ref:*)",

        # Just commands (project-defined, safe)
        "Bash(just:*)",
        "Bash(just lint:*)",
        "Bash(just format:*)",
        "Bash(just test:*)",
        "Bash(just build:*)",
        "Bash(just --list:*)",

        # Read-only exploration
        "Bash(tree:*)",
        "Bash(find:*)",
        "Bash(cat:*)",
        "Bash(ls:*)",
        "Bash(rg:*)",
        "Bash(fd:*)",
        "Bash(pwd)",
        "Bash(which:*)",

        # File operations (local, reversible)
        "Bash(mkdir:*)",

        # GitHub CLI (read operations)
        "Bash(gh pr view:*)",
        "Bash(gh pr checks:*)",
        "Bash(gh api:*)",
        "Bash(gh pr list:*)",

        # Package managers (local, reversible)
        "Bash(uv:*)",
        "Bash(npm install:*)",
        "Bash(pip install:*)",

        # Testing & build
        "Bash(npm test:*)",
        "Bash(npm run test:*)",
        "Bash(python -m pytest:*)",
        "Bash(cargo test:*)",
        "Bash(dotnet:*)",
    ]
```

**Generate MCP tool allowlist:**

```python
def generate_mcp_allowlist(include_writes=False):
    """Generate allowlist for MCP tools."""
    # Always allow read operations
    entries = [
        "mcp__notion__notion-fetch",
        "mcp__notion__notion-search",
        # Add Jira equivalents when available
    ]

    if include_writes:
        entries.extend([
            "mcp__notion__notion-create-pages",
            "mcp__notion__notion-update-page",
            "mcp__notion__notion-move-pages",
        ])

    return entries
```

### Step 4: Ask User for Configuration Level

Present autonomy levels:

```markdown
## Configure Autonomy Level

Choose your preferred autonomy level:

### Level 1: Conservative (Recommended for new users)
- Auto-allow: Read-only operations, local git, just commands
- Require approval: External writes (PM, GitHub), destructive operations

### Level 2: Balanced (Recommended for trusted workflows)
- Auto-allow: All of Level 1 + external writes to PM system
- Require approval: Destructive operations, git push

### Level 3: Maximum (For experienced users with good backups)
- Auto-allow: Almost everything except destructive operations
- Require approval: Only truly destructive operations (force push, delete)

Which level? (1/2/3)
```

### Step 5: Generate Configuration Files

**Generate `.claude/settings.local.json`:**

```python
def generate_settings(level, categorized_skills):
    """Generate settings.local.json based on autonomy level."""

    allowlist = []

    # Read-only tools - always allowed (no side effects)
    allowlist.extend([
        "Read",
        "Glob",
        "Grep",
        "WebFetch",
        "WebSearch",
        "Task",
        "TodoWrite",
    ])

    # Local-reversible tools - level 2+ (git can undo)
    if level >= 2:
        allowlist.extend([
            "Write",
            "Edit",
        ])

    # Skills
    skill_entries = generate_skill_allowlist(
        categorized_skills,
        include_external_writes=(level >= 2)
    )
    allowlist.extend(skill_entries)

    # Bash commands
    allowlist.extend(generate_bash_allowlist())

    # Add push for level 3
    if level >= 3:
        allowlist.extend([
            "Bash(git push:*)",
            "Bash(gh pr create:*)",
            "Bash(gh pr merge:*)",
        ])

    # MCP tools
    allowlist.extend(generate_mcp_allowlist(include_writes=(level >= 2)))

    return {
        "permissions": {
            "allow": allowlist,
            "deny": [
                "Bash(git push --force:*)",
                "Bash(git reset --hard:*)",
                "Bash(rm -rf:*)",
            ]
        }
    }
```

**Write to file:**

```python
import json

settings = generate_settings(level, categorized_skills)

# Ensure .claude directory exists
Path(".claude").mkdir(exist_ok=True)

# Write settings
with open(".claude/settings.local.json", "w") as f:
    json.dump(settings, f, indent=2)

print(f"Generated .claude/settings.local.json with {len(settings['permissions']['allow'])} allowlist entries")
```

### Step 6: Generate Analysis Report

Output a summary:

```markdown
## Autonomy Configuration Complete

**Level:** {level_name}

### Skills Categorization

| Skill | Category | Auto-Allowed |
|-------|----------|--------------|
{skill_table}

### Allowlist Summary

- **Skills:** {skill_count} auto-allowed
- **Bash patterns:** {bash_count} auto-allowed
- **MCP tools:** {mcp_count} auto-allowed

### Files Generated

- `.claude/settings.local.json` - Allowlist configuration

### Next Steps

1. Review `.claude/settings.local.json`
2. Commit if satisfied: `git add .claude/ && git commit -m "chore: configure autonomy"`
3. Test with a simple workflow: `/test`
```

## Output

The skill produces:

1. **`.claude/settings.local.json`** - Allowlist configuration for Claude Code
2. **Console report** - Summary of categorization and configuration

## Integration

**Invoked by:**

- `/setup` command (optional step)
- Direct invocation via skill

**Uses:**

- File system analysis (Glob, Read)
- User input (AskUserQuestion)
- File writing (Write)

## Remember

- Conservative by default (Level 1)
- Never auto-allow destructive operations
- Local git operations are safe (reversible)
- External writes are opt-in
- Generate deny list for dangerous patterns
- Report what was configured
