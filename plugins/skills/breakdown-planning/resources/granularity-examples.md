# Granularity Decision Examples

## How to Choose Task Granularity

**Default strategy:** Lean fine-grained unless there's a clear reason for larger tasks.

**Factors to consider:**

1. Number of components in Technical Plan
2. Number of integration points
3. Team size and parallelization needs
4. Risk level (security, data integrity)
5. Reusability requirements

## Example 1: Simple CRUD API (Medium-grained)

### Context

```yaml
Feature: Blog Post Management API
Components: 2 (model, controller)
Integration points: 1 (database)
Risk level: Low
Team size: 1-2 developers
```

### Decision: Medium-grained

**Rationale:**

- Simple architecture
- Few integration points
- Low risk
- Small team (parallelization not critical)

### Breakdown (3 sub-issues)

```
1. Implement BlogPost model and repository (TDD)
   - [ ] RED: Write tests for CRUD operations
   - [ ] GREEN: Implement model + repository
   - [ ] REFACTOR: Clean up
   Estimated: 4 hours

2. Implement BlogPost API endpoints (TDD)
   - [ ] RED: Write API integration tests
   - [ ] GREEN: Implement POST, GET, PUT, DELETE endpoints
   - [ ] REFACTOR: Clean up
   Estimated: 6 hours

3. Add API documentation (chore)
   - [ ] Generate OpenAPI spec
   - [ ] Add example requests
   - [ ] Update README
   Estimated: 2 hours
```

## Example 2: Authentication System (Fine-grained)

### Context

```yaml
Feature: User Authentication System
Components: 6 (user model, token service, auth middleware, login endpoint, register endpoint, refresh endpoint)
Integration points: 4 (database, cache, email, session)
Risk level: High (security-critical)
Team size: 3-4 developers
```

### Decision: Fine-grained

**Rationale:**

- Complex architecture
- Multiple integration points
- High risk (security-critical)
- Larger team (maximize parallelization)
- Components can be independently tested

### Breakdown (12 sub-issues)

```
Phase 1: Foundation (parallel)
1. Implement User model and repository (TDD)
   Dependencies: None
   Estimated: 4 hours

2. Implement TokenService for JWT operations (TDD)
   Dependencies: None
   Estimated: 4 hours

3. Implement PasswordHasher utility (TDD)
   Dependencies: None
   Estimated: 2 hours

Phase 2: Core Services (depends on Phase 1)
4. Implement AuthService with login logic (TDD)
   Dependencies: User model, TokenService, PasswordHasher
   Estimated: 6 hours

5. Implement SessionManager with Redis (TDD)
   Dependencies: User model
   Estimated: 4 hours

Phase 3: Middleware (depends on Phase 2)
6. Implement AuthMiddleware for protected routes (TDD)
   Dependencies: TokenService, SessionManager
   Estimated: 4 hours

Phase 4: API Endpoints (depends on Phases 2-3)
7. Implement POST /auth/register endpoint (TDD)
   Dependencies: AuthService
   Estimated: 4 hours

8. Implement POST /auth/login endpoint (TDD)
   Dependencies: AuthService
   Estimated: 4 hours

9. Implement POST /auth/refresh endpoint (TDD)
   Dependencies: TokenService, SessionManager
   Estimated: 3 hours

10. Implement POST /auth/logout endpoint (TDD)
    Dependencies: SessionManager
    Estimated: 2 hours

Phase 5: Integration & Security
11. Implement email verification flow (TDD)
    Dependencies: AuthService
    Estimated: 6 hours

12. Add rate limiting to auth endpoints (TDD)
    Dependencies: All endpoints
    Estimated: 3 hours
```

**Parallelization:**

- Phase 1: 3 tasks run in parallel
- Phase 2: 2 tasks run in parallel (after Phase 1)
- Phase 3: 1 task (after Phase 2)
- Phase 4: 4 tasks run in parallel (after Phases 2-3)
- Phase 5: 2 tasks run in parallel (after Phase 4)

## Example 3: UI Component Library (Fine-grained)

### Context

```yaml
Feature: Reusable UI Component Library
Components: 8 (Button, Input, Modal, Dropdown, Checkbox, Radio, Select, Textarea)
Integration points: 2 (theme system, accessibility)
Risk level: Medium
Team size: 2-3 developers
Reusability: High (used across entire application)
```

