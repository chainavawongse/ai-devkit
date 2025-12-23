# Form Patterns

Form handling patterns using React Hook Form + Zod for validation.

## Setup

```bash
npm install react-hook-form zod @hookform/resolvers
```

---

## Basic Form Pattern

```typescript
// src/features/auth/components/LoginForm.tsx

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

// 1. Define schema with Zod
const loginSchema = z.object({
  email: z.string().min(1, 'Email is required').email('Invalid email address'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

// 2. Infer TypeScript type from schema
type LoginFormData = z.infer<typeof loginSchema>;

// 3. Create component
export function LoginForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      email: '',
      password: '',
    },
  });

  const onSubmit = async (data: LoginFormData) => {
    // Handle form submission
    console.log(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <div className="mb-4">
        <label htmlFor="email" className="block mb-2 font-medium">
          Email
        </label>
        <input
          id="email"
          type="email"
          {...register('email')}
          className="w-full px-3 py-2 border rounded"
          aria-invalid={!!errors.email}
        />
        {errors.email && (
          <span className="text-red-500 text-sm">{errors.email.message}</span>
        )}
      </div>

      <div className="mb-4">
        <label htmlFor="password" className="block mb-2 font-medium">
          Password
        </label>
        <input
          id="password"
          type="password"
          {...register('password')}
          className="w-full px-3 py-2 border rounded"
          aria-invalid={!!errors.password}
        />
        {errors.password && (
          <span className="text-red-500 text-sm">{errors.password.message}</span>
        )}
      </div>

      <button
        type="submit"
        disabled={isSubmitting}
        className="w-full px-4 py-2 bg-blue-500 text-white rounded disabled:opacity-50"
      >
        {isSubmitting ? 'Logging in...' : 'Log in'}
      </button>
    </form>
  );
}
```

---

## Reusable Form Input Component

```typescript
// src/components/forms/FormInput.tsx

import { forwardRef, InputHTMLAttributes } from 'react';

type FormInputProps = {
  id: string;
  label: string;
  error?: string;
  required?: boolean;
  helperText?: string;
} & InputHTMLAttributes<HTMLInputElement>;

export const FormInput = forwardRef<HTMLInputElement, FormInputProps>(
  ({ id, label, error, required, helperText, ...inputProps }, ref) => {
    const helperId = `${id}-helper`;
    const errorId = `${id}-error`;

    return (
      <div className="mb-4">
        <label htmlFor={id} className="block mb-2 font-medium">
          {label}
          {required && <span className="text-red-500 ml-1">*</span>}
        </label>

        <input
          id={id}
          ref={ref}
          required={required}
          aria-invalid={!!error}
          aria-describedby={error ? errorId : helperText ? helperId : undefined}
          className={`w-full px-3 py-2 border rounded ${
            error ? 'border-red-500' : 'border-gray-300'
          }`}
          {...inputProps}
        />

        {helperText && !error && (
          <p id={helperId} className="mt-1 text-sm text-gray-600">
            {helperText}
          </p>
        )}

        {error && (
          <p id={errorId} role="alert" className="mt-1 text-sm text-red-500">
            {error}
          </p>
        )}
      </div>
    );
  }
);

FormInput.displayName = 'FormInput';
```

### Usage with React Hook Form

```typescript
export function LoginForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<LoginFormData>({
    resolver: zodResolver(loginSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <FormInput
        id="email"
        label="Email"
        type="email"
        required
        error={errors.email?.message}
        {...register('email')}
      />

      <FormInput
        id="password"
        label="Password"
        type="password"
        required
        error={errors.password?.message}
        {...register('password')}
      />

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Logging in...' : 'Log in'}
      </button>
    </form>
  );
}
```

---

## Common Zod Schemas

