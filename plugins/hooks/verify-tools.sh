#!/bin/bash

# Script to verify required development tools are installed
# Usage: ./scripts/verify-tools.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
ALL_INSTALLED=true

echo "================================================"
echo "  Development Tools Verification"
echo "================================================"
echo ""

# Function to check if a command exists
check_tool() {
    local tool_name=$1
    local command_name=$2
    local install_hint=$3

    if command -v "$command_name" &> /dev/null; then
        local version
        version=$($command_name --version 2>&1 | head -n1)
        echo -e "${GREEN}✓${NC} $tool_name is installed"
        echo "  Version: $version"
    else
        echo -e "${RED}✗${NC} $tool_name is NOT installed"
        echo -e "  ${YELLOW}Install:${NC} $install_hint"
        ALL_INSTALLED=false
    fi
    echo ""
}

# Check each tool
check_tool "ripgrep (rg)" "rg" "cargo install ripgrep  # or: apt install ripgrep / brew install ripgrep"
check_tool "fd" "fd" "cargo install fd-find  # or: apt install fd-find / brew install fd"
check_tool "uv" "uv" "curl -LsSf https://astral.sh/uv/install.sh | sh"
check_tool "tree" "tree" "apt install tree  # or: brew install tree"
check_tool "jq" "jq" "apt install jq  # or: brew install jq"
check_tool "gh" "gh" "https://cli.github.com/  # or: apt install gh / brew install gh"
check_tool "just" "just" "uv tool install rust-just  # or: cargo install just / brew install just"
check_tool "pre-commit" "pre-commit" "pip install pre-commit  # or: brew install pre-commit"

echo "================================================"
if [ "$ALL_INSTALLED" = true ]; then
    echo -e "${GREEN}✓ All required tools are installed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tools are missing. Please install them.${NC}"
    exit 1
fi
