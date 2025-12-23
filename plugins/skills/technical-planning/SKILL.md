---
name: technical-planning
description: Create comprehensive technical implementation plans from refined specifications, translating WHAT to build into HOW to build it, with architecture, technology choices, and implementation guidance
when_to_use: when partner provides issue ID that has been refined (has Specification section) and needs technical planning before breakdown
version: 2.0.0
---

# Technical Planning

## Overview

Transform refined specifications (WHAT to build) into comprehensive technical implementation plans (HOW to build it), covering architecture, technology choices, data models, API contracts, testing strategy, and implementation phases.

**Core principle:** Translate user requirements into technical decisions with clear rationale, reference existing patterns, and create a roadmap for implementation.

**Announce at start:** "I'm using the technical-planning skill to create a comprehensive technical implementation plan."

**Critical distinctions:**

- **Input**: Specification (WHAT) - user needs, behaviors, success criteria
- **Output**: Technical Plan (HOW) - architecture, tech stack, patterns, phases

## Quick Reference

| Phase | Key Activities | Tool Usage | Output |
|-------|---------------|------------|--------|
| **1. Load Specification** | Retrieve refined issue | JIRA MCP tools | Specification loaded |
| **2. Analyze Codebase** | Find patterns, similar code | Grep, Read | Existing patterns identified |
| **3. Research Options** | Investigate technologies | Web search, documentation | Technology options evaluated |
| **4. Design Architecture** | High-level component design | — | Architecture documented |
| **5. Define Contracts** | Data models, APIs | — | Contracts specified |
| **6. Plan Testing** | Strategy per test level | — | Testing approach defined |
| **7. Phase Implementation** | Order tasks logically | — | Implementation phases |
| **8. Document Patterns** | Reference existing code | — | Pattern references |
| **9. Write to Issue** | Append Technical Plan | JIRA MCP update | Issue ready for breakdown |

## The Process

Copy this checklist to track progress:

```
Technical Planning Progress:
- [ ] Phase 1: Load Specification (requirements retrieved from PM system)
- [ ] Phase 2: Analyze Codebase (existing patterns identified)
- [ ] Phase 3: Research Options (technology choices evaluated)
- [ ] Phase 4: Design Architecture (high-level design created)
- [ ] Phase 5: Define Contracts (data models and APIs specified)
- [ ] Phase 6: Plan Testing (strategy per level defined)
- [ ] Phase 7: Phase Implementation (task order determined)
- [ ] Phase 8: Document Patterns (references to existing code)
- [ ] Phase 9: Write to Issue (technical plan written to PM system)
```

### Phase 1: Load Specification

**Verify issue has Specification section:**

```bash
# JIRA:
issue = mcp__atlassian__get_issue(id=issue_id)
# OR JIRA:
issue = mcp__jira__get_issue(issue_key=issue_id)

if "## Specification" not in issue.description:
    ERROR: Issue missing Specification section
    SUGGEST: Run `/refine <issue-id>` first
    STOP
```

**Extract key elements:**

- User stories (who needs what)
- Expected behaviors (given/when/then)
- Success criteria (testable outcomes)
- Data requirements (what data, what relationships)
- Edge cases and error conditions

**Present loaded spec:**

```
Loaded issue TEAM-123: "User authentication system"

Specification Summary:
- 4 user stories identified
- 8 expected behaviors defined
- 5 success criteria
- 2 primary data entities (User, Session)
- 6 edge cases documented

I'm using the technical-planning skill to create the implementation plan.
```

### Phase 2: Analyze Codebase

**Search for existing patterns:**

```bash
# Find similar services/controllers
Grep: pattern="class.*Service"
Grep: pattern="class.*Controller"

# Find domain-specific patterns (auth example)
Grep: pattern="auth|authentication|login"

# Find data model patterns
Grep: pattern="class.*Model|interface.*Entity"

# Find API endpoint patterns
Grep: pattern="@Get|@Post|app.get|app.post|router"

# Find testing patterns
Grep: pattern="describe|test|it\(|def test_"
```

**Document findings:**

```markdown
Codebase Analysis:
- Service pattern: src/services/*-service.ts
- Controller pattern: src/controllers/*-controller.ts
- Data models: src/models/*.ts
- Test structure: tests/**/*.test.ts
- Error handling: src/types/result.ts
```

**Identify constraints:** Framework, database, auth approach, API style, testing tools from package.json and imports.

### Phase 3: Research Options & Confirm Decisions

**For each technical decision, research options:**

**Technology Choices to consider:**

- Authentication: JWT vs Sessions vs OAuth
- Data storage: SQL vs NoSQL considerations
- Caching: Redis vs in-memory vs none
- API design: REST vs GraphQL

