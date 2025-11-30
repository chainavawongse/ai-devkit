# API Integration Patterns

Consistent patterns for API integration using Axios + TanStack Query (React Query).

## Core Pattern

**Axios handles HTTP → React Query handles state management → Components consume clean hooks**

---

## Query Keys Factory

Always create query key factories for consistent cache management:

```typescript
// src/features/products/api/productsApi.ts

export const productKeys = {
  all: ['products'] as const,
  lists: () => [...productKeys.all, 'list'] as const,
  list: (filters?: ProductFilters) => [...productKeys.lists(), filters] as const,
  details: () => [...productKeys.all, 'detail'] as const,
  detail: (id: string) => [...productKeys.details(), id] as const,
};
```

---

## Query Hooks

### Basic Query
```typescript
export function useProducts(filters?: ProductFilters) {
  return useQuery({
    queryKey: productKeys.list(filters),
    queryFn: async () => {
      const { data } = await apiClient.get<Product[]>('/products', {
        params: filters,
      });
      return data;
    },
  });
}
```

### Query with Parameter
```typescript
export function useProduct(id: string) {
  return useQuery({
    queryKey: productKeys.detail(id),
    queryFn: async () => {
      const { data } = await apiClient.get<Product>(`/products/${id}`);
      return data;
    },
    enabled: !!id, // Don't run if id is empty
  });
}
```

### Component Usage
```typescript
export function ProductList() {
  const { data: products, isLoading, error } = useProducts();

  if (isLoading) {
    return <div>Loading products...</div>;
  }

  if (error) {
    return <div>Error: {error.message}</div>;
  }

  return (
    <div className="grid grid-cols-3 gap-4">
      {products?.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
}
```

---

## Mutation Hooks

### Create Mutation
```typescript
export function useCreateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (product: CreateProductRequest) => {
      const { data } = await apiClient.post<Product>('/products', product);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: productKeys.lists() });
      toast.success('Product created successfully');
    },
  });
}
```

### Update Mutation
```typescript
export function useUpdateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, data }: { id: string; data: UpdateProductRequest }) => {
      const response = await apiClient.put<Product>(`/products/${id}`, data);
      return response.data;
    },
    onSuccess: (updatedProduct) => {
      // Update specific item in cache
      queryClient.setQueryData(
        productKeys.detail(updatedProduct.id),
        updatedProduct
      );
      // Invalidate lists
      queryClient.invalidateQueries({ queryKey: productKeys.lists() });
      toast.success('Product updated successfully');
    },
  });
}
```

### Delete Mutation
```typescript
export function useDeleteProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      await apiClient.delete(`/products/${id}`);
      return id;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: productKeys.lists() });
      toast.success('Product deleted successfully');
    },
  });
}
```

### Mutation Usage in Components
```typescript
export function CreateProductForm() {
  const navigate = useNavigate();
  const createProduct = useCreateProduct();
  
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<ProductFormData>({
    resolver: zodResolver(productSchema),
  });

  const onSubmit = async (data: ProductFormData) => {
    try {
      await createProduct.mutateAsync(data);
      navigate('/products');
    } catch (error) {
      // Error handled globally, but can add local handling here
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {/* Form fields */}
      <button
        type="submit"
        disabled={createProduct.isPending}
      >
        {createProduct.isPending ? 'Creating...' : 'Create Product'}
      </button>
    </form>
  );
}
```

---

## Optimistic Updates

For better UX, update UI immediately before server confirms:

```typescript
export function useUpdateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, data }: { id: string; data: UpdateProductRequest }) => {
      const response = await apiClient.put<Product>(`/products/${id}`, data);
      return response.data;
    },
    // Optimistic update
    onMutate: async ({ id, data }) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: productKeys.detail(id) });

      // Snapshot previous value
      const previousProduct = queryClient.getQueryData<Product>(
        productKeys.detail(id)
      );

      // Optimistically update
      if (previousProduct) {
        queryClient.setQueryData<Product>(
          productKeys.detail(id),
          { ...previousProduct, ...data }
        );
      }

      // Return context with snapshot
      return { previousProduct };
    },
    // If mutation fails, rollback
    onError: (error, variables, context) => {
      if (context?.previousProduct) {
        queryClient.setQueryData(
          productKeys.detail(variables.id),
          context.previousProduct
        );
      }
      toast.error('Failed to update product');
    },
    // Always refetch after error or success
    onSettled: (data, error, variables) => {
      queryClient.invalidateQueries({ queryKey: productKeys.detail(variables.id) });
    },
  });
}
```

