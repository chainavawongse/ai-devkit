# React/TypeScript frontend justfile
# Package manager: yarn

# Show available commands
default:
    @just --list

# Install dependencies
install:
    yarn install

# Format code
format:
    yarn prettier --write "src/**/*.{ts,tsx,js,jsx,json,css,md}"

# Lint code
lint:
    yarn eslint src/ --ext .ts,.tsx,.js,.jsx
    yarn tsc --noEmit

# Fix linting issues
lint-fix:
    yarn eslint src/ --ext .ts,.tsx,.js,.jsx --fix

# Run unit tests (optionally specify path)
test PATH="":
    yarn jest {{PATH}}

# Run integration tests
test-integration:
    yarn jest tests/integration/

# Run E2E tests with Playwright
test-e2e:
    yarn playwright test

# Run all tests
test-full:
    yarn jest && yarn playwright test

# Run tests in watch mode
test-watch:
    yarn jest --watch

# Build for production
build: lint test
    yarn build

# Run development server
dev:
    yarn start

# Type check
typecheck:
    yarn tsc --noEmit

# Clean build artifacts
clean:
    rm -rf dist/ build/ node_modules/.cache/ coverage/
