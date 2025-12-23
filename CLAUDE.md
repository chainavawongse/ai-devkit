# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a centralized AI-assisted development configuration repository for Ncontracts. It serves two purposes:

1. **Claude Code Plugin Marketplace** - Hosts the AI DevKit plugin
2. **Shared Configurations** - Provides reusable Claude agents, commands, and settings for copying to other repos

## Architecture

```
ai-devkit/
├── .claude/                    # Shared Claude Code configurations (copy to other repos)
│   ├── agents/                 # Specialized AI agents (codebase-analyzer, etc.)
│   ├── commands/               # Slash commands (/commit, /fix, /review, etc.)
│   └── settings.json           # Permission settings
├── .claude-plugin/             # Marketplace configuration
│   └── marketplace.json        # Plugin registry
├── plugins/                    # Plugin - full documentation at plugins/README.md
│   ├── commands/               # Workflow commands (/refine, /plan, etc.)
│   ├── skills/                 # Reusable workflow units
│   ├── agents/                 # Specialized subagents
│   └── hooks/                  # Quality enforcement scripts
└── .github/workflows/          # GitHub Actions (claude-code-review, pr-size-labeler)
```

## Plugin

The main plugin provides a spec-driven development workflow:

```
/refine → /plan → /breakdown → /execute → /pr → /address-feedback
```

- **refine** - Refine ideas into validated Specifications (WHAT to build)
- **plan** - Create Technical Plans from Specifications (HOW to build)
- **breakdown** - Break plans into sub-tickets with dependencies
- **execute** - Sequential execution in isolated worktrees
- **pr** - Create comprehensive PRs
- **address-feedback** - Auto-implement PR review comments

Full plugin documentation: `plugins/README.md`
AI development guide: `plugins/CLAUDE.md`

## Key Design Decisions

- **Specs live in JIRA** - Never create separate plan files; use JIRA as single source of truth
- **TDD enforced** - Features/bugs require test-first; chores run verification only
- **Just abstraction** - All workflows use `just` commands making plugin stack-agnostic
- **Sequential execution** - Sub-tickets execute one at a time in dependency order
- **Worktrees at ~/worktrees/** - Isolated execution outside main workspace

## Working with This Repository

When modifying this repo:

- **Commands** (`*.md` in commands dirs): Entry points for workflows, should orchestrate skills
- **Skills** (`skills/*/SKILL.md`): Reusable workflow units, target <500 lines, focus on WHAT not WHY
- **Agents** (`*.md` in agents dirs): Subagent definitions invoked via Task() tool

When copying to other repos:
- Copy `.claude/` directory for agents, commands, and settings
- Copy `.github/workflows/` for PR workflows
