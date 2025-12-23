/**
 * ProductCard Component Tests
 *
 * Tests for the ProductCard component covering:
 * - Rendering
 * - User interactions
 * - Accessibility
 * - Edge cases
 */

import { render, screen } from '@testing-library/react';
import { userEvent } from '@testing-library/user-event';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ProductCard } from './ProductCard';
import type { Product } from '../types/product.types';

// -----------------------------------------------------------------------------
// Test Data
// -----------------------------------------------------------------------------

const mockProduct: Product = {
  id: '1',
  name: 'Test Product',
  price: 99.99,
  description: 'A great test product',
  isActive: true,
  imageUrl: 'https://example.com/image.jpg',
  createdAt: '2024-01-01T00:00:00Z',
};

// -----------------------------------------------------------------------------
// Test Suite
// -----------------------------------------------------------------------------

describe('ProductCard', () => {
  // ---------------------------------------------------------------------------
  // Rendering Tests
  // ---------------------------------------------------------------------------

  describe('rendering', () => {
    it('renders product name', () => {
      render(<ProductCard product={mockProduct} />);

      expect(screen.getByText('Test Product')).toBeInTheDocument();
    });

    it('renders formatted price', () => {
      render(<ProductCard product={mockProduct} />);

      expect(screen.getByText('$99.99')).toBeInTheDocument();
    });

    it('renders product description', () => {
      render(<ProductCard product={mockProduct} />);

      expect(screen.getByText('A great test product')).toBeInTheDocument();
    });

    it('renders product image with alt text', () => {
      render(<ProductCard product={mockProduct} />);

      const image = screen.getByRole('img', { name: 'Test Product' });
      expect(image).toHaveAttribute('src', mockProduct.imageUrl);
    });

    it('renders active status badge', () => {
      render(<ProductCard product={mockProduct} />);

      expect(screen.getByText('Active')).toBeInTheDocument();
    });

    it('renders inactive status badge', () => {
      const inactiveProduct = { ...mockProduct, isActive: false };
      render(<ProductCard product={inactiveProduct} />);

      expect(screen.getByText('Inactive')).toBeInTheDocument();
    });

    it('renders without image when imageUrl is not provided', () => {
      const productWithoutImage = { ...mockProduct, imageUrl: undefined };
      render(<ProductCard product={productWithoutImage} />);

      expect(screen.queryByRole('img')).not.toBeInTheDocument();
    });

    it('renders without description when not provided', () => {
      const productWithoutDesc = { ...mockProduct, description: undefined };
      render(<ProductCard product={productWithoutDesc} />);

      expect(screen.queryByText('A great test product')).not.toBeInTheDocument();
    });
  });

  // ---------------------------------------------------------------------------
  // Action Button Tests
  // ---------------------------------------------------------------------------

  describe('actions', () => {
    it('renders edit and delete buttons by default', () => {
      render(<ProductCard product={mockProduct} />);

      expect(screen.getByRole('button', { name: /edit/i })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /delete/i })).toBeInTheDocument();
    });

    it('hides action buttons when showActions is false', () => {
      render(<ProductCard product={mockProduct} showActions={false} />);

      expect(screen.queryByRole('button', { name: /edit/i })).not.toBeInTheDocument();
      expect(screen.queryByRole('button', { name: /delete/i })).not.toBeInTheDocument();
    });

    it('calls onEdit with product id when edit is clicked', async () => {
      const handleEdit = vi.fn();
      const user = userEvent.setup();

      render(<ProductCard product={mockProduct} onEdit={handleEdit} />);

      await user.click(screen.getByRole('button', { name: /edit/i }));

      expect(handleEdit).toHaveBeenCalledTimes(1);
      expect(handleEdit).toHaveBeenCalledWith('1');
    });

    it('calls onDelete with product id when delete is clicked', async () => {
      const handleDelete = vi.fn();
      const user = userEvent.setup();

      render(<ProductCard product={mockProduct} onDelete={handleDelete} />);

      await user.click(screen.getByRole('button', { name: /delete/i }));

      expect(handleDelete).toHaveBeenCalledTimes(1);
      expect(handleDelete).toHaveBeenCalledWith('1');
    });

    it('does not throw when clicking edit without handler', async () => {
      const user = userEvent.setup();

      render(<ProductCard product={mockProduct} />);

      // Should not throw
      await user.click(screen.getByRole('button', { name: /edit/i }));
    });
  });

  // ---------------------------------------------------------------------------
  // Accessibility Tests
  // ---------------------------------------------------------------------------

  describe('accessibility', () => {
    it('has accessible name for edit button', () => {
      render(<ProductCard product={mockProduct} />);

      expect(
        screen.getByRole('button', { name: `Edit ${mockProduct.name}` })
      ).toBeInTheDocument();
    });

    it('has accessible name for delete button', () => {
      render(<ProductCard product={mockProduct} />);

      expect(
        screen.getByRole('button', { name: `Delete ${mockProduct.name}` })
      ).toBeInTheDocument();
    });

    it('image has lazy loading', () => {
      render(<ProductCard product={mockProduct} />);

      const image = screen.getByRole('img');
      expect(image).toHaveAttribute('loading', 'lazy');
    });
  });

  // ---------------------------------------------------------------------------
  // Styling Tests
  // ---------------------------------------------------------------------------

  describe('styling', () => {
    it('applies custom className', () => {
      const { container } = render(
        <ProductCard product={mockProduct} className="custom-class" />
      );

      expect(container.firstChild).toHaveClass('custom-class');
    });
  });
});

// -----------------------------------------------------------------------------
// Hook Test Example
// -----------------------------------------------------------------------------

import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useProducts } from './productsApi';
import { apiClient } from '@/lib/api/client';

vi.mock('@/lib/api/client');

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });

  return ({ children }: { children: React.ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
}

describe('useProducts', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('returns products on success', async () => {
    const mockProducts = [mockProduct];
    vi.mocked(apiClient.get).mockResolvedValueOnce({ data: mockProducts });

    const { result } = renderHook(() => useProducts(), {
      wrapper: createWrapper(),
    });

    expect(result.current.isLoading).toBe(true);

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data).toEqual(mockProducts);
  });

  it('returns error on failure', async () => {
    const error = new Error('Network error');
    vi.mocked(apiClient.get).mockRejectedValueOnce(error);

    const { result } = renderHook(() => useProducts(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => expect(result.current.isError).toBe(true));

    expect(result.current.error).toBe(error);
  });

  it('passes filters to API', async () => {
    vi.mocked(apiClient.get).mockResolvedValueOnce({ data: [] });

    const filters = { category: 'electronics', minPrice: 50 };

    renderHook(() => useProducts(filters), {
      wrapper: createWrapper(),
    });

    await waitFor(() => {
      expect(apiClient.get).toHaveBeenCalledWith('/products', {
        params: filters,
      });
    });
  });
});