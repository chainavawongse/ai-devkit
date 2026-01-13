---
name: configuring-project-management
description: Configure project management integration (Jira, Notion, or GitHub Issues) with MCP server verification and authentication. Records project metadata in repository documentation.
when_to_use: when setting up project management integration for a repository, verifying MCP server installation, or configuring project tracking for AI-assisted development
version: 2.0.0
---

# Configuring Project Management

Configure project management tool integration, verify MCP server installation and authentication, and record project metadata in repository documentation.

**Core principle:** MCP servers are user-installed dependencies. This skill verifies they exist and work correctly, but NEVER attempts to install them.

**Purpose:** Enable plugin workflows to create, update, and track tickets automatically through PM system integration.

## When to Use

**Use this skill when:**

- Setting up new repository with the plugin
- Configuring project management integration for first time
- Verifying MCP server installation and authentication
- Recording project/database metadata for ticket creation

**Don't use when:**

- Project management already configured and verified
- Repository uses no PM tool (manual tracking only)
- MCP integration not needed

## Prerequisites

**User must have MCP server installed separately:**

- **Jira (Atlassian)**: <https://support.atlassian.com/atlassian-rovo-mcp-server/docs/setting-up-claude-ai/>
- **Jira (Alternative)**: User must find and install appropriate Jira MCP server
- **Notion**: Built-in Notion MCP (mcp__notion__*) or separate Notion MCP server
- **GitHub Issues**: Built-in via GitHub CLI (gh) - no MCP server needed

**CRITICAL:** Plugin does NOT install MCP servers. User installs them separately.

## Workflow

### 1. Interview User About Project Management

**Ask which tool is used:**

```
Which project management tool does this repository use?

1. Jira
2. Notion
3. GitHub Issues
4. None (manual tracking)
```

**Record response** for next steps.

---

### 2. Verify MCP Integration

#### If Jira

Check if Jira MCP server is available:

```bash
# Check for Jira MCP tools - look for either:
# - mcp__atlassian__* (Atlassian official)
# - mcp__jira__* (Alternative implementations)
```

**If Jira MCP tools NOT available:**

```
The Jira MCP server is not installed.

Plugin requires a Jira MCP server to work with Jira issues.

**Installation Instructions:**
1. Atlassian Official: https://support.atlassian.com/atlassian-rovo-mcp-server/docs/setting-up-claude-ai/
2. Follow installation instructions for your system
3. Restart Claude Desktop/CLI

After installation, run this setup command again.
```

**Stop workflow** - cannot proceed without MCP server.

#### If Notion

Check if Notion MCP tools are available:

```bash
# Check for Notion MCP tools:
# - mcp__notion__notion-search
# - mcp__notion__notion-fetch
# - mcp__notion__notion-create-pages
# - mcp__notion__notion-create-database
# - mcp__notion__notion-update-page
```

**If Notion MCP tools NOT available:**

```
The Notion MCP server is not installed.

Plugin requires the Notion MCP server to work with Notion databases.

**Installation Instructions:**
1. The Notion MCP may already be available in Claude
2. If not, configure it in your MCP settings
3. Ensure you have authenticated with your Notion workspace

After installation, run this setup command again.
```

**Stop workflow** - cannot proceed without MCP server.

#### If GitHub Issues

No MCP server needed. Use `gh` CLI:

```bash
# Verify gh is installed and authenticated
gh auth status
```

If not authenticated:

```bash
gh auth login
```

---

### 3. Test Authentication

#### For Jira

Try listing projects to verify authentication:

```bash
# Use Jira MCP tool to list projects
# Primary: mcp__atlassian__list_projects
# Fallback: mcp__jira__list_projects
```

**Expected success:** Returns list of projects/teams

**If authentication fails:**

```
Jira MCP authentication failed.

Please verify:
1. Your Jira API key is correctly configured
2. The API key has necessary permissions
3. Your Jira account has access to projects

Check your MCP configuration file and restart Claude.
```

#### For Notion

Try searching to verify authentication:

