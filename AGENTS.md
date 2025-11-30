# AI Agent Instructions

This file provides instructions for AI coding assistants (Claude Code, GitHub Copilot, Cursor, Codex, Gemini, etc.) when working on this project.

> **Tool-specific setup:**
> - **Claude Code**: Symlinked as `CLAUDE.md` (auto-detected)
> - **Gemini Code Assist**: Symlinked as `GEMINI.md` and `.gemini/instructions.md` (auto-detected)
> - **GitHub Copilot**: Symlinked as `.github/copilot-instructions.md` (auto-detected)
> - **Cursor**: Condensed version in `.cursorrules` (auto-detected)
> - **Others**: Reference `AGENTS.md` in your prompt or context

## Project Overview

This is a React frontend application using TypeScript, Vite, Tailwind CSS, React Query, and Zustand. All development guidelines are in the `frontend/` folder.

## Documentation Priority

When implementing features, read documentation in this order:

1. **Always read first:**
   - `frontend/DEVELOPMENT.md` - Entry point and quick reference
   - `frontend/standards/naming-conventions.md` - File and code naming rules

2. **Read based on task type:**

   | Task | Required Reading |
   |------|------------------|
   | New component | `frontend/patterns/component-patterns.md`, `frontend/examples/component-template.tsx` |
   | API integration | `frontend/patterns/api-integration.md`, `frontend/examples/api-template.ts` |
   | Form handling | `frontend/patterns/form-patterns.md` |
   | State management | `frontend/architecture/state-management.md` |
   | Writing tests | `frontend/testing/testing-strategy.md`, `frontend/examples/test-template.test.tsx` |
   | New feature module | `frontend/architecture/folder-structure.md` |
   | Error handling | `frontend/architecture/error-handling.md` |
   | Performance work | `frontend/patterns/performance.md` |
   | Security concerns | `frontend/architecture/security.md` |

3. **Reference as needed:**
   - `frontend/standards/typescript-guidelines.md`
   - `frontend/standards/accessibility.md`
   - `frontend/standards/code-quality.md`

## Code Generation Rules

### Always Do

- Follow naming conventions exactly (PascalCase components, camelCase hooks, etc.)
- Use TypeScript strict mode - no `any` types
- Use `@/` path aliases for imports
- Include JSDoc comments for component props
- Add `aria-label` for icon-only buttons
- Use React Query for ALL server state
- Use Zod schemas for ALL form validation
- Co-locate tests with source files (`Component.test.tsx` next to `Component.tsx`)
- Export from feature's `index.ts` for public API

### Never Do

- Never use `any` type - use `unknown` with type guards
- Never store API data in Zustand - use React Query
- Never use `dangerouslySetInnerHTML` without DOMPurify
- Never log sensitive data (tokens, passwords, PII)
- Never use default exports for components (use named exports)
- Never use `.spec.ts` for unit tests (use `.test.ts`)
- Never skip error handling for mutations
- Never create files outside the established folder structure

### When Uncertain

Ask the user for clarification when:
- The task requires choosing between multiple valid architectural approaches
- The feature doesn't fit clearly into an existing feature module
- Security implications are unclear
- The request conflicts with established patterns
- Performance trade-offs need user input

Do NOT ask when:
- The pattern is clearly documented
- It's a straightforward implementation following existing examples
- The decision is easily reversible

## File Structure Decisions

```
Is it a new feature?
├── YES → Create in src/features/[feature-name]/
│         ├── components/
│         ├── hooks/
│         ├── api/
│         ├── types/
│         └── index.ts (public exports)
│
└── NO → Is it shared across features?
         ├── YES → Is it a component?
         │         ├── YES → src/components/ui/ or src/components/layout/
         │         └── NO → src/hooks/ or src/lib/utils/
         │
         └── NO → Keep in the feature that owns it
```

## Code Patterns Quick Reference

### Component Structure

```typescript
// 1. Imports
import { memo } from 'react';
import type { Product } from '../types/product.types';

// 2. Types
type ProductCardProps = {
  product: Product;
  onEdit?: (id: string) => void;
};

// 3. Component
export const ProductCard = memo(function ProductCard({
  product,
  onEdit,
}: ProductCardProps) {
  return (/* JSX */);
});
```

### API Hook Structure

```typescript
// Query keys factory
export const productKeys = {
  all: ['products'] as const,
  list: (filters?: Filters) => [...productKeys.all, 'list', filters] as const,
  detail: (id: string) => [...productKeys.all, 'detail', id] as const,
};

// Query hook
export function useProducts(filters?: Filters) {
  return useQuery({
    queryKey: productKeys.list(filters),
    queryFn: async () => {
      const { data } = await apiClient.get<Product[]>('/products', { params: filters });
      return data;
    },
  });
}

// Mutation hook
export function useCreateProduct() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (product: CreateProductRequest) => {
      const { data } = await apiClient.post<Product>('/products', product);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: productKeys.all });
      toast.success('Product created');
    },
  });
}
```

### Form Structure

```typescript
// 1. Zod schema
const schema = z.object({
  name: z.string().min(1, 'Required'),
  email: z.string().email('Invalid email'),
});

// 2. Infer type
type FormData = z.infer<typeof schema>;

// 3. Use with React Hook Form
const { register, handleSubmit, formState: { errors } } = useForm<FormData>({
  resolver: zodResolver(schema),
});
```

## Testing Requirements

- Unit tests required for: components, hooks, utility functions
- E2E tests required for: critical user flows (auth, checkout, etc.)
- Use `renderWithProviders` for components needing React Query/Router
- Use `vi.mock()` to mock API client in unit tests
- Use accessible queries: `getByRole`, `getByLabelText` over `getByTestId`

## Commit Message Format

```
<type>(<scope>): <description>

Types: feat, fix, refactor, test, docs, chore, style, perf
Example: feat(auth): add password reset flow
```

## Common Tasks

### Creating a new feature

```bash
# 1. Create folder structure
mkdir -p src/features/[name]/{components,hooks,api,types}

# 2. Create index.ts for public exports
touch src/features/[name]/index.ts

# 3. Follow patterns in frontend/architecture/folder-structure.md
```

### Adding a new API endpoint

1. Add types in `src/features/[name]/types/[name].types.ts`
2. Create query/mutation hooks in `src/features/[name]/api/[name]Api.ts`
3. Export from `src/features/[name]/index.ts`
4. Follow patterns in `frontend/patterns/api-integration.md`

### Adding a new form

1. Define Zod schema
2. Create form component using React Hook Form
3. Handle both client and server validation errors
4. Follow patterns in `frontend/patterns/form-patterns.md`
