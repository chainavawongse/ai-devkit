---
name: pm-operations
description: Abstract interface for project management operations across different PM systems
when_to_use: reference skill for understanding PM abstraction layer - not invoked directly, but used by other skills
version: 1.0.0
---

# PM Operations Skill

## Purpose

Provides a unified interface for PM system operations. Skills should use these abstract operations rather than calling MCP tools directly. The actual implementation varies by configured PM system (Jira, Notion, etc.).

## Prerequisites

- PM system configured in repository's CLAUDE.md (via `/setup` or `configuring-project-management` skill)
- Appropriate MCP server installed and authenticated

## Configuration Detection

Before using any PM operation, check the repository's CLAUDE.md for configuration:

```markdown
## Project Management

**System:** [jira|notion]
**Database/Project:** [identifier]
```

If no configuration found, prompt user to run `/setup` first.

---

## Abstract Operations

### 1. get_issue(id)

**Purpose:** Retrieve a single issue/ticket by ID

**Input:**
- `id` - Issue identifier (Jira key like "TEAM-123" or Notion page ID)

**Output:**
```
Issue {
  id: string           # Unique identifier
  title: string        # Issue title/summary
  description: string  # Full description (markdown)
  status: string       # Current status (Todo, In Progress, Done)
  type: string         # Label type (feature, chore, bug) - execution workflow
  level?: string       # Scope hierarchy (Feature, User Story, Task) - Notion only
  parentId?: string    # Parent issue ID if sub-issue
  blocks?: string[]    # IDs of issues this blocks
  blockedBy?: string[] # IDs of issues blocking this
}
```

**Implementation by System:**

<details>
<summary>Jira (Atlassian MCP)</summary>

```
# Primary
issue = mcp__atlassian__get_issue(id=issue_id)

# Fallback
issue = mcp__jira__get_issue(issue_key=issue_id)

# Map response:
{
  id: issue.key or issue.id,
  title: issue.summary or issue.title,
  description: issue.description,
  status: issue.status or issue.state,
  type: issue.labels[0],  # First label is type
  parentId: issue.parent or issue.parentId,
  blocks: issue.blocks,
  blockedBy: issue.blocked_by
}
```
</details>

<details>
<summary>Notion</summary>

```
page = mcp__notion__notion-fetch(id=issue_id)

# Map response:
{
  id: page.id,
  title: page.properties.Name,
  description: page.content,
  status: page.properties.Status,
  type: page.properties.Type,
  level: page.properties.Level,  # Notion only - scope hierarchy
  parentId: page.properties.Parent[0] if Parent else null,
  blocks: page.properties.Blocks,
  blockedBy: (reverse lookup via search)
}
```
</details>

---

### 2. create_issue({...})

**Purpose:** Create a new issue/ticket

**Input:**
```
{
  title: string           # Required - Issue title
  description: string     # Required - Full description (markdown)
  type: string            # Required - "feature" | "chore" | "bug" (execution workflow)
  level?: string          # Optional - "Feature" | "User Story" | "Task" (Notion only - scope hierarchy)
  parentId?: string       # Optional - Parent issue for sub-issues
  status?: string         # Optional - Initial status (default: "Todo")
  blocks?: string[]       # Optional - Issues this will block
}
```

**Output:** Created issue object (same structure as get_issue)

**Implementation by System:**

<details>
<summary>Jira (Atlassian MCP)</summary>

```
# Get project/team from CLAUDE.md config
project = config.project_key

# Primary
issue = mcp__atlassian__create_issue({
  title: input.title,
  description: input.description,
  team: project,
  labels: [input.type],
  parentId: input.parentId,
  state: input.status or "Todo"
})

# Fallback
issue = mcp__jira__create_issue({
  summary: input.title,
  description: input.description,
  project: project,
  parent: input.parentId,
  labels: [input.type]
})

# If blocks specified, create dependencies
for blocked_id in input.blocks:
  create_dependency(issue.id, blocked_id)
```
</details>

<details>
<summary>Notion</summary>

```
# Get database ID from CLAUDE.md config
database_id = config.data_source_id

page = mcp__notion__notion-create-pages({
  parent: { data_source_id: database_id },
  pages: [{
    properties: {
      Name: input.title,
      Status: input.status or "Todo",
      Type: input.type,
      Level: input.level,      # Notion only - scope hierarchy (Feature/User Story/Task)
      Parent: input.parentId,  # Relation property
      Blocks: input.blocks     # Relation property
    },
    content: input.description
  }]
})
```

