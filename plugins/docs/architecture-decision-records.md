# Architecture Decision Records

Guidelines for creating and maintaining Architecture Decision Records (ADRs).

## Overview

ADRs document significant architectural decisions, providing historical context for why certain choices were made. They help future developers understand the reasoning behind the current architecture.

**ADRs are for history tracking** - they capture decisions at a point in time, not living documentation that changes.

## When to Write an ADR

Write an ADR when:

- Introducing a new technology or framework
- Making significant architectural changes
- Choosing between multiple valid approaches
- Changing established patterns
- Making decisions that will be hard to reverse

**Don't write an ADR for:**

- Bug fixes
- Minor refactors
- Standard implementation choices
- Decisions already covered by existing ADRs

## Location

ADRs live in the repository they affect:

```text
docs/
└── decisions/
    ├── 0001-use-react-query-for-server-state.md
    ├── 0002-adopt-clean-architecture.md
    └── 0003-switch-to-playwright-for-e2e.md
```

## Naming Convention

```text
NNNN-title-of-decision.md
```

- `NNNN` - Sequential 4-digit number (0001, 0002, etc.)
- `title-of-decision` - Lowercase, hyphen-separated summary

## Template (MADR Format)

Based on the [MADR](https://adr.github.io/madr/) (Markdown Architectural Decision Records) format:

```markdown
# [short title of solved problem and solution]

## Status

[Proposed | Accepted | Deprecated | Superseded by [ADR-NNNN](NNNN-title.md)]

## Context

[Describe the context and problem statement. What is the issue that we're seeing that is motivating this decision or change?]

## Decision

[Describe the change that we're proposing or have agreed to implement.]

## Consequences

### Positive

- [e.g., Improved developer experience]
- [e.g., Better performance]

### Negative

- [e.g., Learning curve for team]
- [e.g., Migration effort required]

### Neutral

- [e.g., Requires updating CI/CD pipeline]

## Alternatives Considered

### [Alternative 1]

[Description of alternative]

- **Pros:** [advantages]
- **Cons:** [disadvantages]
- **Why not chosen:** [reason]

### [Alternative 2]

[Description of alternative]

- **Pros:** [advantages]
- **Cons:** [disadvantages]
- **Why not chosen:** [reason]
```

## Example ADR

```markdown
# Use React Query for Server State Management

## Status

Accepted

## Context

Our React applications currently use Redux for all state management, including server
state (data fetched from APIs). This leads to:

- Boilerplate code for fetching, caching, and updating data
- Manual cache invalidation that is error-prone
- Complex state shape with loading/error states mixed with data
- Inconsistent patterns across different features

We need a solution that simplifies data fetching while providing good caching,
background updates, and error handling.

## Decision

We will use React Query (TanStack Query) for server state management in all new
React projects and when significantly refactoring existing features.

Redux will continue to be used for:
- Complex client-only state
- Cross-cutting concerns (auth state, user preferences)
- Legacy code that doesn't justify refactoring

## Consequences

### Positive

- Automatic caching and background refetching
- Built-in loading and error states
- Optimistic updates out of the box
- Reduced boilerplate (no actions/reducers for API calls)
- Better DevTools for debugging data fetching

### Negative

- Learning curve for developers unfamiliar with React Query
- Two state management paradigms in the codebase during transition
- Need to update existing patterns in documentation

### Neutral

- Requires updating testing patterns for components that fetch data
- Bundle size increase (~12kb gzipped)

## Alternatives Considered

### Continue with Redux + Redux Toolkit Query

- **Pros:** Already using Redux, familiar to team
- **Cons:** Still requires more boilerplate than React Query, less active community
- **Why not chosen:** React Query has better DX and is more widely adopted

### SWR

- **Pros:** Similar API to React Query, lighter weight
- **Cons:** Fewer features (no mutations API, less powerful DevTools)
- **Why not chosen:** React Query is more feature-complete for our needs

### Apollo Client

- **Pros:** Excellent caching, good DevTools
- **Cons:** Designed for GraphQL, overhead for REST APIs
- **Why not chosen:** Our APIs are REST-based
```

## Status Lifecycle

```text
Proposed → Accepted → [Deprecated | Superseded]
```

- **Proposed:** Under discussion, not yet implemented
- **Accepted:** Agreed upon and being/has been implemented
- **Deprecated:** No longer recommended, but not replaced
- **Superseded:** Replaced by a newer decision (link to new ADR)

## Best Practices

### Keep ADRs Immutable

Once accepted, don't modify the content of an ADR. If the decision changes:
1. Create a new ADR
2. Mark the old one as "Superseded by [new ADR link]"

### Be Specific About Context

Future readers need to understand:
- What problem you were solving
- What constraints existed at the time
- What alternatives were available

### Document the "Why"

The decision itself is often obvious in hindsight. Focus on:
- Why this solution over alternatives
- What trade-offs were accepted
- What assumptions were made

### Include Dissenting Views

If there was significant debate:
- Mention the main counterarguments
- Explain why they weren't decisive

## Reviewing ADRs

ADRs should be reviewed as part of:
- PR review for the implementing change
- Architecture review meetings
- Onboarding new team members to a codebase

## Quick Reference

| Section | Purpose |
|---------|---------|
| Status | Current state of the decision |
| Context | Problem and constraints |
| Decision | What we chose to do |
| Consequences | Trade-offs accepted |
| Alternatives | Other options considered |

## Related

- [MADR Template](https://adr.github.io/madr/)
- [ADR GitHub Organization](https://adr.github.io/)
