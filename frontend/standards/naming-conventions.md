# Naming Conventions

Consistent naming is critical for maintainability and for Claude Code to generate predictable, high-quality code.

## Files & Folders

### Components
```bash
✅ PascalCase for component files
src/components/ui/Button/Button.tsx
src/features/auth/components/LoginForm.tsx

✅ Index files for clean imports
src/components/ui/Button/index.ts  # exports { Button } from './Button'

✅ Co-located tests use same name
src/components/ui/Button/Button.test.tsx
```

### Non-Component Files
```bash
✅ camelCase for utilities, hooks, services
src/lib/utils/formatDate.ts
src/hooks/useDebounce.ts
src/features/auth/api/authApi.ts

✅ kebab-case for config files (convention)
vite.config.ts
tailwind.config.ts
playwright.config.ts
```

### Type Files
```bash
✅ Suffix with .types.ts
src/types/api.types.ts
src/features/auth/types/auth.types.ts

❌ NOT .d.ts (reserve for ambient declarations)
```

### Test Files
```bash
✅ Same name as source + .test.ts(x)
Button.test.tsx
authApi.test.ts

❌ NOT .spec.ts (keep it consistent)
```

### Folders
```bash
✅ kebab-case for multi-word folders
src/features/user-profile/
src/components/data-table/

✅ Single word folders stay lowercase
src/hooks/
src/utils/
src/lib/
```

---

## TypeScript Types & Interfaces

### Naming
```typescript
✅ PascalCase for types and interfaces
type User = { ... };
interface Product { ... };

✅ Don't prefix interfaces with 'I' (modern convention)
type ButtonProps = { ... };     // ✅ Good
interface IButtonProps { ... }  // ❌ Avoid

✅ Suffix Props types with 'Props'
type ButtonProps = { ... };
type LoginFormProps = { ... };

✅ Suffix API response types with 'Response'
type LoginResponse = { ... };
type GetProductsResponse = { ... };

✅ Suffix API request types with 'Request' or 'Payload'
type CreateUserRequest = { ... };
type UpdateProductPayload = { ... };

✅ Use descriptive union type names
type UserRole = 'admin' | 'user' | 'guest';
type LoadingState = 'idle' | 'loading' | 'success' | 'error';
```

### Enums
```typescript
✅ PascalCase for enum names, SCREAMING_SNAKE_CASE for values
enum ErrorType {
  NETWORK = 'NETWORK',
  VALIDATION = 'VALIDATION',
  AUTHENTICATION = 'AUTHENTICATION',
}

✅ Or use const objects (often preferred)
const ErrorType = {
  NETWORK: 'NETWORK',
  VALIDATION: 'VALIDATION',
  AUTHENTICATION: 'AUTHENTICATION',
} as const;

type ErrorType = typeof ErrorType[keyof typeof ErrorType];
```

---

## Variables & Constants

### Regular Variables
```typescript
✅ camelCase
const userName = 'John';
const isLoading = false;
const hasError = true;
const productList = [];
```

### Constants (Module-Level)
```typescript
✅ SCREAMING_SNAKE_CASE for true constants
const API_BASE_URL = 'https://api.example.com';
const MAX_RETRY_ATTEMPTS = 3;
const DEFAULT_PAGE_SIZE = 20;

✅ camelCase for configuration objects
const apiConfig = {
  baseUrl: 'https://api.example.com',
  timeout: 10000,
};
```

### Boolean Variables
```typescript
✅ Prefix with is, has, can, should
const isLoading = false;
const hasError = true;
const canEdit = user.role === 'admin';
const shouldRender = isVisible && !isLoading;

❌ Avoid ambiguous names
const loading = false;  // ❌ Use isLoading
const error = true;     // ❌ Use hasError
const visible = true;   // ❌ Use isVisible
```

### Arrays & Collections
```typescript
✅ Plural names
const users = [];
const products = [];
const errorMessages = [];

✅ Descriptive for single items in loops
users.map((user) => user.name);
products.filter((product) => product.isActive);

✅ Short names OK for simple iterations
for (let i = 0; i < items.length; i++) { ... }
items.forEach((item, index) => { ... });
```

---

## Functions & Methods

### Regular Functions
```typescript
✅ camelCase, verb-based names
function fetchUser() { ... }
function calculateTotal() { ... }
function formatDate() { ... }
async function processPayment() { ... }

✅ Event handlers: handle + Event
function handleClick() { ... }
function handleSubmit() { ... }
function handleInputChange() { ... }

✅ Callbacks: on + Event (when passing as props)
<Button onClick={handleClick} />
<Form onSubmit={handleSubmit} />
```

### React Hooks
```typescript
✅ Must start with 'use'
function useAuth() { ... }
function useDebounce() { ... }
function useLocalStorage() { ... }

✅ Return tuple for simple hooks
function useToggle(initial = false): [boolean, () => void] { ... }

✅ Return object for complex hooks
function useAuth(): { 
  user: User | null; 
  login: () => void; 
  logout: () => void;
} { ... }
```

### React Query Hooks
```typescript
✅ Prefix with 'use', describe the action/data
function useProducts() { ... }          // Query
function useProduct(id: string) { ... } // Query with param
function useCreateProduct() { ... }     // Mutation
function useUpdateProduct() { ... }     // Mutation
function useDeleteProduct() { ... }     // Mutation
```

### API Functions (Non-Hook)
```typescript
✅ Verb-based, describe the action
async function loginUser(credentials: LoginRequest) { ... }
async function fetchProducts() { ... }
async function createProduct(data: Product) { ... }
async function updateProduct(id: string, data: Partial<Product>) { ... }
async function deleteProduct(id: string) { ... }
```