**Level Classification (Notion Only):**
- Determine level based on complexity indicators before creating
- See `scope-classification` section in pm-operations for heuristics
- Level is independent of Type (a bug can be Feature-level, User Story-level, or Task-level)
</details>

---

### 3. update_issue(id, {...})

**Purpose:** Update an existing issue's properties or content

**Input:**
- `id` - Issue identifier
- Updates object (all optional):
```
{
  title?: string        # New title
  description?: string  # New/appended description
  status?: string       # New status
  type?: string         # New type label
  appendDescription?: boolean  # If true, append to existing description
}
```

**Output:** Updated issue object

**Implementation by System:**

<details>
<summary>Jira (Atlassian MCP)</summary>

```
# If appending description, fetch current first
if input.appendDescription:
  current = get_issue(id)
  input.description = current.description + "\n\n" + input.description

# Primary
mcp__atlassian__update_issue(
  id=id,
  description=input.description,
  state=input.status,
  labels=[input.type] if input.type else undefined
)

# Fallback
mcp__jira__update_issue(
  issue_key=id,
  description=input.description,
  status=input.status,
  labels=[input.type] if input.type else undefined
)
```
</details>

<details>
<summary>Notion</summary>

```
# Update properties
if input.status or input.type or input.title:
  mcp__notion__notion-update-page({
    data: {
      page_id: id,
      command: "update_properties",
      properties: {
        Name: input.title,
        Status: input.status,
        Type: input.type
      }
    }
  })

# Update content
if input.description:
  if input.appendDescription:
    mcp__notion__notion-update-page({
      data: {
        page_id: id,
        command: "insert_content_after",
        selection_with_ellipsis: "...last content...",
        new_str: input.description
      }
    })
  else:
    mcp__notion__notion-update-page({
      data: {
        page_id: id,
        command: "replace_content",
        new_str: input.description
      }
    })
```
</details>

---

### 4. list_children(parentId)

**Purpose:** Get all sub-issues/child tickets of a parent

**Input:**
- `parentId` - Parent issue identifier

**Output:** Array of issue objects

**Implementation by System:**

<details>
<summary>Jira (Atlassian MCP)</summary>

```
# Primary
issues = mcp__atlassian__list_issues(parentId=parentId)

# Fallback
issues = mcp__jira__list_issues(parent=parentId)

# Map each to standard format
return issues.map(issue => ({
  id: issue.key or issue.id,
  title: issue.summary or issue.title,
  description: issue.description,
  status: issue.status or issue.state,
  type: issue.labels[0],
  parentId: parentId,
  blocks: issue.blocks,
  blockedBy: issue.blocked_by
}))
```
</details>

<details>
<summary>Notion</summary>

```
# Get database ID from CLAUDE.md config
database_id = config.data_source_id

# Search within database for pages with Parent = parentId
results = mcp__notion__notion-search({
  query: "",
  data_source_url: "collection://" + database_id,
  # Filter by Parent relation pointing to parentId
})

# Filter results where Parent property contains parentId
children = results.filter(page =>
  page.properties.Parent?.includes(parentId)
)

return children.map(page => ({
  id: page.id,
  title: page.properties.Name,
  status: page.properties.Status,
  type: page.properties.Type,
  parentId: parentId
}))
```
</details>

---

### 5. add_comment(id, text)

**Purpose:** Add a comment to an issue

**Input:**
- `id` - Issue identifier
- `text` - Comment text (markdown)

**Output:** Success/failure

**Implementation by System:**

<details>
<summary>Jira (Atlassian MCP)</summary>

```
# Primary
mcp__atlassian__create_comment(issueId=id, body=text)

# Fallback
mcp__jira__add_comment(issue_key=id, comment=text)
```
</details>

<details>
<summary>Notion</summary>

```
mcp__notion__notion-create-comment({
  parent: { page_id: id },
  rich_text: [{
    type: "text",
    text: { content: text }
  }]
})
```
</details>

---

### 6. link_dependency(fromId, toId)

**Purpose:** Create a blocking dependency (fromId blocks toId)

**Input:**
- `fromId` - Blocking issue ID
- `toId` - Blocked issue ID

**Output:** Success/failure

**Implementation by System:**

<details>
<summary>Jira (Atlassian MCP)</summary>