**For each option, document:**

- Pros and cons
- Fit with existing codebase
- Performance implications
- Security considerations
- Team familiarity

**Context-Aware Decision Making:**

**ONLY ask for user confirmation when:**

1. **New technology not in codebase** (e.g., adding Redis when not currently used)
2. **Multiple valid architectural approaches** (e.g., sync vs async processing)
3. **Significant trade-offs** (e.g., performance vs complexity)
4. **Cross-cutting concerns** (e.g., caching strategy, security model changes)

**DO NOT ask when:**

1. **Codebase already uses the technology** (e.g., Postgres already in use → use Postgres)
2. **Existing patterns dictate approach** (e.g., REST endpoints already present → continue with REST)
3. **Single obvious choice** (e.g., bcrypt for password hashing)
4. **Standard practice** (e.g., JWT for stateless auth when API already uses tokens)

**Use AskUserQuestion for genuine decisions:**

```typescript
// Example: Introducing new technology
AskUserQuestion({
  questions: [{
    question: "For session management, should we introduce Redis caching?",
    header: "Caching",
    multiSelect: false,
    options: [
      {
        label: "Redis cache",
        description: "Fast lookups, requires new infrastructure, better scalability"
      },
      {
        label: "Database only",
        description: "Uses existing Postgres, simpler setup, higher database load"
      },
      {
        label: "In-memory cache",
        description: "No new infrastructure, loses cache on restart, single-server only"
      }
    ]
  }]
})
```

**Document decisions with rationale:**

```markdown
Technology Choices:

**Authentication Method:** JWT tokens
- Rationale: Stateless, scalable, consistent with existing API patterns
- No alternatives considered: Codebase already uses JWT (see src/services/token-service.ts)

**Password Storage:** bcrypt with salt rounds = 12
- Rationale: Industry standard, good security/performance balance
- No alternatives considered: Codebase already uses bcrypt (see src/utils/password-hash.ts)

**Session Management:** Redis for token blacklist [USER CONFIRMED]
- Rationale: Fast lookups, handles distributed system, existing Redis infrastructure
- Alternative considered: Database (rejected: slower, unnecessary load)
- User confirmed: Redis cache over database-only approach
- References: See src/services/cache-service.ts (existing Redis client)
```

**Pattern for interactivity:**

1. Analyze codebase in Phase 2
2. Identify genuine decision points (new tech, architectural choices, trade-offs)
3. Research options for genuine decisions
4. Use AskUserQuestion for decisions with multiple valid approaches
5. Document all decisions with rationale (whether confirmed by user or dictated by codebase)

**For detailed examples of technology decisions, see:** resources/example-technology-choices.md

### Phase 4: Design Architecture

**Document high-level component design:**

```markdown
Architecture Overview:

**Components:**
1. **[ComponentName]** (new/modified)
   - Responsibilities: [What it does]
   - Dependencies: [What it needs]
   - Location: [File path]
   - Pattern: Follows [existing pattern reference]

**Data Flow:**
[Step-by-step flow through components]

**Integration Points:**
[How it connects to existing middleware, error handling, validation]
```

**Generate Mermaid diagrams to visualize the architecture:**

Include appropriate diagrams based on the feature:

| Diagram Type | When to Use | Example Use Case |
|--------------|-------------|------------------|
| `classDiagram` | Class relationships, service hierarchies | New service layer, domain models |
| `flowchart` | Process/functional flows, decision trees | User workflows, validation logic |
| `sequenceDiagram` | Data flow between components, API calls | Request/response flows, auth flow |
| `erDiagram` | Database schema changes | New tables, relationship changes |

**Example diagrams to include:**

```markdown
### Component Relationships
\`\`\`mermaid
classDiagram
    class AuthController {
        +login(credentials)
        +logout()
        +refreshToken()
    }
    class AuthService {
        +authenticate(email, password)
        +generateToken(user)
        +validateToken(token)
    }
    class UserRepository {
        +findByEmail(email)
        +create(userData)
    }
    AuthController --> AuthService
    AuthService --> UserRepository
\`\`\`

### Authentication Flow
\`\`\`mermaid
sequenceDiagram
    participant Client
    participant AuthController
    participant AuthService
    participant Database

    Client->>AuthController: POST /login
    AuthController->>AuthService: authenticate(credentials)
    AuthService->>Database: findByEmail(email)
    Database-->>AuthService: user data
    AuthService-->>AuthController: JWT token
    AuthController-->>Client: 200 OK + token
\`\`\`
```

**Diagram guidelines:**
- Include at least one class/flowchart diagram (component structure)
- Include at least one sequence diagram (data/user flow)
- Add erDiagram when database schema changes are involved
- Keep diagrams focused - split complex flows into multiple diagrams
- These diagrams may be reused in the PR if they still accurately reflect the final implementation

