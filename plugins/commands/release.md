---
description: Create a new release with version bumping, tagging, changelog, and publishing
---

# Create Release

Create a new release for the project, including version bumping, tagging, and publishing.

## Process:

1. **Pre-release checks:**
   ```
   ## Pre-release Checklist
   - [ ] All tests passing
   - [ ] Linting passing
   - [ ] Build successful
   - [ ] Documentation updated
   - [ ] CHANGELOG.md updated
   - [ ] On correct branch (main/master/release)
   ```

2. **Determine version:**
   - Check current version in package.json, pyproject.toml, *.csproj, etc.
   - Review changes since last release
   - Suggest version bump based on semver:
     - BREAKING CHANGE → Major (X.0.0)
     - feat: → Minor (x.Y.0)
     - fix: → Patch (x.y.Z)
   - Ask user to confirm version

3. **Update version numbers:**
   
   **Node.js:**
   - Update package.json version
   - Update package-lock.json: `npm install`
   
   **Python:**
   - Update pyproject.toml or setup.py
   - Update __version__ in package __init__.py
   
   **.NET:**
   - Update Version in .csproj files
   - Update AssemblyInfo if present
   
   **Update other files:**
   - README.md badges
   - Documentation references
   - API version endpoints

4. **Generate/update changelog:**
   - Run the changelog command
   - Ensure changelog includes new version
   - Review and edit if needed

5. **Commit version changes:**
   ```bash
   git add -A
   git commit -m "chore: release v${VERSION}"
   ```

6. **Create git tag:**
   ```bash
   git tag -a v${VERSION} -m "Release v${VERSION}"
   ```

7. **Build release artifacts:**
   
   **Node.js:**
   - `npm run build`
   - `npm pack` for libraries
   
   **Python:**
   - `python -m build`
   - Generate wheel and sdist
   
   **.NET:**
   - `dotnet build --configuration Release`
   - `dotnet pack --configuration Release`

8. **Publish to package registry:**
   
   **NPM:**
   ```bash
   npm publish
   # or with scope
   npm publish --access public
   ```
   
   **PyPI:**
   ```bash
   python -m twine upload dist/*
   ```
   
   **NuGet:**
   ```bash
   dotnet nuget push *.nupkg --source nuget.org
   ```

9. **Push to git remote:**
   ```bash
   git push origin main
   git push origin v${VERSION}
   ```

10. **Create GitHub release:**
    ```bash
    gh release create v${VERSION} \
      --title "Release v${VERSION}" \
      --notes-file CHANGELOG.md \
      --target main
    ```
    
    Or with artifacts:
    ```bash
    gh release create v${VERSION} \
      --title "Release v${VERSION}" \
      --notes-file CHANGELOG.md \
      --target main \
      ./dist/*
    ```

## Release Types:

### Standard Release:
- Full version bump
- Tag and publish
- Update all registries

### Pre-release:
- Alpha: v1.0.0-alpha.1
- Beta: v1.0.0-beta.1
- RC: v1.0.0-rc.1
- Use npm publish --tag next

### Hotfix:
- Branch from last release tag
- Fix issue
- Patch version bump
- Merge back to main

## Output Format:
```
## Release Summary

### Version: v${VERSION}

### ✅ Completed:
- Version bumped in [files]
- Changelog updated
- Git tag created: v${VERSION}
- Artifacts built successfully
- Published to [npm/pypi/nuget]
- GitHub release created

### 📦 Published packages:
- NPM: https://www.npmjs.com/package/[name]
- PyPI: https://pypi.org/project/[name]

### 🔗 Links:
- GitHub Release: [url]
- Changelog: [url]

### Next steps:
- Announce release in Discord/Slack
- Update documentation site
- Monitor for issues
```

## Important:
- Never release from feature branches
- Always run full test suite first
- Tag AFTER successful tests
- Keep changelog up to date
- Use semantic versioning
- Test in staging environment if available
- Have rollback plan ready