```
# Create "blocks" relationship
mcp__atlassian__create_dependency(
  from=fromId,
  to=toId,
  type="blocks"
)

# Or via JIRA MCP
mcp__jira__create_link(
  inward_issue=fromId,
  outward_issue=toId,
  link_type="Blocks"
)
```
</details>

<details>
<summary>Notion</summary>

```
# Update the "Blocks" relation property on fromId
current = mcp__notion__notion-fetch(id=fromId)
current_blocks = current.properties.Blocks or []

mcp__notion__notion-update-page({
  data: {
    page_id: fromId,
    command: "update_properties",
    properties: {
      Blocks: [...current_blocks, toId]
    }
  }
})
```
</details>

---

## Scope Classification (Notion Only)

When using Notion, classify items by scope level before creating. This is complexity-based classification that determines hierarchy position.

### Classification Heuristics

| Level | Indicators | Examples |
|-------|-----------|----------|
| **Feature** | Spans multiple modules/domains; requires architectural decisions; has multiple distinct deliverables; needs cross-team coordination | "User authentication system", "Payment processing pipeline", "Real-time collaboration" |
| **User Story** | Single domain deliverable; delivers user-visible value; can be broken into implementation tasks; coherent unit of functionality | "Password reset via email", "Add to cart functionality", "Export report to PDF" |
| **Task** | Atomic implementation unit; single file or small file set; single behavior change; no further breakdown needed | "Add bcrypt password hashing", "Create CartItem component", "Implement PDF header generation" |

### Classification Decision Tree

```
Analyze the scope:
├── Spans multiple modules/domains?
│   ├── YES → Requires architectural decisions?
│   │          ├── YES → FEATURE
│   │          └── NO  → USER STORY (cross-cutting but simple)
│   └── NO  → Single coherent functionality unit?
│              ├── YES → Can be further broken down?
│              │          ├── YES → USER STORY
│              │          └── NO  → TASK
│              └── NO  → TASK (atomic change)
```

### Classification Output Format

When classifying, explain reasoning:

```
Classifying: "User authentication with JWT tokens"

Analysis:
- Spans modules: YES (auth service, token service, middleware, database)
- Architectural decisions: YES (JWT strategy, token storage, refresh mechanism)
- Multiple deliverables: YES (login, logout, token refresh, session management)

Classification: **Feature**
Reasoning: This spans multiple domains (auth, tokens, middleware) and requires
architectural decisions about token strategy. It will be broken into User Stories.
```

### Strict Hierarchy Rules

When breaking down, enforce level transitions:

| Parent Level | Valid Child Level | Invalid Child Level |
|--------------|-------------------|---------------------|
| Feature | User Story | Task (skip level), Feature (same level) |
| User Story | Task | Feature (wrong direction), User Story (same level) |
| Task | (none - leaf node) | Any (tasks have no children) |

### Integration with Type

Level and Type are independent dimensions:

| | feature | chore | bug |
|---|---------|-------|-----|
| **Feature** | New capability spanning domains | Major refactoring effort | System-wide bug fix |
| **User Story** | Single domain feature | Module-level maintenance | Domain-specific bug |
| **Task** | Atomic feature implementation | Config/docs update | Single file bug fix |

**Example:** A "Payment validation bug" might be:
- **Level:** User Story (single domain - payments, coherent fix)
- **Type:** bug (fixing broken behavior)

---

## Usage Pattern in Skills

When implementing skills that need PM operations:

```markdown
### Step N: [Operation Name]

**Read PM configuration from CLAUDE.md:**
- Determine which PM system is configured (jira/notion)
- Get project/database identifier

**Execute operation based on system:**

**If Jira:**
[Jira-specific MCP calls]

**If Notion:**
[Notion-specific MCP calls]
```

## Error Handling

All operations should handle:

1. **MCP server not available** - Guide user to install/configure
2. **Authentication failure** - Guide user to re-authenticate
3. **Resource not found** - Clear error message with ID
4. **Permission denied** - Explain required permissions
5. **Network errors** - Retry logic with backoff

## Related Skills

- `configuring-project-management` - Initial PM setup
- `creating-tickets` - Standardized ticket creation
- `refining-issues` - Uses get_issue, create_issue, update_issue
- `breakdown-planning` - Uses create_issue, link_dependency
- `executing-plans` - Uses list_children, update_issue