**Confirm architecture approach if significant design decision:**

**ONLY ask when:**

- Multiple valid architectural patterns (e.g., microservices vs monolith expansion)
- Significant component structure changes (e.g., new service layer)
- Integration approach with trade-offs (e.g., event-driven vs synchronous)

**Example confirmation:**

```typescript
AskUserQuestion({
  questions: [{
    question: "For the authentication service, should we use synchronous or event-driven architecture?",
    header: "Architecture",
    multiSelect: false,
    options: [
      {
        label: "Synchronous",
        description: "Direct service calls, simpler, consistent with existing services"
      },
      {
        label: "Event-driven",
        description: "Pub/sub pattern, better scalability, requires event infrastructure"
      }
    ]
  }]
})
```

**For detailed architecture examples, see:** resources/example-architecture-design-section.md

### Phase 5: Define Contracts

**Define data models and API contracts:**

```markdown
**Data Models:**
**[EntityName]** (new/extend existing)
- [field]: [type] ([existing/NEW])
- Validation: [rules]

**API Contracts:**
**[METHOD] /api/[endpoint]**
- Request: { fields }
- Response (200): { fields }
- Errors: [status codes and descriptions]
```

For detailed examples, see **resources/example-contracts-section.md**

### Phase 6: Plan Testing

**Define testing strategy:**

```markdown
Testing Strategy:

**Unit Tests** - Service/utility functions in isolation, mock dependencies
**Integration Tests** - API endpoints with real database
**E2E Tests** - Critical user workflows only

**All implementation follows TDD:** RED → GREEN → REFACTOR
```

**Confirm testing approach if significant decision:**

**ONLY ask when:**

- Multiple testing strategies with trade-offs (e.g., end-to-end vs integration focus)
- Performance testing requirements unclear (e.g., load testing needed?)
- Test infrastructure changes (e.g., introducing contract testing, visual regression)

**Example confirmation:**

```typescript
AskUserQuestion({
  questions: [{
    question: "Should we include performance/load testing for this authentication system?",
    header: "Testing",
    multiSelect: false,
    options: [
      {
        label: "Yes, add load tests",
        description: "Verify performance under concurrent load, catch bottlenecks early"
      },
      {
        label: "No, defer to later",
        description: "Focus on functional correctness first, add performance tests later"
      }
    ]
  }]
})
```

**Testing approach should follow project's CLAUDE.md guidelines.** Otherwise use test pyramid (many unit, some integration, few e2e).

### Phase 7: Phase Implementation

**Order tasks logically with dependencies:**

```markdown
Implementation Phases:

**Phase N: [Category]**
N.1. [Component] (test-first via TDD)
   - Test first: [test type and scope]
   - Dependencies: [Phase X.Y if any]

**Dependency Graph:**
Phase 1 → Phase 2 → Phase 3
(Note which sub-tasks can run in parallel)
```

**For detailed phase examples with dependencies, see:** [resources/example-implementation-phases.md](resources/example-implementation-phases.md)

### Phase 8: Document Patterns

**First, check project documentation:**

1. Read `CLAUDE.md` in project root (architecture patterns, conventions)
2. Read `CLAUDE-patterns/` or `docs/architecture.md` if present
3. Search existing codebase for similar implementations

**Reference existing code patterns:**

```markdown
Patterns to Follow:

**From project CLAUDE.md/CLAUDE-*.md:**
- [List key architectural principles from project docs]
- [Reference specific patterns documented there]

**From existing codebase:**
- Service layer: src/services/[similar-service].ts (follow this structure)
- Controller pattern: src/controllers/[similar-controller].ts (follow this pattern)
- Error handling: src/middleware/error-handler.ts (use existing approach)
- Validation: src/middleware/validator.ts (follow validation pattern)

**Key best practices (if not documented in project):**
- Dependency injection for testability
- Explicit error handling (no silent failures)
- Input validation at boundaries
- Single responsibility per function/class
```

**Always prefer project's documented patterns over generic best practices.**

### Phase 9: Write to Issue

**Format Technical Plan (concise parent-level overview):**

