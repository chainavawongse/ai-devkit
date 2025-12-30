# Frontend Testing Anti-Patterns

Patterns to avoid with concrete examples and fixes.

---

## 1. Using getByTestId as First Choice

### Bad

```typescript
test('submits form', async () => {
  render(<LoginForm />);

  await userEvent.type(screen.getByTestId('email-input'), 'test@example.com');
  await userEvent.type(screen.getByTestId('password-input'), 'secret');
  await userEvent.click(screen.getByTestId('submit-btn'));

  expect(screen.getByTestId('success-message')).toBeInTheDocument();
});
```

### Why It's Bad

- Users don't see test IDs
- Doesn't verify accessibility
- Allows broken UI to pass tests

### Good

```typescript
test('submits form', async () => {
  render(<LoginForm />);

  await userEvent.type(screen.getByLabelText(/email/i), 'test@example.com');
  await userEvent.type(screen.getByLabelText(/password/i), 'secret');
  await userEvent.click(screen.getByRole('button', { name: /sign in/i }));

  expect(screen.getByText(/welcome/i)).toBeInTheDocument();
});
```

---

## 2. Testing Implementation Details

### Bad

```typescript
test('updates state when button clicked', () => {
  const setCount = vi.fn();

  // Spying on React internals
  vi.spyOn(React, 'useState').mockImplementation(() => [0, setCount]);

  render(<Counter />);

  fireEvent.click(screen.getByRole('button', { name: /increment/i }));

  // Testing that internal setter was called
  expect(setCount).toHaveBeenCalledWith(1);
});
```

### Why It's Bad

- Coupled to implementation (breaks if useState → useReducer)
- Mocking React internals is fragile
- Doesn't verify what the user actually sees

### Good

```typescript
test('increments displayed count when button clicked', async () => {
  render(<Counter />);

  expect(screen.getByText('Count: 0')).toBeInTheDocument();

  await userEvent.click(screen.getByRole('button', { name: /increment/i }));

  expect(screen.getByText('Count: 1')).toBeInTheDocument();
});
```

---

## 3. Using fireEvent Instead of userEvent

### Bad

```typescript
test('types in input', () => {
  render(<SearchBox />);

  const input = screen.getByRole('textbox');
  fireEvent.change(input, { target: { value: 'search term' } });

  expect(input).toHaveValue('search term');
});
```

### Why It's Bad

- `fireEvent.change` skips focus, keydown, keyup events
- Doesn't trigger validation that depends on blur
- Doesn't test keyboard navigation

### Good

```typescript
test('types in input', async () => {
  const user = userEvent.setup();
  render(<SearchBox />);

  await user.type(screen.getByRole('textbox'), 'search term');

  expect(screen.getByRole('textbox')).toHaveValue('search term');
});
```

---

## 4. Mocking fetch/axios Directly

### Bad

```typescript
test('loads users', async () => {
  global.fetch = vi.fn().mockResolvedValue({
    ok: true,
    json: () => Promise.resolve([{ id: '1', name: 'Alice' }]),
  });

  render(<UserList />);

  expect(await screen.findByText('Alice')).toBeInTheDocument();

  global.fetch.mockRestore();
});
```

### Why It's Bad

- Coupled to fetch implementation
- Switching to axios breaks tests
- Complex setup for headers, status codes
- No network-level testing

### Good

```typescript
// Setup MSW handler
http.get('/api/users', () => {
  return HttpResponse.json([{ id: '1', name: 'Alice' }]);
});

test('loads users', async () => {
  render(<UserList />);

  expect(await screen.findByText('Alice')).toBeInTheDocument();
});
```

---

## 5. Manual setTimeout Waits

### Bad

```typescript
test('shows message after delay', async () => {
  render(<DelayedMessage />);

  // Arbitrary wait
  await new Promise(r => setTimeout(r, 2000));

  expect(screen.getByText('Hello')).toBeInTheDocument();
});
```

### Why It's Bad

- Slow tests
- Flaky (timing varies)
- Wastes CI time

### Good

```typescript
test('shows message after delay', async () => {
  render(<DelayedMessage />);

  // Waits only as long as needed
  expect(await screen.findByText('Hello')).toBeInTheDocument();
});
```

---

## 6. Testing CSS Classes

### Bad

```typescript
test('button has correct style when disabled', () => {
  render(<Button disabled>Click</Button>);

  expect(screen.getByRole('button')).toHaveClass('btn-disabled');
  expect(screen.getByRole('button')).toHaveStyle({ opacity: 0.5 });
});
```

### Why It's Bad

- CSS classes can change without breaking behavior
- Tests become coupled to styling implementation
- Doesn't verify actual user experience

### Good

```typescript
test('button is disabled', () => {
  render(<Button disabled>Click</Button>);

  expect(screen.getByRole('button')).toBeDisabled();
});
```

---

## 7. Snapshot Tests for Logic

### Bad

```typescript
test('renders correctly', () => {
  const { container } = render(<UserProfile user={mockUser} />);

  expect(container).toMatchSnapshot();
});
```

### Why It's Bad

- Any change triggers failure (false positives)
- Doesn't document expected behavior
- Easy to blindly update snapshots
- Doesn't test logic, just structure

### Good

```typescript
test('displays user information', () => {
  render(<UserProfile user={{ name: 'Alice', email: 'alice@example.com' }} />);

  expect(screen.getByRole('heading')).toHaveTextContent('Alice');
  expect(screen.getByText('alice@example.com')).toBeInTheDocument();
});
```

