#!/usr/bin/env bash
#
# run-post-task-validation.sh - Post-subagent validation runner
#
# Reads SubagentStop hook input from stdin (JSON), uses current working directory
# to find justfile, then runs unit tests and validates that build/dev commands
# still work after a subagent completes work.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Read JSON input from stdin (required by hook spec, even if we don't use it much)
INPUT_JSON=$(cat)

# Use the current working directory from the hook input if available
if command -v jq &> /dev/null; then
    WORK_DIR=$(echo "$INPUT_JSON" | jq -r '.cwd // empty')
else
    # Fallback: extract cwd using grep/sed
    WORK_DIR=$(echo "$INPUT_JSON" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
fi

# If no cwd found, use current directory
if [ -z "$WORK_DIR" ]; then
    WORK_DIR="."
fi

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
JUSTFILE_DIR=$(find_justfile "$WORK_DIR")

if [ -z "$JUSTFILE_DIR" ]; then
    echo -e "${YELLOW}ℹ  No justfile found in directory hierarchy${NC}" >&2
    echo -e "${YELLOW}ℹ  Skipping post-task validation${NC}" >&2
    exit 0
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo -e "${BLUE}  Post-Task Validation${NC}" >&2
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
echo -e "${GREEN}✓${NC} Found justfile in: $JUSTFILE_DIR" >&2

# Change to the directory with the justfile
cd "$JUSTFILE_DIR"

# Track overall status
VALIDATION_PASSED=true

# 1. Run unit tests (fast feedback)
echo "" >&2
echo -e "${BLUE}Step 1: Running unit tests...${NC}" >&2
if just --list 2>/dev/null | grep -q "^  test"; then
    if just test 2>&1; then
        echo -e "${GREEN}✓${NC} Unit tests passed" >&2
    else
        echo -e "${RED}✗${NC} Unit tests failed" >&2
        echo -e "${YELLOW}💡 Tip: Run 'cd $JUSTFILE_DIR && just test' to see failure details${NC}" >&2
        VALIDATION_PASSED=false
    fi
else
    echo -e "${YELLOW}ℹ  No 'test' command in justfile, skipping unit tests${NC}" >&2
fi

# 2. Try to build (if build command exists)
echo "" >&2
echo -e "${BLUE}Step 2: Checking build...${NC}" >&2
if just --list 2>/dev/null | grep -q "^  build"; then
    if timeout 60s just build 2>&1; then
        echo -e "${GREEN}✓${NC} Build successful" >&2
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo -e "${YELLOW}⚠${NC}  Build timed out after 60s" >&2
            echo -e "${YELLOW}💡 Tip: Build may take longer, check manually with 'cd $JUSTFILE_DIR && just build'${NC}" >&2
        else
            echo -e "${RED}✗${NC} Build failed" >&2
            echo -e "${YELLOW}💡 Tip: Run 'cd $JUSTFILE_DIR && just build' to see failure details${NC}" >&2
            VALIDATION_PASSED=false
        fi
    fi
else
    echo -e "${YELLOW}ℹ  No 'build' command in justfile, skipping build check${NC}" >&2
fi

# 3. Try to start dev server and check if it starts successfully
echo "" >&2
echo -e "${BLUE}Step 3: Validating dev server startup...${NC}" >&2
if just --list 2>/dev/null | grep -q "^  dev"; then
    # Start dev server in background with timeout
    echo -e "${GREEN}→${NC} Starting dev server..." >&2

    # Create a temp file for the output
    DEV_OUTPUT=$(mktemp)

    # Start dev server in background, redirect output
    timeout 10s just dev > "$DEV_OUTPUT" 2>&1 &
    DEV_PID=$!

    # Wait a bit for server to start
    sleep 3

    # Check if process is still running
    if kill -0 $DEV_PID 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Dev server started successfully" >&2
        # Kill the dev server
        kill $DEV_PID 2>/dev/null || true
        wait $DEV_PID 2>/dev/null || true
    else
        # Process died, check output
        echo -e "${RED}✗${NC} Dev server failed to start" >&2
        echo -e "${YELLOW}Last 10 lines of output:${NC}" >&2
        tail -10 "$DEV_OUTPUT" >&2
        echo -e "${YELLOW}💡 Tip: Run 'cd $JUSTFILE_DIR && just dev' to start server and see full logs${NC}" >&2
        VALIDATION_PASSED=false
    fi

    rm -f "$DEV_OUTPUT"
else
    echo -e "${YELLOW}ℹ  No 'dev' command in justfile, skipping dev server check${NC}" >&2
fi

# Final summary
echo "" >&2
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
if [ "$VALIDATION_PASSED" = true ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}" >&2
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    exit 0
else
    echo -e "${RED}✗ Some validations failed${NC}" >&2
    echo -e "${YELLOW}Please fix the issues before proceeding${NC}" >&2
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    # Exit code 2 blocks SubagentStop and shows stderr to Claude
    exit 2
fi
