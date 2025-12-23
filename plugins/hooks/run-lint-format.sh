#!/usr/bin/env bash
#
# run-lint-format.sh - Language-agnostic lint and format runner
#
# Reads PostToolUse hook input from stdin (JSON), extracts the file path,
# finds the appropriate justfile in the directory hierarchy, and runs
# lint and format commands. Gracefully handles missing commands.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Read JSON input from stdin
INPUT_JSON=$(cat)

# Extract file path from JSON using jq if available, otherwise use grep/sed
if command -v jq &> /dev/null; then
    CHANGED_FILE=$(echo "$INPUT_JSON" | jq -r '.tool_input.file_path // empty')
else
    # Fallback: extract file_path using grep/sed
    CHANGED_FILE=$(echo "$INPUT_JSON" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

# If no file path found, exit gracefully
if [ -z "$CHANGED_FILE" ]; then
    echo -e "${YELLOW}ℹ  No file path in hook input, skipping lint/format${NC}" >&2
    exit 0
fi

# Get the directory of the changed file
FILE_DIR="$(dirname "$CHANGED_FILE")"

# Function to find justfile in directory hierarchy
find_justfile() {
    local dir="$1"
    while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
        if [ -f "$dir/justfile" ] || [ -f "$dir/Justfile" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Find the nearest justfile
JUSTFILE_DIR=$(find_justfile "$FILE_DIR")

if [ -z "$JUSTFILE_DIR" ]; then
    echo -e "${YELLOW}ℹ  No justfile found in directory hierarchy for $CHANGED_FILE${NC}" >&2
    echo -e "${YELLOW}ℹ  Skipping lint/format checks${NC}" >&2
    exit 0
fi

echo -e "${GREEN}✓${NC} Found justfile in: $JUSTFILE_DIR" >&2

# Change to the directory with the justfile
cd "$JUSTFILE_DIR"

# Check if 'just lint' command exists
if just --list 2>/dev/null | grep -q "^  lint"; then
    echo -e "${GREEN}→${NC} Running lint..." >&2
    if just lint 2>&1; then
        echo -e "${GREEN}✓${NC} Lint passed" >&2
    else
        echo -e "${RED}✗${NC} Lint found issues" >&2
        echo -e "${YELLOW}💡 Tip: Run 'cd $JUSTFILE_DIR && just lint' to see details${NC}" >&2
        echo -e "${YELLOW}💡 Tip: Run 'cd $JUSTFILE_DIR && just lint-fix' if available${NC}" >&2
        # Exit code 2 shows stderr to Claude
        exit 2
    fi
else
    echo -e "${YELLOW}ℹ  No 'lint' command in justfile, skipping lint check${NC}" >&2
fi

# Check if 'just format' command exists
if just --list 2>/dev/null | grep -q "^  format"; then
    echo -e "${GREEN}→${NC} Running format check..." >&2
    if just format 2>&1; then
        echo -e "${GREEN}✓${NC} Format check passed" >&2
    else
        echo -e "${RED}✗${NC} Format check found issues" >&2
        echo -e "${YELLOW}💡 Tip: Run 'cd $JUSTFILE_DIR && just format' to fix formatting${NC}" >&2
        # Exit code 2 shows stderr to Claude
        exit 2
    fi
else
    echo -e "${YELLOW}ℹ  No 'format' command in justfile, skipping format check${NC}" >&2
fi

echo -e "${GREEN}✓${NC} All checks passed for changes in $JUSTFILE_DIR" >&2
exit 0
