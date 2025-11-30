# Component Patterns

Reference patterns for building React components.

## Basic Component Structure

```typescript
/**
 * ProductCard Component
 * 
 * Displays a product with name, price, and actions.
 */

import { memo } from 'react';
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
  const handleEdit = () => onEdit?.(product.id);
  const handleDelete = () => onDelete?.(product.id);

  return (
    <div className={`border rounded-lg p-4 ${className}`}>
      <h3 className="text-lg font-semibold">{product.name}</h3>
      <p className="text-xl font-bold text-blue-600">${product.price}</p>
      
      {product.description && (
        <p className="text-sm text-gray-600">{product.description}</p>
      )}

      {showActions && (
        <div className="flex gap-2 mt-4">
          <button
            onClick={handleEdit}
            aria-label={`Edit ${product.name}`}
            className="px-3 py-1 text-sm border rounded"
          >
            Edit
          </button>
          <button
            onClick={handleDelete}
            aria-label={`Delete ${product.name}`}
            className="px-3 py-1 text-sm bg-red-500 text-white rounded"
          >
            Delete
          </button>
        </div>
      )}
    </div>
  );
});
```

---

## Composition Pattern

```typescript
// Card with composable parts
type CardProps = {
  children: React.ReactNode;
  className?: string;
};

type CardHeaderProps = {
  children: React.ReactNode;
};

type CardBodyProps = {
  children: React.ReactNode;
};

export function Card({ children, className = '' }: CardProps) {
  return (
    <div className={`border rounded-lg shadow-sm ${className}`}>
      {children}
    </div>
  );
}

Card.Header = function CardHeader({ children }: CardHeaderProps) {
  return <div className="px-4 py-3 border-b font-semibold">{children}</div>;
};

Card.Body = function CardBody({ children }: CardBodyProps) {
  return <div className="p-4">{children}</div>;
};

// Usage
<Card>
  <Card.Header>Product Details</Card.Header>
  <Card.Body>
    <p>Product content here</p>
  </Card.Body>
</Card>
```

---

## Render Props Pattern

```typescript
type DataListProps<T> = {
  items: T[];
  isLoading: boolean;
  error: Error | null;
  renderItem: (item: T) => React.ReactNode;
  renderEmpty?: () => React.ReactNode;
  keyExtractor: (item: T) => string;
};

export function DataList<T>({
  items,
  isLoading,
  error,
  renderItem,
  renderEmpty,
  keyExtractor,
}: DataListProps<T>) {
  if (isLoading) {
    return <div>Loading...</div>;
  }

  if (error) {
    return <div className="text-red-500">Error: {error.message}</div>;
  }

  if (items.length === 0) {
    return renderEmpty?.() ?? <div>No items found</div>;
  }

  return (
    <div className="space-y-4">
      {items.map((item) => (
        <div key={keyExtractor(item)}>{renderItem(item)}</div>
      ))}
    </div>
  );
}

// Usage
<DataList
  items={products}
  isLoading={isLoading}
  error={error}
  keyExtractor={(p) => p.id}
  renderItem={(product) => <ProductCard product={product} />}
  renderEmpty={() => <EmptyState message="No products found" />}
/>
```

---

## Controlled vs Uncontrolled

```typescript
// Controlled - parent manages state
type ControlledInputProps = {
  value: string;
  onChange: (value: string) => void;
};

export function ControlledInput({ value, onChange }: ControlledInputProps) {
  return (
    <input
      value={value}
      onChange={(e) => onChange(e.target.value)}
    />
  );
}

// Uncontrolled with ref
export function UncontrolledInput({ defaultValue }: { defaultValue?: string }) {
  const inputRef = useRef<HTMLInputElement>(null);
  
  const getValue = () => inputRef.current?.value ?? '';
  
  return <input ref={inputRef} defaultValue={defaultValue} />;
}

// Hybrid - supports both
type HybridInputProps = {
  value?: string;
  defaultValue?: string;
  onChange?: (value: string) => void;
};

export function HybridInput({ value, defaultValue, onChange }: HybridInputProps) {
  const isControlled = value !== undefined;
  const [internalValue, setInternalValue] = useState(defaultValue ?? '');
  
  const currentValue = isControlled ? value : internalValue;
  
  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = e.target.value;
    if (!isControlled) {
      setInternalValue(newValue);
    }
    onChange?.(newValue);
  };
  
  return <input value={currentValue} onChange={handleChange} />;
}
```

