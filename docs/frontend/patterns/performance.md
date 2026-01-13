# Performance Optimization

Patterns for keeping React apps fast.

## Code Splitting

### Route-Based

```typescript
// src/app/router.tsx

import { lazy, Suspense } from 'react';
import { createBrowserRouter } from 'react-router-dom';

const HomePage = lazy(() => import('@/pages/HomePage'));
const ProductsPage = lazy(() => import('@/pages/ProductsPage'));
const DashboardPage = lazy(() => import('@/pages/DashboardPage'));

function PageLoader() {
  return <div className="flex items-center justify-center min-h-screen">Loading...</div>;
}

export const router = createBrowserRouter([
  {
    path: '/',
    element: <Layout />,
    children: [
      {
        index: true,
        element: (
          <Suspense fallback={<PageLoader />}>
            <HomePage />
          </Suspense>
        ),
      },
      {
        path: 'products',
        element: (
          <Suspense fallback={<PageLoader />}>
            <ProductsPage />
          </Suspense>
        ),
      },
    ],
  },
]);
```

### Component-Based

```typescript
const ProductChart = lazy(() => import('./ProductChart'));

export function ProductDetails() {
  const [showChart, setShowChart] = useState(false);
  
  return (
    <div>
      <button onClick={() => setShowChart(true)}>Show Chart</button>
      
      {showChart && (
        <Suspense fallback={<div>Loading chart...</div>}>
          <ProductChart />
        </Suspense>
      )}
    </div>
  );
}
```

### Library Dynamic Import

```typescript
async function exportToPDF() {
  const { jsPDF } = await import('jspdf');
  const doc = new jsPDF();
  // ...
}
```

---

## Memoization

### React.memo

```typescript
// Only use for expensive components with frequent parent re-renders
export const ProductCard = memo(function ProductCard({ product }: ProductCardProps) {
  return (
    <div className="border rounded p-4">
      <h3>{product.name}</h3>
      <p>${product.price}</p>
    </div>
  );
});
```

### useMemo

```typescript
export function ProductList({ products, filters }: ProductListProps) {
  // ✅ Use for expensive computations
  const filteredProducts = useMemo(() => {
    return products
      .filter((p) => p.price >= filters.minPrice)
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [products, filters]);

  // ❌ Don't use for simple operations
  // const total = useMemo(() => a + b, [a, b]);

  return (
    <div>
      {filteredProducts.map((p) => <ProductCard key={p.id} product={p} />)}
    </div>
  );
}
```

### useCallback

```typescript
export function ParentComponent() {
  const [items, setItems] = useState<Item[]>([]);
  
  // ✅ Use when passing to memoized children
  const handleDelete = useCallback((id: string) => {
    setItems((prev) => prev.filter((item) => item.id !== id));
  }, []);
  
  return <MemoizedList items={items} onDelete={handleDelete} />;
}
```

---

## List Virtualization

For lists with 100+ items:

```typescript
import { useVirtualizer } from '@tanstack/react-virtual';

export function VirtualizedList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);
  
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50,
    overscan: 5,
  });
  
  return (
    <div ref={parentRef} className="h-[500px] overflow-auto">
      <div style={{ height: virtualizer.getTotalSize(), position: 'relative' }}>
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: virtualItem.start,
              height: virtualItem.size,
              width: '100%',
            }}
          >
            {items[virtualItem.index].name}
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

## Image Optimization

### Lazy Loading

```typescript
<img
  src={imageUrl}
  alt={description}
  loading="lazy"
  width={300}
  height={200}
/>
```

### Modern Formats

```typescript
<picture>
  <source srcSet={avifUrl} type="image/avif" />
  <source srcSet={webpUrl} type="image/webp" />
  <img src={jpgUrl} alt={description} loading="lazy" />
</picture>
```

---

## React Query Optimization

### Stale Time

```typescript
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000, // Data fresh for 5 min
      gcTime: 10 * 60 * 1000,   // Cache for 10 min
    },
  },
});
```

### Prefetching

```typescript
export function ProductLink({ productId }: { productId: string }) {
  const queryClient = useQueryClient();
  
  const prefetch = () => {
    queryClient.prefetchQuery({
      queryKey: productKeys.detail(productId),
      queryFn: () => fetchProduct(productId),
    });
  };
  
  return (
    <Link to={`/products/${productId}`} onMouseEnter={prefetch}>
      View Product
    </Link>
  );
}
```

---

## Debouncing

```typescript
export function useDebounce<T>(value: T, delay = 500): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const handler = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(handler);
  }, [value, delay]);

  return debouncedValue;
}

// Usage
function Search() {
  const [search, setSearch] = useState('');
  const debouncedSearch = useDebounce(search, 300);
  const { data } = useProducts({ search: debouncedSearch });
}
```

---

## Bundle Analysis

```typescript
// vite.config.ts
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
  plugins: [
    react(),
    visualizer({ open: true, gzipSize: true }),
  ],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom'],
          'query-vendor': ['@tanstack/react-query'],
        },
      },
    },
  },
});
```

---

## Tree Shaking

```typescript
// ✅ Named imports (tree-shakable)
import { format, parseISO } from 'date-fns';
import { debounce } from 'lodash-es';

// ❌ Default imports (imports entire library)
import moment from 'moment';
import _ from 'lodash';
```

---

## Checklist

- [ ] Routes are lazy loaded
- [ ] Heavy components use lazy loading
- [ ] Lists 100+ items are virtualized
- [ ] Images use lazy loading
- [ ] Search inputs are debounced
- [ ] React Query has appropriate staleTime
- [ ] Bundle size analyzed
- [ ] Named imports for tree shaking
- [ ] memo/useMemo/useCallback used appropriately
