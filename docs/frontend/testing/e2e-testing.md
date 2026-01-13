# E2E Testing

End-to-end testing with Playwright.

## Setup

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
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
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

---

## Test Structure

```
tests/
  └── e2e/
      ├── auth.spec.ts
      ├── products.spec.ts
      ├── checkout.spec.ts
      └── fixtures/
          └── test-data.ts
```

---

## Basic Test Example

```typescript
// tests/e2e/auth.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Authentication', () => {
  test('user can log in successfully', async ({ page }) => {
    // Navigate to login page
    await page.goto('/login');
    
    // Fill in credentials
    await page.getByLabel(/email/i).fill('test@example.com');
    await page.getByLabel(/password/i).fill('password123');
    
    // Submit form
    await page.getByRole('button', { name: /log in/i }).click();
    
    // Assert redirect to dashboard
    await expect(page).toHaveURL('/dashboard');
    
    // Assert welcome message visible
    await expect(page.getByText(/welcome/i)).toBeVisible();
  });

  test('shows error for invalid credentials', async ({ page }) => {
    await page.goto('/login');
    
    await page.getByLabel(/email/i).fill('wrong@example.com');
    await page.getByLabel(/password/i).fill('wrongpassword');
    await page.getByRole('button', { name: /log in/i }).click();
    
    // Assert error message
    await expect(page.getByText(/invalid credentials/i)).toBeVisible();
    
    // Assert still on login page
    await expect(page).toHaveURL('/login');
  });

  test('validates required fields', async ({ page }) => {
    await page.goto('/login');
    
    // Submit without filling fields
    await page.getByRole('button', { name: /log in/i }).click();
    
    // Assert validation errors
    await expect(page.getByText(/email is required/i)).toBeVisible();
    await expect(page.getByText(/password is required/i)).toBeVisible();
  });
});
```

---

## Products CRUD Example

```typescript
// tests/e2e/products.spec.ts

import { test, expect } from '@playwright/test';

test.describe('Product Management', () => {
  test.beforeEach(async ({ page }) => {
    // Login before each test
    await page.goto('/login');
    await page.getByLabel(/email/i).fill('admin@example.com');
    await page.getByLabel(/password/i).fill('password123');
    await page.getByRole('button', { name: /log in/i }).click();
    await expect(page).toHaveURL('/dashboard');
  });

  test('displays product list', async ({ page }) => {
    await page.goto('/products');
    
    // Wait for products to load
    const productCards = page.getByTestId('product-card');
    await expect(productCards.first()).toBeVisible();
    
    // Assert multiple products shown
    await expect(productCards).toHaveCount(10);
  });

  test('can create a new product', async ({ page }) => {
    await page.goto('/products');
    
    // Click create button
    await page.getByRole('button', { name: /create product/i }).click();
    
    // Fill form
    await page.getByLabel(/name/i).fill('New Test Product');
    await page.getByLabel(/price/i).fill('99.99');
    await page.getByLabel(/description/i).fill('A test product description');
    
    // Submit
    await page.getByRole('button', { name: /save/i }).click();
    
    // Assert success
    await expect(page.getByText(/product created/i)).toBeVisible();
    await expect(page.getByText('New Test Product')).toBeVisible();
  });

  test('can search products', async ({ page }) => {
    await page.goto('/products');
    
    // Type in search box
    await page.getByPlaceholder(/search/i).fill('Widget');
    
    // Wait for filtered results
    await page.waitForTimeout(500); // Debounce delay
    
    // Assert filtered results
    const productCards = page.getByTestId('product-card');
    const count = await productCards.count();
    
    for (let i = 0; i < count; i++) {
      await expect(productCards.nth(i)).toContainText(/widget/i);
    }
  });

  test('can delete a product', async ({ page }) => {
    await page.goto('/products');
    
    // Get first product name
    const firstProduct = page.getByTestId('product-card').first();
    const productName = await firstProduct.getByRole('heading').textContent();
    
    // Click delete
    await firstProduct.getByRole('button', { name: /delete/i }).click();
    
    // Confirm deletion
    await page.getByRole('button', { name: /confirm/i }).click();
    
    // Assert success message
    await expect(page.getByText(/product deleted/i)).toBeVisible();
    
    // Assert product no longer visible
    await expect(page.getByText(productName!)).not.toBeVisible();
  });
});
```

---

## Page Object Model

```typescript
// tests/e2e/pages/LoginPage.ts

import { Page, Locator, expect } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    this.page = page;
    this.emailInput = page.getByLabel(/email/i);
    this.passwordInput = page.getByLabel(/password/i);
    this.submitButton = page.getByRole('button', { name: /log in/i });
    this.errorMessage = page.getByRole('alert');
  }

  async goto() {
    await this.page.goto('/login');
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectError(message: string | RegExp) {
    await expect(this.errorMessage).toContainText(message);
  }
}

// Usage in test
import { LoginPage } from './pages/LoginPage';

test('user can log in', async ({ page }) => {
  const loginPage = new LoginPage(page);
  
  await loginPage.goto();
  await loginPage.login('test@example.com', 'password123');
  
  await expect(page).toHaveURL('/dashboard');
});
```

---

## Common Patterns

### Waiting for API

```typescript
// Wait for specific API response
await page.waitForResponse('**/api/products');

// Wait for response and check status
const response = await page.waitForResponse(
  (response) =>
    response.url().includes('/api/products') && response.status() === 200
);
```

### Screenshots

```typescript
// Take screenshot
await page.screenshot({ path: 'screenshot.png' });

// Full page screenshot
await page.screenshot({ path: 'full-page.png', fullPage: true });
```

### Network Mocking

```typescript
test('handles API error', async ({ page }) => {
  // Mock API to return error
  await page.route('**/api/products', (route) =>
    route.fulfill({
      status: 500,
      body: JSON.stringify({ message: 'Server error' }),
    })
  );
  
  await page.goto('/products');
  await expect(page.getByText(/error/i)).toBeVisible();
});
```

---

## Scripts

```json
{
  "scripts": {
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:headed": "playwright test --headed",
    "test:e2e:debug": "playwright test --debug"
  }
}
```

---

## Best Practices

### ✅ DO

- Use accessible locators (`getByRole`, `getByLabel`)
- Create page objects for reusable interactions
- Test critical user journeys
- Run in CI/CD pipeline
- Use `test.describe` to group related tests

### ❌ DON'T

- Don't test implementation details
- Don't rely on CSS selectors
- Don't hardcode wait times (use `waitFor`)
- Don't skip authentication in tests
- Don't test third-party functionality
