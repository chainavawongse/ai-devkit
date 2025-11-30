/**
 * Products API
 *
 * React Query hooks for product CRUD operations.
 *
 * @example
 * ```tsx
 * // Fetching products
 * const { data, isLoading, error } = useProducts({ category: 'electronics' });
 *
 * // Creating a product
 * const createProduct = useCreateProduct();
 * await createProduct.mutateAsync({ name: 'Widget', price: 99 });
 * ```
 */

import {
  useQuery,
  useMutation,
  useQueryClient,
  useInfiniteQuery,
} from '@tanstack/react-query';
import { toast } from 'sonner';
import { apiClient } from '@/lib/api/client';
import type {
  Product,
  CreateProductRequest,
  UpdateProductRequest,
  ProductFilters,
  PaginatedResponse,
} from '../types/product.types';

// -----------------------------------------------------------------------------
// Query Keys Factory
// -----------------------------------------------------------------------------

export const productKeys = {
  all: ['products'] as const,
  lists: () => [...productKeys.all, 'list'] as const,
  list: (filters?: ProductFilters) => [...productKeys.lists(), filters] as const,
  details: () => [...productKeys.all, 'detail'] as const,
  detail: (id: string) => [...productKeys.details(), id] as const,
};

// -----------------------------------------------------------------------------
// Query Hooks
// -----------------------------------------------------------------------------

/**
 * Fetch all products with optional filters
 */
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

/**
 * Fetch a single product by ID
 */
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

/**
 * Fetch products with infinite scroll pagination
 */
export function useProductsInfinite(filters?: Omit<ProductFilters, 'page'>) {
  return useInfiniteQuery({
    queryKey: [...productKeys.lists(), 'infinite', filters],
    queryFn: async ({ pageParam = 1 }) => {
      const { data } = await apiClient.get<PaginatedResponse<Product>>('/products', {
        params: { ...filters, page: pageParam, pageSize: 20 },
      });
      return data;
    },
    getNextPageParam: (lastPage) => {
      return lastPage.page < lastPage.totalPages ? lastPage.page + 1 : undefined;
    },
    initialPageParam: 1,
  });
}

// -----------------------------------------------------------------------------
// Mutation Hooks
// -----------------------------------------------------------------------------

/**
 * Create a new product
 */
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
    onError: () => {
      toast.error('Failed to create product');
    },
  });
}

/**
 * Update an existing product
 */
export function useUpdateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, data }: { id: string; data: UpdateProductRequest }) => {
      const response = await apiClient.put<Product>(`/products/${id}`, data);
      return response.data;
    },
    onSuccess: (updatedProduct) => {
      // Update cache directly
      queryClient.setQueryData(
        productKeys.detail(updatedProduct.id),
        updatedProduct
      );
      // Invalidate lists
      queryClient.invalidateQueries({ queryKey: productKeys.lists() });
      toast.success('Product updated successfully');
    },
    onError: () => {
      toast.error('Failed to update product');
    },
  });
}

/**
 * Update product with optimistic update
 */
export function useUpdateProductOptimistic() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ id, data }: { id: string; data: UpdateProductRequest }) => {
      const response = await apiClient.put<Product>(`/products/${id}`, data);
      return response.data;
    },
    onMutate: async ({ id, data }) => {
      await queryClient.cancelQueries({ queryKey: productKeys.detail(id) });

      const previousProduct = queryClient.getQueryData<Product>(
        productKeys.detail(id)
      );

      if (previousProduct) {
        queryClient.setQueryData<Product>(productKeys.detail(id), {
          ...previousProduct,
          ...data,
        });
      }

      return { previousProduct };
    },
    onError: (err, { id }, context) => {
      if (context?.previousProduct) {
        queryClient.setQueryData(productKeys.detail(id), context.previousProduct);
      }
      toast.error('Failed to update product');
    },
    onSettled: (_, __, { id }) => {
      queryClient.invalidateQueries({ queryKey: productKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: productKeys.lists() });
    },
  });
}

/**
 * Delete a product
 */
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
    onError: () => {
      toast.error('Failed to delete product');
    },
  });
}

// -----------------------------------------------------------------------------
// Prefetch Utility
// -----------------------------------------------------------------------------

/**
 * Prefetch a product (use on hover for better UX)
 */
export function usePrefetchProduct() {
  const queryClient = useQueryClient();

  return (id: string) => {
    queryClient.prefetchQuery({
      queryKey: productKeys.detail(id),
      queryFn: async () => {
        const { data } = await apiClient.get<Product>(`/products/${id}`);
        return data;
      },
      staleTime: 5 * 60 * 1000, // 5 minutes
    });
  };
}