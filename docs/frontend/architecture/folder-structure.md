# Folder Structure

A hybrid folder structure combining feature-based and type-based organization for scalability and maintainability.

## Complete Structure

```
src/
  ├── app/                        # App setup & providers
  │   ├── App.tsx                 # Root component
  │   ├── router.tsx              # Route configuration
  │   └── providers.tsx           # Global providers (Query, Auth, Theme)
  │
  ├── features/                   # Feature modules
  │   ├── auth/
  │   │   ├── components/
  │   │   │   ├── LoginForm.tsx
  │   │   │   ├── LoginForm.test.tsx
  │   │   │   ├── RegisterForm.tsx
  │   │   │   └── PasswordResetForm.tsx
  │   │   ├── hooks/
  │   │   │   ├── useAuth.ts
  │   │   │   └── usePermissions.ts
  │   │   ├── api/
  │   │   │   └── authApi.ts      # React Query hooks
  │   │   ├── stores/
  │   │   │   └── authStore.ts    # Zustand store
  │   │   ├── types/
  │   │   │   └── auth.types.ts
  │   │   ├── utils/
  │   │   │   └── tokenStorage.ts # Feature-specific utilities
  │   │   └── index.ts            # Public API exports
  │   │
  │   ├── products/
  │   │   ├── components/
  │   │   ├── hooks/
  │   │   ├── api/
  │   │   ├── types/
  │   │   └── index.ts
  │   │
  │   ├── dashboard/
  │   └── ...
  │
  ├── components/                 # Shared/common components
  │   ├── ui/                     # Pure UI components
  │   │   ├── Button/
  │   │   │   ├── Button.tsx
  │   │   │   ├── Button.test.tsx
  │   │   │   └── index.ts
  │   │   ├── Input/
  │   │   ├── Modal/
  │   │   ├── Card/
  │   │   ├── Dropdown/
  │   │   └── ...
  │   ├── layout/                 # Layout components
  │   │   ├── Header.tsx
  │   │   ├── Sidebar.tsx
  │   │   ├── Footer.tsx
  │   │   └── Layout.tsx
  │   └── forms/                  # Shared form components
  │       ├── FormInput.tsx
  │       ├── FormSelect.tsx
  │       ├── FormCheckbox.tsx
  │       └── FormError.tsx
  │
  ├── hooks/                      # Shared hooks
  │   ├── useDebounce.ts
  │   ├── useThrottle.ts
  │   ├── useLocalStorage.ts
  │   ├── useMediaQuery.ts
  │   └── usePrefersReducedMotion.ts
  │
  ├── lib/                        # Core utilities & config
  │   ├── api/
  │   │   ├── client.ts           # Axios instance
  │   │   └── queryClient.ts      # React Query config
  │   ├── stores/                 # Global Zustand stores
  │   │   ├── uiStore.ts
  │   │   └── userStore.ts
  │   ├── utils/
  │   │   ├── format.ts           # Formatting utilities
  │   │   ├── validation.ts       # Validation helpers
  │   │   └── cn.ts               # Tailwind class merger
  │   ├── config.ts               # App configuration
  │   └── constants.ts            # App-wide constants
  │
  ├── types/                      # Shared TypeScript types
  │   ├── api.types.ts            # API response/request types
  │   ├── common.types.ts         # Common shared types
  │   └── error.types.ts          # Error types
  │
  ├── styles/                     # Global styles
  │   └── index.css               # Tailwind imports + global CSS
  │
  ├── pages/                      # Route page components
  │   ├── HomePage.tsx
  │   ├── LoginPage.tsx
  │   ├── DashboardPage.tsx
  │   ├── ProductsPage.tsx
  │   ├── ProductDetailPage.tsx
  │   └── NotFoundPage.tsx
  │
  ├── test/                       # Test utilities & setup
  │   ├── setup.ts                # Test setup file
  │   ├── utils.tsx               # Test utilities (renderWithProviders)
  │   └── mocks/                  # Mock data and handlers
  │       ├── handlers.ts
  │       └── data.ts
  │
  └── main.tsx                    # Entry point

# Root level files
├── docs/                         # Documentation (this folder)
├── tests/                        # E2E tests
│   └── e2e/
│       ├── auth.spec.ts
│       └── products.spec.ts
├── public/                       # Static assets
├── .env                          # Default env vars
├── .env.example                  # Env vars template
├── .eslintrc.cjs                 # ESLint config
├── .prettierrc                   # Prettier config
├── tailwind.config.ts            # Tailwind config
├── tsconfig.json                 # TypeScript config
├── vite.config.ts                # Vite config
├── vitest.config.ts              # Vitest config
└── playwright.config.ts          # Playwright config
```