```typescript
// src/lib/validation/schemas.ts

import { z } from 'zod';

// String validations
export const emailSchema = z.string().min(1, 'Email is required').email('Invalid email');
export const passwordSchema = z.string().min(8, 'Password must be at least 8 characters');
export const requiredString = z.string().min(1, 'This field is required');

// Number validations
export const positiveNumber = z.number().positive('Must be a positive number');
export const priceSchema = z.number().min(0, 'Price must be non-negative');

// Optional with transform
export const optionalString = z.string().optional().or(z.literal(''));

// Date validations
export const futureDateSchema = z.coerce.date().refine(
  (date) => date > new Date(),
  'Date must be in the future'
);

// Custom validations
export const phoneSchema = z.string().regex(
  /^\+?[1-9]\d{1,14}$/,
  'Invalid phone number'
);

// URL validation
export const urlSchema = z.string().url('Invalid URL');

// Password with requirements
export const strongPasswordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .regex(/[A-Z]/, 'Password must contain an uppercase letter')
  .regex(/[a-z]/, 'Password must contain a lowercase letter')
  .regex(/[0-9]/, 'Password must contain a number')
  .regex(/[^A-Za-z0-9]/, 'Password must contain a special character');

// Password confirmation
export const passwordConfirmSchema = z
  .object({
    password: strongPasswordSchema,
    confirmPassword: z.string(),
  })
  .refine((data) => data.password === data.confirmPassword, {
    message: 'Passwords do not match',
    path: ['confirmPassword'],
  });
```

---

## Form with API Integration

```typescript
// src/features/products/components/CreateProductForm.tsx

import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { useNavigate } from 'react-router-dom';
import { useCreateProduct } from '../api/productsApi';
import { FormInput } from '@/components/forms/FormInput';
import { AppError, ErrorType } from '@/types/error.types';

const productSchema = z.object({
  name: z.string().min(1, 'Product name is required'),
  price: z.number().min(0, 'Price must be non-negative'),
  description: z.string().max(500, 'Description must be 500 characters or less').optional(),
  category: z.string().min(1, 'Category is required'),
});

type ProductFormData = z.infer<typeof productSchema>;

export function CreateProductForm() {
  const navigate = useNavigate();
  const createProduct = useCreateProduct();
  
  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm<ProductFormData>({
    resolver: zodResolver(productSchema),
    defaultValues: {
      name: '',
      price: 0,
      description: '',
      category: '',
    },
  });

  const onSubmit = async (data: ProductFormData) => {
    try {
      await createProduct.mutateAsync(data);
      navigate('/products');
    } catch (error) {
      const appError = error as AppError;
      
      // Handle server validation errors
      if (appError.type === ErrorType.VALIDATION && appError.fieldErrors) {
        Object.entries(appError.fieldErrors).forEach(([field, message]) => {
          setError(field as keyof ProductFormData, {
            type: 'server',
            message,
          });
        });
      }
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="max-w-lg">
      <FormInput
        id="name"
        label="Product Name"
        required
        error={errors.name?.message}
        {...register('name')}
      />

      <FormInput
        id="price"
        label="Price"
        type="number"
        step="0.01"
        required
        error={errors.price?.message}
        {...register('price', { valueAsNumber: true })}
      />

      <div className="mb-4">
        <label htmlFor="description" className="block mb-2 font-medium">
          Description
        </label>
        <textarea
          id="description"
          rows={4}
          className="w-full px-3 py-2 border rounded"
          {...register('description')}
        />
        {errors.description && (
          <span className="text-red-500 text-sm">{errors.description.message}</span>
        )}
      </div>

      <div className="mb-4">
        <label htmlFor="category" className="block mb-2 font-medium">
          Category <span className="text-red-500">*</span>
        </label>
        <select
          id="category"
          className="w-full px-3 py-2 border rounded"
          {...register('category')}
        >
          <option value="">Select a category</option>
          <option value="electronics">Electronics</option>
          <option value="clothing">Clothing</option>
          <option value="home">Home & Garden</option>
        </select>
        {errors.category && (
          <span className="text-red-500 text-sm">{errors.category.message}</span>
        )}
      </div>

      <div className="flex gap-4">
        <button
          type="button"
          onClick={() => navigate('/products')}
          className="px-4 py-2 border rounded"
        >
          Cancel
        </button>
        <button
          type="submit"
          disabled={isSubmitting}
          className="px-4 py-2 bg-blue-500 text-white rounded disabled:opacity-50"
        >
          {isSubmitting ? 'Creating...' : 'Create Product'}
        </button>
      </div>
    </form>
  );
}
```

