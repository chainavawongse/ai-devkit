# Query Priority Guide

## The Golden Rule

Query elements the way users find them. Users don't see test IDs or CSS classes.

## Priority 1: getByRole (Default Choice)

Queries the accessibility tree. Works for almost everything.

### Buttons

```typescript
// Simple button
screen.getByRole('button', { name: /submit/i })
screen.getByRole('button', { name: /cancel/i })

// Icon button with aria-label
screen.getByRole('button', { name: /close/i })  // <button aria-label="Close">X</button>

// Button in specific state
screen.getByRole('button', { name: /submit/i, disabled: true })
```

### Form Elements

```typescript
// Text input (textbox role)
screen.getByRole('textbox', { name: /email/i })

// Checkbox
screen.getByRole('checkbox', { name: /remember me/i })
screen.getByRole('checkbox', { checked: true })

// Radio buttons
screen.getByRole('radio', { name: /monthly/i })

// Combobox (select or autocomplete)
screen.getByRole('combobox', { name: /country/i })

// Spinbutton (number input)
screen.getByRole('spinbutton', { name: /quantity/i })

// Slider (range input)
screen.getByRole('slider', { name: /volume/i })
```

### Navigation & Structure

```typescript
// Links
screen.getByRole('link', { name: /home/i })
screen.getByRole('link', { name: /learn more/i })

// Headings
screen.getByRole('heading', { level: 1 })
screen.getByRole('heading', { name: /welcome/i })

// Navigation regions
screen.getByRole('navigation')
screen.getByRole('navigation', { name: /main/i })

// Main content
screen.getByRole('main')

// Lists
screen.getByRole('list')
screen.getAllByRole('listitem')

// Tables
screen.getByRole('table')
screen.getAllByRole('row')
screen.getAllByRole('cell')
```

### Interactive Elements

```typescript
// Tabs
screen.getByRole('tablist')
screen.getByRole('tab', { name: /settings/i })
screen.getByRole('tab', { selected: true })
screen.getByRole('tabpanel')

// Dialogs/Modals
screen.getByRole('dialog')
screen.getByRole('alertdialog')

// Menus
screen.getByRole('menu')
screen.getByRole('menuitem', { name: /edit/i })

// Progress indicators
screen.getByRole('progressbar')
screen.getByRole('status')

// Alerts
screen.getByRole('alert')
```

## Priority 2: getByLabelText (Form Fields)

Best for form inputs with associated labels.

```typescript
// Standard label
screen.getByLabelText('Email Address')
screen.getByLabelText(/email/i)

// Label wrapping input
// <label>Username <input /></label>
screen.getByLabelText('Username')

// aria-labelledby
// <span id="billing">Billing Address</span>
// <input aria-labelledby="billing" />
screen.getByLabelText('Billing Address')

// Multiple labels
screen.getByLabelText('Street Address', { selector: 'input' })
```

## Priority 3: getByPlaceholderText

Only when no label is available (not recommended UI pattern).

```typescript
// Search field without visible label
screen.getByPlaceholderText('Search...')
screen.getByPlaceholderText(/search/i)
```

## Priority 4: getByText

Non-interactive content (paragraphs, spans, divs).

```typescript
// Paragraphs and text content
screen.getByText('Welcome to our application')
screen.getByText(/no results found/i)

// Exact vs partial matching
screen.getByText('Hello World')           // Exact
screen.getByText(/hello/i)                 // Partial, case-insensitive
screen.getByText('Hello', { exact: false }) // Substring

// Within specific container
within(card).getByText('Details')
```

## Priority 5: getByDisplayValue

Inputs with pre-filled values (rare use case).

```typescript
// Pre-populated form field
screen.getByDisplayValue('john@example.com')
screen.getByDisplayValue(/john/i)

// After user types
await user.type(input, 'hello');
screen.getByDisplayValue('hello')
```

## Priority 6: getByAltText

Images and elements with alt text.

```typescript
// Images
screen.getByAltText('Company Logo')
screen.getByAltText(/profile picture/i)

// Areas in image maps
screen.getByAltText('Navigate to products')
```

## Priority 7: getByTestId (Last Resort)

Only when semantic queries are impossible.

```typescript
// Dynamic content with no accessible name
screen.getByTestId('user-avatar-skeleton')

// Third-party components without accessibility
screen.getByTestId('chart-container')
```

**When forced to use testId:**

1. Document why semantic query is impossible
2. Consider adding accessibility attributes instead
3. File issue to fix accessibility

## Query Variants

### get vs query vs find

| Prefix | No Match | Multiple | Async |
|--------|----------|----------|-------|
| `getBy` | Throws | Throws | No |
| `queryBy` | Returns null | Throws | No |
| `findBy` | Throws | Throws | Yes (waits) |
| `getAllBy` | Throws | Returns array | No |
| `queryAllBy` | Returns [] | Returns array | No |
| `findAllBy` | Throws | Returns array | Yes |

```typescript
// Element must exist
screen.getByRole('button')

// Element might not exist (checking absence)
expect(screen.queryByRole('alert')).not.toBeInTheDocument()

// Element appears asynchronously
await screen.findByText('Data loaded')

// Multiple elements
screen.getAllByRole('listitem')
```

## within() for Scoped Queries

```typescript
import { within } from '@testing-library/react';

// Find within specific container
const modal = screen.getByRole('dialog');
const closeButton = within(modal).getByRole('button', { name: /close/i });

// List items
const items = screen.getAllByRole('listitem');
within(items[0]).getByText('First item');

// Forms
const loginForm = screen.getByRole('form', { name: /login/i });
within(loginForm).getByLabelText('Password');
```

## Common Roles Reference

| Element | Role |
|---------|------|
| `<button>` | button |
| `<a href>` | link |
| `<input type="text">` | textbox |
| `<input type="checkbox">` | checkbox |
| `<input type="radio">` | radio |
| `<input type="number">` | spinbutton |
| `<input type="range">` | slider |
| `<select>` | combobox |
| `<textarea>` | textbox |
| `<h1>` - `<h6>` | heading |
| `<ul>`, `<ol>` | list |
| `<li>` | listitem |
| `<table>` | table |
| `<tr>` | row |
| `<td>` | cell |
| `<th>` | columnheader / rowheader |
| `<nav>` | navigation |
| `<main>` | main |
| `<article>` | article |
| `<aside>` | complementary |
| `<footer>` | contentinfo |
| `<header>` | banner |
| `<img>` | img |
| `<form>` | form (if named) |

## Accessibility Wins

Using role-based queries naturally improves accessibility:

```typescript
// This test...
screen.getByRole('button', { name: /submit/i })

// ...requires this accessible HTML:
<button>Submit</button>
// or
<button aria-label="Submit">→</button>

// Not this:
<div onClick={submit}>Submit</div>  // Fails query, fails accessibility
```

**Query priority = accessibility priority.** If you can't query it by role, users with assistive technology can't use it either.