```bash
# Use Notion MCP tool to search
mcp__notion__notion-search(query="test", query_type="internal")
```

**Expected success:** Returns search results (even if empty)

**If authentication fails:**

```
Notion MCP authentication failed.

Please verify:
1. You have connected your Notion workspace
2. The integration has access to the pages/databases you need
3. Check Notion integration settings

Re-authenticate and restart Claude.
```

#### For GitHub Issues

```bash
# Verify gh authentication
gh auth status

# Test API access
gh repo view --json name
```

---

### 4. Configure Project/Database

#### If Jira

Ask user:

```
What is the top-level project or epic for this repository?

This will be used as the default parent when creating new issues.

Provide: Project key (e.g., PROJ) or epic ID (e.g., PROJ-123)
```

**Validate the provided ID:**

```bash
# Try to fetch the project or epic
# Confirm it exists and is accessible
mcp__atlassian__get_issue(id=provided_id)
# OR
mcp__jira__get_issue(issue_key=provided_id)
```

#### If Notion

Ask user:

```
How would you like to set up Notion for project tracking?

1. Create new database (recommended)
   - I'll create a "Project Tasks" database with the required schema
   - You'll need to specify a parent page

2. Use existing database
   - Provide the URL or ID of an existing Notion database
   - Must have required properties (Status, Type, etc.)
```

**Option 1 - Create New Database:**

```
Please provide the Notion page URL or ID where I should create the database.

This will be the parent page containing your project tracking database.
```

Then create the database using the template schema:

```bash
# Create database with standard schema
mcp__notion__notion-create-database({
  parent: { page_id: user_provided_page_id },
  title: [{ type: "text", text: { content: "Project Tasks" }}],
  properties: {
    "Name": { type: "title", title: {} },
    "Status": {
      type: "select",
      select: {
        options: [
          { name: "Todo", color: "gray" },
          { name: "In Progress", color: "blue" },
          { name: "Done", color: "green" }
        ]
      }
    },
    "Type": {
      type: "select",
      select: {
        options: [
          { name: "feature", color: "purple" },
          { name: "chore", color: "yellow" },
          { name: "bug", color: "red" }
        ]
      }
    },
    "Priority": {
      type: "select",
      select: {
        options: [
          { name: "Low", color: "gray" },
          { name: "Medium", color: "yellow" },
          { name: "High", color: "red" }
        ]
      }
    },
    "Parent": {
      type: "relation",
      relation: { type: "single_property", single_property: {} }
    },
    "Blocks": {
      type: "relation",
      relation: {
        type: "dual_property",
        dual_property: { synced_property_name: "Blocked By" }
      }
    }
  }
})
```

Record the returned database ID and data source URL.

**Option 2 - Use Existing Database:**

```
Please provide the Notion database URL or ID.

Example: https://notion.so/workspace/abc123...
```

Fetch and validate the database:

```bash
mcp__notion__notion-fetch(id=database_url_or_id)
```

**Verify required properties exist:**

- Name (title)
- Status (select with Todo, In Progress, Done)
- Type (select with feature, chore, bug)

If missing properties:

```
The database is missing required properties:
- [list missing properties]

Would you like me to add them? (This will modify your database schema)
```

If user agrees, update database schema:

```bash
mcp__notion__notion-update-database({
  database_id: id,
  properties: {
    # Add missing properties
  }
})
```

#### If GitHub Issues

Record repository name (auto-detected from git remote):

```bash
# Get repository from git remote
git remote get-url origin
# Extract: owner/repo
```

---

### 5. Record Configuration in Documentation

**Update top-level CLAUDE.md** with project management metadata.

**If CLAUDE.md exists:**

Add or update the project management section:

**For Jira:**

```markdown
## Project Management

**System:** Jira
**Project Key:** [PROJECT-KEY]

### Jira Configuration
- MCP Server: atlassian (or jira)
- Authentication: ✓ Verified
- Auto ticket creation: Enabled
```

**For Notion:**

