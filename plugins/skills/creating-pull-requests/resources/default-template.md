# Default PR Template

Use this template when no custom PR template is found in the repository.

## Template

```markdown
# Pull Request Description

{Summary of the change and which issue is fixed or feature is added. Provide relevant motivation and context.}

Implements {TICKET-ID}

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] This change requires a documentation update

## How Has This Been Tested?

{Describe the tests that you ran to verify your changes. Provide instructions so we can reproduce.}

- Test A: {description}
- Test B: {description}

## Checklist

- [ ] I have performed a self-review of my own code
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Usage Notes

### Summary Section
- Lead with the ticket ID (e.g., "Implements PAS-123")
- Explain what changed and why
- Keep it concise but informative

### Type of Change
- Check exactly one primary type
- Check documentation update if README, docs, or comments were updated

### Testing Section
- List specific tests added or run
- Include steps to reproduce manual testing if applicable
- Reference test files if helpful

### Checklist
- All items should be checked before requesting review
- If an item doesn't apply, explain why in the description

## When to Use Extended Sections

For complex PRs, you may add:

### Architecture Diagrams
When introducing new components or significant refactoring:
```mermaid
{diagram showing component relationships}
```

### Breaking Changes
When changes affect existing functionality:
- List affected APIs or interfaces
- Provide migration instructions

### Screenshots
When changes affect UI:
- Include before/after screenshots
- Show key user flows