---

## Feature Module Structure

Each feature is a self-contained module with everything it needs:

```
src/features/products/
  ├── components/                 # Feature-specific components
  │   ├── ProductCard.tsx
  │   ├── ProductCard.test.tsx
  │   ├── ProductList.tsx
  │   ├── ProductForm.tsx
  │   └── ProductFilters.tsx
  │
  ├── hooks/                      # Feature-specific hooks
  │   ├── useProductFilters.ts
  │   └── useProductSearch.ts
  │
  ├── api/                        # API integration (React Query)
  │   └── productsApi.ts
  │
  ├── stores/                     # Feature-specific Zustand stores
  │   └── productFiltersStore.ts
  │
  ├── types/                      # Feature-specific types
  │   └── product.types.ts
  │
  ├── utils/                      # Feature-specific utilities
  │   └── productHelpers.ts
  │
  └── index.ts                    # Public exports
```

---

## Public API Pattern (index.ts)

Each feature exposes a public API through its `index.ts`:

```typescript
// src/features/products/index.ts

// Components
export { ProductCard } from './components/ProductCard';
export { ProductList } from './components/ProductList';
export { ProductForm } from './components/ProductForm';

// Hooks
export { useProductFilters } from './hooks/useProductFilters';

// API Hooks
export { 
  useProducts, 
  useProduct, 
  useCreateProduct,
  useUpdateProduct,
  useDeleteProduct,
  productKeys,
} from './api/productsApi';

// Types
export type { 
  Product, 
  CreateProductRequest, 
  UpdateProductRequest,
  ProductFilters,
} from './types/product.types';
```

### Importing from Features

```typescript
// ✅ Good: Import from feature's public API
import { ProductCard, useProducts, type Product } from '@/features/products';

// ❌ Bad: Reaching into feature internals
import { ProductCard } from '@/features/products/components/ProductCard';
```

---

## Shared Components Structure

UI components follow atomic design principles:

```
src/components/
  ├── ui/                         # Atomic UI components
  │   ├── Button/
  │   │   ├── Button.tsx
  │   │   ├── Button.test.tsx
  │   │   └── index.ts
  │   ├── Input/
  │   ├── Select/
  │   ├── Modal/
  │   ├── Card/
  │   ├── Badge/
  │   ├── Avatar/
  │   ├── Spinner/
  │   ├── Toast/
  │   └── ...
  │
  ├── layout/                     # Layout components
  │   ├── Header.tsx
  │   ├── Sidebar.tsx
  │   ├── Footer.tsx
  │   ├── Layout.tsx
  │   └── PageContainer.tsx
  │
  ├── forms/                      # Form components
  │   ├── FormInput.tsx
  │   ├── FormSelect.tsx
  │   ├── FormCheckbox.tsx
  │   ├── FormRadio.tsx
  │   ├── FormTextarea.tsx
  │   └── FormError.tsx
  │
  └── feedback/                   # User feedback components
      ├── ErrorBoundary.tsx
      ├── LoadingSpinner.tsx
      ├── EmptyState.tsx
      └── ConfirmDialog.tsx
```

---

## Path Aliases

Configure path aliases in both `tsconfig.json` and `vite.config.ts`:

```json
// tsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@/components/*": ["./src/components/*"],
      "@/features/*": ["./src/features/*"],
      "@/lib/*": ["./src/lib/*"],
      "@/hooks/*": ["./src/hooks/*"],
      "@/types/*": ["./src/types/*"]
    }
  }
}
```

