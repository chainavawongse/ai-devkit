# MSW (Mock Service Worker) Patterns

## Why MSW?

MSW intercepts requests at the network level, providing:

- **Realistic testing** - Your code makes real fetch/axios calls
- **No implementation coupling** - Change HTTP library without changing tests
- **Reusable mocks** - Same handlers for tests and dev server
- **Network error simulation** - Test timeouts, failures, slow responses

## Setup

### Install

```bash
npm install msw --save-dev
```

### Handler File

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  // GET request
  http.get('/api/users', () => {
    return HttpResponse.json([
      { id: '1', name: 'Alice', email: 'alice@example.com' },
      { id: '2', name: 'Bob', email: 'bob@example.com' },
    ]);
  }),

  // GET with params
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({
      id: params.id,
      name: 'Alice',
      email: 'alice@example.com',
    });
  }),

  // POST request
  http.post('/api/users', async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json(
      { id: crypto.randomUUID(), ...body },
      { status: 201 }
    );
  }),

  // PUT request
  http.put('/api/users/:id', async ({ params, request }) => {
    const body = await request.json();
    return HttpResponse.json({ id: params.id, ...body });
  }),

  // DELETE request
  http.delete('/api/users/:id', () => {
    return new HttpResponse(null, { status: 204 });
  }),
];
```

### Server Setup

```typescript
// src/mocks/server.ts
import { setupServer } from 'msw/node';
import { handlers } from './handlers';

export const server = setupServer(...handlers);
```

### Vitest Integration

```typescript
// vitest.setup.ts
import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach, beforeAll, afterAll } from 'vitest';
import { server } from './src/mocks/server';

// Start server before all tests
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));

// Reset handlers after each test
afterEach(() => {
  cleanup();
  server.resetHandlers();
});

// Clean up after all tests
afterAll(() => server.close());
```

## Common Patterns

### Override Handler for Specific Test

```typescript
import { server } from '../mocks/server';
import { http, HttpResponse } from 'msw';

test('handles 404 error', async () => {
  // Override only for this test
  server.use(
    http.get('/api/users/:id', () => {
      return HttpResponse.json(
        { error: 'User not found' },
        { status: 404 }
      );
    })
  );

  render(<UserProfile userId="999" />);

  expect(await screen.findByRole('alert')).toHaveTextContent(/not found/i);
});
```

### Network Error

```typescript
test('handles network failure', async () => {
  server.use(
    http.get('/api/users', () => {
      return HttpResponse.error();
    })
  );

  render(<UserList />);

  expect(await screen.findByRole('alert')).toHaveTextContent(/network error/i);
});
```

### Delayed Response

```typescript
import { delay } from 'msw';

test('shows loading state', async () => {
  server.use(
    http.get('/api/users', async () => {
      await delay(100);
      return HttpResponse.json([]);
    })
  );

  render(<UserList />);

  // Loading state visible
  expect(screen.getByRole('progressbar')).toBeInTheDocument();

  // Wait for data to load
  await waitFor(() => {
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument();
  });
});
```

### Request Validation

```typescript
test('sends correct request body', async () => {
  let capturedBody: any;

  server.use(
    http.post('/api/users', async ({ request }) => {
      capturedBody = await request.json();
      return HttpResponse.json({ id: '123', ...capturedBody }, { status: 201 });
    })
  );

  render(<CreateUserForm />);

  await userEvent.type(screen.getByLabelText(/name/i), 'Alice');
  await userEvent.type(screen.getByLabelText(/email/i), 'alice@example.com');
  await userEvent.click(screen.getByRole('button', { name: /create/i }));

  await waitFor(() => {
    expect(capturedBody).toEqual({
      name: 'Alice',
      email: 'alice@example.com',
    });
  });
});
```

### Query Parameters

```typescript
http.get('/api/users', ({ request }) => {
  const url = new URL(request.url);
  const search = url.searchParams.get('search');
  const page = url.searchParams.get('page');

  // Filter based on query params
  let users = allUsers;
  if (search) {
    users = users.filter(u => u.name.includes(search));
  }

  return HttpResponse.json({
    users,
    page: Number(page) || 1,
    total: users.length,
  });
});
```

### Headers

```typescript
// Check authorization header
http.get('/api/protected', ({ request }) => {
  const auth = request.headers.get('Authorization');

  if (!auth || !auth.startsWith('Bearer ')) {
    return HttpResponse.json(
      { error: 'Unauthorized' },
      { status: 401 }
    );
  }

  return HttpResponse.json({ data: 'secret' });
});

