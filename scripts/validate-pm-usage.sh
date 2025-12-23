#!/usr/bin/env bash
# Validate that PM operations are referenced correctly (not hard-coded to specific MCP)
set -e

COMMANDS_DIR="plugins/commands"
SKILLS_DIR="plugins/skills"
ERRORS=0
WARNINGS=0

echo "=== Validating PM Operations Usage ==="
echo ""

# Commands that should use pm-operations abstraction
PM_COMMANDS=("refine" "plan" "breakdown" "execute" "bug-fix" "chore" "address-feedback")

# Patterns that indicate hard-coded PM system usage (should use pm-operations instead)
HARDCODED_PATTERNS=(
    "mcp__atlassian__"
    "mcp__jira__"
    "mcp__notion__"
)

echo "Checking for hard-coded MCP calls in PM-related commands..."
for cmd in "${PM_COMMANDS[@]}"; do
    cmd_file="$COMMANDS_DIR/$cmd.md"

    if [ ! -f "$cmd_file" ]; then
        echo "⚠️  Command file not found: $cmd.md"
        WARNINGS=$((WARNINGS + 1))
        continue
    fi

    for pattern in "${HARDCODED_PATTERNS[@]}"; do
        # Check for direct MCP tool calls (excluding documentation/examples context)
        matches=$(grep -n "$pattern" "$cmd_file" 2>/dev/null | grep -v "pm-operations\|#.*example\|Implementation by System" || true)

        if [ -n "$matches" ]; then
            # Check if it's in a code block showing the abstraction
            if echo "$matches" | grep -q "pm_operations"; then
                continue
            fi
            echo "⚠️  $cmd.md: Contains direct MCP reference '$pattern'"
            echo "   Consider using pm-operations abstraction"
            WARNINGS=$((WARNINGS + 1))
        fi
    done
done

echo ""
echo "Checking that PM commands reference CLAUDE.md configuration..."
for cmd in "${PM_COMMANDS[@]}"; do
    cmd_file="$COMMANDS_DIR/$cmd.md"

    if [ ! -f "$cmd_file" ]; then
        continue
    fi

    # Check for CLAUDE.md or pm-operations reference
    if ! grep -qi "CLAUDE.md\|pm-operations\|pm.operations\|PM configuration" "$cmd_file"; then
        echo "⚠️  $cmd.md: Does not reference PM configuration from CLAUDE.md"
        WARNINGS=$((WARNINGS + 1))
    fi
done

echo ""
echo "Checking pm-operations skill exists and has all operations..."
PM_OPS_FILE="$SKILLS_DIR/pm-operations/SKILL.md"
if [ ! -f "$PM_OPS_FILE" ]; then
    echo "❌ pm-operations skill not found!"
    ERRORS=$((ERRORS + 1))
else
    # Check for required operations
    REQUIRED_OPS=("get_issue" "create_issue" "update_issue" "list_children")
    for op in "${REQUIRED_OPS[@]}"; do
        if ! grep -q "$op" "$PM_OPS_FILE"; then
            echo "❌ pm-operations: Missing operation '$op'"
            ERRORS=$((ERRORS + 1))
        fi
    done
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ PM operations validation passed"
    if [ $WARNINGS -gt 0 ]; then
        echo "⚠️  $WARNINGS warning(s)"
    fi
    exit 0
else
    echo "❌ Found $ERRORS error(s)"
    exit 1
fi