```typescript
// vite.config.ts
import path from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

### Usage

```typescript
// ✅ Use path aliases
import { Button } from '@/components/ui/Button';
import { useAuth } from '@/features/auth';
import { apiClient } from '@/lib/api/client';
import { useDebounce } from '@/hooks/useDebounce';
import type { User } from '@/types/common.types';

// ❌ Avoid relative imports for shared code
import { Button } from '../../../components/ui/Button';
```

---

## Where Things Go

### Decision Tree

```
Is it used by multiple features?
  ├── YES → Is it a React component?
  │           ├── YES → src/components/
  │           └── NO → Is it a hook?
  │                     ├── YES → src/hooks/
  │                     └── NO → src/lib/utils/ or src/lib/
  │
  └── NO → It belongs in the feature folder
            src/features/[feature-name]/
```

### Quick Reference

| Type | Location | Example |
|------|----------|---------|
| Feature component | `src/features/[name]/components/` | `ProductCard.tsx` |
| Shared UI component | `src/components/ui/` | `Button.tsx` |
| Layout component | `src/components/layout/` | `Header.tsx` |
| Feature hook | `src/features/[name]/hooks/` | `useProductFilters.ts` |
| Shared hook | `src/hooks/` | `useDebounce.ts` |
| Feature API | `src/features/[name]/api/` | `productsApi.ts` |
| Axios client | `src/lib/api/` | `client.ts` |
| Feature types | `src/features/[name]/types/` | `product.types.ts` |
| Shared types | `src/types/` | `common.types.ts` |
| Feature store | `src/features/[name]/stores/` | `cartStore.ts` |
| Global store | `src/lib/stores/` | `uiStore.ts` |
| Utilities | `src/lib/utils/` | `format.ts` |
| Constants | `src/lib/constants.ts` | `API_BASE_URL` |
| Config | `src/lib/config.ts` | `config.api.baseUrl` |
| Page component | `src/pages/` | `ProductsPage.tsx` |
| Test setup | `src/test/` | `setup.ts` |
| E2E tests | `tests/e2e/` | `auth.spec.ts` |

---

## Principles

### 1. Feature Isolation

- Each feature is self-contained
- Features don't import from other features directly
- Shared code goes in `components/`, `hooks/`, `lib/`

### 2. Co-location

- Tests live next to the code they test
- Types live close to where they're used
- Feature-specific code stays in the feature

### 3. Clear Boundaries

- Import from features through `index.ts`
- Don't reach into feature internals
- Keep the public API minimal

### 4. Shared vs Feature-Specific

- If 2+ features need it → move to shared
- If only one feature needs it → keep in feature
- When in doubt, start in feature, move to shared when needed

### 5. Flat Where Possible

- Avoid deep nesting (max 3-4 levels)
- Flatten when structure becomes unwieldy
- Group by feature, not by type

---

## Anti-Patterns to Avoid

```
❌ Deep nesting
src/components/common/forms/inputs/text/TextInput.tsx

❌ Importing feature internals
import { helper } from '@/features/products/utils/internal';

❌ Circular dependencies between features
// products imports from orders, orders imports from products

❌ Mixing concerns
src/utils/ProductCard.tsx  // Component in utils folder

❌ Generic dumping grounds
src/helpers/          // What kind of helpers?
src/misc/            // Avoid catch-all folders
```

---

## Creating a New Feature

```bash
# 1. Create the feature folder structure
mkdir -p src/features/my-feature/{components,hooks,api,types,stores}

# 2. Create the index.ts for public exports
touch src/features/my-feature/index.ts

# 3. Create initial files
touch src/features/my-feature/types/my-feature.types.ts
touch src/features/my-feature/api/myFeatureApi.ts
touch src/features/my-feature/components/MyFeatureList.tsx
```

Then follow the patterns in:

- [Component Patterns](../patterns/component-patterns.md)
- [API Integration](../patterns/api-integration.md)
- [Testing Strategy](../testing/testing-strategy.md)