### Decision: Fine-grained

**Rationale:**

- Reusable components need isolation
- Each component independently testable
- Parallel development beneficial
- Consistency enforced through individual component quality

### Breakdown (10 sub-issues)

```
Phase 1: Foundation
1. Set up component library structure and Storybook (chore)
   Dependencies: None
   Estimated: 3 hours

2. Implement theme system with CSS variables (TDD)
   Dependencies: None
   Estimated: 4 hours

Phase 2: Basic Components (parallel)
3. Implement Button component with variants (TDD)
   Dependencies: Theme system
   Estimated: 4 hours

4. Implement Input component with validation (TDD)
   Dependencies: Theme system
   Estimated: 4 hours

5. Implement Checkbox component (TDD)
   Dependencies: Theme system
   Estimated: 3 hours

6. Implement Radio component (TDD)
   Dependencies: Theme system
   Estimated: 3 hours

Phase 3: Complex Components (parallel)
7. Implement Select component with search (TDD)
   Dependencies: Input component
   Estimated: 6 hours

8. Implement Dropdown component (TDD)
   Dependencies: Button component
   Estimated: 5 hours

9. Implement Modal component with animations (TDD)
   Dependencies: Button component
   Estimated: 5 hours

10. Implement Textarea component with auto-resize (TDD)
    Dependencies: Theme system
    Estimated: 4 hours
```

## Example 4: Data Migration Tool (Coarse-grained)

### Context

```yaml
Feature: Database Migration Script
Components: 1 (migration script)
Integration points: 1 (database)
Risk level: High (data integrity)
Team size: 1 developer
One-time use: Yes
```

### Decision: Coarse-grained

**Rationale:**

- Single component
- One integration point
- Must be tested as a whole (cannot split)
- Not reusable
- Single developer (no parallelization benefit)

### Breakdown (3 sub-issues)

```
1. Implement migration script with rollback (TDD)
   - [ ] RED: Write tests with test database
   - [ ] GREEN: Implement migration logic
   - [ ] GREEN: Implement rollback logic
   - [ ] REFACTOR: Clean up
   Estimated: 8 hours

2. Test migration on staging database (chore)
   - [ ] Run migration on staging
   - [ ] Verify data integrity
   - [ ] Test rollback
   - [ ] Document results
   Estimated: 4 hours

3. Create migration runbook (chore)
   - [ ] Document steps
   - [ ] Add rollback procedure
   - [ ] List verification queries
   Estimated: 2 hours
```

## Example 5: Payment Integration (Fine-grained)

### Context

```yaml
Feature: Stripe Payment Integration
Components: 5 (payment model, stripe service, webhook handler, payment endpoints, payment UI)
Integration points: 3 (Stripe API, database, email)
Risk level: Critical (financial transactions)
Team size: 2 developers
Compliance: PCI DSS requirements
```

### Decision: Fine-grained

**Rationale:**

- Critical system (financial transactions)
- External API integration (needs isolation for testing)
- Compliance requirements (need clear audit trail)
- Multiple integration points
- Can parallelize frontend and backend

### Breakdown (9 sub-issues)

```
Phase 1: Backend Foundation
1. Implement Payment model and repository (TDD)
   Dependencies: None
   Estimated: 4 hours

2. Implement StripeService wrapper (TDD)
   Dependencies: None
   Estimated: 6 hours

Phase 2: Payment Flow (depends on Phase 1)
3. Implement create payment intent endpoint (TDD)
   Dependencies: Payment model, StripeService
   Estimated: 5 hours

4. Implement confirm payment endpoint (TDD)
   Dependencies: Payment model, StripeService
   Estimated: 5 hours

5. Implement webhook handler for payment events (TDD)
   Dependencies: Payment model, StripeService
   Estimated: 6 hours

Phase 3: Refunds & Disputes
6. Implement refund processing (TDD)
   Dependencies: Payment model, StripeService
   Estimated: 5 hours

7. Implement dispute handling (TDD)
   Dependencies: Payment model, StripeService
   Estimated: 4 hours

Phase 4: Frontend (parallel with Phase 2-3)
8. Implement payment form UI with Stripe Elements (TDD)
   Dependencies: None (uses mock Stripe)
   Estimated: 6 hours

Phase 5: Integration
9. Implement end-to-end payment flow tests (TDD)
   Dependencies: All previous tasks
   Estimated: 8 hours
```

