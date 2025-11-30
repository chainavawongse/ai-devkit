# Error Handling

Centralized error handling strategy for consistent error management.

## Error Types

```typescript
// src/types/error.types.ts

export enum ErrorType {
  NETWORK = 'NETWORK',
  VALIDATION = 'VALIDATION',
  AUTHENTICATION = 'AUTHENTICATION',
  AUTHORIZATION = 'AUTHORIZATION',
  NOT_FOUND = 'NOT_FOUND',
  SERVER = 'SERVER',
  UNKNOWN = 'UNKNOWN',
}

export interface AppError {
  type: ErrorType;
  message: string;
  statusCode?: number;
  fieldErrors?: Record<string, string>;
  originalError?: unknown;
}
```

---

## API Client Setup

```typescript
// src/lib/api/client.ts

import axios, { InternalAxiosRequestConfig } from 'axios';
import { ErrorType, AppError } from '@/types/error.types';
import { useAuthStore } from '@/lib/stores/authStore';
import { config } from '@/lib/config';

export const apiClient = axios.create({
  baseURL: config.api.baseUrl,
  timeout: config.api.timeout,
  headers: { 'Content-Type': 'application/json' },
});

// Request interceptor - Add auth token
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = useAuthStore.getState().token;
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// Response interceptor - Normalize errors
apiClient.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    
    // Handle token refresh on 401
    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      try {
        const newToken = await refreshAccessToken();
        useAuthStore.getState().setToken(newToken);
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        return apiClient(originalRequest);
      } catch (refreshError) {
        useAuthStore.getState().logout();
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }
    
    return Promise.reject(normalizeError(error));
  }
);

function normalizeError(error: unknown): AppError {
  if (axios.isAxiosError(error)) {
    const statusCode = error.response?.status;
    
    if (!error.response) {
      return {
        type: ErrorType.NETWORK,
        message: 'Network error. Please check your connection.',
        originalError: error,
      };
    }
    
    if (statusCode === 401) {
      return {
        type: ErrorType.AUTHENTICATION,
        message: 'Your session has expired. Please log in again.',
        statusCode,
        originalError: error,
      };
    }
    
    if (statusCode === 403) {
      return {
        type: ErrorType.AUTHORIZATION,
        message: 'You do not have permission to perform this action.',
        statusCode,
        originalError: error,
      };
    }
    
    if (statusCode === 404) {
      return {
        type: ErrorType.NOT_FOUND,
        message: 'The requested resource was not found.',
        statusCode,
        originalError: error,
      };
    }
    
    if (statusCode === 422 || statusCode === 400) {
      return {
        type: ErrorType.VALIDATION,
        message: error.response?.data?.message || 'Validation failed.',
        statusCode,
        fieldErrors: error.response?.data?.errors,
        originalError: error,
      };
    }
    
    if (statusCode && statusCode >= 500) {
      return {
        type: ErrorType.SERVER,
        message: 'A server error occurred. Please try again later.',
        statusCode,
        originalError: error,
      };
    }
    
    return {
      type: ErrorType.UNKNOWN,
      message: error.response?.data?.message || 'An unexpected error occurred.',
      statusCode,
      originalError: error,
    };
  }
  
  return {
    type: ErrorType.UNKNOWN,
    message: 'An unexpected error occurred.',
    originalError: error,
  };
}

async function refreshAccessToken(): Promise<string> {
  const refreshToken = useAuthStore.getState().refreshToken;
  const { data } = await axios.post(`${config.api.baseUrl}/auth/refresh`, {
    refreshToken,
  });
  return data.accessToken;
}
```

---

## React Query Configuration

```typescript
// src/lib/api/queryClient.ts

import { QueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import { AppError, ErrorType } from '@/types/error.types';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: (failureCount, error) => {
        const appError = error as AppError;
        // Don't retry on auth/validation errors
        if (
          appError.type === ErrorType.AUTHENTICATION ||
          appError.type === ErrorType.AUTHORIZATION ||
          appError.type === ErrorType.VALIDATION ||
          appError.type === ErrorType.NOT_FOUND
        ) {
          return false;
        }
        return failureCount < 2;
      },
      staleTime: 5 * 60 * 1000,
      gcTime: 10 * 60 * 1000,
      refetchOnWindowFocus: false,
    },
    mutations: {
      onError: (error) => {
        const appError = error as AppError;
        if (appError.type !== ErrorType.VALIDATION) {
          toast.error(appError.message);
        }
        if (appError.type === ErrorType.AUTHENTICATION) {
          window.location.href = '/login';
        }
      },
    },
  },
});
```

---

## Form Validation Errors

```typescript
const onSubmit = async (data: FormData) => {
  try {
    await createProduct.mutateAsync(data);
  } catch (error) {
    const appError = error as AppError;
    
    // Handle field-specific validation errors from backend
    if (appError.type === ErrorType.VALIDATION && appError.fieldErrors) {
      Object.entries(appError.fieldErrors).forEach(([field, message]) => {
        setError(field as keyof FormData, {
          type: 'server',
          message,
        });
      });
    }
  }
};
```

---

## Error Boundary

```typescript
// src/components/feedback/ErrorBoundary.tsx

import { Component, ReactNode } from 'react';
import { Button } from '@/components/ui/Button';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(): State {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || (
        <div className="flex flex-col items-center justify-center min-h-screen p-4">
          <h1 className="text-2xl font-bold mb-4">Something went wrong</h1>
          <Button onClick={() => window.location.reload()}>
            Refresh Page
          </Button>
        </div>
      );
    }
    return this.props.children;
  }
}
```

---

## Error Handling Hierarchy

| Error Type | Where Handled | User Feedback |
|------------|--------------|---------------|
| Form validation (client) | Component | Inline errors |
| Form validation (server) | Component | Inline errors |
| Network errors | React Query | Toast |
| Auth errors | API interceptor | Redirect to login |
| Server errors (5xx) | React Query | Toast |
| Runtime errors | Error Boundary | Full-page fallback |

---

## Toast Setup

```bash
npm install sonner
```

```typescript
// src/app/providers.tsx
import { Toaster } from 'sonner';

export function Providers({ children }: { children: ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
      <Toaster position="top-right" richColors closeButton />
    </QueryClientProvider>
  );
}
```