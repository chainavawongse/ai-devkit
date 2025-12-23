# Security

Frontend security best practices to prevent common vulnerabilities.

## XSS Prevention

### Never Use dangerouslySetInnerHTML

```typescript
// ❌ Dangerous - allows XSS attacks
<div dangerouslySetInnerHTML={{ __html: userInput }} />

// ✅ Safe - React escapes by default
<div>{userInput}</div>
```

### If You Must Render HTML

```typescript
import DOMPurify from 'dompurify';

// ✅ Sanitize first
const sanitizedHtml = DOMPurify.sanitize(untrustedHtml);
<div dangerouslySetInnerHTML={{ __html: sanitizedHtml }} />
```

### URL Validation

```typescript
// ❌ Dangerous - javascript: URLs can execute code
<a href={userProvidedUrl}>Link</a>

// ✅ Safe - validate protocol
function isSafeUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    return ['http:', 'https:', 'mailto:'].includes(parsed.protocol);
  } catch {
    return false;
  }
}

<a href={isSafeUrl(url) ? url : '#'}>Link</a>
```

---

## Authentication & Tokens

### Token Storage

```typescript
// ✅ Recommended: HttpOnly cookies (set by backend)
// Tokens are never accessible to JavaScript

// ⚠️ Acceptable: In-memory only (lost on refresh)
let accessToken: string | null = null;

// ❌ Avoid: localStorage for sensitive tokens
localStorage.setItem('token', accessToken); // Vulnerable to XSS
```

### Secure Token Handling with Zustand

```typescript
// src/lib/stores/authStore.ts

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      // Store refresh token only (short-lived access token in memory)
      refreshToken: null,
      accessToken: null, // Not persisted

      setTokens: (access: string, refresh: string) =>
        set({ accessToken: access, refreshToken: refresh }),

      logout: () => set({ accessToken: null, refreshToken: null }),
    }),
    {
      name: 'auth-storage',
      // Only persist refresh token, not access token
      partialize: (state) => ({ refreshToken: state.refreshToken }),
    }
  )
);
```

### Token Refresh Pattern

```typescript
// src/lib/api/client.ts

let isRefreshing = false;
let refreshSubscribers: ((token: string) => void)[] = [];

apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;

    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        // Queue requests while refreshing
        return new Promise((resolve) => {
          refreshSubscribers.push((token: string) => {
            originalRequest.headers.Authorization = `Bearer ${token}`;
            resolve(apiClient(originalRequest));
          });
        });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const newToken = await refreshAccessToken();
        refreshSubscribers.forEach((callback) => callback(newToken));
        refreshSubscribers = [];

        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        useAuthStore.getState().logout();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }

    return Promise.reject(error);
  }
);
```

---

## Input Validation

### Validate at Boundaries

```typescript
// ✅ Validate all external input with Zod
const userInputSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  website: z.string().url().optional(),
});

// Validate before using
const result = userInputSchema.safeParse(formData);
if (!result.success) {
  // Handle validation errors
}
```

### Sanitize for Display

```typescript
// For user-generated content that might contain special characters
function escapeHtml(text: string): string {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}
```

---

## Sensitive Data Handling

### Never Log Sensitive Data

```typescript
// ❌ Never log tokens, passwords, or PII
console.log('User data:', { email, password, token });
console.log('Auth header:', config.headers.Authorization);

// ✅ Log safe identifiers only
console.log('Login attempt for user ID:', userId);
console.error('Auth failed for session:', sessionId);
```

### Mask Sensitive Display

```typescript
// Mask credit card numbers
function maskCardNumber(cardNumber: string): string {
  return `****-****-****-${cardNumber.slice(-4)}`;
}

// Mask email addresses
function maskEmail(email: string): string {
  const [local, domain] = email.split('@');
  return `${local[0]}***@${domain}`;
}
```

### Clear Sensitive Data

```typescript
// Clear sensitive data on logout
function logout() {
  // Clear auth state
  useAuthStore.getState().logout();

  // Clear React Query cache (may contain user data)
  queryClient.clear();

  // Clear any sensitive sessionStorage
  sessionStorage.clear();

  // Redirect to login
  window.location.href = '/login';
}
```

---

## CSRF Protection

### Use SameSite Cookies

