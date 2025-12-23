# Implementation Phases Examples

This document provides examples of how to structure implementation phases with dependencies during technical planning.

## Phase Structure Template

```markdown
**Phase N: [Category]**
N.1. [Component] (test-first via TDD)
   - Test first: [test type and scope]
   - Dependencies: [Phase X.Y if any]
N.2. [Another component]
   - Test first: [test type]
   - Dependencies: [Phase X.Y]

**Dependency Graph:**
Phase 1 → Phase 2 → Phase 3
(Note which sub-tasks can run in parallel)
```

## example-1-authentication-system

```markdown
Implementation Phases:

**Phase 1: Foundation (data models)**
1.1. Extend User model (add passwordHash, lastLoginAt fields)
   - Test first: Unit tests for model validation
   - Dependencies: None
1.2. Create Session model (new entity)
   - Test first: Unit tests for session expiry logic
   - Dependencies: Phase 1.1 (User model)
1.3. Create database migrations
   - Test first: Migration up/down tests
   - Dependencies: Phases 1.1, 1.2

**Phase 2: Core Services (business logic)**
2.1. PasswordHasher utility (hash, verify)
   - Test first: Unit tests for hashing and verification
   - Dependencies: None
2.2. TokenService (generate, validate JWT)
   - Test first: Unit tests for token operations
   - Dependencies: None
2.3. UserAuthService (authenticate, issue token, revoke)
   - Test first: Unit tests mocking repositories
   - Dependencies: Phases 1.1, 1.2, 2.1, 2.2

**Phase 3: API Layer (endpoints)**
3.1. POST /api/auth/login endpoint
   - Test first: Integration tests with test database
   - Dependencies: Phase 2.3
3.2. POST /api/auth/logout endpoint
   - Test first: Integration tests
   - Dependencies: Phase 2.3
3.3. POST /api/auth/refresh endpoint
   - Test first: Integration tests
   - Dependencies: Phase 2.3

**Phase 4: Integration (middleware)**
4.1. Extend AuthMiddleware for JWT validation
   - Test first: Integration tests with authenticated routes
   - Dependencies: Phase 2.2 (TokenService)

**Phase 5: E2E Validation**
5.1. Complete auth flow E2E tests
   - Test: Login → authenticated request → logout
   - Dependencies: All previous phases

**Dependency Graph:**
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5
- Phase 1 sub-tasks: 1.1 and 1.2 can run in parallel, 1.3 waits for both
- Phase 2 sub-tasks: 2.1 and 2.2 can run in parallel, 2.3 waits for all
- Phase 3 sub-tasks: All can run in parallel after 2.3 completes
- Phase 4 can run in parallel with Phase 3
```

## example-2-payment-processing

```markdown
Implementation Phases:

**Phase 1: Foundation (data models)**
1.1. Create Payment model (amount, status, metadata)
   - Test first: Unit tests for model validation
   - Dependencies: None
1.2. Create PaymentMethod model (card details, billing address)
   - Test first: Unit tests for secure field handling
   - Dependencies: None
1.3. Database migrations
   - Test first: Migration tests
   - Dependencies: Phases 1.1, 1.2

**Phase 2: External Integration (Stripe)**
2.1. PaymentGateway adapter (Stripe SDK wrapper)
   - Test first: Unit tests with Stripe mocks
   - Dependencies: None
2.2. Webhook signature verification
   - Test first: Unit tests for signature validation
   - Dependencies: None

**Phase 3: Core Services**
3.1. PaymentService (create payment intent, capture, refund)
   - Test first: Unit tests mocking gateway
   - Dependencies: Phases 1.1, 2.1
3.2. PaymentMethodService (save, validate, remove)
   - Test first: Unit tests
   - Dependencies: Phase 1.2

**Phase 4: API Layer**
4.1. POST /api/payments endpoint
   - Test first: Integration tests with test Stripe account
   - Dependencies: Phase 3.1
4.2. POST /api/webhooks/stripe endpoint
   - Test first: Integration tests with webhook payloads
   - Dependencies: Phases 2.2, 3.1

**Phase 5: Integration with Orders**
5.1. Update OrderService to trigger payments
   - Test first: Integration tests
   - Dependencies: Phase 3.1

**Dependency Graph:**
Phase 1 (1.1, 1.2 parallel) → 1.3
Phase 2 (2.1, 2.2 parallel)
Phase 3 (3.1, 3.2 parallel) - waits for Phase 1 + Phase 2
Phase 4 (4.1, 4.2 parallel) - waits for Phase 3
Phase 5 - waits for Phase 3.1
```

## example-3-realtime-chat

```markdown
Implementation Phases:

**Phase 1: Foundation**
1.1. ChatRoom model (name, participants)
   - Test first: Unit tests
   - Dependencies: None
1.2. Message model (content, sender, timestamp)
   - Test first: Unit tests
   - Dependencies: Phase 1.1
1.3. Database migrations
   - Test first: Migration tests
   - Dependencies: Phases 1.1, 1.2

**Phase 2: WebSocket Infrastructure**
2.1. WebSocketManager (connection handling)
   - Test first: Unit tests with Socket.io mocks
   - Dependencies: None
2.2. Auth handshake for WebSocket
   - Test first: Integration tests
   - Dependencies: Phase 2.1

**Phase 3: Core Services**
3.1. ChatService (send message, get history)
   - Test first: Unit tests
   - Dependencies: Phases 1.1, 1.2
3.2. Room management (create, join, leave)
   - Test first: Unit tests
   - Dependencies: Phases 1.1, 1.2

**Phase 4: Real-time Features**
4.1. Message broadcasting
   - Test first: Integration tests with multiple connections
   - Dependencies: Phases 2.1, 3.1
4.2. User presence tracking (online/offline)
   - Test first: Integration tests
   - Dependencies: Phase 2.1

**Phase 5: REST API (history)**
5.1. GET /api/chat/rooms/:id/messages endpoint
   - Test first: Integration tests
   - Dependencies: Phase 3.1

**Phase 6: E2E Validation**
6.1. Complete chat flow (connect → join room → send → receive → disconnect)
   - Test: E2E tests with multiple clients
   - Dependencies: All previous phases

**Dependency Graph:**
Phase 1 → Phase 3
Phase 2 → Phase 4
Phase 3 + Phase 4 → Phase 5 and Phase 6

Parallel opportunities:
- Phase 1 and Phase 2 can run completely in parallel
- Phase 4.1 and 4.2 can run in parallel
- Phase 5 can run in parallel with Phase 4
```

## Dependency Management Best Practices

1. **Identify hard dependencies** - What MUST be done first?
2. **Maximize parallelism** - What CAN run at the same time?
3. **Group by layer** - Data → Services → API → Integration
4. **TDD at every step** - Tests first, implementation second
5. **Small increments** - Each sub-task should be 1-3 days max

## Dependency Graph Notation

- `→` Sequential dependency (must wait)
- `parallel` Can run simultaneously
- `waits for` Blocks on completion of specific tasks
- `can run in parallel` No dependencies between them

## Anti-Pattern: No Dependency Analysis

**Bad example:**

```markdown
Tasks:
1. User model
2. Session model
3. Auth service
4. Login endpoint
5. Logout endpoint
```

This provides no information about what depends on what or what can run in parallel.

**Good example:**

```markdown
**Phase 1:** User model (no deps) | Session model (no deps) → both can run in parallel
**Phase 2:** Auth service (waits for Phase 1 complete)
**Phase 3:** Login + Logout endpoints (both wait for Phase 2, can run in parallel)
```

This clearly shows the dependency chain and parallelization opportunities.
