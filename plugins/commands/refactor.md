---
description: Refactor code to improve structure and readability while preserving behavior
---

# Refactor Code

Refactor code to improve its structure, readability, and maintainability without changing its behavior.

## Process:

1. **Understand the scope:**
   - Ask the user what they want to refactor if not specified
   - Identify the files/components to refactor
   - Read the code thoroughly to understand current behavior
   - Note existing tests that cover this code

2. **Ensure safety net:**
   - Run existing tests to ensure they pass
   - If no tests exist, consider writing characterization tests first
   - Save current test output for comparison

3. **Plan the refactoring:**
   Present the refactoring plan:
   ```
   ## Refactoring Plan
   
   ### Current Issues:
   - [Problem 1: e.g., duplicated code]
   - [Problem 2: e.g., unclear naming]
   
   ### Proposed Changes:
   1. [Change 1: e.g., extract common logic to function]
   2. [Change 2: e.g., rename variables for clarity]
   
   ### Risk Assessment:
   - Test coverage: [Good/Partial/None]
   - Complexity: [Low/Medium/High]
   
   Shall I proceed with these refactoring steps?
   ```

4. **Execute refactoring (one step at a time):**
   
   Common refactoring patterns:
   - **Extract Method**: Pull out code into a well-named function
   - **Rename**: Give better names to variables, functions, classes
   - **Extract Variable**: Replace expressions with meaningful variables
   - **Inline**: Remove unnecessary indirection
   - **Move**: Relocate code to more appropriate location
   - **Replace Magic Numbers**: Use named constants
   - **Simplify Conditionals**: Make if-statements clearer
   - **Remove Dead Code**: Delete unused code
   - **DRY (Don't Repeat Yourself)**: Eliminate duplication

5. **After each refactoring step:**
   - Run tests to ensure behavior unchanged
   - Run linters to ensure code quality
   - Commit if tests pass (small, atomic commits)

6. **Review the changes:**
   - Show a summary of all refactoring done
   - Run tests one final time
   - Check performance if applicable
   - Ensure documentation is updated if needed

## Refactoring Checklist:
- [ ] Tests pass before starting
- [ ] Each refactoring step is small
- [ ] Tests pass after each step
- [ ] No behavior changes
- [ ] Code is more readable
- [ ] Code follows project patterns
- [ ] No performance degradation
- [ ] Documentation updated

## Common Code Smells to Fix:
- Long methods (>20 lines)
- Large classes (>200 lines)
- Long parameter lists (>3 params)
- Duplicate code
- Complex conditionals
- Feature envy (method uses another class too much)
- Inappropriate intimacy (classes know too much about each other)
- Comments explaining bad code (fix the code instead)

## Output Format:
```
## Refactoring Complete

### Changes Made:
1. ✅ [Refactoring 1]: [Brief description]
   - Files: `path/to/file.js`
   - Lines affected: 10-25

2. ✅ [Refactoring 2]: [Brief description]
   - Files: `path/to/other.js`
   - Lines affected: 30-45

### Improvements:
- Reduced complexity from X to Y
- Eliminated N lines of duplicate code
- Improved readability score

### All tests: ✅ PASSING
```

## Important:
- Never change behavior during refactoring
- Make one type of change at a time
- Commit frequently with clear messages
- If tests fail, revert and try smaller steps
- Focus on clarity over cleverness