Backend should set cookies with:
```
Set-Cookie: token=xxx; HttpOnly; Secure; SameSite=Strict
```

### Include CSRF Token

```typescript
// If backend provides CSRF token
apiClient.interceptors.request.use((config) => {
  const csrfToken = document.querySelector<HTMLMetaElement>(
    'meta[name="csrf-token"]'
  )?.content;

  if (csrfToken) {
    config.headers['X-CSRF-Token'] = csrfToken;
  }

  return config;
});
```

---

## Content Security Policy

### Recommended CSP Headers

```html
<!-- In index.html or set by server -->
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' https: data:;
  connect-src 'self' https://api.example.com;
  font-src 'self';
  frame-ancestors 'none';
">
```

### Avoid Inline Scripts

```typescript
// ❌ Avoid inline event handlers
<button onclick="handleClick()">Click</button>

// ✅ Use React event handlers
<button onClick={handleClick}>Click</button>
```

---

## Dependency Security

### Regular Audits

```bash
# Check for vulnerabilities
npm audit

# Fix automatically where possible
npm audit fix

# Update dependencies
npm update
```

### Lock File

```bash
# Always commit lock files
git add package-lock.json

# Use exact versions in CI
npm ci  # Not npm install
```

### Trusted Sources Only

```typescript
// ✅ Use well-maintained packages
import { format } from 'date-fns';

// ❌ Avoid unmaintained or suspicious packages
// Check: last update, downloads, open issues, maintainers
```

---

## Environment Variables

### Never Expose Secrets

```bash
# ✅ Safe to expose (VITE_ prefix = bundled into client)
VITE_API_BASE_URL=https://api.example.com
VITE_STRIPE_PUBLIC_KEY=pk_live_xxx

# ❌ Never expose (no VITE_ prefix = server only)
DATABASE_URL=postgresql://...
STRIPE_SECRET_KEY=sk_live_xxx
JWT_SECRET=xxx
API_INTERNAL_KEY=xxx
```

### Validate at Startup

```typescript
// src/lib/config.ts

function requireEnv(key: string): string {
  const value = import.meta.env[key];
  if (!value) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

export const config = {
  api: {
    baseUrl: requireEnv('VITE_API_BASE_URL'),
  },
} as const;

// Validate on app start
if (import.meta.env.DEV) {
  console.info('Config loaded:', {
    apiBaseUrl: config.api.baseUrl,
  });
}
```

---

## Secure Communication

### HTTPS Only

```typescript
// Redirect HTTP to HTTPS (usually handled by server/CDN)
// But validate in client if needed
if (location.protocol !== 'https:' && !import.meta.env.DEV) {
  location.replace(`https:${location.href.substring(location.protocol.length)}`);
}
```

### API Security Headers

```typescript
// Ensure API client uses secure defaults
export const apiClient = axios.create({
  baseURL: config.api.baseUrl,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // For HttpOnly cookies
});
```

---

## Security Checklist

### Authentication
- [ ] Tokens stored securely (HttpOnly cookies or memory)
- [ ] Access tokens are short-lived
- [ ] Refresh token rotation implemented
- [ ] Logout clears all sensitive data

### Input/Output
- [ ] All user input validated with Zod
- [ ] No dangerouslySetInnerHTML with unsanitized content
- [ ] URLs validated before use
- [ ] Sensitive data masked in UI

### Data Protection
- [ ] No sensitive data in console logs
- [ ] No secrets in client-side code
- [ ] Environment variables properly scoped
- [ ] HTTPS enforced in production

### Dependencies
- [ ] Regular npm audit runs
- [ ] Lock files committed
- [ ] Dependencies from trusted sources

### Headers
- [ ] CSP headers configured
- [ ] CSRF protection enabled
- [ ] Secure cookie flags set

---

## Common Vulnerabilities Reference

| Vulnerability | Prevention |
|---------------|------------|
| XSS | React's default escaping, sanitize HTML, validate URLs |
| CSRF | SameSite cookies, CSRF tokens |
| Token theft | HttpOnly cookies, short expiry, secure storage |
| Data exposure | No logging PII, mask sensitive display |
| Injection | Validate all input, parameterized queries (backend) |
| Dependency attacks | Regular audits, lock files, trusted sources |
