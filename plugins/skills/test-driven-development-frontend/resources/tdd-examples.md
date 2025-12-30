# Frontend TDD Examples

Complete RED-GREEN-REFACTOR cycles for common component patterns.

## Example 1: Form Component

### RED - Write Failing Test

```typescript
// src/components/LoginForm.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { LoginForm } from './LoginForm';

describe('LoginForm', () => {
  test('submits credentials when form is filled and submitted', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();

    render(<LoginForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText(/email/i), 'user@example.com');
    await user.type(screen.getByLabelText(/password/i), 'secret123');
    await user.click(screen.getByRole('button', { name: /sign in/i }));

    expect(onSubmit).toHaveBeenCalledWith({
      email: 'user@example.com',
      password: 'secret123'
    });
  });

  test('shows validation error for invalid email', async () => {
    const user = userEvent.setup();

    render(<LoginForm onSubmit={vi.fn()} />);

    await user.type(screen.getByLabelText(/email/i), 'invalid-email');
    await user.click(screen.getByRole('button', { name: /sign in/i }));

    expect(screen.getByRole('alert')).toHaveTextContent(/valid email/i);
  });

  test('disables submit button while submitting', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn(() => new Promise(r => setTimeout(r, 100)));

    render(<LoginForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText(/email/i), 'user@example.com');
    await user.type(screen.getByLabelText(/password/i), 'secret123');
    await user.click(screen.getByRole('button', { name: /sign in/i }));

    expect(screen.getByRole('button', { name: /sign in/i })).toBeDisabled();
  });
});
```

### Run and verify failure

```bash
just test src/components/LoginForm.test.tsx
# FAIL - LoginForm module not found
```

### GREEN - Minimal Implementation

```typescript
// src/components/LoginForm.tsx
import { useState, FormEvent } from 'react';

interface LoginFormProps {
  onSubmit: (credentials: { email: string; password: string }) => Promise<void> | void;
}

export function LoginForm({ onSubmit }: LoginFormProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError('');

    if (!email.includes('@')) {
      setError('Please enter a valid email address');
      return;
    }

    setIsSubmitting(true);
    try {
      await onSubmit({ email, password });
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <label>
        Email
        <input
          type="email"
          value={email}
          onChange={e => setEmail(e.target.value)}
        />
      </label>
      <label>
        Password
        <input
          type="password"
          value={password}
          onChange={e => setPassword(e.target.value)}
        />
      </label>
      {error && <div role="alert">{error}</div>}
      <button type="submit" disabled={isSubmitting}>
        Sign In
      </button>
    </form>
  );
}
```

### Verify GREEN

```bash
just test src/components/LoginForm.test.tsx
# PASS
```

---

## Example 2: Async Data Component

### RED - Write Failing Test

```typescript
// src/components/UserProfile.test.tsx
import { render, screen } from '@testing-library/react';
import { UserProfile } from './UserProfile';
import { server } from '../mocks/server';
import { http, HttpResponse } from 'msw';

describe('UserProfile', () => {
  test('displays user data after loading', async () => {
    render(<UserProfile userId="123" />);

    // Shows loading state
    expect(screen.getByRole('progressbar')).toBeInTheDocument();

    // Shows user data after load
    expect(await screen.findByRole('heading', { name: 'Jane Doe' })).toBeInTheDocument();
    expect(screen.getByText('jane@example.com')).toBeInTheDocument();

    // Loading indicator gone
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument();
  });

  test('displays error message when user not found', async () => {
    server.use(
      http.get('/api/users/:id', () => {
        return HttpResponse.json({ error: 'User not found' }, { status: 404 });
      })
    );

    render(<UserProfile userId="999" />);

    expect(await screen.findByRole('alert')).toHaveTextContent(/user not found/i);
  });

  test('displays error message on network failure', async () => {
    server.use(
      http.get('/api/users/:id', () => {
        return HttpResponse.error();
      })
    );

    render(<UserProfile userId="123" />);

    expect(await screen.findByRole('alert')).toHaveTextContent(/failed to load/i);
  });
});
```

### MSW Handler Setup

```typescript
// src/mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/users/:id', ({ params }) => {
    return HttpResponse.json({
      id: params.id,
      name: 'Jane Doe',
      email: 'jane@example.com'
    });
  }),
];
```

### GREEN - Minimal Implementation

