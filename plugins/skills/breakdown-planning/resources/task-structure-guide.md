# Task Structure Guide

## Core Task Breakdown Rules

### The Iron Law: One Task = One Complete Feature with TDD

Every task must include BOTH tests AND implementation. Never split them.

**NEVER do this (BAD):**

```
Task 1: Write tests for UserAuthService
Task 2: Implement UserAuthService
```

**ALWAYS do this (GOOD):**

```
Task 1: Implement UserAuthService (includes writing tests first via TDD)
```

### Task Completeness

**Description:** A task is only complete when both functionality AND tests are done

**Definition of done:**

- Feature code is implemented
- All tests are written and passing
- Edge cases are covered
- Code is refactored and clean

**Enforcement:** A task cannot be marked complete without its tests

### Exceptions to TDD Task Structure

There are rare cases where separate test tasks are appropriate:

```yaml
rule: "Never create tasks titled 'Write tests for X' or 'Add test coverage'"
exceptions:
  - "Client explicitly requests separate test tasks"
  - "Retrofitting tests to legacy code without changes"
  - "Test infrastructure or framework setup"
```

## Task Isolation Requirements

### Single Responsibility

Each task must represent an isolated, testable piece of functionality.

**Requirements:**

- Single responsibility - one feature or behavior
- Clear inputs and outputs
- Independently deployable when possible
- Can be tested in isolation from other tasks

### Good Task Examples

```
✓ Implement user authentication with JWT tokens
✓ Add email validation to registration form
✓ Create calculation engine for tax computation
✓ Build API endpoint for fetching user profiles
✓ Implement password reset flow with email verification
✓ Add rate limiting middleware to API endpoints
✓ Create error handling middleware with logging
```

### Bad Task Examples

```
✗ Write tests for user service
  Why: Testing separate from functionality

✗ Implement entire user management system
  Why: Too broad - needs breakdown

✗ Fix stuff in authentication
  Why: Too vague - unclear scope

✗ Add test coverage
  Why: Testing as afterthought

✗ Update user endpoints
  Why: Vague - which endpoints, what changes?

✗ Refactor authentication logic
  Why: Too broad - what specific improvements?
```

## Task Sizing Guidelines

### The Golden Rule

Tasks should be small enough to complete with tests in one cycle.

**Guidelines:**

- 1-3 days maximum including tests
- If larger, break into smaller testable chunks
- Each chunk should deliver working, tested functionality

### Signs a Task is Too Large

- Takes more than 3 days
- Touches more than 5 files
- Has more than 3 dependencies
- Requires multiple rounds of testing
- Cannot be code reviewed in one session

**Solution:** Break into smaller, independently deliverable features

### Signs a Task is Too Small

- Takes less than 1 hour
- Touches only 1 line
- No meaningful test to write
- Trivial change (typo fix, formatting)

**Solution:** Combine with related tasks or handle as quick fix

## Task Description Structure

### Required Sections

Every task description must include:

1. **Objective** - What is being built
2. **Specification Context** - Why it's needed (user stories)
3. **Technical Plan Guidance** - How to build it (architecture)
4. **TDD Implementation Checklist** - Step-by-step workflow
5. **Acceptance Criteria** - Definition of done
6. **Files to Touch** - Scope of changes
7. **Dependencies** - Blocking relationships

### Example Complete Task Description

```markdown
## Objective
Implement UserAuthService with full TDD workflow (tests first, then implementation).

## Specification Context (WHAT we're building)
From parent issue Specification section:
- User story: As a user, I want to log in with email/password so I can access my account
- Expected behavior: Valid credentials return JWT token, invalid return 401 error
- Success criteria: 100% test coverage, token expires in 24h, rate limited to 5 attempts/min
- Edge cases: Account locked after 5 failures, case-insensitive email

## Technical Plan Guidance (HOW to build it)
From parent issue Technical Plan section:
- Component: services/auth/UserAuthService.ts
- Responsibilities: Authenticate users, issue JWT tokens, handle rate limiting
- Dependencies: UserRepository, TokenService, RateLimiter
- Pattern: Follow existing pattern in services/user/UserService.ts
- Error handling: Return Result<Token, AuthError> type
- Testing approach: Unit tests for service, integration tests for full flow

## TDD Implementation Checklist
Follow test-driven-development skill (devkit:test-driven-development):

**RED Phase:**
- [ ] Write test for successful authentication - verify it fails
- [ ] Write test for invalid credentials - verify it fails
- [ ] Write test for account lockout - verify it fails
- [ ] Write test for rate limiting - verify it fails

**GREEN Phase:**
- [ ] Implement minimal code to pass authentication test
- [ ] Implement minimal code to pass invalid credentials test
- [ ] Implement minimal code to pass lockout test
- [ ] Implement minimal code to pass rate limit test
- [ ] All tests passing

**REFACTOR Phase:**
- [ ] Check for code smells (duplication, long functions)
- [ ] Refactor while keeping tests green
- [ ] Final verification: all tests still passing

## Acceptance Criteria
- [ ] All tests written and passing
- [ ] Follows pattern from services/user/UserService.ts
- [ ] Error handling uses Result<T, E> type
- [ ] Code reviewed and approved
- [ ] Committed with clear message

## Files to Touch
- Create: tests/services/auth/UserAuthService.test.ts
- Create: services/auth/UserAuthService.ts
- Reference: services/user/UserService.ts

## Estimated Complexity
Medium (4-6 hours)

## Dependencies
- Blocked by: USER-123 (UserRepository implementation)
- Blocked by: USER-124 (TokenService implementation)
- Parent issue: USER-100 (see full Specification + Technical Plan)
- Technical Plan Phase: 2 (Core Services)
```

