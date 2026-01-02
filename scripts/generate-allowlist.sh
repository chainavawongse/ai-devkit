#!/usr/bin/env bash
# generate-allowlist.sh - Generate Claude Code allowlist from plugin structure
#
# Usage:
#   ./scripts/generate-allowlist.sh [level]
#
# Levels:
#   1 - Conservative: Read-only, local git, just commands
#   2 - Balanced: Level 1 + external writes to PM
#   3 - Maximum: Almost everything except destructive ops
#
# Output:
#   Prints allowlist entries to stdout
#   Use with: ./scripts/generate-allowlist.sh 2 > allowlist.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default level
LEVEL="${1:-1}"

# Color output (disabled if not terminal)
if [[ -t 2 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Skill categorization lists
READONLY_SKILLS="systematic-debugging root-cause-tracing writing-tests writing-code-comments writing-justfiles validating-claude-md receiving-code-review pm-operations"
LOCAL_REVERSIBLE_SKILLS="test-driven-development test-driven-development-frontend executing-tasks executing-chores executing-bug-fixes executing-plans adding-logging setting-up-pre-commit using-git-worktrees generating-agent-documentation requesting-code-review configuring-autonomy"
EXTERNAL_WRITE_SKILLS="refining-issues technical-planning breakdown-planning creating-tickets creating-pull-requests addressing-pr-feedback configuring-project-management"
DESTRUCTIVE_SKILLS="cleaning-up-git-worktrees"

# Store categorized skills for report
SKILL_REPORT=""

contains() {
    local list="$1"
    local item="$2"
    [[ " $list " == *" $item "* ]]
}

categorize_skill() {
    local skill="$1"

    if contains "$READONLY_SKILLS" "$skill"; then
        echo "read-only"
    elif contains "$LOCAL_REVERSIBLE_SKILLS" "$skill"; then
        echo "local-reversible"
    elif contains "$EXTERNAL_WRITE_SKILLS" "$skill"; then
        echo "external-write"
    elif contains "$DESTRUCTIVE_SKILLS" "$skill"; then
        echo "destructive"
    else
        # Default to local-reversible for unknown skills
        echo "local-reversible"
    fi
}

generate_skill_allowlist() {
    local level="$1"
    local skills_dir="$REPO_ROOT/plugins/skills"

    if [[ ! -d "$skills_dir" ]]; then
        echo "# No skills directory found" >&2
        return
    fi

    for skill_dir in "$skills_dir"/*/; do
        [[ -d "$skill_dir" ]] || continue
        local skill_name=$(basename "$skill_dir")

        # Skip hidden directories
        [[ "$skill_name" == .* ]] && continue

        local category=$(categorize_skill "$skill_name")

        # Add to report
        SKILL_REPORT="${SKILL_REPORT}${skill_name}|${category}\n"

        case "$category" in
            "read-only"|"local-reversible")
                echo "Skill(devkit:$skill_name)"
                ;;
            "external-write")
                if [[ "$level" -ge 2 ]]; then
                    echo "Skill(devkit:$skill_name)"
                fi
                ;;
            "destructive")
                # Never auto-allow
                ;;
        esac
    done
}

generate_bash_allowlist() {
    local level="$1"

    cat << 'EOF'
# Git operations (local, reversible)
Bash(git add:*)
Bash(git commit:*)
Bash(git checkout:*)
Bash(git worktree:*)
Bash(git branch:*)
Bash(git status)
Bash(git diff:*)
Bash(git log:*)
Bash(git fetch:*)
Bash(git merge:*)
Bash(git symbolic-ref:*)
Bash(git stash:*)

# Just commands (project-defined, safe)
Bash(just:*)
Bash(just lint:*)
Bash(just format:*)
Bash(just test:*)
Bash(just build:*)
Bash(just --list:*)

# Read-only exploration
Bash(tree:*)
Bash(find:*)
Bash(cat:*)
Bash(ls:*)

# GitHub CLI (read operations)
Bash(gh pr view:*)
Bash(gh pr checks:*)
Bash(gh pr list:*)
Bash(gh issue view:*)
Bash(gh issue list:*)
Bash(gh api:*)

# Testing
Bash(npm test:*)
Bash(npm run test:*)
Bash(python -m pytest:*)
Bash(cargo test:*)
Bash(dotnet test:*)

# Package management (read/install)
Bash(npm install:*)
Bash(pip install:*)
Bash(uv pip install:*)
Bash(cargo build:*)
Bash(dotnet restore:*)
EOF

    if [[ "$level" -ge 3 ]]; then
        cat << 'EOF'

# Level 3: Push and PR operations
Bash(git push:*)
Bash(gh pr create:*)
Bash(gh pr edit:*)
Bash(gh pr merge:*)
EOF
    fi
}

generate_mcp_allowlist() {
    local level="$1"

    cat << 'EOF'
# Notion (read operations)
mcp__notion__notion-fetch
mcp__notion__notion-search
mcp__notion__notion-get-users
mcp__notion__notion-get-teams
EOF

    if [[ "$level" -ge 2 ]]; then
        cat << 'EOF'

# Level 2+: Notion write operations
mcp__notion__notion-create-pages
mcp__notion__notion-update-page
mcp__notion__notion-move-pages
mcp__notion__notion-create-database
mcp__notion__notion-update-database
mcp__notion__notion-create-comment
EOF
    fi
}

generate_deny_list() {
    cat << 'EOF'
# Always deny (destructive operations)
Bash(git push --force:*)
Bash(git push -f:*)
Bash(git reset --hard:*)
Bash(rm -rf:*)
Bash(rm -r:*)
EOF
}

print_report() {
    local level="$1"

    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}" >&2
    echo -e "${BLUE}  Claude Code Autonomy Configuration - Level $level${NC}" >&2
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}" >&2
    echo "" >&2

    case "$level" in
        1)
            echo -e "${GREEN}Level 1: Conservative${NC}" >&2
            echo "  - Auto-allow: Read-only operations, local git, just commands" >&2
            echo "  - Require approval: External writes (PM, GitHub), destructive ops" >&2
            ;;
        2)
            echo -e "${YELLOW}Level 2: Balanced${NC}" >&2
            echo "  - Auto-allow: Level 1 + external writes to PM system" >&2
            echo "  - Require approval: Destructive operations, git push" >&2
            ;;
        3)
            echo -e "${RED}Level 3: Maximum${NC}" >&2
            echo "  - Auto-allow: Almost everything except destructive ops" >&2
            echo "  - Require approval: Only force push, hard reset, rm -rf" >&2
            ;;
    esac

    echo "" >&2
    echo -e "${BLUE}Skill Categorization:${NC}" >&2
    echo "" >&2

    # Parse and display skill report
    echo -e "$SKILL_REPORT" | while IFS='|' read -r skill category; do
        [[ -z "$skill" ]] && continue
        local icon=""
        local auto=""
        case "$category" in
            "read-only")
                icon="${GREEN}[R]${NC}"
                auto="yes"
                ;;
            "local-reversible")
                icon="${GREEN}[L]${NC}"
                auto="yes"
                ;;
            "external-write")
                icon="${YELLOW}[E]${NC}"
                if [[ "$level" -ge 2 ]]; then
                    auto="yes (level 2+)"
                else
                    auto="no"
                fi
                ;;
            "destructive")
                icon="${RED}[D]${NC}"
                auto="never"
                ;;
        esac
        printf "  %b %-40s %-20s %s\n" "$icon" "$skill" "$category" "$auto" >&2
    done

    echo "" >&2
    echo -e "${BLUE}Legend:${NC}" >&2
    echo -e "  ${GREEN}[R]${NC} Read-only     - Always auto-allowed" >&2
    echo -e "  ${GREEN}[L]${NC} Local         - Auto-allowed (reversible via git)" >&2
    echo -e "  ${YELLOW}[E]${NC} External      - Auto-allowed at level 2+" >&2
    echo -e "  ${RED}[D]${NC} Destructive   - Never auto-allowed" >&2
    echo "" >&2
}

generate_json_settings() {
    local level="$1"
    local output_file="$2"

    # Collect all allowlist entries into a temp file
    local tmp_allow=$(mktemp)
    local tmp_deny=$(mktemp)

    # Skills
    generate_skill_allowlist "$level" | grep -v '^#' | grep -v '^$' >> "$tmp_allow"

    # Bash
    generate_bash_allowlist "$level" | grep -v '^#' | grep -v '^$' >> "$tmp_allow"

    # MCP
    generate_mcp_allowlist "$level" | grep -v '^#' | grep -v '^$' >> "$tmp_allow"

    # Deny
    generate_deny_list | grep -v '^#' | grep -v '^$' >> "$tmp_deny"

    # Count entries
    local allow_count=$(wc -l < "$tmp_allow" | tr -d ' ')
    local deny_count=$(wc -l < "$tmp_deny" | tr -d ' ')

    # Build JSON manually (jq might not be available)
    echo "{" > "$output_file"
    echo "  \"_comment\": \"Generated by generate-allowlist.sh - Level $level\"," >> "$output_file"
    echo "  \"_generated\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$output_file"
    echo "  \"permissions\": {" >> "$output_file"
    echo "    \"allow\": [" >> "$output_file"

    # Add allow entries
    local first=true
    while IFS= read -r line; do
        if $first; then
            first=false
        else
            echo "," >> "$output_file"
        fi
        printf "      \"%s\"" "$line" >> "$output_file"
    done < "$tmp_allow"
    echo "" >> "$output_file"
    echo "    ]," >> "$output_file"

    echo "    \"deny\": [" >> "$output_file"

    # Add deny entries
    first=true
    while IFS= read -r line; do
        if $first; then
            first=false
        else
            echo "," >> "$output_file"
        fi
        printf "      \"%s\"" "$line" >> "$output_file"
    done < "$tmp_deny"
    echo "" >> "$output_file"
    echo "    ]" >> "$output_file"

    echo "  }" >> "$output_file"
    echo "}" >> "$output_file"

    # Cleanup
    rm -f "$tmp_allow" "$tmp_deny"

    echo -e "${GREEN}Generated: $output_file${NC}" >&2
    echo "  Allow entries: $allow_count" >&2
    echo "  Deny entries: $deny_count" >&2
}

main() {
    local level="$LEVEL"
    local output_mode="${2:-report}"

    # Validate level
    if [[ ! "$level" =~ ^[1-3]$ ]]; then
        echo "Error: Level must be 1, 2, or 3" >&2
        echo "Usage: $0 [level] [output_mode]" >&2
        echo "  level: 1 (conservative), 2 (balanced), 3 (maximum)" >&2
        echo "  output_mode: report (default), json, raw" >&2
        exit 1
    fi

    case "$output_mode" in
        "json")
            # Generate JSON settings file
            mkdir -p "$REPO_ROOT/.claude"
            # Populate skill report first
            generate_skill_allowlist "$level" > /dev/null
            generate_json_settings "$level" "$REPO_ROOT/.claude/settings.local.json"
            print_report "$level"
            ;;
        "raw")
            # Just output the allowlist entries
            generate_skill_allowlist "$level"
            generate_bash_allowlist "$level"
            generate_mcp_allowlist "$level"
            ;;
        "report"|*)
            # Full report with allowlist
            generate_skill_allowlist "$level" > /dev/null  # Populate SKILL_REPORT
            print_report "$level"
            echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "${BLUE}  Allowlist Entries${NC}"
            echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
            echo ""
            echo "# Skills"
            generate_skill_allowlist "$level"
            echo ""
            generate_bash_allowlist "$level"
            echo ""
            generate_mcp_allowlist "$level"
            echo ""
            echo "# Deny list"
            generate_deny_list
            ;;
    esac
}

main "$@"