```typescript
// src/components/UserProfile.tsx
import { useState, useEffect } from 'react';

interface User {
  id: string;
  name: string;
  email: string;
}

interface UserProfileProps {
  userId: string;
}

export function UserProfile({ userId }: UserProfileProps) {
  const [user, setUser] = useState<User | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const response = await fetch(`/api/users/${userId}`);
        if (!response.ok) {
          const data = await response.json();
          throw new Error(data.error || 'Failed to load user');
        }
        const data = await response.json();
        setUser(data);
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to load user');
      } finally {
        setLoading(false);
      }
    };

    fetchUser();
  }, [userId]);

  if (loading) {
    return <div role="progressbar" aria-label="Loading">Loading...</div>;
  }

  if (error) {
    return <div role="alert">{error}</div>;
  }

  if (!user) return null;

  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  );
}
```

---

## Example 3: List with Actions

### RED - Write Failing Test

```typescript
// src/components/TodoList.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { TodoList } from './TodoList';

describe('TodoList', () => {
  const initialTodos = [
    { id: '1', text: 'Learn React', completed: false },
    { id: '2', text: 'Write tests', completed: true },
  ];

  test('renders list of todos', () => {
    render(<TodoList initialTodos={initialTodos} />);

    expect(screen.getByRole('list')).toBeInTheDocument();
    expect(screen.getAllByRole('listitem')).toHaveLength(2);
    expect(screen.getByText('Learn React')).toBeInTheDocument();
    expect(screen.getByText('Write tests')).toBeInTheDocument();
  });

  test('adds new todo when form submitted', async () => {
    const user = userEvent.setup();

    render(<TodoList initialTodos={initialTodos} />);

    await user.type(screen.getByLabelText(/new todo/i), 'Build app');
    await user.click(screen.getByRole('button', { name: /add/i }));

    expect(screen.getAllByRole('listitem')).toHaveLength(3);
    expect(screen.getByText('Build app')).toBeInTheDocument();
  });

  test('toggles todo completion', async () => {
    const user = userEvent.setup();

    render(<TodoList initialTodos={initialTodos} />);

    const checkbox = screen.getByRole('checkbox', { name: /learn react/i });
    expect(checkbox).not.toBeChecked();

    await user.click(checkbox);

    expect(checkbox).toBeChecked();
  });

  test('deletes todo when delete button clicked', async () => {
    const user = userEvent.setup();

    render(<TodoList initialTodos={initialTodos} />);

    const deleteButtons = screen.getAllByRole('button', { name: /delete/i });
    await user.click(deleteButtons[0]);

    expect(screen.getAllByRole('listitem')).toHaveLength(1);
    expect(screen.queryByText('Learn React')).not.toBeInTheDocument();
  });
});
```

### GREEN - Minimal Implementation

```typescript
// src/components/TodoList.tsx
import { useState, FormEvent } from 'react';

interface Todo {
  id: string;
  text: string;
  completed: boolean;
}

interface TodoListProps {
  initialTodos: Todo[];
}

export function TodoList({ initialTodos }: TodoListProps) {
  const [todos, setTodos] = useState<Todo[]>(initialTodos);
  const [newTodo, setNewTodo] = useState('');

  const handleAdd = (e: FormEvent) => {
    e.preventDefault();
    if (!newTodo.trim()) return;

    setTodos([
      ...todos,
      { id: Date.now().toString(), text: newTodo, completed: false }
    ]);
    setNewTodo('');
  };

  const handleToggle = (id: string) => {
    setTodos(todos.map(todo =>
      todo.id === id ? { ...todo, completed: !todo.completed } : todo
    ));
  };

  const handleDelete = (id: string) => {
    setTodos(todos.filter(todo => todo.id !== id));
  };

  return (
    <div>
      <form onSubmit={handleAdd}>
        <label>
          New todo
          <input
            value={newTodo}
            onChange={e => setNewTodo(e.target.value)}
          />
        </label>
        <button type="submit">Add</button>
      </form>

      <ul>
        {todos.map(todo => (
          <li key={todo.id}>
            <label>
              <input
                type="checkbox"
                checked={todo.completed}
                onChange={() => handleToggle(todo.id)}
              />
              {todo.text}
            </label>
            <button onClick={() => handleDelete(todo.id)}>Delete</button>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

---

## Example 4: Modal/Dialog

### RED - Write Failing Test

```typescript
// src/components/ConfirmDialog.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ConfirmDialog } from './ConfirmDialog';

