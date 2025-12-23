# Plugin Testing Guide

This document describes how to test the AI DevKit plugin before using it in production.

## Testing Levels

### Level 1: Static Validation (Automated)

Run automated checks to validate plugin structure and references:

```bash
just validate
```

This runs three validation scripts:

| Recipe | What it checks |
|--------|----------------|
| `validate-skills` | Skill files have proper YAML frontmatter |
| `validate-references` | All `Skill(devkit:xyz)` references point to existing skills |
| `validate-pm` | PM operations use abstraction layer (not hard-coded MCP calls) |

**Expected result:** All checks pass (warnings are OK, errors are not)

### Level 2: Plugin Installation Test

1. **Install the plugin:**
   ```bash
   just install-plugin
   ```

2. **Verify commands appear:**
   - Restart Claude Code
   - Run `/help`
   - Confirm plugin commands appear (e.g., `/refine`, `/plan`, `/breakdown`, `/execute`)

3. **Test command loading:**
   - Try running `/setup` - it should start the setup wizard
   - Press Ctrl+C to cancel if you don't want to complete setup

### Level 3: Integration Test (Manual)

Test the full workflow in a test repository.

#### Setup Test Repository

```bash
# Create a test repo
mkdir ~/test-plugin-repo
cd ~/test-plugin-repo
git init

# Create minimal structure
echo "# Test Repo" > README.md
git add . && git commit -m "initial"

# Create package.json for a simple Node.js project
cat > package.json << 'EOF'
{
  "name": "test-plugin-repo",
  "scripts": {
    "test": "echo 'no tests yet'",
    "lint": "echo 'no linting yet'"
  }
}
EOF
git add . && git commit -m "add package.json"
```

#### Test Workflow

**Option A: GitHub Issues (easiest - no MCP needed)**

1. Push repo to GitHub:
   ```bash
   gh repo create test-plugin-repo --public --source=. --push
   ```

2. Run `/setup` and select "GitHub Issues"

3. Test the workflow:
   ```bash
   /refine "Add a hello world function"
   # → Should create GitHub issue, ask clarifying questions

   /plan <issue-number>
   # → Should add technical plan to issue

   /breakdown <issue-number>
   # → Should create sub-issues

   /execute <issue-number>
   # → Should execute tasks (may fail if no real code yet)
   ```

**Option B: Notion (if MCP configured)**

1. Run `/setup` and select "Notion"
2. Provide a Notion database or let it create one
3. Test the same workflow as above

**Option C: Jira (if MCP configured)**

1. Run `/setup` and select "Jira"
2. Provide project key
3. Test the same workflow as above

#### What to Verify

| Command | Expected Behavior |
|---------|-------------------|
| `/setup` | Creates CLAUDE.md, justfile, configures PM system |
| `/refine` | Creates/updates issue with Specification section |
| `/plan` | Adds Technical Plan section to issue |
| `/breakdown` | Creates labeled sub-issues with dependencies |
| `/execute` | Creates worktree, executes tasks, offers PR |
| `/chore` | Executes maintenance task with verification |
| `/bug-fix` | Investigates and fixes bugs with TDD |
| `/pr` | Creates PR with comprehensive description |

### Level 4: Error Handling Test

Test that errors are handled gracefully:

1. **Missing PM configuration:**
   ```bash
   # In a repo without /setup run
   /refine "test"
   # → Should suggest running /setup first
   ```

2. **Missing sections:**
   ```bash
   /plan <issue-without-specification>
   # → Should suggest running /refine first

   /breakdown <issue-without-plan>
   # → Should suggest running /plan first
   ```

3. **Invalid issue ID:**
   ```bash
   /refine INVALID-999
   # → Should show helpful error message
   ```

## CI Integration

The CI pipeline runs:

```bash
just ci
```

Which executes:
- `check` (lint, link check, JSON validation)
- `check-plugin` (plugin structure validation)
- `validate` (skill and reference validation)

## Cleanup

After testing:

```bash
# Remove test repo
rm -rf ~/test-plugin-repo

# Optionally uninstall plugin
just uninstall-plugin
```

## Reporting Issues

If you find issues during testing:

1. Note the command that failed
2. Copy the error message
3. Check if it's a known warning in `just validate`
4. Report at: https://github.com/chainavawongse/ai-devkit/issues
