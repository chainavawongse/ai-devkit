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

## Configure JIRA

plugin requires JIRA integration via the Atlassian MCP server.

```bash
claude mcp add --transport sse atlassian https://mcp.atlassian.com/v1/sse
```

Then authenticate:
1. Restart Claude Code
2. Open "Search & Tools" menu
3. Select "Connect Atlassian Account"
4. Complete OAuth flow and grant JIRA access

See [Atlassian MCP Server Setup](https://support.atlassian.com/atlassian-rovo-mcp-server/docs/setting-up-claude-ai/) for detailed instructions.

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

**JIRA connection issues**
- Re-authenticate via `/mcp` command
- Test: Ask Claude "Can you list my JIRA issues?"