## Example 6: Real-time Chat Feature (Fine-grained)

### Context

```yaml
Feature: Real-time Chat System
Components: 7 (message model, websocket server, chat service, presence tracking, message endpoints, chat UI, notification service)
Integration points: 4 (WebSocket, database, Redis, push notifications)
Risk level: Medium
Team size: 3 developers
Real-time: Yes (requires WebSocket integration)
```

### Decision: Fine-grained

**Rationale:**

- Real-time system (needs careful testing)
- Multiple integration points
- Can parallelize backend, frontend, notifications
- Each component has distinct responsibilities

### Breakdown (11 sub-issues)

```
Phase 1: Foundation (parallel)
1. Implement Message model and repository (TDD)
   Dependencies: None
   Estimated: 4 hours

2. Set up WebSocket server infrastructure (chore)
   Dependencies: None
   Estimated: 4 hours

3. Set up Redis for presence tracking (chore)
   Dependencies: None
   Estimated: 3 hours

Phase 2: Core Services (depends on Phase 1)
4. Implement ChatService for message operations (TDD)
   Dependencies: Message model
   Estimated: 5 hours

5. Implement PresenceTracker with Redis (TDD)
   Dependencies: Redis setup
   Estimated: 4 hours

6. Implement WebSocket message handler (TDD)
   Dependencies: WebSocket server, ChatService
   Estimated: 6 hours

Phase 3: REST API (parallel, depends on Phase 2)
7. Implement GET /messages endpoint with pagination (TDD)
   Dependencies: ChatService
   Estimated: 4 hours

8. Implement POST /messages endpoint (TDD)
   Dependencies: ChatService
   Estimated: 3 hours

Phase 4: Frontend (parallel with Phase 3)
9. Implement chat UI with message list (TDD)
   Dependencies: None (uses mock data)
   Estimated: 6 hours

10. Implement WebSocket client integration (TDD)
    Dependencies: Chat UI
    Estimated: 5 hours

Phase 5: Notifications
11. Implement push notification service for offline users (TDD)
    Dependencies: ChatService
    Estimated: 5 hours
```

## Decision Matrix

Use this matrix to decide granularity:

| Factor | Fine-grained | Medium-grained | Coarse-grained |
|--------|--------------|----------------|----------------|
| **Components** | 5+ | 2-4 | 1 |
| **Integration points** | 3+ | 1-2 | 0-1 |
| **Risk level** | High/Critical | Medium | Low |
| **Team size** | 3+ | 2 | 1 |
| **Reusability** | High | Medium | Low/None |
| **Parallelization need** | High | Medium | Low |
| **Typical sub-issues** | 10-20 | 4-8 | 1-3 |

## When to Choose Each Granularity

### Choose Fine-grained when

- Complex system with many components
- High risk (security, financial, data integrity)
- Large team (3+ developers)
- High reusability requirements
- Many integration points
- Need for parallelization

### Choose Medium-grained when

- Moderate complexity
- Medium risk
- Small team (1-2 developers)
- Few integration points
- Standard CRUD operations

### Choose Coarse-grained when

- Simple, single-component task
- One-time scripts or migrations
- Single developer
- No reusability
- Cannot be meaningfully split

## Anti-pattern: Over-granularization

**Warning:** Too fine-grained can be counterproductive.

**Bad example:**

```
1. Create User model class
2. Add User model properties
3. Create User model constructor
4. Create User model methods
5. Write User model tests
```

**Why it's bad:**

- Creates artificial task boundaries
- High coordination overhead
- Each task too small to be meaningful
- Violates TDD principle (tests separate)

**Better:**

```
1. Implement User model (TDD)
   - [ ] RED: Write tests
   - [ ] GREEN: Implement model
   - [ ] REFACTOR: Clean up
```

## Summary

**Default:** Lean fine-grained when uncertain

**Key principle:** Each task should be:

- Independently testable
- Deliverable as working functionality
- Completable in 1-3 days
- Includes both tests and implementation (TDD)

**Technical Plan phases already provide structure** - use them as starting point for granularity decisions.
