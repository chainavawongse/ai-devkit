# Development Guidelines

Quick reference for development standards and best practices. This project uses a spec-driven development workflow optimized for working with Claude Code.

## 📚 Documentation Index

### Standards

- **[Naming Conventions](./standards/naming-conventions.md)** - File, variable, function, component naming rules
- **[Code Quality & Tooling](./standards/code-quality.md)** - ESLint, Prettier, pre-commit hooks
- **[TypeScript Guidelines](./standards/typescript-guidelines.md)** - Type safety and TS best practices
- **[Accessibility Standards](./standards/accessibility.md)** - a11y requirements and patterns

### Architecture

- **[Folder Structure](./architecture/folder-structure.md)** - Complete project organization
- **[State Management](./architecture/state-management.md)** - Zustand + React Query strategy
- **[Error Handling](./architecture/error-handling.md)** - Centralized error handling approach
- **[Environment Configuration](./architecture/environment-config.md)** - Environment variables and config management
- **[Security](./architecture/security.md)** - Frontend security best practices
- **[CI/CD Pipeline](./architecture/ci-cd.md)** - GitHub Actions workflows for CI/CD

### Patterns

- **[API Integration](./patterns/api-integration.md)** - Axios + React Query patterns
- **[Component Patterns](./patterns/component-patterns.md)** - React component best practices
- **[Form Patterns](./patterns/form-patterns.md)** - React Hook Form + Zod patterns
- **[Performance Optimization](./patterns/performance.md)** - Code splitting, memoization, optimization

### Testing

- **[Testing Strategy](./testing/testing-strategy.md)** - Overall testing approach
- **[Unit Testing](./testing/unit-testing.md)** - Vitest + React Testing Library
- **[E2E Testing](./testing/e2e-testing.md)** - Playwright end-to-end tests

### Examples

- **[Component Template](./examples/component-template.tsx)** - Reference component implementation
- **[Hook Template](./examples/hook-template.ts)** - Reference custom hook
- **[API Template](./examples/api-template.ts)** - Reference API integration
- **[Test Template](./examples/test-template.test.tsx)** - Reference test file

---

## 🚀 Tech Stack

| Category | Technology |
|----------|-----------|
| **Framework** | React 18 |
| **Language** | TypeScript (strict, no `any`) |
| **Build Tool** | Vite |
| **Styling** | Tailwind CSS |
| **State Management** | Zustand (client state) + TanStack Query (server state) |
| **Forms** | React Hook Form + Zod |
| **HTTP Client** | Axios |
| **Testing** | Vitest + React Testing Library + Playwright |
| **Code Quality** | ESLint + Prettier + Husky |

---

## 📁 Project Structure Overview

```
src/
  ├── app/                    # App setup & providers
  ├── features/               # Feature modules (auth, products, etc.)
  │   └── [feature]/
  │       ├── components/
  │       ├── hooks/
  │       ├── api/
  │       ├── stores/
  │       └── types/
  ├── components/             # Shared components
  │   ├── ui/                # Pure UI components
  │   ├── layout/            # Layout components
  │   └── forms/             # Shared form components
  ├── lib/                   # Core utilities & config
  │   ├── api/
  │   ├── stores/
  │   └── utils/
  ├── hooks/                 # Shared hooks
  ├── types/                 # Shared TypeScript types
  └── pages/                 # Route components
```

See [Folder Structure](./architecture/folder-structure.md) for complete details.

---

## 🎯 Quick Start

### Common Commands

```bash
# Development
npm run dev                 # Start dev server
npm run build               # Build for production
npm run preview             # Preview production build

# Code Quality
npm run lint                # Run ESLint
npm run lint:fix            # Fix ESLint issues
npm run format              # Format with Prettier
npm run type-check          # TypeScript type checking

# Testing
npm run test                # Run unit tests
npm run test:ui             # Run tests with UI
npm run test:coverage       # Generate coverage report
npm run test:e2e            # Run E2E tests

# All Checks (useful before committing)
npm run check               # Run all checks (type-check, lint, format, test)
```

### Environment Setup

1. Copy environment template:

   ```bash
   cp .env.example .env.local
   ```

2. Fill in your local values in `.env.local`

3. See [Environment Configuration](./architecture/environment-config.md) for details

---

