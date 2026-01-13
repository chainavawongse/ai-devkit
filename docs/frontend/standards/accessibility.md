# Accessibility Standards

Guidelines for building accessible React applications.

## Core Principles

1. **Perceivable** - Information must be presentable in ways users can perceive
2. **Operable** - UI components must be operable by all users
3. **Understandable** - Information and UI operation must be understandable
4. **Robust** - Content must be robust enough for assistive technologies

---

## Semantic HTML

```typescript
// ✅ Good: Semantic elements
<nav>
  <ul>
    <li><Link to="/home">Home</Link></li>
  </ul>
</nav>

<main>
  <article>
    <header>
      <h1>Page Title</h1>
    </header>
    <section>Content</section>
  </article>
</main>

<aside>Sidebar</aside>
<footer>Footer content</footer>

// ❌ Bad: Div soup
<div className="nav">
  <div onClick={...}>Home</div>
</div>
```

---

## ARIA Labels

### Interactive Elements

```typescript
// Icon-only button
<button onClick={handleDelete} aria-label="Delete product">
  <TrashIcon aria-hidden="true" />
</button>

// Link opening in new tab
<a
  href="https://example.com"
  target="_blank"
  rel="noopener noreferrer"
  aria-label="Learn more (opens in new tab)"
>
  Learn more
</a>

// Loading button
<button aria-busy={isLoading} disabled={isLoading}>
  {isLoading ? 'Saving...' : 'Save'}
</button>
```

### Form Fields

```typescript
<div>
  <label htmlFor="email">Email</label>
  <input
    id="email"
    type="email"
    aria-invalid={!!error}
    aria-describedby={error ? 'email-error' : 'email-hint'}
  />
  <p id="email-hint">We'll never share your email</p>
  {error && (
    <p id="email-error" role="alert">{error}</p>
  )}
</div>
```

### Live Regions

```typescript
// Status updates
<div aria-live="polite">
  {isLoading ? 'Loading...' : `Found ${count} results`}
</div>

// Urgent announcements
<div role="alert" aria-live="assertive">
  {errorMessage}
</div>
```

---

## Keyboard Navigation

### Focus Management

```typescript
// Modal focus trap
export function Modal({ isOpen, onClose, children }) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousFocus = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      previousFocus.current = document.activeElement as HTMLElement;
      modalRef.current?.querySelector<HTMLElement>('button')?.focus();
    } else {
      previousFocus.current?.focus();
    }
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      
      if (e.key === 'Tab') {
        // Trap focus logic here
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  return (
    <div role="dialog" aria-modal="true" ref={modalRef}>
      {children}
    </div>
  );
}
```

### Skip Link

```typescript
export function Layout({ children }) {
  return (
    <>
      <a
        href="#main-content"
        className="sr-only focus:not-sr-only focus:absolute focus:top-0 focus:left-0 bg-blue-500 text-white p-2"
      >
        Skip to main content
      </a>
      <Header />
      <main id="main-content" tabIndex={-1}>
        {children}
      </main>
    </>
  );
}
```

---

## Color & Contrast

### Minimum Contrast Ratios

- **Normal text**: 4.5:1
- **Large text (18px+ or 14px+ bold)**: 3:1
- **UI components**: 3:1

### Don't Rely on Color Alone

```typescript
// ❌ Bad: Only color indicates state
<span className={isError ? 'text-red-500' : 'text-green-500'}>
  Status
</span>

// ✅ Good: Color + icon + text
<span className={isError ? 'text-red-500' : 'text-green-500'}>
  {isError ? (
    <>
      <AlertIcon aria-hidden="true" />
      <span>Error: {message}</span>
    </>
  ) : (
    <>
      <CheckIcon aria-hidden="true" />
      <span>Success</span>
    </>
  )}
</span>
```

---

## Screen Reader Support

### Visually Hidden Content

```css
/* src/styles/index.css */
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}
```

```typescript
// Icon with screen reader text
<button>
  <TrashIcon aria-hidden="true" />
  <span className="sr-only">Delete item</span>
</button>

// Decorative images
<img src="decoration.png" alt="" aria-hidden="true" />

// Informative images
<img src="chart.png" alt="Sales increased 25% in Q4" />
```

---

## Touch Targets

Minimum 44x44px for touch targets:

```typescript
// Icon button with proper size
<button className="p-3 min-h-[44px] min-w-[44px]">
  <MenuIcon className="w-5 h-5" />
</button>

// Checkbox with larger hit area
<label className="flex items-center gap-3 py-2 cursor-pointer">
  <input type="checkbox" className="w-5 h-5" />
  <span>Accept terms</span>
</label>
```

---

## Reduced Motion

```typescript
// src/hooks/usePrefersReducedMotion.ts
export function usePrefersReducedMotion(): boolean {
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
    setPrefersReducedMotion(mediaQuery.matches);

    const handler = (e: MediaQueryListEvent) => setPrefersReducedMotion(e.matches);
    mediaQuery.addEventListener('change', handler);
    return () => mediaQuery.removeEventListener('change', handler);
  }, []);

  return prefersReducedMotion;
}

// Usage
const prefersReducedMotion = usePrefersReducedMotion();
<div className={prefersReducedMotion ? '' : 'animate-fade-in'}>
```

Or use Tailwind utilities:

```typescript
<div className="motion-safe:animate-pulse motion-reduce:animate-none">
```

---

## Testing Checklist

**Automated:**

- [ ] ESLint jsx-a11y plugin passes
- [ ] Lighthouse accessibility audit > 90
- [ ] axe DevTools shows no violations

**Manual:**

- [ ] Navigate with keyboard only (Tab, Enter, Escape)
- [ ] Test with screen reader (VoiceOver/NVDA)
- [ ] Test at 200% zoom
- [ ] Verify focus indicators visible
- [ ] Check color contrast ratios

---

## ESLint Plugin

```bash
npm install -D eslint-plugin-jsx-a11y
```

```javascript
// eslint.config.js
import jsxA11y from 'eslint-plugin-jsx-a11y';

export default [
  {
    plugins: { 'jsx-a11y': jsxA11y },
    rules: {
      ...jsxA11y.configs.recommended.rules,
      'jsx-a11y/alt-text': 'error',
      'jsx-a11y/click-events-have-key-events': 'error',
      'jsx-a11y/label-has-associated-control': 'error',
    },
  },
];
```
