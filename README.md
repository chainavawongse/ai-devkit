# AI DevKit

A comprehensive development kit that provides standardized instructions and documentation for AI coding assistants working on full-stack projects (React/TypeScript frontend and .NET backend).

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
├── frontend/                    # React/TypeScript frontend docs
│   ├── DEVELOPMENT.md           # Entry point & quick reference
│   ├── architecture/            # Architectural decisions
│   ├── patterns/                # Code patterns
│   ├── standards/               # Coding standards
│   ├── testing/                 # Testing strategies
│   └── examples/                # Reference implementations
│
└── backend-dotnet/              # .NET backend API docs
    ├── DEVELOPMENT.md           # Entry point & quick reference
    └── api/
        ├── architecture/        # Solution structure, DI, configuration
        ├── patterns/            # Controllers, CQRS, validation, OData
        ├── data/                # Entity Framework Core
        ├── security/            # Authentication & authorization
        ├── standards/           # Naming conventions
        ├── observability/       # Logging & monitoring
        ├── testing/             # Testing strategies
        └── examples/            # Template files (.cs)
```

## Tech Stack (Documented)

### Frontend (React/TypeScript)

- **Framework**: React 18
- **Language**: TypeScript (strict mode)
- **Build Tool**: Vite
- **Styling**: Tailwind CSS
- **State Management**: Zustand (client) + TanStack Query (server)
- **Forms**: React Hook Form + Zod
- **HTTP Client**: Axios
- **Testing**: Vitest + React Testing Library + Playwright
- **Code Quality**: ESLint + Prettier + Husky

### Backend (.NET)

- **Framework**: ASP.NET Core 8
- **Language**: C# 12
- **Architecture**: Clean Architecture + CQRS
- **Mediator**: MediatR
- **Validation**: FluentValidation
- **ORM**: Entity Framework Core 8
- **Database**: PostgreSQL (with pgvector, PostGIS support)
- **Query**: OData
- **Mapping**: AutoMapper
- **Authentication**: JWT + OAuth (Google, GitHub, Apple, Microsoft)
- **Logging**: Serilog
- **Testing**: xUnit + Moq + FluentAssertions

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
