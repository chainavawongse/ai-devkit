/**
 * Custom Hooks Reference
 * 
 * This file contains reference implementations for common custom hooks.
 * Copy and adapt these patterns for your own hooks.
 */

import { useEffect, useState, useCallback, useRef } from 'react';

// =============================================================================
// useDebounce
// =============================================================================

/**
 * Debounces a value by the specified delay.
 * Useful for search inputs or expensive operations.
 *
 * @param value - The value to debounce
 * @param delay - Delay in milliseconds (default: 500ms)
 * @returns The debounced value
 *
 * @example
 * ```tsx
 * const [search, setSearch] = useState('');
 * const debouncedSearch = useDebounce(search, 300);
 *
 * // API call only fires 300ms after user stops typing
 * const { data } = useProducts({ search: debouncedSearch });
 * ```
 */
export function useDebounce<T>(value: T, delay = 500): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
}

// =============================================================================
// useThrottle
// =============================================================================

/**
 * Throttles a value, updating at most once per specified interval.
 * Useful for scroll handlers or resize events.
 *
 * @param value - The value to throttle
 * @param limit - Minimum time between updates in ms (default: 500ms)
 * @returns The throttled value
 *
 * @example
 * ```tsx
 * const [scrollY, setScrollY] = useState(0);
 * const throttledScrollY = useThrottle(scrollY, 100);
 * ```
 */
export function useThrottle<T>(value: T, limit = 500): T {
  const [throttledValue, setThrottledValue] = useState<T>(value);
  const lastRan = useRef(Date.now());

  useEffect(() => {
    const handler = setTimeout(() => {
      if (Date.now() - lastRan.current >= limit) {
        setThrottledValue(value);
        lastRan.current = Date.now();
      }
    }, limit - (Date.now() - lastRan.current));

    return () => {
      clearTimeout(handler);
    };
  }, [value, limit]);

  return throttledValue;
}

// =============================================================================
// useLocalStorage
// =============================================================================

/**
 * Syncs state with localStorage.
 *
 * @param key - localStorage key
 * @param initialValue - Initial value if key doesn't exist
 * @returns Tuple of [value, setValue]
 *
 * @example
 * ```tsx
 * const [theme, setTheme] = useLocalStorage('theme', 'light');
 * ```
 */
export function useLocalStorage<T>(
  key: string,
  initialValue: T
): [T, (value: T | ((val: T) => T)) => void] {
  const [storedValue, setStoredValue] = useState<T>(() => {
    if (typeof window === 'undefined') {
      return initialValue;
    }

    try {
      const item = window.localStorage.getItem(key);
      return item ? (JSON.parse(item) as T) : initialValue;
    } catch (error) {
      console.error(`Error reading localStorage key "${key}":`, error);
      return initialValue;
    }
  });

  const setValue = (value: T | ((val: T) => T)) => {
    try {
      const valueToStore = value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);

      if (typeof window !== 'undefined') {
        window.localStorage.setItem(key, JSON.stringify(valueToStore));
      }
    } catch (error) {
      console.error(`Error setting localStorage key "${key}":`, error);
    }
  };

  return [storedValue, setValue];
}

// =============================================================================
// useMediaQuery
// =============================================================================

/**
 * Returns true if the media query matches.
 *
 * @param query - CSS media query string
 * @returns Whether the media query matches
 *
 * @example
 * ```tsx
 * const isMobile = useMediaQuery('(max-width: 768px)');
 * const prefersDark = useMediaQuery('(prefers-color-scheme: dark)');
 * ```
 */
export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(() => {
    if (typeof window === 'undefined') {
      return false;
    }
    return window.matchMedia(query).matches;
  });

  useEffect(() => {
    const mediaQuery = window.matchMedia(query);

    const handleChange = (event: MediaQueryListEvent) => {
      setMatches(event.matches);
    };

    mediaQuery.addEventListener('change', handleChange);
    return () => mediaQuery.removeEventListener('change', handleChange);
  }, [query]);

  return matches;
}

// =============================================================================
// usePrefersReducedMotion
// =============================================================================

