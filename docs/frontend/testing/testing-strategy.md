# Testing Strategy

Comprehensive testing approach using Vitest + React Testing Library for unit tests and Playwright for E2E tests.

## Testing Pyramid

```
        /\
       /  \
      / E2E \        10% - Critical user flows
     /______\
    /        \
   / Integration \   20% - Feature interactions
  /______________\
 /                \
/   Unit Tests     \ 70% - Individual functions/components
\__________________/
```

---

## Setup

### Vitest Installation

```bash
npm install -D vitest @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom
```

### Vitest Configuration

```typescript
// vitest.config.ts

import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    css: true,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 75,
        statements: 80,
      },
      exclude: [
        'node_modules/',
        'src/test/',
        '**/*.test.{ts,tsx}',
        '**/types/**',
        'src/main.tsx',
      ],
    },
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

### Test Setup File

```typescript
// src/test/setup.ts

import '@testing-library/jest-dom';
import { cleanup } from '@testing-library/react';
import { afterEach, vi } from 'vitest';

afterEach(() => {
  cleanup();
});

// Mock window.matchMedia
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

// Mock IntersectionObserver
global.IntersectionObserver = vi.fn().mockImplementation(() => ({
  observe: vi.fn(),
  unobserve: vi.fn(),
  disconnect: vi.fn(),
}));
```

### Test Utilities

```typescript
// src/test/utils.tsx

import { ReactNode } from 'react';
import { render, RenderOptions } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter } from 'react-router-dom';

export function createTestQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
        gcTime: 0,
      },
    },
  });
}

export function renderWithProviders(
  ui: React.ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>
) {
  const queryClient = createTestQueryClient();

  function Wrapper({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <BrowserRouter>{children}</BrowserRouter>
      </QueryClientProvider>
    );
  }

  return {
    ...render(ui, { wrapper: Wrapper, ...options }),
    queryClient,
  };
}

export * from '@testing-library/react';
export { renderWithProviders as render };
```

---

## Unit Testing Components

### Basic Component Test

```typescript
// src/components/ui/Button/Button.test.tsx

import { render, screen } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { Button } from './Button';

describe('Button', () => {
  it('renders with children text', () => {
    render(<Button>Click me</Button>);
    expect(screen.getByRole('button', { name: /click me/i })).toBeInTheDocument();
  });

  it('calls onClick when clicked', async () => {
    const handleClick = vi.fn();
    const user = userEvent.setup();
    
    render(<Button onClick={handleClick}>Click me</Button>);
    
    await user.click(screen.getByRole('button'));
    
    expect(handleClick).toHaveBeenCalledTimes(1);
  });

  it('is disabled when disabled prop is true', () => {
    render(<Button disabled>Click me</Button>);
    expect(screen.getByRole('button')).toBeDisabled();
  });

  it('shows loading state', () => {
    render(<Button loading>Click me</Button>);
    expect(screen.getByRole('button')).toHaveAttribute('aria-busy', 'true');
  });
});
```

### Form Component Test

```typescript
// src/features/auth/components/LoginForm.test.tsx

import { render, screen, waitFor } from '@/test/utils';
import { userEvent } from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { LoginForm } from './LoginForm';

describe('LoginForm', () => {
  it('renders all form fields', () => {
    render(<LoginForm onSubmit={vi.fn()} />);
    
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /log in/i })).toBeInTheDocument();
  });

  it('shows validation errors for empty fields', async () => {
    const user = userEvent.setup();
    render(<LoginForm onSubmit={vi.fn()} />);
    
    await user.click(screen.getByRole('button', { name: /log in/i }));
    
    expect(await screen.findByText(/email is required/i)).toBeInTheDocument();
    expect(await screen.findByText(/password is required/i)).toBeInTheDocument();
  });

  it('shows error for invalid email', async () => {
    const user = userEvent.setup();
    render(<LoginForm onSubmit={vi.fn()} />);
    
    await user.type(screen.getByLabelText(/email/i), 'invalid');
    await user.tab();
    
    expect(await screen.findByText(/invalid email/i)).toBeInTheDocument();
  });

  it('submits with valid data', async () => {
    const handleSubmit = vi.fn();
    const user = userEvent.setup();
    
    render(<LoginForm onSubmit={handleSubmit} />);
    
    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/password/i), 'password123');
    await user.click(screen.getByRole('button', { name: /log in/i }));
    
    await waitFor(() => {
      expect(handleSubmit).toHaveBeenCalledWith({
        email: 'test@example.com',
        password: 'password123',
      });
    });
  });

  it('disables submit during submission', async () => {
    const user = userEvent.setup();
    const handleSubmit = vi.fn(() => new Promise((r) => setTimeout(r, 100)));
    
    render(<LoginForm onSubmit={handleSubmit} />);
    
    await user.type(screen.getByLabelText(/email/i), 'test@example.com');
    await user.type(screen.getByLabelText(/password/i), 'password123');
    await user.click(screen.getByRole('button', { name: /log in/i }));
    
    expect(screen.getByRole('button')).toBeDisabled();
  });
});
```

---

## Testing Hooks

```typescript
// src/hooks/useDebounce.test.ts

import { renderHook, waitFor } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { useDebounce } from './useDebounce';