---

## Loading & Error States

```typescript
type AsyncContentProps<T> = {
  isLoading: boolean;
  error: Error | null;
  data: T | undefined;
  children: (data: T) => React.ReactNode;
  loadingFallback?: React.ReactNode;
  errorFallback?: (error: Error) => React.ReactNode;
};

export function AsyncContent<T>({
  isLoading,
  error,
  data,
  children,
  loadingFallback = <div>Loading...</div>,
  errorFallback = (err) => <div>Error: {err.message}</div>,
}: AsyncContentProps<T>) {
  if (isLoading) return <>{loadingFallback}</>;
  if (error) return <>{errorFallback(error)}</>;
  if (!data) return null;
  return <>{children(data)}</>;
}

// Usage
<AsyncContent
  isLoading={isLoading}
  error={error}
  data={product}
  loadingFallback={<ProductSkeleton />}
>
  {(product) => <ProductCard product={product} />}
</AsyncContent>
```

---

## forwardRef Pattern

```typescript
import { forwardRef, InputHTMLAttributes } from 'react';

type InputProps = {
  label: string;
  error?: string;
} & InputHTMLAttributes<HTMLInputElement>;

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, id, ...props }, ref) => {
    const inputId = id ?? label.toLowerCase().replace(/\s/g, '-');
    
    return (
      <div className="mb-4">
        <label htmlFor={inputId} className="block mb-1 font-medium">
          {label}
        </label>
        <input
          ref={ref}
          id={inputId}
          className={`w-full px-3 py-2 border rounded ${
            error ? 'border-red-500' : 'border-gray-300'
          }`}
          aria-invalid={!!error}
          {...props}
        />
        {error && <p className="mt-1 text-sm text-red-500">{error}</p>}
      </div>
    );
  }
);

Input.displayName = 'Input';
```

---

## Container/Presentational Pattern

```typescript
// Container - handles logic and data
export function ProductListContainer() {
  const { data: products, isLoading, error } = useProducts();
  const deleteProduct = useDeleteProduct();
  
  const handleDelete = async (id: string) => {
    if (confirm('Delete this product?')) {
      await deleteProduct.mutateAsync(id);
    }
  };
  
  return (
    <ProductListView
      products={products ?? []}
      isLoading={isLoading}
      error={error}
      onDelete={handleDelete}
    />
  );
}

// Presentational - only renders UI
type ProductListViewProps = {
  products: Product[];
  isLoading: boolean;
  error: Error | null;
  onDelete: (id: string) => void;
};

export function ProductListView({
  products,
  isLoading,
  error,
  onDelete,
}: ProductListViewProps) {
  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  if (products.length === 0) return <EmptyState />;
  
  return (
    <div className="grid grid-cols-3 gap-4">
      {products.map((product) => (
        <ProductCard
          key={product.id}
          product={product}
          onDelete={onDelete}
        />
      ))}
    </div>
  );
}
```

---

## Best Practices

### ✅ DO:

- Use `memo()` for expensive components with stable props
- Define types/interfaces above the component
- Use meaningful prop names with JSDoc comments
- Provide accessible labels for interactive elements
- Export named components (not default when possible)

### ❌ DON'T:

- Don't use `any` type for props
- Don't forget key prop in lists
- Don't inline complex logic in JSX
- Don't skip accessibility attributes
- Don't create deeply nested component hierarchies