describe('ConfirmDialog', () => {
  test('renders dialog with title and message', () => {
    render(
      <ConfirmDialog
        isOpen={true}
        title="Delete Item"
        message="Are you sure you want to delete this item?"
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />
    );

    expect(screen.getByRole('dialog')).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Delete Item' })).toBeInTheDocument();
    expect(screen.getByText(/are you sure/i)).toBeInTheDocument();
  });

  test('does not render when closed', () => {
    render(
      <ConfirmDialog
        isOpen={false}
        title="Delete Item"
        message="Are you sure?"
        onConfirm={vi.fn()}
        onCancel={vi.fn()}
      />
    );

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });

  test('calls onConfirm when confirm button clicked', async () => {
    const user = userEvent.setup();
    const onConfirm = vi.fn();

    render(
      <ConfirmDialog
        isOpen={true}
        title="Delete Item"
        message="Are you sure?"
        onConfirm={onConfirm}
        onCancel={vi.fn()}
      />
    );

    await user.click(screen.getByRole('button', { name: /confirm/i }));

    expect(onConfirm).toHaveBeenCalledTimes(1);
  });

  test('calls onCancel when cancel button clicked', async () => {
    const user = userEvent.setup();
    const onCancel = vi.fn();

    render(
      <ConfirmDialog
        isOpen={true}
        title="Delete Item"
        message="Are you sure?"
        onConfirm={vi.fn()}
        onCancel={onCancel}
      />
    );

    await user.click(screen.getByRole('button', { name: /cancel/i }));

    expect(onCancel).toHaveBeenCalledTimes(1);
  });

  test('closes on Escape key', async () => {
    const user = userEvent.setup();
    const onCancel = vi.fn();

    render(
      <ConfirmDialog
        isOpen={true}
        title="Delete Item"
        message="Are you sure?"
        onConfirm={vi.fn()}
        onCancel={onCancel}
      />
    );

    await user.keyboard('{Escape}');

    expect(onCancel).toHaveBeenCalledTimes(1);
  });
});
```

### GREEN - Minimal Implementation

```typescript
// src/components/ConfirmDialog.tsx
import { useEffect, useRef } from 'react';

interface ConfirmDialogProps {
  isOpen: boolean;
  title: string;
  message: string;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmDialog({
  isOpen,
  title,
  message,
  onConfirm,
  onCancel
}: ConfirmDialogProps) {
  const dialogRef = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const dialog = dialogRef.current;
    if (!dialog) return;

    if (isOpen) {
      dialog.showModal();
    } else {
      dialog.close();
    }
  }, [isOpen]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && isOpen) {
        onCancel();
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onCancel]);

  if (!isOpen) return null;

  return (
    <dialog ref={dialogRef} role="dialog">
      <h2>{title}</h2>
      <p>{message}</p>
      <div>
        <button onClick={onCancel}>Cancel</button>
        <button onClick={onConfirm}>Confirm</button>
      </div>
    </dialog>
  );
}
```

---

## Example 5: Custom Hook

### RED - Write Failing Test

```typescript
// src/hooks/useDebounce.test.ts
import { renderHook, act } from '@testing-library/react';
import { useDebounce } from './useDebounce';

describe('useDebounce', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  test('returns initial value immediately', () => {
    const { result } = renderHook(() => useDebounce('hello', 500));

    expect(result.current).toBe('hello');
  });

  test('does not update value before delay', () => {
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebounce(value, delay),
      { initialProps: { value: 'hello', delay: 500 } }
    );

    rerender({ value: 'world', delay: 500 });

    // Before delay
    act(() => {
      vi.advanceTimersByTime(400);
    });

    expect(result.current).toBe('hello');
  });

  test('updates value after delay', () => {
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebounce(value, delay),
      { initialProps: { value: 'hello', delay: 500 } }
    );

    rerender({ value: 'world', delay: 500 });

    act(() => {
      vi.advanceTimersByTime(500);
    });

    expect(result.current).toBe('world');
  });

  test('resets timer on rapid value changes', () => {
    const { result, rerender } = renderHook(
      ({ value, delay }) => useDebounce(value, delay),
      { initialProps: { value: 'a', delay: 500 } }
    );

    rerender({ value: 'b', delay: 500 });
    act(() => vi.advanceTimersByTime(300));

    rerender({ value: 'c', delay: 500 });
    act(() => vi.advanceTimersByTime(300));

    // Still 'a' because timer keeps resetting
    expect(result.current).toBe('a');

    // Complete the delay
    act(() => vi.advanceTimersByTime(200));

    expect(result.current).toBe('c');
  });
});
```

### GREEN - Minimal Implementation

```typescript
// src/hooks/useDebounce.ts
import { useState, useEffect } from 'react';

export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}
```

---

## Key Takeaways

1. **Always start with the test** - Write what the component should do before implementing
2. **Test user behavior** - Use role queries and userEvent
3. **Use MSW for API calls** - Mock at network level, not fetch/axios
4. **Test all states** - Loading, error, success
5. **Keep implementations minimal** - Only code needed to pass tests
