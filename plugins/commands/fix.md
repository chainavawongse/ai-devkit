---
description: Automatically fix linting and type errors using just commands with language-specific fallbacks
---

# Fix Linting and Type Errors

Automatically fix linting and type errors in the codebase.

## Process:

1. **Detect project type and tools:**
   - Check for ESLint, Prettier (JavaScript/TypeScript)
   - Check for Black, Ruff, Flake8, MyPy (Python)
   - Check for StyleCop, dotnet format (.NET)
   - Check for RuboCop (Ruby)
   - Check Makefile for lint/format targets

2. **Run diagnostic commands first:**
   - Run linters in check mode to see all issues
   - Run type checkers to identify type errors
   - Count total issues before fixing

3. **Auto-fix what's possible:**
   - For JavaScript/TypeScript:
     - `npx eslint --fix .` or `npm run lint:fix`
     - `npx prettier --write .` or `npm run format`
   - For Python:
     - `black .` for formatting
     - `ruff --fix .` for linting fixes
     - `isort .` for import sorting
   - For .NET:
     - `dotnet format`
   - For Ruby:
     - `rubocop -a` for safe auto-corrections

4. **Handle remaining issues:**
   - Re-run diagnostic commands
   - For issues that can't be auto-fixed:
     - Read the specific files
     - Manually fix type errors
     - Fix linting issues that require code changes
     - Update or suppress warnings if appropriate

5. **Verify fixes:**
   - Run all checks again
   - Ensure no new issues introduced
   - Run tests to ensure nothing broke

## Common Commands:

### JavaScript/TypeScript:
- Check: `npm run lint`, `npm run typecheck`
- Fix: `npm run lint:fix`, `npm run format`

### Python:
- Check: `ruff check`, `mypy .`, `black --check .`
- Fix: `ruff --fix`, `black .`, `isort .`

### .NET:
- Check: `dotnet build`
- Fix: `dotnet format`

### Makefile:
- Often: `make lint`, `make format`, `make fix`

## Output:
```
## Fix Summary

### 🔧 Auto-fixed:
- [X] linting issues in [Y] files
- Formatted [Z] files

### ✅ Manually fixed:
- `file.ts:10` - Fixed type error: [description]
- `file.py:25` - Fixed import order

### ⚠️ Remaining issues:
- `file.js:30` - [Issue that needs human decision]

### Next steps:
[What the user should do next, if anything]
```

## Important:
- Always run tests after fixes to ensure nothing broke
- Don't suppress warnings without good reason
- Fix root causes, not symptoms
- Preserve code functionality while fixing style