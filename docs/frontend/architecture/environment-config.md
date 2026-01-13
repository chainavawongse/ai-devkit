# Environment Configuration

Managing environment variables and configuration across environments.

## File Structure

```
project-root/
  ├── .env                    # Default values (committed)
  ├── .env.local              # Local overrides (NOT committed)
  ├── .env.development        # Development-specific
  ├── .env.production         # Production-specific
  └── .env.example            # Template for developers
```

---

## Environment Files

### .env.example (Template)

```bash
# Copy to .env.local and fill in values

# API
VITE_API_BASE_URL=http://localhost:3000/api
VITE_API_TIMEOUT=10000

# App
VITE_APP_NAME=MyApp
VITE_APP_VERSION=1.0.0

# Features
VITE_ENABLE_ANALYTICS=false
VITE_ENABLE_DEBUG_MODE=true

# Auth (fill in your values)
VITE_AUTH_DOMAIN=
VITE_AUTH_CLIENT_ID=

# External Services
VITE_STRIPE_PUBLIC_KEY=
```

### .env (Defaults)

```bash
VITE_API_BASE_URL=http://localhost:3000/api
VITE_API_TIMEOUT=10000
VITE_APP_NAME=MyApp
VITE_ENABLE_ANALYTICS=false
```

### .env.production

```bash
VITE_API_BASE_URL=https://api.example.com
VITE_ENABLE_ANALYTICS=true
VITE_ENABLE_DEBUG_MODE=false
```

---

## Type-Safe Configuration

### Type Definitions

```typescript
// src/types/env.d.ts

/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string;
  readonly VITE_API_TIMEOUT: string;
  readonly VITE_APP_NAME: string;
  readonly VITE_ENABLE_ANALYTICS: string;
  readonly VITE_ENABLE_DEBUG_MODE: string;
  readonly VITE_AUTH_DOMAIN: string;
  readonly VITE_AUTH_CLIENT_ID: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

### Config Module

```typescript
// src/lib/config.ts

function parseBoolean(value: string | undefined, defaultValue: boolean): boolean {
  if (value === undefined) return defaultValue;
  return value.toLowerCase() === 'true';
}

function requireEnv(key: string, value: string | undefined): string {
  if (!value) {
    throw new Error(`Missing required env var: ${key}`);
  }
  return value;
}

export const config = {
  api: {
    baseUrl: requireEnv('VITE_API_BASE_URL', import.meta.env.VITE_API_BASE_URL),
    timeout: parseInt(import.meta.env.VITE_API_TIMEOUT || '10000', 10),
  },

  app: {
    name: import.meta.env.VITE_APP_NAME || 'MyApp',
    isDevelopment: import.meta.env.DEV,
    isProduction: import.meta.env.PROD,
  },

  features: {
    analytics: parseBoolean(import.meta.env.VITE_ENABLE_ANALYTICS, false),
    debugMode: parseBoolean(import.meta.env.VITE_ENABLE_DEBUG_MODE, false),
  },

  auth: {
    domain: import.meta.env.VITE_AUTH_DOMAIN,
    clientId: import.meta.env.VITE_AUTH_CLIENT_ID,
  },
} as const;

export function validateConfig(): void {
  try {
    config.api.baseUrl;
    console.info('✅ Configuration validated');
  } catch (error) {
    console.error('❌ Configuration failed:', error);
    throw error;
  }
}
```

---

## Usage

```typescript
// ✅ Always use config module
import { config } from '@/lib/config';

const apiClient = axios.create({
  baseURL: config.api.baseUrl,
  timeout: config.api.timeout,
});

if (config.features.analytics) {
  initAnalytics();
}

// ❌ Don't access import.meta.env directly in components
const url = import.meta.env.VITE_API_BASE_URL;
```

---

## Feature Flags

```typescript
// src/lib/featureFlags.ts

import { config } from './config';

export const featureFlags = {
  analytics: config.features.analytics,
  debugMode: config.features.debugMode,
} as const;

// Component helper
export function FeatureFlag({
  flag,
  children,
}: {
  flag: keyof typeof featureFlags;
  children: React.ReactNode;
}) {
  return featureFlags[flag] ? <>{children}</> : null;
}

// Usage
<FeatureFlag flag="analytics">
  <AnalyticsProvider />
</FeatureFlag>
```

---

## Git Configuration

```gitignore
# .gitignore

# Local env files with secrets
.env.local
.env.*.local

# Keep these committed (no secrets)
# .env
# .env.development
# .env.production
# .env.example
```

---

## Security Rules

### ✅ Safe to Expose (VITE_ prefix)

```bash
VITE_API_BASE_URL=https://api.example.com
VITE_STRIPE_PUBLIC_KEY=pk_live_...
VITE_GOOGLE_MAPS_API_KEY=AIza...
```

### ❌ Never Expose to Browser

```bash
# These go on server only (no VITE_ prefix)
DATABASE_URL=postgresql://...
STRIPE_SECRET_KEY=sk_live_...
JWT_SECRET=...
```

---

## Build Modes

```json
// package.json
{
  "scripts": {
    "dev": "vite",
    "dev:staging": "vite --mode staging",
    "build": "vite build",
    "build:staging": "vite build --mode staging"
  }
}
```
