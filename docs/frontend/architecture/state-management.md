# State Management

Layered approach using React Query for server state and Zustand for client state.

## State Categories

| Type | Tool | Example |
|------|------|---------|
| **Server State** | TanStack Query | API data, user profile |
| **Global Client State** | Zustand | Theme, UI preferences |
| **Local State** | useState | Form inputs, toggles |
| **URL State** | React Router | Filters, pagination |

---

## Server State (TanStack Query)

For any data that comes from an API:

```typescript
// src/features/products/api/productsApi.ts

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '@/lib/api/client';

export const productKeys = {
  all: ['products'] as const,
  lists: () => [...productKeys.all, 'list'] as const,
  list: (filters?: ProductFilters) => [...productKeys.lists(), filters] as const,
  details: () => [...productKeys.all, 'detail'] as const,
  detail: (id: string) => [...productKeys.details(), id] as const,
};

export function useProducts(filters?: ProductFilters) {
  return useQuery({
    queryKey: productKeys.list(filters),
    queryFn: async () => {
      const { data } = await apiClient.get<Product[]>('/products', { params: filters });
      return data;
    },
  });
}

export function useProduct(id: string) {
  return useQuery({
    queryKey: productKeys.detail(id),
    queryFn: async () => {
      const { data } = await apiClient.get<Product>(`/products/${id}`);
      return data;
    },
    enabled: !!id,
  });
}
```

### Query Client Configuration

```typescript
// src/lib/api/queryClient.ts

import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,     // 5 minutes
      gcTime: 10 * 60 * 1000,       // 10 minutes
      refetchOnWindowFocus: false,
      retry: 2,
    },
  },
});
```

---

## Global Client State (Zustand)

For app-wide client-only state:

```typescript
// src/lib/stores/authStore.ts

import { create } from 'zustand';
import { persist } from 'zustand/middleware';

type User = {
  id: string;
  email: string;
  name: string;
};

type AuthState = {
  user: User | null;
  token: string | null;
  refreshToken: string | null;
  isAuthenticated: boolean;
  setUser: (user: User) => void;
  setToken: (token: string) => void;
  setRefreshToken: (token: string) => void;
  logout: () => void;
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      token: null,
      refreshToken: null,
      isAuthenticated: false,
      
      setUser: (user) => set({ user, isAuthenticated: true }),
      setToken: (token) => set({ token }),
      setRefreshToken: (refreshToken) => set({ refreshToken }),
      logout: () => set({ 
        user: null, 
        token: null, 
        refreshToken: null, 
        isAuthenticated: false 
      }),
    }),
    {
      name: 'auth-storage',
      partialize: (state) => ({ 
        token: state.token,
        refreshToken: state.refreshToken,
      }),
    }
  )
);
```

```typescript
// src/lib/stores/uiStore.ts

import { create } from 'zustand';

type UiState = {
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  setTheme: (theme: 'light' | 'dark') => void;
  toggleSidebar: () => void;
};

export const useUiStore = create<UiState>((set) => ({
  theme: 'light',
  sidebarOpen: true,
  
  setTheme: (theme) => set({ theme }),
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),
}));
```

### Usage with Selectors

```typescript
// ✅ Good: Select only what you need (prevents re-renders)
const user = useAuthStore((state) => state.user);
const theme = useUiStore((state) => state.theme);

// ❌ Bad: Selecting entire store (re-renders on any change)
const authStore = useAuthStore();
```

---

## Local State (useState)

For component-scoped state:

```typescript
export function ProductFilters() {
  // Local UI state
  const [isOpen, setIsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  
  return (
    <div>
      <input
        value={searchTerm}
        onChange={(e) => setSearchTerm(e.target.value)}
      />
    </div>
  );
}
```

---

## URL State (React Router)

For shareable, bookmarkable state:

```typescript
// src/features/products/hooks/useProductFilters.ts

import { useSearchParams } from 'react-router-dom';

export function useProductFilters() {
  const [searchParams, setSearchParams] = useSearchParams();
  
  const filters = {
    search: searchParams.get('search') || '',
    category: searchParams.get('category') || '',
    page: parseInt(searchParams.get('page') || '1', 10),
  };
  
  const setFilters = (newFilters: Partial<typeof filters>) => {
    const params = new URLSearchParams(searchParams);
    
    Object.entries(newFilters).forEach(([key, value]) => {
      if (value) {
        params.set(key, String(value));
      } else {
        params.delete(key);
      }
    });
    
    setSearchParams(params);
  };
  
  return { filters, setFilters };
}

// Usage
function ProductsPage() {
  const { filters, setFilters } = useProductFilters();
  const { data } = useProducts(filters);
  
  return (
    <input
      value={filters.search}
      onChange={(e) => setFilters({ search: e.target.value })}
    />
  );
}
```

---

## Decision Tree

```
Where does the data come from?
├── API/Server → TanStack Query
└── Client-only
    ├── Needs to persist across sessions? → Zustand (with persist)
    ├── Multiple components need it? → Zustand
    ├── Should be in URL (shareable)? → URL state
    └── Only one component needs it? → useState
```

---

## Best Practices

### ✅ DO

- Use React Query for ALL server state
- Use Zustand selectors to prevent re-renders
- Colocate local state with components
- Keep URL state for filters/pagination
- Invalidate queries after mutations

### ❌ DON'T

- Don't store API data in Zustand
- Don't use React Context for frequently changing state
- Don't create global state for local concerns
- Don't forget to invalidate queries after mutations
