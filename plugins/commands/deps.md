---
description: Update project dependencies safely with security and breaking change analysis
---

# Update Dependencies

Update project dependencies safely and systematically.

## Process

1. **Detect package manager and current state:**
   - Node.js: npm, yarn, pnpm, bun (check package.json)
   - Python: pip, poetry, pipenv, uv (check requirements.txt, pyproject.toml)
   - .NET: NuGet (check *.csproj files)
   - Ruby: Bundler (check Gemfile)

2. **Check for outdated dependencies:**
   - Node.js: `npm outdated`, `yarn outdated`
   - Python: `pip list --outdated`, `poetry show --outdated`
   - .NET: `dotnet list package --outdated`
   - Ruby: `bundle outdated`

3. **Analyze update safety:**

   ```
   ## Dependency Update Analysis
   
   ### 📦 Current outdated packages:
   
   #### Safe updates (patch/minor):
   - package-a: 1.2.3 → 1.2.5 (patch)
   - package-b: 2.1.0 → 2.3.0 (minor)
   
   #### Breaking changes (major):
   - package-c: 3.0.0 → 4.0.0 (major)
     - Breaking: [check changelog]
   
   #### Security updates:
   - package-d: Has known vulnerability (CVE-XXXX)
   
   Proceed with updates? [all/safe/security/none]
   ```

4. **Update strategy:**

   **For patch/minor updates:**
   - Update directly
   - Run tests after each group

   **For major updates:**
   - Update one at a time
   - Check migration guide/changelog
   - Update code if needed
   - Run tests thoroughly

   **For security updates:**
   - Prioritize and update immediately
   - Even if major version change

5. **Execute updates:**
   - Node.js: `npm update`, `npm install package@latest`
   - Python: `pip install --upgrade`, `poetry update`
   - .NET: `dotnet add package PackageName --version X.Y.Z`
   - Ruby: `bundle update`

6. **Verify updates:**
   - Run all tests
   - Run linters
   - Check for deprecation warnings
   - Test critical user paths manually if needed
   - Review changelogs for important notes

7. **Lock file management:**
   - Commit lock files (package-lock.json, poetry.lock, etc.)
   - Ensure reproducible builds

## Update Commands

### Node.js

- Check: `npm outdated`, `npm audit`
- Update: `npm update`, `npm install package@version`
- Update all: `npm update --save`

### Python

- Check: `pip list --outdated`
- Update: `pip install --upgrade package`
- With poetry: `poetry update`, `poetry update package`

### .NET

- Check: `dotnet list package --outdated`
- Update: `dotnet add package PackageName --version X.Y.Z`

### Ruby

- Check: `bundle outdated`
- Update: `bundle update`, `bundle update gem-name`

## Output Format

```
## Dependency Update Summary

### ✅ Successfully updated:
- package-a: 1.2.3 → 1.2.5
- package-b: 2.1.0 → 2.3.0

### 🔒 Security fixes:
- package-d: Fixed CVE-XXXX

### ⚠️ Skipped (need manual review):
- package-c: Major version (3.0.0 → 4.0.0)
  - Migration guide: [link]

### Test results: ✅ All passing

### Next steps:
- Review major version updates
- Consider updating dev dependencies
```

## Important

- Always run tests after updates
- Update incrementally, not all at once
- Read changelogs for major updates
- Keep security updates current
- Don't update right before a release
- Document any required code changes
