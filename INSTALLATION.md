# Plugin Installation

## Prerequisites

- [Claude Code](https://docs.anthropic.com/claude-code) installed
- [Just](https://github.com/casey/just#installation) task runner installed
- Repository access to chainavawongse/ai-devkit

## Install

```bash
git clone https://github.com/chainavawongse/ai-devkit.git
cd ai-devkit
just install-plugin
```

Restart Claude Code, then run `/help` to verify `/*` commands appear.

## Configure Project Management (Optional)

The plugin supports multiple project management systems. Choose the one your team uses:

### Option 1: Jira (Atlassian MCP)

```bash
claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse
```

Then authenticate:
1. Restart Claude Code
2. Open "Search & Tools" menu
3. Select "Connect Atlassian Account"
4. Complete OAuth flow and grant Jira access

See [Atlassian MCP Server Setup](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/setting-up-claude-ai/) for detailed instructions.

### Option 2: Notion

The Notion MCP server may already be available in Claude. If not:

1. Configure Notion MCP in your Claude settings
2. Authenticate with your Notion workspace
3. Grant access to the databases you want to use

### Option 3: GitHub Issues

No MCP server needed. Uses the `gh` CLI:

```bash
# Install GitHub CLI if not already installed
brew install gh  # macOS
# or see https://cli.github.com/

# Authenticate
gh auth login
```

### Verify Configuration

After installation, run `/setup` in your repository to configure PM integration. The setup wizard will:
- Detect available MCP servers
- Verify authentication
- Configure project/database settings
- Record configuration in CLAUDE.md

## Update

```bash
cd /path/to/ai-devkit
just update-plugin
```

Restart Claude Code after updating.

## Uninstall

```bash
just uninstall-plugin
```

## Troubleshooting

**Commands not showing in /help**
1. Restart Claude Code
2. Verify plugin: `claude plugin marketplace list`
3. Reinstall: `just uninstall-plugin && just install-plugin`

**PM system connection issues**
- Re-authenticate via your MCP server settings
- Run `/setup` to reconfigure project management
- Test: Ask Claude to fetch an issue from your PM system
