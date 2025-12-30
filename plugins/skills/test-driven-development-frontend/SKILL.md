---
name: test-driven-development-frontend
description: Frontend-specific TDD with React Testing Library, Vitest, MSW, and user-centric testing philosophy
when_to_use: when implementing React/frontend components, hooks, or features - always write the test first
version: 1.0.0
---

# Frontend Test-Driven Development

## Overview

Write tests that interact with your UI the way users do.

**Core philosophy:** "The more your tests resemble the way your software is used, the more confidence they can give you."

**Stack:** Vitest + React Testing Library + @testing-library/user-event + jest-dom + MSW

**Parent skill:** This extends `Skill(devkit:test-driven-development)` with frontend-specific patterns.

## The Iron Law (Frontend Edition)

```
NO COMPONENT CODE WITHOUT A FAILING TEST FIRST
```

Test what users see. Test what users do. Never test implementation details.

## Query Priority (MANDATORY)

Use queries in this order. **Lower priority = last resort.**

| Priority | Query | When to Use |
|----------|-------|-------------|
| 1 | `getByRole` | **Default choice** - buttons, inputs, headings, links |
| 2 | `getByLabelText` | Form fields with labels |
| 3 | `getByPlaceholderText` | Only when no label available |
| 4 | `getByText` | Non-interactive elements (paragraphs, spans) |
| 5 | `getByDisplayValue` | Inputs with pre-filled values |
| 6 | `getByAltText` | Images |
| 7 | `getByTestId` | **Last resort only** - users cannot see these |

```typescript
// GOOD: Query by role with accessible name
screen.getByRole('button', { name: /submit/i })
screen.getByRole('textbox', { name: /email/i })
screen.getByRole('heading', { level: 1 })

// BAD: Lazy test-id usage
screen.getByTestId('submit-btn')  // Users don't see test IDs
```

**See `resources/query-priority.md` for complete examples.**

## userEvent Over fireEvent (MANDATORY)

Always use `userEvent` - it simulates real user interactions.

```typescript
import userEvent from '@testing-library/user-event';

// GOOD: Realistic interaction sequence
const user = userEvent.setup();
await user.type(emailInput, 'test@example.com');
await user.click(submitButton);

// BAD: Synthetic events
fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
```

## Red-Green-Refactor (Frontend)

### RED - Write Failing Component Test

```typescript
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ContactForm } from './ContactForm';

test('submits form with user-entered data', async () => {
  const user = userEvent.setup();
  const onSubmit = vi.fn();

  render(<ContactForm onSubmit={onSubmit} />);

  // Act as user would
  await user.type(screen.getByLabelText(/name/i), 'Jane Doe');
  await user.type(screen.getByLabelText(/email/i), 'jane@example.com');
  await user.click(screen.getByRole('button', { name: /submit/i }));

  // Assert user-visible outcome
  expect(onSubmit).toHaveBeenCalledWith({
    name: 'Jane Doe',
    email: 'jane@example.com'
  });
});
```

### Verify RED (MANDATORY CHECKPOINT)

```bash
# Run and capture failure
just test path/to/Component.test.tsx 2>&1 | tee .tdd-red-phase.log

# Verify it fails for the right reason
grep -E "(FAIL|failed|✗)" .tdd-red-phase.log
```

**Report format (REQUIRED before GREEN):**

```markdown
## RED Phase Complete

**Test file:** src/components/ContactForm.test.tsx
**Test name:** "submits form with user-entered data"
**Failure output:**
```
FAIL src/components/ContactForm.test.tsx
  ✗ submits form with user-entered data
    Unable to find an accessible element with the role "textbox" and name "/name/i"
```
**Reason:** Component not implemented yet (correct RED state)
```

### GREEN - Minimal Implementation

Write the minimum code to make the test pass.

```typescript
export function ContactForm({ onSubmit }: { onSubmit: (data: FormData) => void }) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    onSubmit({ name, email });
  };

  return (
    <form onSubmit={handleSubmit}>
      <label>
        Name
        <input value={name} onChange={e => setName(e.target.value)} />
      </label>
      <label>
        Email
        <input value={email} onChange={e => setEmail(e.target.value)} />
      </label>
      <button type="submit">Submit</button>
    </form>
  );
}
```

### Verify GREEN

```bash
just test path/to/Component.test.tsx
```

All tests must pass before refactoring.

### REFACTOR

Clean up while keeping tests green. Run tests after each change.

## What to Test (Behavior)

| Test This | Don't Test This |
|-----------|-----------------|
| Rendered text users see | Internal state values |
| Button click outcomes | Implementation methods |
| Form submission results | CSS classes or styles |
| Error messages displayed | Specific DOM structure |
| Loading/disabled states | Component lifecycle |
| Navigation changes | How many times rendered |

## jest-dom Assertions (USE THESE)

```typescript
// Visibility
expect(element).toBeVisible();
expect(element).toBeInTheDocument();

// State
expect(button).toBeDisabled();
expect(button).toBeEnabled();
expect(input).toBeRequired();
expect(input).toBeValid();
expect(input).toBeInvalid();

// Content
expect(element).toHaveTextContent('Hello');
expect(input).toHaveValue('test@example.com');
expect(input).toHaveDisplayValue('test@example.com');

// Attributes
expect(element).toHaveAttribute('href', '/home');
expect(element).toHaveClass('active');

// Forms
expect(form).toHaveFormValues({ email: 'test@example.com' });
```

## Async Patterns

### Waiting for Elements