describe('useDebounce', () => {
  it('returns initial value immediately', () => {
    const { result } = renderHook(() => useDebounce('initial', 500));
    expect(result.current).toBe('initial');
  });

  it('debounces value changes', async () => {
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebounce(value, delay),
      { initialProps: { value: 'initial', delay: 500 } }
    );
    
    rerender({ value: 'updated', delay: 500 });
    
    // Still initial immediately
    expect(result.current).toBe('initial');
    
    // Updated after delay
    await waitFor(() => expect(result.current).toBe('updated'), {
      timeout: 600,
    });
  });

  it('cancels previous timeout on rapid changes', async () => {
    vi.useFakeTimers();
    
    const { result, rerender } = renderHook(
      ({ value }) => useDebounce(value, 500),
      { initialProps: { value: 'initial' } }
    );
    
    rerender({ value: 'first' });
    vi.advanceTimersByTime(300);
    
    rerender({ value: 'second' });
    vi.advanceTimersByTime(300);
    
    rerender({ value: 'final' });
    vi.advanceTimersByTime(500);
    
    expect(result.current).toBe('final');
    
    vi.useRealTimers();
  });
});
```

---

## Testing API Hooks (React Query)

```typescript
// src/features/products/api/productsApi.test.tsx

import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { useProducts, useCreateProduct } from './productsApi';
import { apiClient } from '@/lib/api/client';

vi.mock('@/lib/api/client');

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  
  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
}

describe('useProducts', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('fetches products successfully', async () => {
    const mockProducts = [
      { id: '1', name: 'Product 1', price: 100 },
      { id: '2', name: 'Product 2', price: 200 },
    ];
    
    vi.mocked(apiClient.get).mockResolvedValueOnce({ data: mockProducts });
    
    const { result } = renderHook(() => useProducts(), {
      wrapper: createWrapper(),
    });
    
    expect(result.current.isLoading).toBe(true);
    
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    
    expect(result.current.data).toEqual(mockProducts);
  });

  it('handles error state', async () => {
    const error = new Error('Failed to fetch');
    vi.mocked(apiClient.get).mockRejectedValueOnce(error);
    
    const { result } = renderHook(() => useProducts(), {
      wrapper: createWrapper(),
    });
    
    await waitFor(() => expect(result.current.isError).toBe(true));
    
    expect(result.current.error).toBe(error);
  });
});

describe('useCreateProduct', () => {
  it('creates product successfully', async () => {
    const newProduct = { name: 'New Product', price: 150 };
    const createdProduct = { id: '3', ...newProduct };
    
    vi.mocked(apiClient.post).mockResolvedValueOnce({ data: createdProduct });
    
    const { result } = renderHook(() => useCreateProduct(), {
      wrapper: createWrapper(),
    });
    
    result.current.mutate(newProduct);
    
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    
    expect(result.current.data).toEqual(createdProduct);
  });
});
```

---

## E2E Testing (Playwright)

### Installation

```bash
npm install -D @playwright/test
npx playwright install
```

### Configuration

```typescript
// playwright.config.ts

import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',
  
  use: {
    baseURL: 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
  },
});
```

### E2E Test Examples

```typescript
// tests/e2e/auth.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Authentication', () => {
  test('user can log in', async ({ page }) => {
    await page.goto('/login');
    
    await page.getByLabel(/email/i).fill('test@example.com');
    await page.getByLabel(/password/i).fill('password123');
    await page.getByRole('button', { name: /log in/i }).click();
    
    await expect(page).toHaveURL('/dashboard');
    await expect(page.getByText(/welcome/i)).toBeVisible();
  });

  test('shows error for invalid credentials', async ({ page }) => {
    await page.goto('/login');
    
    await page.getByLabel(/email/i).fill('wrong@example.com');
    await page.getByLabel(/password/i).fill('wrongpassword');
    await page.getByRole('button', { name: /log in/i }).click();
    
    await expect(page.getByText(/invalid credentials/i)).toBeVisible();
    await expect(page).toHaveURL('/login');
  });
});
```

```typescript
// tests/e2e/products.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Products', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/products');
  });

  test('displays product list', async ({ page }) => {
    const products = page.getByTestId('product-card');
    await expect(products.first()).toBeVisible();
  });

  test('can search products', async ({ page }) => {
    await page.getByPlaceholder(/search/i).fill('Widget');
    
    const products = page.getByTestId('product-card');
    
    for (const product of await products.all()) {
      await expect(product).toContainText(/widget/i);
    }
  });

  test('can create product', async ({ page }) => {
    await page.getByRole('button', { name: /create/i }).click();
    
    await page.getByLabel(/name/i).fill('New Product');
    await page.getByLabel(/price/i).fill('99.99');
    await page.getByRole('button', { name: /save/i }).click();
    
    await expect(page.getByText(/product created/i)).toBeVisible();
  });
});
```

---

## Query Priority (React Testing Library)

Use in this order:

1. **`getByRole`** - Most accessible

   ```typescript
   screen.getByRole('button', { name: /submit/i });
   ```

2. **`getByLabelText`** - Best for form fields

   ```typescript
   screen.getByLabelText(/email/i);
   ```

3. **`getByPlaceholderText`** - For inputs

   ```typescript
   screen.getByPlaceholderText(/search/i);
   ```

4. **`getByText`** - For non-interactive content

   ```typescript
   screen.getByText(/welcome/i);
   ```

5. **`getByTestId`** - Last resort

   ```typescript
   screen.getByTestId('product-card');
   ```

---

## Best Practices

### ✅ DO

- Test behavior, not implementation
- Use accessible queries (getByRole, getByLabelText)
- Test user interactions with `userEvent`
- Test error states and edge cases
- Keep tests focused and isolated
- Use meaningful test descriptions

### ❌ DON'T

- Don't test implementation details
- Don't test third-party libraries
- Don't use `getByTestId` as first choice
- Don't forget async handling
- Don't skip error state testing

---

## Testing Checklist

**Before Committing:**

- [ ] All tests pass
- [ ] New features have tests
- [ ] Bug fixes have regression tests
- [ ] Coverage meets thresholds

**Test Coverage:**

- [ ] Happy path
- [ ] Error states
- [ ] Loading states
- [ ] Empty states
- [ ] Form validation
- [ ] User interactions