## 📝 Development Workflow

### Creating a New Feature

1. **Create feature folder**

   ```bash
   mkdir -p src/features/my-feature/{components,hooks,api,types}
   ```

2. **Follow the structure** defined in [Folder Structure](./architecture/folder-structure.md)

3. **Implement components** using patterns from [Component Patterns](./patterns/component-patterns.md)

4. **Add API integration** following [API Integration](./patterns/api-integration.md)

5. **Write tests** per [Testing Strategy](./testing/testing-strategy.md)

6. **Ensure accessibility** using [Accessibility Standards](./standards/accessibility.md)

### Working with Claude Code

This project is optimized for spec-driven development with Claude Code:

1. **Write a specification** describing what you want to build
2. **Reference relevant docs** when invoking Claude Code:

   ```bash
   claude-code "Implement user profile editing feature per spec.md.
   Follow patterns in docs/patterns/form-patterns.md and 
   docs/architecture/error-handling.md"
   ```

3. **Review and iterate** on the implementation

---

## 🎨 Quick Reference

### File Naming

```bash
# Components
Button.tsx              # ✅ PascalCase
user-profile.tsx        # ❌ kebab-case

# Utilities & Hooks
formatDate.ts           # ✅ camelCase
useDebounce.ts          # ✅ Hooks start with 'use'

# Types
user.types.ts           # ✅ name.types.ts
types.ts                # ❌ Too generic

# Tests
Button.test.tsx         # ✅ Matches component name
Button.spec.tsx         # ❌ Use .test not .spec
```

See [Naming Conventions](./standards/naming-conventions.md) for complete rules.

### Code Style

```typescript
// ✅ Always use async/await
async function fetchUser(id: string): Promise<User> {
  const { data } = await apiClient.get(`/users/${id}`);
  return data;
}

// ✅ No 'any' type
function processData(data: unknown): ProcessedData {
  // Type guard or assertion
}

// ✅ Explicit return types for functions
function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}

// ✅ Boolean variables with is/has/can/should prefix
const isLoading = true;
const hasError = false;
const canEdit = user.role === 'admin';
```

### State Management

```typescript
// Server state (API data) - Use React Query
const { data: products } = useProducts();
const createProduct = useCreateProduct();

// Global client state - Use Zustand
const user = useAuthStore((state) => state.user);
const theme = useUiStore((state) => state.theme);

// Local component state - Use useState
const [isOpen, setIsOpen] = useState(false);
```

See [State Management](./architecture/state-management.md) for details.

---

## ✅ Pre-Commit Checklist

Before committing code:

- [ ] All tests pass (`npm run test`)
- [ ] No TypeScript errors (`npm run type-check`)
- [ ] No lint errors (`npm run lint`)
- [ ] Code is formatted (`npm run format`)
- [ ] New features have tests
- [ ] Accessibility standards followed
- [ ] No console.log statements (use console.warn/error if needed)

---

## 🐛 Common Issues

### Import Errors

- Use path aliases: `@/components/ui/Button` not `../../../components/ui/Button`
- Ensure `tsconfig.json` and `vite.config.ts` have matching path aliases

### Type Errors

- Never use `any` - use `unknown` and type guards instead
- Enable all strict TypeScript flags
- See [TypeScript Guidelines](./standards/typescript-guidelines.md)

### Test Failures

- Mock API calls in unit tests
- Use `renderWithProviders` for components that need React Query
- See [Unit Testing](./testing/unit-testing.md)

### Performance Issues

- Lazy load routes and heavy components
- Use React Query's `staleTime` to reduce refetches
- Virtualize long lists (100+ items)
- See [Performance Optimization](./patterns/performance.md)

---

## 🔗 External Resources

- [React Documentation](https://react.dev)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Tailwind CSS Docs](https://tailwindcss.com/docs)
- [TanStack Query Docs](https://tanstack.com/query/latest)
- [React Hook Form Docs](https://react-hook-form.com)
- [Vitest Documentation](https://vitest.dev)
- [Playwright Documentation](https://playwright.dev)

---

## 💡 Getting Help

1. Check the relevant documentation in `/docs`
2. Review `/examples` for reference implementations
3. Search existing issues/PRs for similar problems
4. Ask in team communication channels

---

## 📄 License

[Your License Here]
