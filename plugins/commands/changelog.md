---
description: Generate changelog from git commits organized by conventional commit types
---

# Generate Changelog

Generate a changelog from git commits and organize them into a readable format.

## Process:

1. **Determine version range:**
   - Check for existing tags: `git tag --list`
   - Find last release tag or ask user for range
   - Default to commits since last tag: `git describe --tags --abbrev=0`

2. **Gather commits:**
   ```bash
   # Since last tag
   git log $(git describe --tags --abbrev=0)..HEAD --oneline
   
   # Or between tags
   git log v1.0.0..v2.0.0 --oneline
   
   # Or since date
   git log --since="2024-01-01" --oneline
   ```

3. **Analyze commit messages:**
   - Group by type (feat, fix, chore, docs, refactor, test, perf)
   - Identify breaking changes (look for BREAKING CHANGE or !)
   - Extract scope if using conventional commits
   - Note PR numbers if present

4. **Check for additional context:**
   - Closed issues: `gh issue list --state closed --limit 50`
   - Merged PRs: `gh pr list --state merged --limit 50`
   - Link commits to issues/PRs where possible

5. **Generate changelog structure:**
   ```markdown
   # Changelog
   
   ## [Version] - YYYY-MM-DD
   
   ### 🚨 Breaking Changes
   - Description of breaking change
   
   ### ✨ Features
   - feat: New feature description (#PR)
   - feat(scope): Another feature
   
   ### 🐛 Bug Fixes
   - fix: Bug fix description (#PR)
   - fix(scope): Another fix
   
   ### 📚 Documentation
   - docs: Documentation updates
   
   ### 🔧 Maintenance
   - chore: Dependency updates
   - refactor: Code improvements
   
   ### ⚡ Performance
   - perf: Performance improvement
   
   ### Contributors
   - @user1, @user2
   ```

6. **Enhance descriptions:**
   - Rewrite commit messages for clarity
   - Add context for significant changes
   - Include migration instructions for breaking changes
   - Add links to relevant PRs/issues

7. **Version determination:**
   If no version specified, suggest based on changes:
   - Breaking changes → Major version bump (X.0.0)
   - New features → Minor version bump (x.Y.0)
   - Only fixes → Patch version bump (x.y.Z)

## Conventional Commit Types:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `style:` Code style (formatting)
- `refactor:` Code change that neither fixes nor adds
- `perf:` Performance improvement
- `test:` Adding tests
- `chore:` Maintenance tasks
- `build:` Build system changes
- `ci:` CI configuration changes

## Output Format:

### For file output (CHANGELOG.md):
- Update existing CHANGELOG.md if it exists
- Add new version section at the top
- Keep previous versions intact

### For display:
```
## Changelog Generated

### Suggested version: X.Y.Z
Based on: [breaking/features/fixes]

### Preview:
[Show the generated changelog section]

### Actions:
- [ ] Update CHANGELOG.md
- [ ] Create git tag: v.X.Y.Z
- [ ] Create GitHub release

Would you like me to update the CHANGELOG.md file?
```

## Important:
- Keep descriptions user-focused (what changed, not how)
- Group similar changes together
- Highlight breaking changes prominently
- Include upgrade/migration instructions
- Credit contributors
- Use clear, concise language
- Link to PRs/issues for more detail