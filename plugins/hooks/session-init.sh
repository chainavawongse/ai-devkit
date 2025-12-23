#!/usr/bin/env bash

# Plugin - Session Initialization Script
# This script runs on every Claude Code session start
# It verifies tools, checks repo initialization, and provides workflow guidance

set -e

# Get the script's directory
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

# =============================================================================
# Build Context Output (for JSON)
# =============================================================================

build_context() {
    cat << 'EOF'
# Plugin Session Context

## Critical Development Practices

### 1. Review Available Skills
- Check `Skill(devkit:*)` for available skills
- Skills provide reusable best-practice guidance
- Use skills proactively when tasks match their purpose

### 2. Use Subagents Extensively
- Delegate complex tasks to specialized subagents
- Use `Task(subagent_type='...')` for focused work
- Subagents maintain focused context and expertise
- Quality hooks validate subagent work automatically

### 3. Review Documentation First
- Read CLAUDE.md before making changes
- Check CLAUDE-architecture.md for design patterns
- Review CLAUDE-patterns.md for coding conventions
- Documentation prevents architectural drift

### 4. Use Justfiles for All Commands
- Use `just lint` instead of direct linter commands
- Use `just format` instead of direct formatter commandsW
- Use `just test` instead of direct test commands
- Use `just build` instead of direct build commands
- Justfiles ensure project-specific configuration
- Run `just --list` to discover available commands

### 5. Prefer Modern Tools
- Use `rg` not grep, `fd` not find
- Use `uv` for Python, `gh` for GitHub
- Modern tools are faster and more user-friendly

## Key Tools Available

**rg (ripgrep)** - Fast code search
  Use: `rg 'pattern' path/`
  Better than grep - use it for searching code

**fd** - Fast file finder
  Use: `fd 'filename' path/`
  Better than find - use it for finding files

**uv** - Fast Python package manager
  Use: `uv pip install package`
  Better than pip - use it for Python dependencies

**tree** - Directory visualization
  Use: `tree -L 2 path/`
  Use to understand directory structure

**jq** - JSON processor
  Use: `cat file.json | jq '.field'`
  Use for parsing and manipulating JSON

**gh** - GitHub CLI
  Use: `gh pr create, gh issue list`
  Use for GitHub operations (PRs, issues, etc.)

**just** - Command runner
  Use: `just lint, just test, just build`
  ALWAYS prefer just commands over direct tool invocation

## plugin Workflow

For ANY feature or code change:

1.  /refine → Define WHAT to build (specification)
2.  /plan → Define HOW to build (technical plan)
3.  /breakdown → Break down into implementation tasks
4.  /execute → Implement with TDD & review
5.  /pr → Create comprehensive pull request

Other commands:
- /setup → Initialize repository
- /address-feedback → Process PR review feedback

💡 **Best Practice:** Always suggest the complete workflow
   refine → plan → breakdown → execute → pr
   for features and significant code changes.

## Session Reminders
- Review skills and use them proactively
- Delegate to subagents for complex work
- Read documentation before changing code
- Use justfiles for all development commands
- Prefer modern tools (rg, fd, uv, gh)

EOF
}

# =============================================================================
# Check Repository Initialization Status
# =============================================================================

check_repo_status() {
    local CLAUDE_MD="$REPO_ROOT/CLAUDE.md"
    local status=""
    local JUSTFILE_COUNT=0

    if [ -f "$CLAUDE_MD" ]; then
        status="Repository initialized (CLAUDE.md found)"

        # Check for justfiles
        JUSTFILE_COUNT=$((JUSTFILE_COUNT + $(find "$REPO_ROOT" -maxdepth 3 -name "justfile" -o -name "Justfile" 2>/dev/null | wc -l)))
        if [ "$JUSTFILE_COUNT" -gt 0 ]; then
            status="$status | Found $JUSTFILE_COUNT justfile(s)"
        fi
    else
        status="⚠️  Repository NOT initialized - recommend running /setup"
    fi

    echo "$status"
}

# =============================================================================
# Build and Output JSON
# =============================================================================

# Build the context content
CONTEXT_CONTENT=$(build_context)
REPO_STATUS=$(check_repo_status)

# Escape content for JSON
ESCAPED_CONTEXT=$(echo "$CONTEXT_CONTENT" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
ESCAPED_STATUS=$(echo "$REPO_STATUS" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

# Output JSON
cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<EXTREMELY_IMPORTANT> ${ESCAPED_CONTEXT} </EXTREMELY_IMPORTANT> \nRepository Status: ${ESCAPED_STATUS} \n Repeat the plugin workflow in your first response to the user."
  }
}
EOF

exit 0