```typescript
// GOOD: Use findBy for async elements (auto-waits)
const userName = await screen.findByText('John Doe');

// GOOD: waitFor for complex conditions
await waitFor(() => {
  expect(screen.getByRole('status')).toHaveTextContent('Complete');
});

// BAD: Manual delays
await new Promise(r => setTimeout(r, 1000));  // Never do this
```

### Loading States

```typescript
test('shows loading then content', async () => {
  render(<UserProfile userId="123" />);

  // Loading state
  expect(screen.getByRole('progressbar')).toBeInTheDocument();

  // Wait for content
  expect(await screen.findByText('John Doe')).toBeInTheDocument();

  // Loading gone
  expect(screen.queryByRole('progressbar')).not.toBeInTheDocument();
});
```

## MSW for API Mocking (MANDATORY for API calls)

**Never mock fetch/axios directly.** Use MSW to mock at the network level.

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({
      id: params.id,
      name: 'John Doe',
      email: 'john@example.com'
    });
  }),

  http.post('/api/users', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json({ id: '123', ...body }, { status: 201 });
  }),
];
```

```typescript
// src/mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

```typescript
// vitest.setup.ts
import { server } from './src/mocks/server';

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

```typescript
// In test: Override for specific scenarios
import { server } from '../mocks/server';
import { http, HttpResponse } from 'msw';

test('handles API error', async () => {
  server.use(
    http.get('/api/users/:id', () => {
      return HttpResponse.json({ error: 'Not found' }, { status: 404 });
    })
  );

  render(<UserProfile userId="999" />);

  expect(await screen.findByText(/user not found/i)).toBeInTheDocument();
});
```

**See `resources/msw-patterns.md` for complete patterns.**

## Testing Custom Hooks

```typescript
import { renderHook, act } from '@testing-library/react';
import { useCounter } from './useCounter';

test('increments counter', () => {
  const { result } = renderHook(() => useCounter());

  expect(result.current.count).toBe(0);

  act(() => {
    result.current.increment();
  });

  expect(result.current.count).toBe(1);
});
```

## Test File Structure

```typescript
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ComponentUnderTest } from './ComponentUnderTest';

describe('ComponentUnderTest', () => {
  describe('when rendered', () => {
    test('displays initial state', () => {
      render(<ComponentUnderTest />);
      expect(screen.getByRole('heading')).toHaveTextContent('Welcome');
    });
  });

  describe('when user interacts', () => {
    test('responds to button click', async () => {
      const user = userEvent.setup();
      render(<ComponentUnderTest />);

      await user.click(screen.getByRole('button', { name: /submit/i }));

      expect(screen.getByText(/success/i)).toBeInTheDocument();
    });
  });

  describe('when loading data', () => {
    test('shows loading then content', async () => {
      render(<ComponentUnderTest />);

      expect(screen.getByRole('progressbar')).toBeInTheDocument();
      expect(await screen.findByText('Data loaded')).toBeInTheDocument();
    });
  });

  describe('when error occurs', () => {
    test('displays error message', async () => {
      server.use(/* error handler */);
      render(<ComponentUnderTest />);

      expect(await screen.findByRole('alert')).toHaveTextContent(/error/i);
    });
  });
});
```

## Verification Checklist (MANDATORY)

Before marking frontend work complete:

- [ ] Every component has tests for user-visible behavior
- [ ] Watched each test fail before implementing (RED phase documented)
- [ ] Used `getByRole` or `getByLabelText` (not `getByTestId` unless necessary)
- [ ] Used `userEvent` (not `fireEvent`)
- [ ] API calls mocked with MSW (not fetch/axios mocks)
- [ ] Async operations use `findBy` or `waitFor`
- [ ] Error states tested
- [ ] Loading states tested (if applicable)
- [ ] All tests pass with `just test`
- [ ] No console errors or warnings in test output

## Anti-Patterns (NEVER DO)

| Anti-Pattern | Why It's Bad | Do This Instead |
|--------------|--------------|-----------------|
| `getByTestId` as first choice | Users don't see test IDs | `getByRole`, `getByLabelText` |
| Testing internal state | Brittle, implementation-coupled | Test rendered output |
| Mocking fetch/axios | Doesn't test real integration | Use MSW |
| `fireEvent` for user actions | Incomplete event sequence | `userEvent` |
| Manual `setTimeout` waits | Flaky, slow | `findBy`, `waitFor` |
| Testing CSS classes | Style is not behavior | Test visible outcomes |
| Snapshot tests for logic | Don't catch regressions | Explicit assertions |

**See `resources/anti-patterns.md` for detailed examples.**

## Vitest Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./vitest.setup.ts'],
    include: ['src/**/*.test.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
      exclude: ['src/mocks/**', '**/*.d.ts'],
    },
  },
});
```

```typescript
// vitest.setup.ts
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach, beforeAll, afterAll } from 'vitest';
import { server } from './src/mocks/server';

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => {
  cleanup();
  server.resetHandlers();
});
afterAll(() => server.close());
```

## When Stuck

| Problem | Solution |
|---------|----------|
| Can't find element | Check accessibility - add labels, roles |
| Test passes immediately | Component already exists or test is wrong |
| Async test flaky | Use `findBy` or increase `waitFor` timeout |
| Too many mocks | Component too coupled - refactor |
| Can't test hook | Use `renderHook` from @testing-library/react |

## Additional Resources

- **resources/query-priority.md** - Complete query examples with accessibility guidance
- **resources/tdd-examples.md** - Full TDD cycles for forms, lists, modals, async components
- **resources/msw-patterns.md** - API mocking patterns for REST and GraphQL
- **resources/anti-patterns.md** - Detailed anti-pattern examples with fixes
- **Skill(devkit:writing-tests)** - General testing principles (AAA, coverage, test levels)