**When snapshots are OK:** Visual regression testing with proper tooling (Chromatic, Percy).

---

## 8. Not Testing Error States

### Bad

```typescript
test('loads data', async () => {
  render(<DataDisplay />);

  expect(await screen.findByText('Data loaded')).toBeInTheDocument();
});
// No error test!
```

### Why It's Bad

- Users hit errors
- Error UI might be broken
- No confidence in error handling

### Good

```typescript
test('loads data', async () => {
  render(<DataDisplay />);

  expect(await screen.findByText('Data loaded')).toBeInTheDocument();
});

test('shows error when request fails', async () => {
  server.use(
    http.get('/api/data', () => {
      return HttpResponse.json({ error: 'Server error' }, { status: 500 });
    })
  );

  render(<DataDisplay />);

  expect(await screen.findByRole('alert')).toHaveTextContent(/error/i);
});
```

---

## 9. Empty waitFor Callbacks

### Bad

```typescript
test('data loads', async () => {
  render(<DataLoader />);

  // What are we waiting for?!
  await waitFor(() => {});

  expect(screen.getByText('Data')).toBeInTheDocument();
});
```

### Why It's Bad

- Doesn't wait for anything specific
- Race conditions
- Flaky tests

### Good

```typescript
test('data loads', async () => {
  render(<DataLoader />);

  await waitFor(() => {
    expect(screen.getByText('Data')).toBeInTheDocument();
  });
});

// Or better:
test('data loads', async () => {
  render(<DataLoader />);

  expect(await screen.findByText('Data')).toBeInTheDocument();
});
```

---

## 10. Not Using screen

### Bad

```typescript
test('renders button', () => {
  const { getByRole, getByText } = render(<MyComponent />);

  expect(getByRole('button')).toBeInTheDocument();
  expect(getByText('Hello')).toBeInTheDocument();
});
```

### Why It's Bad

- Inconsistent with documentation
- Harder to refactor (need to add to destructure)
- `screen` always available

### Good

```typescript
test('renders button', () => {
  render(<MyComponent />);

  expect(screen.getByRole('button')).toBeInTheDocument();
  expect(screen.getByText('Hello')).toBeInTheDocument();
});
```

---

## 11. Using query* for Elements That Should Exist

### Bad

```typescript
test('shows title', () => {
  render(<Page />);

  // Returns null if not found - no helpful error
  expect(screen.queryByRole('heading')).toBeInTheDocument();
});
```

### Why It's Bad

- `queryBy` returns null instead of throwing
- Error message unhelpful: "expected null to be in document"
- `getBy` provides better error messages

### Good

```typescript
test('shows title', () => {
  render(<Page />);

  // Throws with helpful message if not found
  expect(screen.getByRole('heading')).toBeInTheDocument();
});

// Use queryBy only for asserting absence:
test('hides error initially', () => {
  render(<Form />);

  expect(screen.queryByRole('alert')).not.toBeInTheDocument();
});
```

---

## 12. Testing Third-Party Library Behavior

### Bad

```typescript
test('datepicker opens calendar', async () => {
  render(<DatePicker />);

  await userEvent.click(screen.getByRole('textbox'));

  // Testing that react-datepicker works
  expect(screen.getByRole('grid')).toBeInTheDocument();
  expect(screen.getAllByRole('gridcell')).toHaveLength(42);
});
```

### Why It's Bad

- Tests library, not your code
- Will break when library updates
- Library is already tested

### Good

```typescript
test('selected date is passed to handler', async () => {
  const onSelect = vi.fn();
  render(<DatePicker onSelect={onSelect} />);

  // Only test your integration
  await userEvent.click(screen.getByRole('textbox'));
  await userEvent.click(screen.getByText('15'));

  expect(onSelect).toHaveBeenCalledWith(expect.any(Date));
});
```

---

## 13. Not Cleaning Up

### Bad

```typescript
// No cleanup between tests
let rendered: RenderResult;

beforeEach(() => {
  rendered = render(<App />);
});

test('first test', () => {
  // Modifies DOM
});

test('second test', () => {
  // Previous test's DOM still there!
});
```

### Why It's Bad

- Tests affect each other
- Order-dependent failures
- Hard to debug

### Good

```typescript
// vitest.setup.ts handles cleanup automatically with:
afterEach(() => {
  cleanup();
});

// Each test renders fresh
test('first test', () => {
  render(<App />);
  // ...
});

test('second test', () => {
  render(<App />);  // Fresh render
  // ...
});
```

---

## Quick Reference

| Anti-Pattern | Fix |
|--------------|-----|
| `getByTestId` first | `getByRole`, `getByLabelText` |
| Testing state | Test rendered output |
| `fireEvent` | `userEvent` |
| Mock fetch/axios | MSW |
| `setTimeout` waits | `findBy`, `waitFor` |
| Testing CSS classes | Test behavior (disabled, visible) |
| Snapshots for logic | Explicit assertions |
| No error tests | Test error states with MSW |
| Empty `waitFor` | Put assertion inside |
| Destructure from render | Use `screen` |
| `queryBy` for existence | `getBy` for existence, `queryBy` for absence |
| Test library behavior | Test your integration only |
| No cleanup | Use `afterEach(cleanup)` |
