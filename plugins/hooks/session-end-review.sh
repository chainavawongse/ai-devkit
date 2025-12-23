#!/usr/bin/env bash
#
# session-end-review.sh - Session-end documentation review
#
# Analyzes changes made during the session and intelligently determines
# if documentation updates are needed. Only suggests updates for:
# - New architectural patterns
# - Significant design decisions
# - New modules or major components
# - Changes to development tooling/workflow
#
# Does NOT suggest documentation for:
# - Simple bug fixes
# - Feature implementations following existing patterns
# - Refactoring without architectural changes
# - Test additions
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Read and discard JSON input from stdin (hook contract requirement)
# Note: Session info like session_id and reason available if needed in future:
# INPUT_JSON=$(cat) && echo "$INPUT_JSON" | jq -r '.session_id // empty'
cat > /dev/null

# Get repo root
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"

echo "" >&2
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo -e "${CYAN}  Session End - Documentation Review${NC}" >&2
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo ""

# Check if there are any uncommitted changes
cd "$REPO_ROOT"

if ! git diff --quiet HEAD 2>/dev/null && ! git diff --cached --quiet 2>/dev/null; then
    HAS_CHANGES=true
else
    HAS_CHANGES=false
fi

if [ "$HAS_CHANGES" = false ]; then
    echo -e "${GREEN}✓${NC} No uncommitted changes - documentation likely up to date" >&2
    echo "" >&2
    exit 0
fi

# Analyze the changes to determine if documentation is needed
echo -e "${BLUE}→${NC} Analyzing session changes..." >&2
echo "" >&2

# Check for indicators that documentation might be needed
DOC_UPDATE_NEEDED=false
REASONS=()

# 1. Check for new architectural files
if git diff HEAD --name-only 2>/dev/null | grep -qE "(architecture|design|pattern|service|repository|model|controller|middleware)"; then
    REASONS+=("architectural files modified")
fi

# 2. Check for new modules/directories
NEW_DIRS=$(git diff HEAD --name-only 2>/dev/null | awk -F/ '{print $1}' | sort -u | wc -l)
if [ "$NEW_DIRS" -gt 3 ]; then
    REASONS+=("multiple new directories/modules created")
fi

# 3. Check for tooling changes
if git diff HEAD --name-only 2>/dev/null | grep -qE "(package\.json|pyproject\.toml|Cargo\.toml|go\.mod|justfile|Makefile|\.github/workflows)"; then
    REASONS+=("development tooling modified")
fi

# 4. Check for significant code additions (new patterns might be introduced)
LINES_ADDED=$(git diff HEAD --shortstat 2>/dev/null | grep -o '[0-9]\+ insertion' | grep -o '[0-9]\+' || echo "0")
if [ "$LINES_ADDED" -gt 500 ]; then
    REASONS+=("significant code changes ($LINES_ADDED lines added)")
fi

# Determine if we should suggest documentation update
if [ ${#REASONS[@]} -gt 0 ]; then
    DOC_UPDATE_NEEDED=true
fi

if [ "$DOC_UPDATE_NEEDED" = true ]; then
    echo -e "${YELLOW}⚠${NC}  Potential documentation update needed" >&2
    echo "" >&2
    echo -e "${YELLOW}Indicators:${NC}" >&2
    for reason in "${REASONS[@]}"; do
        echo -e "  • $reason" >&2
    done
    echo "" >&2

    # Output message for Claude to process
    cat <<EOF >&2

${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${MAGENTA}📝 Documentation Review Needed${NC}
${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${YELLOW}Before ending this session, consider:${NC}

${GREEN}1. Review your changes:${NC}
   • Did you introduce NEW architectural patterns?
   • Did you make SIGNIFICANT design decisions?
   • Did you add NEW modules or major components?
   • Did you change development tooling or workflows?

${GREEN}2. If YES to any above:${NC}
   ${CYAN}Ask the user:${NC} "Should I update the project documentation to
   reflect the architectural/design changes made in this session?"

${GREEN}3. If user confirms, update:${NC}
   • CLAUDE-architecture.md - For new architectural patterns
   • CLAUDE-patterns.md - For new coding conventions
   • Module CLAUDE.md - For new tooling or commands
   • justfile - For new development commands

${RED}Do NOT update documentation for:${NC}
   ✗ Simple feature implementations following existing patterns
   ✗ Bug fixes that don't change architecture
   ✗ Refactoring without pattern changes
   ✗ Test additions
   ✗ Minor code changes

${MAGENTA}💡 Remember:${NC} Code documents features. Documentation documents
   patterns, architecture, and design decisions.

${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

EOF

    # Exit code 2 will show this to Claude (blocking)
    exit 2
else
    echo -e "${GREEN}✓${NC} Session changes appear to be routine - no documentation update needed" >&2
    echo -e "  ${GREEN}Criteria checked:${NC}" >&2
    echo -e "    • No architectural file changes" >&2
    echo -e "    • No significant new modules" >&2
    echo -e "    • No tooling changes" >&2
    echo -e "    • Code changes within normal scope" >&2
    echo "" >&2
    exit 0
fi