---

## Edit Form (Pre-populated)

```typescript
// src/features/products/components/EditProductForm.tsx

import { useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { useProduct, useUpdateProduct } from '../api/productsApi';

export function EditProductForm({ productId }: { productId: string }) {
  const { data: product, isLoading } = useProduct(productId);
  const updateProduct = useUpdateProduct();
  
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isSubmitting, isDirty },
  } = useForm<ProductFormData>({
    resolver: zodResolver(productSchema),
  });

  // Populate form when data loads
  useEffect(() => {
    if (product) {
      reset({
        name: product.name,
        price: product.price,
        description: product.description ?? '',
        category: product.category,
      });
    }
  }, [product, reset]);

  const onSubmit = async (data: ProductFormData) => {
    await updateProduct.mutateAsync({ id: productId, data });
  };

  if (isLoading) {
    return <div>Loading...</div>;
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {/* Form fields same as CreateProductForm */}
      
      <button type="submit" disabled={isSubmitting || !isDirty}>
        {isSubmitting ? 'Saving...' : 'Save Changes'}
      </button>
    </form>
  );
}
```

---

## Multi-Step Form

```typescript
// src/features/onboarding/components/OnboardingForm.tsx

import { useState } from 'react';
import { useForm, FormProvider } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const step1Schema = z.object({
  firstName: z.string().min(1, 'First name is required'),
  lastName: z.string().min(1, 'Last name is required'),
});

const step2Schema = z.object({
  email: z.string().email('Invalid email'),
  phone: z.string().min(10, 'Invalid phone number'),
});

const step3Schema = z.object({
  company: z.string().min(1, 'Company is required'),
  role: z.string().min(1, 'Role is required'),
});

const fullSchema = step1Schema.merge(step2Schema).merge(step3Schema);

type OnboardingFormData = z.infer<typeof fullSchema>;

const schemas = [step1Schema, step2Schema, step3Schema];

export function OnboardingForm() {
  const [step, setStep] = useState(0);
  
  const methods = useForm<OnboardingFormData>({
    resolver: zodResolver(fullSchema),
    mode: 'onChange',
  });

  const { trigger, handleSubmit, formState: { isSubmitting } } = methods;

  const nextStep = async () => {
    // Validate current step before proceeding
    const fieldsToValidate = Object.keys(schemas[step].shape) as (keyof OnboardingFormData)[];
    const isValid = await trigger(fieldsToValidate);
    
    if (isValid) {
      setStep((prev) => Math.min(prev + 1, schemas.length - 1));
    }
  };

  const prevStep = () => {
    setStep((prev) => Math.max(prev - 1, 0));
  };

  const onSubmit = async (data: OnboardingFormData) => {
    console.log('Final data:', data);
    // Submit to API
  };

  return (
    <FormProvider {...methods}>
      <form onSubmit={handleSubmit(onSubmit)}>
        {/* Progress indicator */}
        <div className="flex mb-8">
          {schemas.map((_, index) => (
            <div
              key={index}
              className={`flex-1 h-2 ${
                index <= step ? 'bg-blue-500' : 'bg-gray-200'
              }`}
            />
          ))}
        </div>

        {/* Step content */}
        {step === 0 && <Step1 />}
        {step === 1 && <Step2 />}
        {step === 2 && <Step3 />}

        {/* Navigation */}
        <div className="flex justify-between mt-8">
          <button
            type="button"
            onClick={prevStep}
            disabled={step === 0}
            className="px-4 py-2 border rounded disabled:opacity-50"
          >
            Previous
          </button>

          {step < schemas.length - 1 ? (
            <button
              type="button"
              onClick={nextStep}
              className="px-4 py-2 bg-blue-500 text-white rounded"
            >
              Next
            </button>
          ) : (
            <button
              type="submit"
              disabled={isSubmitting}
              className="px-4 py-2 bg-green-500 text-white rounded"
            >
              {isSubmitting ? 'Submitting...' : 'Complete'}
            </button>
          )}
        </div>
      </form>
    </FormProvider>
  );
}

// Step components use useFormContext
function Step1() {
  const { register, formState: { errors } } = useFormContext<OnboardingFormData>();
  
  return (
    <div>
      <h2 className="text-xl font-bold mb-4">Personal Information</h2>
      <FormInput
        id="firstName"
        label="First Name"
        error={errors.firstName?.message}
        {...register('firstName')}
      />
      <FormInput
        id="lastName"
        label="Last Name"
        error={errors.lastName?.message}
        {...register('lastName')}
      />
    </div>
  );
}
```