---

## Pagination

```typescript
// Types
type PaginatedResponse<T> = {
  data: T[];
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
};

type PaginationParams = {
  page: number;
  pageSize: number;
};

// API Hook
export function useProductsPaginated(params: PaginationParams) {
  return useQuery({
    queryKey: [...productKeys.lists(), 'paginated', params],
    queryFn: async () => {
      const { data } = await apiClient.get<PaginatedResponse<Product>>('/products', {
        params,
      });
      return data;
    },
    placeholderData: (previousData) => previousData, // Keep previous data while loading
  });
}

// Component Usage
export function ProductListPaginated() {
  const [page, setPage] = useState(1);
  const pageSize = 20;
  
  const { data, isLoading, isPlaceholderData } = useProductsPaginated({
    page,
    pageSize,
  });

  return (
    <div>
      {isLoading && !isPlaceholderData && <div>Loading...</div>}
      
      <div className={isPlaceholderData ? 'opacity-50' : ''}>
        {data?.data.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))}
      </div>

      <div className="flex gap-2 mt-4">
        <button
          onClick={() => setPage((p) => Math.max(1, p - 1))}
          disabled={page === 1}
        >
          Previous
        </button>
        <span>Page {page} of {data?.totalPages}</span>
        <button
          onClick={() => setPage((p) => p + 1)}
          disabled={page >= (data?.totalPages ?? 0)}
        >
          Next
        </button>
      </div>
    </div>
  );
}
```

---

## Infinite Scroll

```typescript
export function useProductsInfinite() {
  return useInfiniteQuery({
    queryKey: productKeys.lists(),
    queryFn: async ({ pageParam = 1 }) => {
      const { data } = await apiClient.get<PaginatedResponse<Product>>('/products', {
        params: { page: pageParam, pageSize: 20 },
      });
      return data;
    },
    getNextPageParam: (lastPage) => {
      return lastPage.page < lastPage.totalPages
        ? lastPage.page + 1
        : undefined;
    },
    initialPageParam: 1,
  });
}

// Component Usage
export function ProductListInfinite() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useProductsInfinite();

  return (
    <div>
      {data?.pages.map((page) =>
        page.data.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))
      )}

      {hasNextPage && (
        <button
          onClick={() => fetchNextPage()}
          disabled={isFetchingNextPage}
        >
          {isFetchingNextPage ? 'Loading...' : 'Load More'}
        </button>
      )}
    </div>
  );
}
```

---

## Dependent Queries

When one query depends on another:

```typescript
export function ProductDetails({ productId }: { productId: string }) {
  // First query
  const { data: product } = useProduct(productId);

  // Second query depends on first
  const { data: reviews } = useQuery({
    queryKey: ['reviews', product?.id],
    queryFn: async () => {
      const { data } = await apiClient.get(`/products/${product!.id}/reviews`);
      return data;
    },
    enabled: !!product, // Only run when product exists
  });

  return (
    <div>
      <h1>{product?.name}</h1>
      {reviews?.map((review) => (
        <div key={review.id}>{review.comment}</div>
      ))}
    </div>
  );
}
```

---

## Parallel Queries

```typescript
export function Dashboard() {
  // Run multiple queries in parallel
  const productsQuery = useProducts();
  const ordersQuery = useOrders();
  const statsQuery = useStats();

  // Or use useQueries for dynamic list
  const results = useQueries({
    queries: [
      { queryKey: ['products'], queryFn: fetchProducts },
      { queryKey: ['orders'], queryFn: fetchOrders },
      { queryKey: ['stats'], queryFn: fetchStats },
    ],
  });

  const isLoading = results.some((result) => result.isLoading);
  
  return <div>...</div>;
}
```

---

## File Upload

