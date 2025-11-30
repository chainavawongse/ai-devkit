# TypeScript Guidelines

Strict TypeScript patterns and best practices.

## Core Rules

1. **No `any` type** - Use `unknown` with type guards instead
2. **Strict mode enabled** - All strict flags on
3. **Explicit return types** - For public functions
4. **Type imports** - Use `import type` where possible

---

## tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "jsx": "react-jsx",
    "module": "ESNext",
    "moduleResolution": "bundler",

    // Strict Type Checking
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitReturns": true,

    // Path Aliases
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

---

## Type vs Interface

```typescript
// Use `type` for:
// - Unions, intersections, primitives
// - Function types
// - Mapped types

type Status = 'idle' | 'loading' | 'success' | 'error';
type UserRole = 'admin' | 'user' | 'guest';
type Callback = (value: string) => void;
type Nullable<T> = T | null;

// Use `interface` for:
// - Object shapes that may be extended
// - Public API contracts

interface User {
  id: string;
  email: string;
  name: string;
}

interface AdminUser extends User {
  permissions: string[];
}
```

---

## Props Types

```typescript
// Component props - use `type`
type ButtonProps = {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  loading?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
};

// With HTML attributes
type InputProps = {
  label: string;
  error?: string;
} & React.InputHTMLAttributes<HTMLInputElement>;

// Omit specific attributes
type CustomInputProps = {
  label: string;
} & Omit<React.InputHTMLAttributes<HTMLInputElement>, 'className'>;
```

---

## Avoiding `any`

```typescript
// ❌ Bad
function processData(data: any) {
  return data.value;
}

// ✅ Good - Use unknown with type guard
function processData(data: unknown): string {
  if (isValidData(data)) {
    return data.value;
  }
  throw new Error('Invalid data');
}

function isValidData(data: unknown): data is { value: string } {
  return (
    typeof data === 'object' &&
    data !== null &&
    'value' in data &&
    typeof (data as { value: unknown }).value === 'string'
  );
}

// ✅ Good - Use generics
function processData<T extends { value: string }>(data: T): string {
  return data.value;
}
```

---

## Type Guards

```typescript
// Custom type guard
function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'email' in value
  );
}

// Usage
function handleResponse(data: unknown) {
  if (isUser(data)) {
    // data is now typed as User
    console.log(data.email);
  }
}

// Discriminated unions
type ApiResponse =
  | { status: 'success'; data: User }
  | { status: 'error'; message: string };

function handleApiResponse(response: ApiResponse) {
  if (response.status === 'success') {
    // TypeScript knows response.data exists
    console.log(response.data.email);
  } else {
    // TypeScript knows response.message exists
    console.log(response.message);
  }
}
```

---

## Generics

```typescript
// Generic function
function getFirstItem<T>(items: T[]): T | undefined {
  return items[0];
}

// Generic with constraint
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

// Generic component
type ListProps<T> = {
  items: T[];
  renderItem: (item: T) => React.ReactNode;
  keyExtractor: (item: T) => string;
};

function List<T>({ items, renderItem, keyExtractor }: ListProps<T>) {
  return (
    <ul>
      {items.map((item) => (
        <li key={keyExtractor(item)}>{renderItem(item)}</li>
      ))}
    </ul>
  );
}

// Usage
<List
  items={users}
  renderItem={(user) => <span>{user.name}</span>}
  keyExtractor={(user) => user.id}
/>
```

---

## Utility Types

```typescript
// Partial - all properties optional
type UpdateUserRequest = Partial<User>;

// Required - all properties required
type RequiredUser = Required<User>;

// Pick - select specific properties
type UserPreview = Pick<User, 'id' | 'name'>;

// Omit - exclude specific properties
type CreateUserRequest = Omit<User, 'id' | 'createdAt'>;

// Record - typed object
type UserMap = Record<string, User>;

// Extract / Exclude - for unions
type SuccessStatus = Extract<Status, 'success' | 'idle'>;
type ErrorStatus = Exclude<Status, 'success' | 'idle'>;

// ReturnType - get function return type
type UserServiceReturn = ReturnType<typeof fetchUser>;

// Parameters - get function parameter types
type UserServiceParams = Parameters<typeof fetchUser>;
```

---

## Const Assertions

```typescript
// Without const - types are widened
const config = {
  endpoint: '/api/users',
  method: 'GET',
};
// type: { endpoint: string; method: string }

// With const - types are narrowed
const config = {
  endpoint: '/api/users',
  method: 'GET',
} as const;
// type: { readonly endpoint: '/api/users'; readonly method: 'GET' }

// Useful for query keys
export const productKeys = {
  all: ['products'] as const,
  list: (filters: Filters) => [...productKeys.all, 'list', filters] as const,
  detail: (id: string) => [...productKeys.all, 'detail', id] as const,
};
```

---

## Type Imports

```typescript
// ✅ Use type imports for types only
import type { User, Product } from './types';
import type { ButtonProps } from './Button';

// ✅ Mixed import
import { useState, type Dispatch, type SetStateAction } from 'react';

// ESLint rule enforces this:
// '@typescript-eslint/consistent-type-imports': 'error'
```

---

## Event Handlers

```typescript
// Form events
const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
  e.preventDefault();
};

// Input change
const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
  setValue(e.target.value);
};

// Click events
const handleClick = (e: React.MouseEvent<HTMLButtonElement>) => {
  // ...
};

// Keyboard events
const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
  if (e.key === 'Enter') {
    // ...
  }
};
```

---

## API Response Types

```typescript
// Base response type
type ApiResponse<T> = {
  data: T;
  message: string;
  timestamp: string;
};

// Paginated response
type PaginatedResponse<T> = {
  data: T[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
};

// Error response
type ApiError = {
  message: string;
  code: string;
  fieldErrors?: Record<string, string>;
};

// Usage
type ProductsResponse = PaginatedResponse<Product>;
type UserResponse = ApiResponse<User>;
```

---

## Best Practices

### ✅ DO:

- Enable all strict mode flags
- Use `unknown` instead of `any`
- Define explicit return types for public functions
- Use discriminated unions for state
- Leverage utility types

### ❌ DON'T:

- Don't use `any` (use `unknown` + type guards)
- Don't use `@ts-ignore` (use `@ts-expect-error` if needed)
- Don't use non-null assertion `!` without good reason
- Don't use `as` for unsafe casting
- Don't export mutable objects