#!/usr/bin/env bash
# Validate that all Skill(devkit:xyz) references point to existing skills
set -e

SKILLS_DIR="plugins/skills"
COMMANDS_DIR="plugins/commands"
ERRORS=0
WARNINGS=0

echo "=== Validating Skill References ==="
echo ""

# Build list of available skills (one per line in temp file)
AVAILABLE_SKILLS_FILE=$(mktemp)
trap "rm -f $AVAILABLE_SKILLS_FILE" EXIT

for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
        echo "$skill_name" >> "$AVAILABLE_SKILLS_FILE"
    fi
done

echo "Available skills:"
cat "$AVAILABLE_SKILLS_FILE"
echo ""

# Function to check if skill exists
skill_exists() {
    grep -q "^$1$" "$AVAILABLE_SKILLS_FILE"
}

# Find all Skill(devkit:xxx) references in commands and skills
echo "Checking references in commands..."
for cmd_file in "$COMMANDS_DIR"/*.md; do
    cmd_name=$(basename "$cmd_file")

    # Find Skill(devkit:xxx) patterns
    refs=$(grep -oE 'Skill\(devkit:[a-z0-9-]+\)' "$cmd_file" 2>/dev/null || true)

    for ref in $refs; do
        # Extract skill name from Skill(devkit:xxx)
        skill_name=$(echo "$ref" | sed 's/Skill(devkit:\([^)]*\))/\1/')

        if ! skill_exists "$skill_name"; then
            echo "❌ $cmd_name: References non-existent skill '$skill_name'"
            ERRORS=$((ERRORS + 1))
        fi
    done
done

echo ""
echo "Checking references in skills..."
for skill_dir in "$SKILLS_DIR"/*/; do
    skill_file="$skill_dir/SKILL.md"
    skill_name=$(basename "$skill_dir")

    if [ ! -f "$skill_file" ]; then
        continue
    fi

    # Find Skill(devkit:xxx) patterns
    refs=$(grep -oE 'Skill\(devkit:[a-z0-9-]+\)' "$skill_file" 2>/dev/null || true)

    for ref in $refs; do
        # Extract skill name from Skill(devkit:xxx)
        ref_skill=$(echo "$ref" | sed 's/Skill(devkit:\([^)]*\))/\1/')

        if ! skill_exists "$ref_skill"; then
            echo "❌ $skill_name/SKILL.md: References non-existent skill '$ref_skill'"
            ERRORS=$((ERRORS + 1))
        fi
    done
done

echo ""

# Check for orphaned skills (not referenced anywhere)
echo "Checking for orphaned skills..."
while read -r skill_name; do
    # Skip pm-operations as it's a reference skill
    if [ "$skill_name" = "pm-operations" ]; then
        continue
    fi

    # Search for references in commands and other skills
    ref_count=$(grep -r "devkit:$skill_name" "$COMMANDS_DIR" "$SKILLS_DIR" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$ref_count" -eq 0 ]; then
        echo "⚠️  Skill '$skill_name' is not referenced by any command or skill"
        WARNINGS=$((WARNINGS + 1))
    fi
done < "$AVAILABLE_SKILLS_FILE"

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All skill references are valid"
    if [ $WARNINGS -gt 0 ]; then
        echo "⚠️  $WARNINGS warning(s) (orphaned skills)"
    fi
    exit 0
else
    echo "❌ Found $ERRORS error(s)"
    exit 1
fi