---

## React Components

### Component Names
```typescript
✅ PascalCase, noun-based
function Button() { ... }
function UserProfile() { ... }
function ProductCard() { ... }

✅ Descriptive, not generic
function ProductList() { ... }    // ✅ Clear
function List() { ... }           // ❌ Too generic

✅ Avoid 'Component' suffix
function UserProfile() { ... }            // ✅ Good
function UserProfileComponent() { ... }   // ❌ Redundant
```

### Component Props
```typescript
✅ Define props type with component name + 'Props'
type ButtonProps = {
  variant?: 'primary' | 'secondary';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  onClick?: () => void;
  children: ReactNode;
};

function Button({ variant = 'primary', size = 'md', ...props }: ButtonProps) {
  return <button {...props} />;
}

✅ Boolean props: use is/has/can/should prefix
type CardProps = {
  isActive?: boolean;
  hasError?: boolean;
  canClose?: boolean;
  shouldAnimate?: boolean;
};
```

---

## CSS Classes (Tailwind)

```typescript
✅ Use Tailwind's utility classes directly
<div className="flex items-center justify-between p-4 bg-white rounded-lg shadow">

✅ For complex patterns, use template literals
const buttonClasses = `
  px-4 py-2 rounded-md font-medium
  ${variant === 'primary' ? 'bg-blue-500 text-white' : 'bg-gray-200'}
  ${isDisabled ? 'opacity-50 cursor-not-allowed' : 'hover:opacity-90'}
`;

✅ Or extract to utility function
function getButtonClasses(variant: string, disabled: boolean): string {
  // ...
}
```

---

## Git Conventions

### Branch Names
```bash
✅ kebab-case, prefix with type
feature/user-authentication
fix/login-validation-error
refactor/error-handling
chore/update-dependencies

✅ Include ticket number if applicable
feature/PROJ-123-user-authentication
fix/PROJ-456-login-bug
```

### Commit Messages (Conventional Commits)
```bash
✅ Format: <type>(<scope>): <description>

feat(auth): add login form validation
fix(products): resolve price calculation error
refactor(api): simplify error handling
chore(deps): update React to v18.3
docs(readme): add setup instructions
test(auth): add login form tests

✅ Types: feat, fix, refactor, test, docs, chore, style, perf
```

### Environment Variables
```bash
✅ SCREAMING_SNAKE_CASE with VITE_ prefix
VITE_API_BASE_URL=https://api.example.com
VITE_ENABLE_ANALYTICS=true
VITE_MAX_FILE_SIZE=5242880

✅ Prefix clearly indicates usage context
VITE_API_BASE_URL      # API related
VITE_AUTH_DOMAIN       # Auth related
VITE_FEATURE_FLAG_X    # Feature flag
```

---

## Query Keys (React Query)

```typescript
✅ Array-based, hierarchical
queryKey: ['products']                          // All products
queryKey: ['products', id]                      // Single product
queryKey: ['products', 'list', { status }]      // Filtered list
queryKey: ['user', 'profile']                   // User profile

✅ Create query key factories
export const productKeys = {
  all: ['products'] as const,
  lists: () => [...productKeys.all, 'list'] as const,
  list: (filters: ProductFilters) => [...productKeys.lists(), filters] as const,
  details: () => [...productKeys.all, 'detail'] as const,
  detail: (id: string) => [...productKeys.details(), id] as const,
};

// Usage
queryKey: productKeys.detail(productId)
```

---

## Zustand Store Names

```typescript
✅ Suffix with 'Store', camelCase filename
// src/lib/stores/authStore.ts
export const useAuthStore = create<AuthState>((set) => ({ ... }));

// src/lib/stores/uiStore.ts
export const useUiStore = create<UiState>((set) => ({ ... }));

✅ Store slice selectors: descriptive names
const user = useAuthStore((state) => state.user);
const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
```

---

## Quick Reference Card

```
Files:
  Components:     PascalCase          (Button.tsx)
  Utilities:      camelCase           (formatDate.ts)
  Types:          name.types.ts       (user.types.ts)
  Tests:          name.test.ts        (Button.test.tsx)
  Folders:        kebab-case          (user-profile/)

Code:
  Types/Interfaces:  PascalCase       (User, ButtonProps)
  Variables:         camelCase        (userName, isLoading)
  Constants:         SCREAMING_SNAKE  (API_BASE_URL)
  Functions:         camelCase        (fetchUser, handleClick)
  React Hooks:       use + PascalCase (useAuth, useDebounce)
  Components:        PascalCase       (Button, UserProfile)
  Boolean vars:      is/has/can/should prefix

Git:
  Branches:    kebab-case + type      (feature/user-auth)
  Commits:     conventional           (feat(auth): add login)
  Env vars:    SCREAMING_SNAKE        (VITE_API_URL)
```

---

## Anti-Patterns to Avoid

```typescript
❌ Generic names
function get() { ... }
const data = ...;
const temp = ...;

❌ Abbreviations (unless universally known)
const usrNm = ...;     // Use userName
const btnClk = ...;    // Use handleButtonClick

❌ Hungarian notation
const strName = ...;   // Use name (type is obvious in TS)
const arrUsers = ...;  // Use users

❌ Inconsistent naming
handleClick() vs onClick() vs clickHandler()
// Pick one pattern and stick to it: handleClick

❌ Redundant context
// In ProductCard component:
const productCardTitle = ...;  // ❌ Use title
const productCardPrice = ...;  // ❌ Use price
```