```markdown
## Project Management

**System:** Notion
**Database:** [Database Name]

### Notion Configuration
- Database URL: https://notion.so/...
- Database ID: [uuid]
- Data Source ID: collection://[uuid]
- Schema: Standard (Name, Status, Type, Parent, Blocks)
- Authentication: ✓ Verified
```

**For GitHub Issues:**

```markdown
## Project Management

**System:** GitHub Issues
**Repository:** [owner/repo]

### GitHub Configuration
- CLI: gh (authenticated)
- Auto issue creation: Enabled
```

**If CLAUDE.md does NOT exist:**

Inform user:

```
CLAUDE.md does not exist yet. Project management configuration will be added when documentation is generated.

For now, I'll record:
- System: [Jira/Notion/GitHub Issues]
- Project/Database: [identifier]
- Status: MCP verified and authenticated ✓
```

Store this temporarily for later documentation generation.

---

### 6. Final Verification

**Run one more connectivity test:**

**For Jira:**

```bash
# Test read access
mcp__atlassian__get_issue(id=test_issue_id)
```

**For Notion:**

```bash
# Test create and delete a page
test_page = mcp__notion__notion-create-pages({
  parent: { data_source_id: database_id },
  pages: [{ properties: { Name: "Setup Test - Delete Me" }}]
})
# Verify creation succeeded
mcp__notion__notion-fetch(id=test_page.id)
```

**For GitHub Issues:**

```bash
# Verify can list issues
gh issue list --limit 1
```

**If verification succeeds:**

```
✓ Project management configured successfully

System: [Jira/Notion/GitHub Issues]
Project/Database: [name/id]
MCP Status: Verified and authenticated
```

Proceed to next phase of setup.

**If verification fails:**

Show error and ask user to resolve before continuing.

---

## Expected Output

**Successful completion:**

- Project management tool identified
- MCP server verified
- Authentication confirmed working
- Project/database ID recorded
- CLAUDE.md updated (or info stored for later)
- Connectivity verified

**Summary to provide:**

```markdown
# Project Management Configuration Complete

**System:** [Jira/Notion/GitHub Issues/None]
**Project/Database:** [identifier]
**MCP Integration:** [✓ Verified / N/A]
**Authentication:** [✓ Verified / N/A]

## Available Plugin Workflows

With project management configured, you can now use:
- `/refine` - Create/refine specifications
- `/plan` - Add technical plans to issues
- `/breakdown` - Create sub-issues with dependencies
- `/execute` - Auto-execute ticket workflows

## Next Steps

1. Generate repository documentation (if not done)
2. Create or refine your first issue
3. Use plugin workflows for automated development
```

---

## Error Handling

**MCP server not installed:**

- Provide clear installation instructions
- Link to official documentation
- Stop workflow gracefully
- Instruct user to re-run setup after installation

**Authentication fails:**

- Explain what authentication is needed
- Provide troubleshooting steps
- Link to MCP configuration documentation
- Allow user to fix and retry

**Project/database not found:**

- Verify user has access
- Check for typos in ID/URL
- Offer to list available options (if MCP supports it)
- Allow user to skip and configure manually later

**Schema validation fails (Notion):**

- List missing or incorrect properties
- Offer to add/update properties automatically
- Provide manual fix instructions

**Write access issues:**

- Confirm API/integration has write permissions
- Check user's role in project
- Provide instructions to update permissions
- Allow read-only mode if write not needed

---

## Notes

**MCP Server Responsibility:**

- Plugin does NOT install MCP servers
- Users install MCP servers separately
- This skill only verifies installation and authentication

**Integration with Other Skills:**

- Called from `/setup` command Phase 1
- Configuration used by all PM operations via `pm-operations` skill
- Skills read config from CLAUDE.md to determine which MCP tools to use

**Configuration Persistence:**

- Stored in top-level CLAUDE.md (primary)
- Can also store in `.devkit/config.json` if needed
- Should survive documentation regeneration

**Supported Systems:**

- Jira (via mcp__atlassian__*or mcp__jira__*)
- Notion (via mcp__notion__*)
- GitHub Issues (via gh CLI)
- Future: Linear, Monday.com, Asana
