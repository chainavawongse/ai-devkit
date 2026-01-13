# AI Configs

Centralized AI-assisted development configurations for Ncontracts. Contains the **Plugin** and shared Claude Code configurations.

## Plugin

AI DevKit is a spec-driven development workflow integrated with JIRA:

```
/refine → /plan → /breakdown → /execute → /pr → /address-feedback
```

**Core features:**

- **Spec-driven** - Separates WHAT (Specification) from HOW (Technical Plan)
- **Test-driven** - TDD enforced at all levels (RED → GREEN → REFACTOR)
- **Sequential execution** - Tasks run in dependency order in isolated worktrees
- **Stack-agnostic** - Uses `just` commands, works with any language/framework
- **JIRA integration** - All context lives in tickets, real-time status updates

**Get started:**

- [Installation Guide](INSTALLATION.md)
- [Quick Start & Usage](plugins/QUICK-START.md)
- [Full Documentation](plugins/README.md)

## Shared Configurations

Copy these to other repositories for consistent Claude Code setup.

### Custom Agents

Specialized agents for the Task tool (`subagent_type`):

| Agent | Purpose |
|-------|---------|
| `codebase-analyzer` | Deep-dive implementation analysis |
| `codebase-locator` | Find files and components |
| `codebase-pattern-finder` | Find similar implementations |
| `web-search-researcher` | Research modern information |

### Custom Commands

Development workflow commands:

| Command | Purpose |
|---------|---------|
| `/commit` | Context-aware git commits |
| `/fix` | Systematic debugging |
| `/review` | Code review |
| `/describe_pr` | Generate PR descriptions |

### GitHub Actions

| Workflow | Trigger |
|----------|---------|
| `claude-code-review.yml` | `@claude-review` mention in PR |
| `pr-size-labeler.yml` | Automatic on all PRs |

## Usage

**Copy to another repository:**

```bash
# Claude configurations
cp -r ai-devkit/.claude your-repo/

# GitHub workflows (optional)
cp ai-devkit/.github/workflows/*.yml your-repo/.github/workflows/
```

## Repository Structure

```
ai-devkit/
├── .claude/                 # Shared configurations (copy to other repos)
│   ├── agents/              # Custom agents
│   ├── commands/            # Slash commands
│   └── settings.json        # Permissions
├── .claude-plugin/          # Marketplace config
├── plugins/            # plugin
└── .github/workflows/       # GitHub Actions
```

## Support

- [GitHub Issues](https://github.com/chainavawongse/ai-devkit/issues)
