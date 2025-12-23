/**
 * ProductCard Component
 *
 * Displays a product with name, price, and actions.
 *
 * @example
 * ```tsx
 * <ProductCard
 *   product={product}
 *   onEdit={(id) => navigate(`/products/${id}/edit`)}
 *   onDelete={(id) => deleteProduct(id)}
 * />
 * ```
 */

import { memo } from 'react';
import { Button } from '@/components/ui/Button';
import { Card } from '@/components/ui/Card';
import { formatCurrency } from '@/lib/utils/format';
import type { Product } from '../types/product.types';

// -----------------------------------------------------------------------------
// Types
// -----------------------------------------------------------------------------

type ProductCardProps = {
  /** The product to display */
  product: Product;
  /** Called when edit button is clicked */
  onEdit?: (id: string) => void;
  /** Called when delete button is clicked */
  onDelete?: (id: string) => void;
  /** Whether to show action buttons */
  showActions?: boolean;
  /** Additional CSS classes */
  className?: string;
};

// -----------------------------------------------------------------------------
// Component
// -----------------------------------------------------------------------------

export const ProductCard = memo(function ProductCard({
  product,
  onEdit,
  onDelete,
  showActions = true,
  className = '',
}: ProductCardProps) {
  const handleEdit = () => {
    onEdit?.(product.id);
  };

  const handleDelete = () => {
    onDelete?.(product.id);
  };

  return (
    <Card className={`p-4 ${className}`}>
      {/* Image */}
      {product.imageUrl && (
        <img
          src={product.imageUrl}
          alt={product.name}
          className="w-full h-48 object-cover rounded-md mb-4"
          loading="lazy"
        />
      )}

      {/* Content */}
      <div className="space-y-2">
        <h3 className="text-lg font-semibold text-gray-900">
          {product.name}
        </h3>

        <p className="text-xl font-bold text-blue-600">
          {formatCurrency(product.price)}
        </p>

        {product.description && (
          <p className="text-sm text-gray-600 line-clamp-2">
            {product.description}
          </p>
        )}

        {/* Status Badge */}
        <div className="flex items-center gap-2">
          <span
            className={`inline-flex items-center px-2 py-1 text-xs font-medium rounded-full ${
              product.isActive
                ? 'bg-green-100 text-green-800'
                : 'bg-gray-100 text-gray-800'
            }`}
          >
            {product.isActive ? 'Active' : 'Inactive'}
          </span>
        </div>
      </div>

      {/* Actions */}
      {showActions && (
        <div className="flex gap-2 mt-4 pt-4 border-t">
          <Button
            variant="secondary"
            size="sm"
            onClick={handleEdit}
            aria-label={`Edit ${product.name}`}
          >
            Edit
          </Button>
          <Button
            variant="danger"
            size="sm"
            onClick={handleDelete}
            aria-label={`Delete ${product.name}`}
          >
            Delete
          </Button>
        </div>
      )}
    </Card>
  );
});

// -----------------------------------------------------------------------------
// Default Export (optional, prefer named exports)
// -----------------------------------------------------------------------------

export default ProductCard;