// Return custom headers
http.get('/api/data', () => {
  return HttpResponse.json(
    { data: 'value' },
    {
      headers: {
        'X-Total-Count': '100',
        'X-Page': '1',
      },
    }
  );
});
```

### Sequential Responses

```typescript
test('handles retry after failure', async () => {
  let callCount = 0;

  server.use(
    http.get('/api/data', () => {
      callCount++;
      if (callCount === 1) {
        return HttpResponse.json({ error: 'Server error' }, { status: 500 });
      }
      return HttpResponse.json({ data: 'success' });
    })
  );

  render(<DataWithRetry />);

  // First call fails, component retries
  expect(await screen.findByText('success')).toBeInTheDocument();
  expect(callCount).toBe(2);
});
```

### Response Based on Request Body

```typescript
http.post('/api/login', async ({ request }) => {
  const { email, password } = await request.json();

  if (email === 'user@example.com' && password === 'correct') {
    return HttpResponse.json({
      token: 'fake-jwt-token',
      user: { id: '1', email },
    });
  }

  return HttpResponse.json(
    { error: 'Invalid credentials' },
    { status: 401 }
  );
});
```

## GraphQL Patterns

```typescript
import { graphql, HttpResponse } from 'msw';

export const graphqlHandlers = [
  // Query
  graphql.query('GetUser', ({ variables }) => {
    return HttpResponse.json({
      data: {
        user: {
          id: variables.id,
          name: 'Alice',
          email: 'alice@example.com',
        },
      },
    });
  }),

  // Mutation
  graphql.mutation('CreateUser', ({ variables }) => {
    return HttpResponse.json({
      data: {
        createUser: {
          id: '123',
          ...variables.input,
        },
      },
    });
  }),

  // Error
  graphql.query('GetUsers', () => {
    return HttpResponse.json({
      errors: [
        { message: 'Not authorized' },
      ],
    });
  }),
];
```

## Organizing Handlers

### By Feature

```typescript
// src/mocks/handlers/users.ts
export const userHandlers = [
  http.get('/api/users', ...),
  http.get('/api/users/:id', ...),
  http.post('/api/users', ...),
];

// src/mocks/handlers/posts.ts
export const postHandlers = [
  http.get('/api/posts', ...),
  http.post('/api/posts', ...),
];

// src/mocks/handlers/index.ts
import { userHandlers } from './users';
import { postHandlers } from './posts';

export const handlers = [
  ...userHandlers,
  ...postHandlers,
];
```

### Factory Functions

```typescript
// src/mocks/factories.ts
export function createUserHandler(users: User[]) {
  return http.get('/api/users', () => {
    return HttpResponse.json(users);
  });
}

export function createErrorHandler(path: string, status: number, message: string) {
  return http.get(path, () => {
    return HttpResponse.json({ error: message }, { status });
  });
}

// In test
server.use(
  createUserHandler([{ id: '1', name: 'Test User' }]),
  createErrorHandler('/api/posts', 500, 'Server error')
);
```

## Debugging

### Log Requests

```typescript
server.events.on('request:start', ({ request }) => {
  console.log('Request:', request.method, request.url);
});

server.events.on('request:match', ({ request }) => {
  console.log('Matched:', request.method, request.url);
});

server.events.on('request:unhandled', ({ request }) => {
  console.warn('Unhandled:', request.method, request.url);
});
```

### Unhandled Request Strategies

```typescript
// Error on unhandled (recommended for tests)
server.listen({ onUnhandledRequest: 'error' });

// Warn only
server.listen({ onUnhandledRequest: 'warn' });

// Custom handling
server.listen({
  onUnhandledRequest(request, print) {
    if (request.url.includes('/analytics')) {
      return; // Ignore analytics
    }
    print.error();
  },
});
```

## Testing Checklist

- [ ] Default handlers return success responses
- [ ] Error states tested with `server.use()` overrides
- [ ] Loading states tested with `delay()`
- [ ] Request bodies validated when needed
- [ ] Handlers reset after each test (`server.resetHandlers()`)
- [ ] Unhandled requests error (`onUnhandledRequest: 'error'`)