/**
 * Returns true if user prefers reduced motion.
 *
 * @returns Whether user prefers reduced motion
 *
 * @example
 * ```tsx
 * const prefersReducedMotion = usePrefersReducedMotion();
 *
 * <div className={prefersReducedMotion ? '' : 'animate-fade-in'}>
 *   Content
 * </div>
 * ```
 */
export function usePrefersReducedMotion(): boolean {
  return useMediaQuery('(prefers-reduced-motion: reduce)');
}

// =============================================================================
// useToggle
// =============================================================================

/**
 * Simple boolean toggle.
 *
 * @param initialValue - Initial boolean value (default: false)
 * @returns Tuple of [value, toggle, setValue]
 *
 * @example
 * ```tsx
 * const [isOpen, toggle, setIsOpen] = useToggle(false);
 *
 * <button onClick={toggle}>Toggle</button>
 * <button onClick={() => setIsOpen(true)}>Open</button>
 * ```
 */
export function useToggle(
  initialValue = false
): [boolean, () => void, (value: boolean) => void] {
  const [value, setValue] = useState(initialValue);

  const toggle = useCallback(() => setValue((prev) => !prev), []);

  return [value, toggle, setValue];
}

// =============================================================================
// useClickOutside
// =============================================================================

/**
 * Calls handler when clicking outside of the ref element.
 * Useful for dropdowns, modals, etc.
 *
 * @param ref - React ref to the element
 * @param handler - Function to call on outside click
 *
 * @example
 * ```tsx
 * const dropdownRef = useRef<HTMLDivElement>(null);
 * useClickOutside(dropdownRef, () => setIsOpen(false));
 *
 * return <div ref={dropdownRef}>Dropdown content</div>;
 * ```
 */
export function useClickOutside<T extends HTMLElement>(
  ref: React.RefObject<T>,
  handler: () => void
): void {
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        handler();
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [ref, handler]);
}

// =============================================================================
// usePrevious
// =============================================================================

/**
 * Returns the previous value of a variable.
 *
 * @param value - The current value
 * @returns The previous value
 *
 * @example
 * ```tsx
 * const [count, setCount] = useState(0);
 * const prevCount = usePrevious(count);
 *
 * // prevCount shows the value before the last render
 * ```
 */
export function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T>();

  useEffect(() => {
    ref.current = value;
  }, [value]);

  return ref.current;
}

// =============================================================================
// useInterval
// =============================================================================

/**
 * Sets up an interval that properly cleans up.
 *
 * @param callback - Function to call on each interval
 * @param delay - Delay in ms (null to pause)
 *
 * @example
 * ```tsx
 * const [count, setCount] = useState(0);
 *
 * useInterval(() => {
 *   setCount(count + 1);
 * }, 1000); // Increment every second
 * ```
 */
export function useInterval(callback: () => void, delay: number | null): void {
  const savedCallback = useRef(callback);

  useEffect(() => {
    savedCallback.current = callback;
  }, [callback]);

  useEffect(() => {
    if (delay === null) {
      return;
    }

    const id = setInterval(() => savedCallback.current(), delay);
    return () => clearInterval(id);
  }, [delay]);
}

// =============================================================================
// useAsync
// =============================================================================

type AsyncState<T> = {
  data: T | null;
  isLoading: boolean;
  error: Error | null;
};

/**
 * Manages async operation state.
 *
 * @param asyncFunction - Async function to execute
 * @param immediate - Whether to run immediately (default: true)
 * @returns State object and execute function
 *
 * @example
 * ```tsx
 * const { data, isLoading, error, execute } = useAsync(
 *   () => fetchUser(userId),
 *   true
 * );
 * ```
 */
export function useAsync<T>(
  asyncFunction: () => Promise<T>,
  immediate = true
): AsyncState<T> & { execute: () => Promise<void> } {
  const [state, setState] = useState<AsyncState<T>>({
    data: null,
    isLoading: immediate,
    error: null,
  });

  const execute = useCallback(async () => {
    setState({ data: null, isLoading: true, error: null });

    try {
      const data = await asyncFunction();
      setState({ data, isLoading: false, error: null });
    } catch (error) {
      setState({ data: null, isLoading: false, error: error as Error });
    }
  }, [asyncFunction]);

  useEffect(() => {
    if (immediate) {
      execute();
    }
  }, [execute, immediate]);

  return { ...state, execute };
}