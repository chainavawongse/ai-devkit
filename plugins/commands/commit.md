---
description: Create git commits for session changes with clear, atomic commit messages
---

# Commit Changes

Create git commits for the changes made during this session.

## Process

1. **Run formatting first (REQUIRED):**
   - Check if a justfile exists in the repository (look for `justfile` or `Justfile`)
   - If justfile exists, check available recipes with `just --list`
   - Run `just fmt` if available, otherwise run `just format` if available
   - If neither exists, skip this step
   - Stage any formatting changes that were made

2. **Think about what changed:**
   - Review the conversation history and understand what was accomplished
   - Run `git status` to see current changes
   - Run `git diff` to understand the modifications
   - Consider whether changes should be one commit or multiple logical commits

3. **Plan your commit(s):**
   - Identify which files belong together
   - Draft clear, descriptive commit messages
   - Use imperative mood in commit messages
   - Focus on why the changes were made, not just what

4. **Present your plan to the user:**
   - List the files you plan to add for each commit
   - Show the commit message(s) you'll use
   - Ask: "I plan to create [N] commit(s) with these changes. Shall I proceed?"

5. **Execute upon confirmation:**
   - Use `git add` with specific files (never use `-A` or `.`)
   - Create commits with your planned messages
   - Show the result with `git log --oneline -n [number]`

## Important

- Write commit messages as if the user wrote them
- Keep commits focused and atomic when possible
- Group related changes together

## Remember

- You have the full context of what was done in this session
- The user trusts your judgment - they asked you to commit
