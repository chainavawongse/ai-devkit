# AI DevKit

A comprehensive development kit that provides standardized instructions and documentation for AI coding assistants working on React/TypeScript projects.

## What is this?

AI DevKit is a collection of configuration files, guidelines, and documentation templates designed to help AI coding assistants (Claude Code, GitHub Copilot, Cursor, Gemini, etc.) understand your project structure and generate consistent, high-quality code.

## Supported AI Tools

| Tool | Configuration File | Auto-detected |
|------|-------------------|---------------|
| Claude Code | `CLAUDE.md` (symlink to `AGENTS.md`) | Yes |
| GitHub Copilot | `.github/copilot-instructions.md` (symlink) | Yes |
| Gemini Code Assist | `GEMINI.md`, `.gemini/instructions.md` (symlinks) | Yes |
| Cursor | `.cursorrules` | Yes |
| Others | Reference `AGENTS.md` in your prompt | Manual |

## Project Structure

```
ai-devkit/
├── AGENTS.md                    # Main AI instructions (source of truth)
├── CLAUDE.md                    # Symlink → AGENTS.md
├── GEMINI.md                    # Symlink → AGENTS.md
├── .cursorrules                 # Condensed version for Cursor
├── .github/
│   └── copilot-instructions.md  # Symlink → AGENTS.md
├── .gemini/
│   └── instructions.md          # Symlink → AGENTS.md
├── frontend/                    # Development documentation
│   ├── DEVELOPMENT.md           # Entry point & quick reference
│   ├── architecture/            # Architectural decisions
│   │   ├── folder-structure.md
│   │   ├── state-management.md
│   │   ├── error-handling.md
│   │   ├── security.md
│   │   └── ...
│   ├── patterns/                # Code patterns
│   │   ├── component-patterns.md
│   │   ├── api-integration.md
│   │   ├── form-patterns.md
│   │   └── performance.md
│   ├── standards/               # Coding standards
│   │   ├── naming-conventions.md
│   │   ├── typescript-guidelines.md
│   │   ├── accessibility.md
│   │   └── code-quality.md
│   ├── testing/                 # Testing strategies
│   │   ├── testing-strategy.md
│   │   ├── unit-testing.md
│   │   └── e2e-testing.md
│   └── examples/                # Reference implementations
│       ├── component-template.tsx
│       ├── api-template.ts
│       ├── hook-template.ts
│       └── test-template.test.tsx
└── backend/                     # (placeholder for backend docs)
```

## Tech Stack (Documented)

The documentation covers a modern React frontend stack:

- **Framework**: React 18
- **Language**: TypeScript (strict mode)
- **Build Tool**: Vite
- **Styling**: Tailwind CSS
- **State Management**: Zustand (client) + TanStack Query (server)
- **Forms**: React Hook Form + Zod
- **HTTP Client**: Axios
- **Testing**: Vitest + React Testing Library + Playwright
- **Code Quality**: ESLint + Prettier + Husky

## Usage

### For Your Own Project

1. **Clone or copy** this repository into your project
2. **Customize** the documentation in `frontend/` to match your project
3. **Update** `AGENTS.md` with your specific rules and patterns
4. The symlinks will automatically provide instructions to supported AI tools

### How It Works

When you use an AI coding assistant in a project containing these files:

1. The tool reads its configuration file (e.g., `CLAUDE.md` for Claude Code)
2. The AI receives context about your project structure, patterns, and rules
3. Generated code follows your established conventions automatically

## Key Features

- **Unified instructions**: Single source of truth (`AGENTS.md`) for all AI tools
- **Comprehensive documentation**: Architecture, patterns, standards, and examples
- **Ready-to-use templates**: Component, hook, API, and test templates
- **Best practices baked in**: TypeScript strict mode, accessibility, security
- **Tool-specific optimizations**: Condensed `.cursorrules` for Cursor's format

## Customization

1. **Edit `AGENTS.md`** to change the main instructions
2. **Modify documentation** in `frontend/` folders for detailed guidelines
3. **Update examples** in `frontend/examples/` with your patterns
4. **Adjust `.cursorrules`** separately (it's a condensed version, not a symlink)

## Contributing

Feel free to submit issues and pull requests for:
- Additional AI tool configurations
- Improved documentation templates
- New code patterns and examples
- Bug fixes and clarifications

## License

MIT
