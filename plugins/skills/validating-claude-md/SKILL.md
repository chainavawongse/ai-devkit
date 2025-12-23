---
name: validating-claude-md
description: Validate CLAUDE.md exists and contains required configuration sections before skill execution
when_to_use: at the start of any skill that depends on CLAUDE.md configuration (PM system, project settings)
version: 1.0.0
---

# Validating CLAUDE.md

## Overview

Centralized validation for CLAUDE.md configuration. Call this skill at the start of any workflow that depends on repository configuration.

**Core principle:** Fail fast with clear guidance if configuration is missing or invalid.

## When to Use

Call this skill at the start of:

- `executing-plans` - needs PM system config
- `executing-tasks` - needs PM system config
- `executing-chores` - needs PM system config
- `executing-bug-fixes` - needs PM system config
- `refining-issues` - needs PM system config
- `breakdown-planning` - needs PM system config
- Any skill that reads from `## Project Management` section

## The Process

### Step 1: Check CLAUDE.md Exists

```python
claude_md_path = find_claude_md()  # Search current dir and parents

if not claude_md_path:
    ERROR: """
    ❌ CLAUDE.md not found

    This repository has not been set up for AI-assisted development.

    Run `/setup` to:
    - Generate CLAUDE.md with repository documentation
    - Configure project management system (Jira/Notion)
    - Set up justfile with verification commands
    - Configure pre-commit hooks

    After setup, retry your command.
    """
    STOP
```

### Step 2: Validate Required Sections

```python
claude_md = Read(claude_md_path)

# Check for Project Management section
if "## Project Management" not in claude_md:
    ERROR: """
    ❌ CLAUDE.md missing required section: ## Project Management

    Your CLAUDE.md exists but is missing PM configuration.

    Run `/setup` to configure:
    - PM system type (Jira or Notion)
    - Project/Database ID
    - Required credentials

    Or manually add:

    ## Project Management

    **System:** Jira  # or: Notion
    **Project/Database:** YOUR-PROJECT-KEY
    """
    STOP
```

### Step 3: Parse PM Configuration

```python
pm_section = extract_section(claude_md, "## Project Management")

# Extract system type
system_match = re.search(r'\*\*System:\*\*\s*(Jira|Notion)', pm_section, re.IGNORECASE)
if not system_match:
    ERROR: """
    ❌ Invalid PM system configuration

    Could not determine PM system type. Expected format:

    ## Project Management

    **System:** Jira  # or: Notion
    **Project/Database:** YOUR-ID

    Valid systems: Jira, Notion
    """
    STOP

pm_system = system_match.group(1).lower()  # 'jira' or 'notion'

# Extract project/database ID
id_match = re.search(r'\*\*(?:Project|Database)[^:]*:\*\*\s*(\S+)', pm_section)
if not id_match:
    ERROR: """
    ❌ Missing project/database ID

    PM system is configured but project ID is missing.

    Add to ## Project Management section:

    **Project/Database:** YOUR-PROJECT-KEY  # e.g., TEAM-123 for Jira, or Notion database ID
    """
    STOP

project_id = id_match.group(1)
```

### Step 4: Validate System-Specific Config

**For Jira:**

```python
if pm_system == 'jira':
    # Check for Jira-specific config
    config = {
        'system': 'jira',
        'project_key': project_id,
        'mcp_server': 'atlassian'  # default, can be overridden
    }

    # Check for MCP server override
    mcp_match = re.search(r'\*\*MCP Server:\*\*\s*(\S+)', pm_section)
    if mcp_match:
        config['mcp_server'] = mcp_match.group(1)

    # Validate project key format (typically uppercase letters + optional numbers)
    if not re.match(r'^[A-Z][A-Z0-9]*(-\d+)?$', project_id):
        WARNING: f"Project key '{project_id}' may not be valid Jira format (expected: TEAM or TEAM-123)"
```

**For Notion:**

```python
if pm_system == 'notion':
    config = {
        'system': 'notion',
        'database_id': project_id,
        'data_source_id': None  # Will be extracted if present
    }

    # Check for data source ID (collection://)
    ds_match = re.search(r'\*\*Data Source ID:\*\*\s*(?:collection://)?(\S+)', pm_section)
    if ds_match:
        config['data_source_id'] = ds_match.group(1)

    # Validate database ID format (UUID)
    uuid_pattern = r'^[a-f0-9]{8}-?[a-f0-9]{4}-?[a-f0-9]{4}-?[a-f0-9]{4}-?[a-f0-9]{12}$'
    if not re.match(uuid_pattern, project_id.replace('-', ''), re.IGNORECASE):
        WARNING: f"Database ID '{project_id}' may not be valid Notion UUID format"
```

### Step 5: Return Configuration

```python
# Return validated configuration for calling skill to use
return {
    'valid': True,
    'claude_md_path': claude_md_path,
    'pm_config': config,
    'raw_section': pm_section
}
```

## Output Format

**On Success:**

```markdown
✅ CLAUDE.md validation passed

**Configuration:**
- PM System: {system}
- Project/Database: {project_id}
- MCP Server: {mcp_server}  # Jira only

Proceeding with skill execution...
```

**On Failure:**

```markdown
❌ CLAUDE.md validation failed

{specific_error_message}

**Resolution:** Run `/setup` to configure this repository
```

## Configuration Schema

### Minimal Valid Configuration

```markdown
## Project Management

**System:** Jira
**Project/Database:** TEAM
```

### Full Jira Configuration

```markdown
## Project Management

**System:** Jira
**Project/Database:** TEAM
**MCP Server:** atlassian

### Jira Configuration
- Project Key: TEAM
- Base URL: https://company.atlassian.net
```

### Full Notion Configuration

```markdown
## Project Management

**System:** Notion
**Project/Database:** a1b2c3d4-e5f6-7890-abcd-ef1234567890

### Notion Configuration
- Database URL: https://notion.so/workspace/Tasks-a1b2c3d4e5f6
- Data Source ID: collection://a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

## Integration

**Called by:**

- `executing-plans` - validates before dispatching tasks
- `executing-tasks` - validates before loading ticket
- `executing-chores` - validates before loading ticket
- `executing-bug-fixes` - validates before loading ticket
- `refining-issues` - validates before PM operations
- `breakdown-planning` - validates before creating sub-issues

**Provides:**

- Validated PM configuration
- Clear error messages
- Guidance to run `/setup`

## Remember

- Fail fast with clear messages
- Always point to `/setup` as resolution
- Return structured config for calling skill
- Validate both existence AND content
- Support both Jira and Notion configurations