```markdown
## Technical Plan

### Architecture Overview
[1-2 paragraphs: High-level component structure and data flow]
Example: "This feature consists of 3 main components: UserAuthService for business logic,
AuthController for API endpoints, and Session model for data persistence. User credentials
flow through validation → service authentication → token generation → session creation."

### Architecture Diagrams
[Include Mermaid diagrams created in Phase 4]
- At minimum: one component/class diagram + one sequence/flow diagram
- Add ER diagram if database changes involved
- These diagrams may be reused in the PR if they accurately reflect the final implementation

### Key Technology Choices
[1 paragraph per major decision with brief rationale]
Example: "JWT tokens for authentication (stateless, scalable). Bcrypt for password hashing
(industry standard). Redis for token blacklist (fast lookups). Following existing patterns
in src/services/ and src/controllers/."

### Implementation Approach
[1-2 paragraphs: Phase structure and dependencies]
Example: "Implementation follows 5 phases: Foundation (data models), Core Services (business
logic), API Layer (endpoints), Integration (middleware), E2E Validation. Phases 1-2 have
parallel sub-tasks. Detailed component specs, API contracts, and test cases provided in
sub-issue descriptions during breakdown."

### Testing Strategy
[1 paragraph: Overview of test levels]
Example: "Unit tests for service logic and utilities (mocked dependencies). Integration
tests for API endpoints (with test database). E2E tests for critical paths only (login,
logout, session expiry). TDD approach enforced via sub-issue checklists."

### Key Patterns
[Bullet list of reference files]
Example:
- Service structure: src/services/data-service.ts
- Controller structure: src/controllers/user-controller.ts
- Error handling: src/types/result.ts
- Testing: tests/services/data-service.test.ts
```

**IMPORTANT: Keep parent plan concise**

- **1-2 paragraphs** per section maximum
- **High-level overview** only - no detailed schemas, API contracts, or full component specs
- **Detailed technical context** will be written to sub-issues during breakdown
- **Focus on architecture and approach**, not implementation details

**Update the issue:**

```bash
# Append concise Technical Plan to existing Specification
current_description = issue.description
technical_plan = format_concise_technical_plan()
new_description = current_description + "\n\n---\n\n" + technical_plan

# JIRA:
mcp__atlassian__update_issue(
    id=issue_id,
    description=new_description,
    labels=['planned', 'refined'],
    state='Todo'
)

# OR JIRA:
mcp__jira__update_issue(
    issue_key=issue_id,
    description=new_description,
    labels=['planned', 'refined'],
    status='To Do'
)
```

**Confirm with user:**

```
Technical Plan written to issue TEAM-123 (concise parent-level overview).

This defines HOW to build the features from the specification.
Detailed technical context (data models, API contracts, component specs) will be
provided in sub-issue descriptions during breakdown.

Next steps:
1. Review the technical plan
2. Run `/breakdown TEAM-123` to create implementation tasks

Ready to break this down into implementation tasks?
```

## Integration with Other Skills

**Follows:**

- `refining-issues` skill (via `/refine` command) - Provides Specification (WHAT)

**Precedes:**

- `breakdown-planning` skill (via `/breakdown` command) - Creates sub-issues from Specification + Technical Plan

**May use during planning:**

- Web search for technology research
- Documentation reading for API patterns
- Codebase analysis for existing patterns

**The workflow:**

1. `/refine` → Specification (WHAT to build)
2. `/plan` → Technical Plan (HOW to build) - THIS SKILL
3. `/breakdown` → Sub-issues (tasks to execute)
4. `/execute` → Implementation (build it)

## Key Principles

| Principle | Application |
|-----------|-------------|
| **Specification-driven** | Every technical decision maps back to specification requirements |
| **Rationale required** | Every technology choice must explain "why" |
| **Reference existing** | Always point to similar code in codebase |
| **Test-first planning** | Testing strategy drives implementation phases |
| **Phased approach** | Break implementation into logical, testable phases |
| **Dependency-aware** | Clearly document what blocks what |
| **Pattern consistency** | Follow established patterns in codebase |
| **Technology-appropriate** | Choose tech that fits team, scale, and existing stack |
| **High-level focus** | Avoid code-level details, stay architectural |

## Remember

- **Specification provides context** - Every decision traces back to a requirement
- **Existing patterns matter** - Don't invent new patterns when existing ones work
- **Technology rationale is critical** - "Why" is more important than "what"
- **Testing strategy drives tasks** - TDD approach requires test-first planning
- **Phases must have clear dependencies** - Breakdown depends on understanding order
- **High-level not code-level** - Focus on architecture, not implementation details
- **All in PM system** - Technical Plan lives in JIRA issue, not separate files

## Additional Resources

- **resources/example-technology-choices.md** - Technology decision examples with rationale (auth, database, caching, etc.)
- **resources/example-architecture-design-section.md** - Component architecture examples (auth system, payments, real-time chat)
- **resources/example-implementation-phases.md** - Phase breakdown examples with dependency graphs
- **resources/example-contracts-section.md** - Detailed API contract and data model examples (REST, GraphQL)
- **Project CLAUDE.md and CLAUDE-*.md** - Always check project's architecture patterns and conventions first
- **Project docs/** - Architecture guides, design decisions, pattern catalogs
