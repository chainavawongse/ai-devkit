# Notion Database Schema Template

This template defines the standard Notion database schema used by the plugin for project management.

## Database Creation

Use `mcp__notion__notion-create-database` to create this schema:

```json
{
  "parent": {
    "page_id": "<user-specified-parent-page-id>"
  },
  "title": [
    {
      "type": "text",
      "text": { "content": "Project Tasks" }
    }
  ],
  "properties": {
    "Name": {
      "type": "title",
      "title": {}
    },
    "Status": {
      "type": "select",
      "select": {
        "options": [
          { "name": "Todo", "color": "gray" },
          { "name": "In Progress", "color": "blue" },
          { "name": "Done", "color": "green" }
        ]
      }
    },
    "Type": {
      "type": "select",
      "select": {
        "options": [
          { "name": "feature", "color": "purple" },
          { "name": "chore", "color": "yellow" },
          { "name": "bug", "color": "red" }
        ]
      }
    },
    "Priority": {
      "type": "select",
      "select": {
        "options": [
          { "name": "Low", "color": "gray" },
          { "name": "Medium", "color": "yellow" },
          { "name": "High", "color": "red" }
        ]
      }
    },
    "Parent": {
      "type": "relation",
      "relation": {
        "type": "single_property",
        "single_property": {}
      }
    },
    "Blocks": {
      "type": "relation",
      "relation": {
        "type": "dual_property",
        "dual_property": {
          "synced_property_name": "Blocked By"
        }
      }
    }
  }
}
```

## Property Descriptions

| Property | Type | Purpose | Values |
|----------|------|---------|--------|
| **Name** | title | Issue title/summary | Free text |
| **Status** | select | Current workflow state | Todo, In Progress, Done |
| **Type** | select | Issue classification for routing | feature, chore, bug |
| **Priority** | select | Importance level | Low, Medium, High |
| **Parent** | relation | Links sub-issues to parent | Self-referential |
| **Blocks** | relation | Dependency tracking | Self-referential, creates "Blocked By" |

## Property Mapping

### From Plugin Operations to Notion Properties

| Plugin Field | Notion Property | Notes |
|--------------|-----------------|-------|
| `title` | Name | Title property |
| `description` | Page content | Stored as markdown in page body |
| `status` | Status | Select property |
| `type` | Type | Maps to feature/chore/bug |
| `parentId` | Parent | Relation to parent page |
| `blocks` | Blocks | Relation array |
| `blockedBy` | Blocked By | Auto-created by dual relation |

### Status Transitions

```
Todo → In Progress → Done
```

The plugin will update Status property during execution:
- Task starts: `Todo` → `In Progress`
- Task completes: `In Progress` → `Done`

### Type-Based Routing

The `Type` property determines which execution skill is invoked:
- `feature` → `Skill('devkit:executing-tasks')` - Full TDD workflow
- `chore` → `Skill('devkit:executing-chores')` - Verification-focused
- `bug` → `Skill('devkit:executing-bug-fixes')` - Debug + TDD fix

## Page Content Structure

Issue descriptions are stored as page content using Notion-flavored markdown:

```markdown
## Specification Context (WHAT we're building)

[Extracted from parent Specification section]

## Technical Plan Guidance (HOW to build it)

[Extracted from parent Technical Plan section]

## TDD Implementation Checklist

**RED Phase:**
- [ ] Write test for [behavior 1] - verify it fails
- [ ] Write test for [behavior 2] - verify it fails

**GREEN Phase:**
- [ ] Implement minimal code to pass tests
- [ ] All tests passing

**REFACTOR Phase:**
- [ ] Check for code smells
- [ ] Refactor while keeping tests green

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Files to Touch

- `path/to/file1.ts`
- `path/to/file2.ts`
```

## Self-Referential Relations

The `Parent` and `Blocks` properties are self-referential relations pointing to the same database. This enables:

1. **Parent-Child Hierarchy**
   - Epic/Story has no Parent
   - Sub-tasks reference their parent via Parent property

2. **Dependency Tracking**
   - Task A blocks Task B: A.Blocks includes B
   - Task B is blocked by A: B."Blocked By" automatically includes A (dual relation)

## Database Views (Optional)

Recommended views to create after database setup:

1. **Board View** - Kanban grouped by Status
2. **Table View** - All issues with all properties
3. **By Parent View** - Grouped by Parent for hierarchy
4. **Blocked View** - Filtered to show blocked issues

## Validation

After creating the database, verify:

1. All 6 properties exist with correct types
2. Status has exactly: Todo, In Progress, Done
3. Type has exactly: feature, chore, bug
4. Parent relation points to same database
5. Blocks/Blocked By dual relation is working

Test by creating a sample page and setting all properties.
