# Common Dependency Patterns

## Understanding Task Dependencies

Dependencies determine execution order and parallelization opportunities. Proper dependency mapping is critical for efficient execution.

## Dependency Types

### 1. Hard Dependency (Blocking)

**Definition:** Task B cannot start until Task A completes.

**When to use:**

- Task B requires code from Task A
- Task B needs interface defined in Task A
- Task B needs data schema from Task A

**Example:**

```
Task A: Implement UserRepository
Task B: Implement AuthService
Dependency: B blocked by A (AuthService needs UserRepository)
```

### 2. Soft Dependency (Non-blocking)

**Definition:** Task B can start, but cannot complete until Task A finishes.

**When to use:**

- Task B can write tests/interfaces without Task A
- Task B needs Task A only for integration
- Task B can use mocks until Task A ready

**Example:**

```
Task A: Implement PaymentService
Task B: Implement payment UI
Dependency: B can start (use mock PaymentService), needs A for integration
```

### 3. Data Dependency

**Definition:** Task B needs specific data structures from Task A.

**When to use:**

- Database schemas
- API contracts
- Type definitions

**Example:**

```
Task A: Define User schema
Task B: Implement user validation
Dependency: B needs User schema from A
```

### 4. Interface Dependency

**Definition:** Task B needs interface contract from Task A, but not implementation.

**When to use:**

- Following interface segregation principle
- Task B implements consumer, Task A implements provider
- Clear contract between tasks

**Example:**

```
Task A: Define IAuthService interface
Task B: Implement AuthController (uses IAuthService)
Dependency: B needs interface from A, can use mock implementation
```

## Common Dependency Patterns

### Pattern 1: Sequential Chain

**Structure:**

```
A → B → C → D
```

**Characteristics:**

- No parallelization
- Highest risk (any failure blocks all downstream)
- Longest critical path

**When appropriate:**

- Natural sequential dependencies (schema → service → endpoint → UI)
- Small number of tasks (< 5)

**Example:**

```
1. Define User schema →
2. Implement UserRepository →
3. Implement AuthService →
4. Implement login endpoint
```

**Optimization opportunity:** Review if tasks can be made parallel by introducing interfaces or mocks.

### Pattern 2: Fan-out (Parallel Foundation)

**Structure:**

```
    A
   /|\
  B C D
```

**Characteristics:**

- Foundation task enables multiple parallel tasks
- High parallelization
- Short critical path

**When appropriate:**

- Foundation provides common dependencies (schema, types, utilities)
- Multiple independent features built on foundation

**Example:**

```
1. Define data models (User, Session, Token)
   ├─> 2. Implement UserService (parallel)
   ├─> 3. Implement SessionService (parallel)
   └─> 4. Implement TokenService (parallel)
```

### Pattern 3: Fan-in (Convergent Integration)

**Structure:**

```
A  B  C
 \ | /
   D
```

**Characteristics:**

- Multiple parallel tasks converge on integration task
- Maximizes early parallelization
- Integration task is critical bottleneck

**When appropriate:**

- Independent components need integration testing
- Multiple services combined in higher-level component

**Example:**

```
1. Implement UserService (parallel)
2. Implement SessionService (parallel)
3. Implement TokenService (parallel)
   └─> 4. Implement AuthService (integrates all three)
```

### Pattern 4: Layered Architecture

**Structure:**

```
Layer 1: A  B  C  (parallel)
           ↓  ↓  ↓
Layer 2: D  E  F  (parallel, depends on Layer 1)
           ↓  ↓  ↓
Layer 3: G  H  I  (parallel, depends on Layer 2)
```

**Characteristics:**

- Parallelization within each layer
- Clear architectural boundaries
- Medium critical path

**When appropriate:**

- Following clean architecture (data → domain → application → presentation)
- Large systems with clear layers

**Example:**

```
Layer 1 (Data):
- Implement User model (parallel)
- Implement Session model (parallel)
- Implement Token model (parallel)

Layer 2 (Services):
- Implement UserService (parallel, depends on User model)
- Implement SessionService (parallel, depends on Session model)
- Implement TokenService (parallel, depends on Token model)

Layer 3 (API):
- Implement /auth/login endpoint (parallel, depends on services)
- Implement /auth/register endpoint (parallel, depends on services)
- Implement /auth/refresh endpoint (parallel, depends on services)
```

### Pattern 5: Diamond Dependency

**Structure:**

```
   A
  / \
 B   C
  \ /
   D
```

**Characteristics:**

- Two parallel paths converge
- Medium parallelization
- Risk of integration conflicts at convergence

**When appropriate:**

- Two independent approaches to same problem
- Frontend and backend developed in parallel

**Example:**

```
1. Define API contract
   ├─> 2. Implement backend API (parallel)
   └─> 3. Implement frontend API client (parallel)
       └─> 4. Implement E2E integration tests (depends on both)
```

### Pattern 6: Dependency-Ordered Execution

**Structure:**

```
Task 1: A (no dependencies)
Task 2: B (no dependencies)
Task 3: C (no dependencies)
Task 4: D (depends on A, B)
Task 5: E (depends on B, C)
Task 6: F (depends on D)
Task 7: G (depends on D, E)
Task 8: H (depends on E)
Task 9: I (depends on F, G, H)
```

**Characteristics:**

- Sequential execution respecting dependencies
- Tasks execute one at a time
- the plugin's execution pattern

**When appropriate:**

- Complex systems with multiple dependency levels
- Need to maintain execution order

**Example:**