```typescript
export function useUploadProductImage() {
  return useMutation({
    mutationFn: async ({ productId, file }: { productId: string; file: File }) => {
      const formData = new FormData();
      formData.append('image', file);

      const { data } = await apiClient.post(
        `/products/${productId}/image`,
        formData,
        {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        }
      );
      return data;
    },
    onSuccess: () => {
      toast.success('Image uploaded successfully');
    },
  });
}

// Component
export function ProductImageUpload({ productId }: { productId: string }) {
  const uploadImage = useUploadProductImage();

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      uploadImage.mutate({ productId, file });
    }
  };

  return (
    <div>
      <input type="file" accept="image/*" onChange={handleFileChange} />
      {uploadImage.isPending && <div>Uploading...</div>}
    </div>
  );
}
```

---

## Prefetching

Prefetch data on hover for better UX:

```typescript
export function usePrefetchProduct(id: string) {
  const queryClient = useQueryClient();
  
  return useCallback(() => {
    queryClient.prefetchQuery({
      queryKey: productKeys.detail(id),
      queryFn: async () => {
        const { data } = await apiClient.get<Product>(`/products/${id}`);
        return data;
      },
    });
  }, [id, queryClient]);
}

// Usage
export function ProductLink({ productId }: { productId: string }) {
  const prefetch = usePrefetchProduct(productId);
  
  return (
    <Link 
      to={`/products/${productId}`}
      onMouseEnter={prefetch} // Prefetch on hover
    >
      View Product
    </Link>
  );
}
```

---

## Best Practices

### ✅ DO:

- Always use async/await in query/mutation functions
- Create query key factories for each feature
- Use React Query for ALL server state (no local state for API data)
- Invalidate appropriate queries after mutations
- Use optimistic updates for better UX
- Show loading and error states
- Provide user feedback (toasts) for mutations

### ❌ DON'T:

- Don't store API data in local state (useState)
- Don't manually trigger refetches without a reason
- Don't forget to handle error states
- Don't create deeply nested query keys
- Don't use .then()/.catch() chains (use async/await)

---

## Error Handling

Errors are handled globally in the API client interceptor and React Query configuration. See [Error Handling](../architecture/error-handling.md) for complete details.

For mutation-specific error handling:

```typescript
export function useCreateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (product: CreateProductRequest) => {
      const { data } = await apiClient.post<Product>('/products', product);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: productKeys.lists() });
      toast.success('Product created successfully');
    },
    onError: (error: AppError) => {
      // Override global error handling if needed
      if (error.type === ErrorType.VALIDATION && error.fieldErrors) {
        // Handle validation errors specifically
        toast.error('Please check the form for errors');
      }
    },
  });
}
```

---

## Complete Feature Example

```typescript
// src/features/products/api/productsApi.ts

import { useQuery, useMutation, useQueryClient, useInfiniteQuery } from '@tanstack/react-query';
import { apiClient } from '@/lib/api/client';
import { toast } from 'sonner';
import type { Product, CreateProductRequest, UpdateProductRequest } from '../types/product.types';

// Query Keys Factory
export const productKeys = {
  all: ['products'] as const,
  lists: () => [...productKeys.all, 'list'] as const,
  list: (filters?: ProductFilters) => [...productKeys.lists(), filters] as const,
  details: () => [...productKeys.all, 'detail'] as const,
  detail: (id: string) => [...productKeys.details(), id] as const,
};

// Queries
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

// Mutations
export function useCreateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (product: CreateProductRequest) => {
      const { data } = await apiClient.post<Product>('/products', product);
      return data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: productKeys.lists() });
      toast.success('Product created successfully');
    },
  });
}

export function useUpdateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, data }: { id: string; data: UpdateProductRequest }) => {
      const response = await apiClient.put<Product>(`/products/${id}`, data);
      return response.data;
    },
    onSuccess: (updatedProduct) => {
      queryClient.setQueryData(productKeys.detail(updatedProduct.id), updatedProduct);
      queryClient.invalidateQueries({ queryKey: productKeys.lists() });
      toast.success('Product updated successfully');
    },
  });
}

export function useDeleteProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (id: string) => {
      await apiClient.delete(`/products/${id}`);
      return id;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: productKeys.lists() });
      toast.success('Product deleted successfully');
    },
  });
}
```