## Task Dependencies

### Identifying Dependencies

**From Technical Plan:**

- **Blocks:** Other components that depend on this one
- **Blocked by:** Components this one depends on
- **Parallel:** Components in same phase with no interdependencies

### Dependency Types

1. **Hard dependency:** Cannot start until blocker completes
2. **Soft dependency:** Can start but cannot finish until blocker completes
3. **Data dependency:** Needs specific data/schema from blocker
4. **Interface dependency:** Needs interface definition from blocker

### Examples

```
Hard dependency:
  AuthService → requires UserRepository (cannot start without it)

Soft dependency:
  API endpoint → can write tests before service ready, needs service for integration

Data dependency:
  SessionService → needs User schema from UserModel

Interface dependency:
  AuthController → needs IAuthService interface before implementing
```

## Task Anti-Patterns

### 1. The Test Splitter

**Anti-pattern:**

```
Task 1: Write tests for feature X
Task 2: Implement feature X
```

**Why it's bad:**

- Violates TDD principle (test-first)
- Creates false dependency
- Developer might implement before testing
- Doubles number of tasks unnecessarily

**Solution:**

```
Task 1: Implement feature X (TDD)
  - [ ] RED: Write failing tests
  - [ ] GREEN: Minimal implementation
  - [ ] REFACTOR: Clean up
```

### 2. The Mega Task

**Anti-pattern:**

```
Task: Implement entire user management system
```

**Why it's bad:**

- Too broad to estimate
- Cannot be completed in one cycle
- Hard to test comprehensively
- Blocks too many other tasks

**Solution:**

```
Task 1: Implement user registration (TDD)
Task 2: Implement user authentication (TDD)
Task 3: Implement user profile management (TDD)
Task 4: Implement password reset flow (TDD)
```

### 3. The Vague Task

**Anti-pattern:**

```
Task: Fix authentication issues
Task: Update user endpoints
Task: Improve error handling
```

**Why it's bad:**

- Unclear scope
- Cannot write clear acceptance criteria
- Hard to know when done
- Cannot estimate effort

**Solution:**

```
Task: Fix JWT token expiration not being validated (TDD)
Task: Add pagination to GET /users endpoint (TDD)
Task: Implement error logging middleware (TDD)
```

### 4. The Test Afterthought

**Anti-pattern:**

```
Task: Implement feature X
  - [ ] Write code
  - [ ] Add tests if time permits
```

**Why it's bad:**

- Tests become optional
- Hard to retrofit tests
- Implementation not driven by tests
- Lower quality code

**Solution:**

```
Task: Implement feature X (TDD)
  - [ ] RED: Write failing tests (required)
  - [ ] GREEN: Minimal implementation
  - [ ] REFACTOR: Clean up
```

### 5. The Kitchen Sink

**Anti-pattern:**

```
Task: Implement authentication, authorization, rate limiting, logging, and monitoring
```

**Why it's bad:**

- Multiple responsibilities
- Hard to test in isolation
- Cannot be parallelized
- High risk of scope creep

**Solution:**

```
Task 1: Implement authentication service (TDD)
Task 2: Implement authorization middleware (TDD)
Task 3: Implement rate limiting middleware (TDD)
Task 4: Implement logging middleware (TDD)
Task 5: Implement monitoring integration (TDD)
```

## Special Cases

### Infrastructure Tasks (Chores)

**Example:**

```
Task: Set up test infrastructure for E2E tests
  - [ ] Install Playwright
  - [ ] Configure test environment
  - [ ] Create example test
  - [ ] Document usage
```

**Note:** Infrastructure tasks may not follow strict TDD (no tests for test infrastructure), but should still be small and focused.

### Bug Fix Tasks

**Example:**

```
Task: Fix JWT token not expiring after 24h (TDD)
  - [ ] RED: Write test reproducing bug
  - [ ] GREEN: Fix implementation
  - [ ] REFACTOR: Clean up
```

**Note:** Bug fixes MUST start with reproduction test (RED phase).

### Refactoring Tasks (Chores)

**Example:**

```
Task: Refactor UserService to use dependency injection
  - [ ] Ensure all existing tests pass (baseline)
  - [ ] Refactor service structure
  - [ ] Verify all tests still pass
```

**Note:** Refactoring starts GREEN (tests passing), stays GREEN (tests never break).

## Checklist: Task Quality Review

Before creating a task, verify:

- [ ] Task has single, clear responsibility
- [ ] Task includes BOTH tests and implementation (for features/bugs)
- [ ] Task can be completed in 1-3 days
- [ ] Task has clear acceptance criteria
- [ ] Dependencies are identified and documented
- [ ] TDD checklist included (RED-GREEN-REFACTOR)
- [ ] Files to touch are specified
- [ ] Pattern/reference code identified
- [ ] Appropriate label assigned (feature/chore/bug)
- [ ] Task is parallelizable when possible
