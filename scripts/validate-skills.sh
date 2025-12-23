#!/usr/bin/env bash
# Validate skill files have proper structure and frontmatter
set -e

SKILLS_DIR="plugins/skills"
ERRORS=0

echo "=== Validating Skill Files ==="
echo ""

# Check each skill directory has SKILL.md
for skill_dir in "$SKILLS_DIR"/*/; do
    skill_name=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"

    if [ ! -f "$skill_file" ]; then
        echo "❌ Missing SKILL.md in $skill_name"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Check for YAML frontmatter (starts with ---)
    if ! head -1 "$skill_file" | grep -q "^---$"; then
        echo "❌ $skill_name: Missing YAML frontmatter"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    # Extract frontmatter and check required fields
    frontmatter=$(sed -n '/^---$/,/^---$/p' "$skill_file" | sed '1d;$d')

    # Check for name field
    if ! echo "$frontmatter" | grep -q "^name:"; then
        echo "❌ $skill_name: Missing 'name' in frontmatter"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for description field
    if ! echo "$frontmatter" | grep -q "^description:"; then
        echo "❌ $skill_name: Missing 'description' in frontmatter"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for when_to_use field
    if ! echo "$frontmatter" | grep -q "^when_to_use:"; then
        echo "⚠️  $skill_name: Missing 'when_to_use' in frontmatter (recommended)"
    fi

    # Check for version field
    if ! echo "$frontmatter" | grep -q "^version:"; then
        echo "⚠️  $skill_name: Missing 'version' in frontmatter (recommended)"
    fi
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All skill files are valid"
    exit 0
else
    echo "❌ Found $ERRORS error(s)"
    exit 1
fi