```
Sequential Execution Order:
1. Implement User model (no dependencies)
2. Implement Session model (no dependencies)
3. Implement Token model (no dependencies)
4. Implement UserService (depends on User model)
5. Implement SessionService (depends on Session, Token)
6. Implement AuthService (depends on UserService, SessionService)
7. Implement AuthMiddleware (depends on AuthService)
8. Implement login endpoint (depends on AuthMiddleware)
9. Implement register endpoint (depends on AuthMiddleware)
10. Implement refresh endpoint (depends on AuthMiddleware)
```

## Dependency Mapping Strategies

### Strategy 1: Bottom-Up (Data First)

Start with data models, build up to API.

```
1. Data layer (models, schemas)
2. Repository layer (data access)
3. Service layer (business logic)
4. API layer (endpoints)
5. UI layer (components)
```

**Advantages:**

- Solid foundation
- Clear architectural layers
- Easy to test each layer

**Disadvantages:**

- Longer before visible features
- Cannot demo until upper layers done

### Strategy 2: Top-Down (API First)

Start with API contract, build down to implementation.

```
1. API contract (OpenAPI spec)
2. API endpoints (with mocks)
3. Service layer (business logic)
4. Repository layer (data access)
5. Data layer (models)
```

**Advantages:**

- Early API feedback
- Can demo with mocks
- Frontend can start early

**Disadvantages:**

- Contract might change as you learn
- Risk of mismatch between contract and implementation

### Strategy 3: Outside-In (Use Case Driven)

Start with user journey, implement what's needed.

```
1. User story: "User logs in"
2. Implement login UI
3. Implement login endpoint
4. Implement AuthService
5. Implement UserRepository
6. Implement User model
```

**Advantages:**

- Delivers complete features early
- Aligns with user value
- YAGNI compliance (only build what's needed)

**Disadvantages:**

- May miss architectural patterns
- Risk of technical debt

## Identifying Dependencies from Technical Plan

### Step 1: Parse Component Relationships

Look for "depends on" language in Technical Plan:

```markdown
## Phase 2: Core Services

### UserAuthService
- Responsibilities: Authenticate users, issue tokens
- Dependencies: UserRepository, TokenService, PasswordHasher
```

**Dependency mapping:**

```
UserAuthService blocked by:
- UserRepository
- TokenService
- PasswordHasher
```

### Step 2: Identify Parallel Opportunities

Components with no dependencies can run in parallel:

```markdown
## Phase 1: Foundation

### User Model
- Dependencies: None

### Session Model
- Dependencies: None

### Token Model
- Dependencies: None
```

**Parallel mapping:**

```
Wave 1 (parallel):
- User Model
- Session Model
- Token Model
```

### Step 3: Map Integration Points

Integration tasks depend on all components they integrate:

```markdown
## Phase 5: Integration

### End-to-end Authentication Flow
- Dependencies: All auth components
```

**Dependency mapping:**

```
E2E Auth Flow blocked by:
- User Model
- Session Model
- TokenService
- UserAuthService
- Login Endpoint
- Register Endpoint
```

## Anti-Patterns to Avoid

### Anti-pattern 1: Circular Dependencies

**Example:**

```
Task A depends on Task B
Task B depends on Task A
```

**Why it's bad:**

- Cannot execute either task
- Indicates design flaw

**Solution:**

- Extract common interface/abstraction
- Use dependency inversion principle
- Refactor to break cycle

### Anti-pattern 2: God Task (Everything Depends on It)

**Example:**

```
Task A: Implement core system
  ├─ Task B depends on A
  ├─ Task C depends on A
  ├─ Task D depends on A
  ├─ Task E depends on A
  └─ Task F depends on A
```

**Why it's bad:**

- No parallelization
- Task A is critical bottleneck
- High risk (if A fails, everything blocked)

**Solution:**

- Break Task A into smaller, independent tasks
- Use interfaces to allow parallel development with mocks

### Anti-pattern 3: Unnecessary Dependencies

**Example:**

```
Task A: Implement login UI
Task B: Implement register UI
Dependency: B blocked by A (no real dependency)
```

**Why it's bad:**

- False dependency reduces parallelization
- No technical reason for dependency

**Solution:**

- Remove dependency
- Allow parallel execution

### Anti-pattern 4: Missing Dependencies

**Example:**

```
Task A: Implement AuthService (depends on UserRepository)
Task B: Implement UserRepository
No dependency documented
```

**Why it's bad:**

- Tasks executed in wrong order
- Integration failures
- Rework required

**Solution:**

- Carefully review Technical Plan for dependencies
- Document all blocking relationships

## Dependency Documentation Format

### In Sub-Issue Description

```markdown
## Dependencies
- Blocked by: USER-123 (UserRepository implementation)
- Blocked by: USER-124 (TokenService implementation)
- Blocks: USER-130 (Login endpoint)
- Blocks: USER-131 (Register endpoint)
- Parent issue: USER-100 (see full Specification + Technical Plan)
- Technical Plan Phase: 2 (Core Services)
```

### In Breakdown Summary

```markdown
## Dependency Graph

USER-101 (User model)
  ├─> USER-105 (UserRepository)
  │     ├─> USER-110 (AuthService)
  │     │     ├─> USER-115 (Login endpoint)
  │     │     └─> USER-116 (Register endpoint)
  │     └─> USER-111 (UserController)
  └─> USER-106 (User validation)

USER-102 (Session model)
  └─> USER-107 (SessionService)
        └─> USER-110 (AuthService)

USER-103 (Token model)
  └─> USER-108 (TokenService)
        └─> USER-110 (AuthService)
```

## Summary

**Key principles:**

1. Document all dependencies explicitly
2. Maximize parallelization within constraints
3. Respect architectural layers
4. Avoid circular dependencies
5. Watch for bottleneck tasks (everything depends on one task)
6. Technical Plan phases provide natural dependency structure

**the plugin's sequential execution automatically handles dependency resolution** - your job is to document dependencies correctly in Technical Plan and sub-issues.
