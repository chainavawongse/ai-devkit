# ai-devkit justfile
# Run `just` to see available recipes
#
# Prerequisites:
#   - Node.js (for npx)
#   - jq (for JSON validation)
#   - Windows users: run from Git Bash or WSL

marketplace_name := "ai-devkit-marketplace"
plugin_name := "devkit"
repo_path := justfile_directory()

# Default recipe - show help
default:
    @just --list

# ============================================================================
# Standard Recipes
# ============================================================================

# Install dependencies
install:
    npm install --save-dev markdownlint-cli2 markdown-link-check

# Lint all markdown files
lint:
    @echo "Linting markdown files..."
    npx markdownlint-cli2 "**/*.md" "#node_modules"

# Format files (auto-fix markdown lint issues)
format:
    @echo "Formatting markdown files..."
    npx markdownlint-cli2 --fix "**/*.md" "#node_modules"

# Run tests (none in this repository)
test:
    @echo "No tests in this repository"

# Build project (nothing to build)
build:
    @echo "No build step required for this repository"

# ============================================================================
# Quality Checks
# ============================================================================

# Run all quality checks
check: lint check-links check-json

# Check for broken links in markdown files
check-links:
    #!/usr/bin/env bash
    set -e
    echo "Checking links in markdown files..."
    find . -name "*.md" -not -path "./node_modules/*" -print0 | \
        xargs -0 -I {} npx markdown-link-check --quiet --config .markdown-link-check.json {}

# Check for broken links in changed markdown files only (used by CI)
check-links-changed:
    #!/usr/bin/env bash
    set -e
    echo "Checking links in changed markdown files..."
    # Use --diff-filter=d to exclude deleted files (lowercase d = exclude deletions)
    CHANGED_FILES=$(git diff --name-only --diff-filter=d origin/main...HEAD -- '*.md' 2>/dev/null || git diff --name-only --diff-filter=d HEAD~1 -- '*.md')
    if [ -n "$CHANGED_FILES" ]; then
        echo "$CHANGED_FILES" | xargs -I {} npx markdown-link-check --quiet --config .markdown-link-check.json {}
    else
        echo "No markdown files changed"
    fi

# Validate JSON files
check-json:
    @echo "Validating JSON files..."
    @find . -name "*.json" -not -path "./node_modules/*" -exec jq empty {} +
    @echo "All JSON files valid"

# ============================================================================
# Plugin Management
# ============================================================================

# Install the plugin via Claude CLI
install-plugin:
    claude plugin marketplace add "{{repo_path}}"
    claude plugin install {{plugin_name}}@{{marketplace_name}}

# Update the plugin
update-plugin:
    @echo "Note: Run 'git pull' first if you want the latest changes"
    claude plugin update {{plugin_name}}@{{marketplace_name}}

# Uninstall the plugin
uninstall-plugin:
    claude plugin uninstall {{plugin_name}}@{{marketplace_name}}
    claude plugin marketplace remove {{marketplace_name}}

# ============================================================================
# Plugin Inspection
# ============================================================================

# Check plugin structure
check-plugin:
    @echo "Checking plugin structure..."
    @test -f ".claude-plugin/marketplace.json" || (echo "Missing .claude-plugin/marketplace.json" && exit 1)
    @test -f "plugins/.claude_plugin/plugin.json" || (echo "Missing plugins/.claude_plugin/plugin.json" && exit 1)
    @test -f "plugins/README.md" || (echo "Missing README.md" && exit 1)
    @jq empty ".claude-plugin/marketplace.json"
    @jq empty "plugins/.claude_plugin/plugin.json"
    @echo "Plugin structure valid"

# List all skills in the plugin
list-skills:
    @echo "Available skills:"
    @find "plugins/skills" -name "SKILL.md" -exec dirname {} \; | xargs -I {} basename {}

# List all commands in the plugin
list-commands:
    @echo "Available commands:"
    @ls -1 "plugins/commands/"

# ============================================================================
# Plugin Validation
# ============================================================================

# Validate skill files have proper frontmatter
validate-skills:
    @chmod +x scripts/validate-skills.sh
    @./scripts/validate-skills.sh

# Validate skill references point to existing skills
validate-references:
    @chmod +x scripts/validate-references.sh
    @./scripts/validate-references.sh

# Validate PM operations usage (no hard-coded MCP calls)
validate-pm:
    @chmod +x scripts/validate-pm-usage.sh
    @./scripts/validate-pm-usage.sh

# Run all plugin validations
validate: validate-skills validate-references validate-pm
    @echo ""
    @echo "✅ All plugin validations passed"

# ============================================================================
# Autonomy Configuration
# ============================================================================

# Show autonomy allowlist report (level 1-3)
show-allowlist level="1":
    @chmod +x scripts/generate-allowlist.sh
    @./scripts/generate-allowlist.sh {{level}} report

# Generate .claude/settings.local.json with autonomy allowlist
configure-autonomy level="2":
    @chmod +x scripts/generate-allowlist.sh
    @./scripts/generate-allowlist.sh {{level}} json
    @echo ""
    @echo "To apply, copy entries to your Claude Code settings or commit .claude/settings.local.json"

# Output raw allowlist entries (for copying to settings)
raw-allowlist level="2":
    @chmod +x scripts/generate-allowlist.sh
    @./scripts/generate-allowlist.sh {{level}} raw

# ============================================================================
# CI
# ============================================================================

# Run all checks for CI
ci: check check-plugin validate
    @echo "All CI checks passed"