---

## Form with Dynamic Fields

```typescript
// src/features/products/components/ProductVariantsForm.tsx

import { useFieldArray, useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';

const variantSchema = z.object({
  name: z.string().min(1, 'Variant name is required'),
  sku: z.string().min(1, 'SKU is required'),
  price: z.number().min(0, 'Price must be non-negative'),
});

const productWithVariantsSchema = z.object({
  productName: z.string().min(1, 'Product name is required'),
  variants: z.array(variantSchema).min(1, 'At least one variant is required'),
});

type ProductWithVariantsFormData = z.infer<typeof productWithVariantsSchema>;

export function ProductVariantsForm() {
  const {
    register,
    control,
    handleSubmit,
    formState: { errors },
  } = useForm<ProductWithVariantsFormData>({
    resolver: zodResolver(productWithVariantsSchema),
    defaultValues: {
      productName: '',
      variants: [{ name: '', sku: '', price: 0 }],
    },
  });

  const { fields, append, remove } = useFieldArray({
    control,
    name: 'variants',
  });

  const onSubmit = async (data: ProductWithVariantsFormData) => {
    console.log(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <FormInput
        id="productName"
        label="Product Name"
        error={errors.productName?.message}
        {...register('productName')}
      />

      <div className="mt-6">
        <h3 className="font-bold mb-4">Variants</h3>
        
        {fields.map((field, index) => (
          <div key={field.id} className="border p-4 mb-4 rounded">
            <div className="flex justify-between items-center mb-2">
              <span className="font-medium">Variant {index + 1}</span>
              {fields.length > 1 && (
                <button
                  type="button"
                  onClick={() => remove(index)}
                  className="text-red-500"
                >
                  Remove
                </button>
              )}
            </div>
            
            <div className="grid grid-cols-3 gap-4">
              <FormInput
                id={`variants.${index}.name`}
                label="Name"
                error={errors.variants?.[index]?.name?.message}
                {...register(`variants.${index}.name`)}
              />
              <FormInput
                id={`variants.${index}.sku`}
                label="SKU"
                error={errors.variants?.[index]?.sku?.message}
                {...register(`variants.${index}.sku`)}
              />
              <FormInput
                id={`variants.${index}.price`}
                label="Price"
                type="number"
                error={errors.variants?.[index]?.price?.message}
                {...register(`variants.${index}.price`, { valueAsNumber: true })}
              />
            </div>
          </div>
        ))}

        <button
          type="button"
          onClick={() => append({ name: '', sku: '', price: 0 })}
          className="px-4 py-2 border rounded"
        >
          Add Variant
        </button>
      </div>

      <button type="submit" className="mt-6 px-4 py-2 bg-blue-500 text-white rounded">
        Save Product
      </button>
    </form>
  );
}
```

---

## Best Practices

### ✅ DO:

- Use Zod for all form validation
- Infer types from Zod schemas (`z.infer<typeof schema>`)
- Use `noValidate` on forms (rely on Zod, not browser validation)
- Show loading state during submission
- Disable submit button while submitting
- Handle both client and server validation errors
- Use `aria-invalid` and `aria-describedby` for accessibility
- Provide clear error messages

### ❌ DON'T:

- Don't mix validation approaches (pick Zod)
- Don't forget to handle API validation errors
- Don't show raw technical errors to users
- Don't allow double-submission
- Don't forget loading states