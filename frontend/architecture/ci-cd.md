# CI/CD Pipeline

GitHub Actions workflows for continuous integration and deployment.

## Workflow Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Commit    │────▶│   Quality   │────▶│    Build    │────▶│   Deploy    │
│             │     │   Checks    │     │   & Test    │     │             │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                          │                    │                    │
                    ┌─────┴─────┐        ┌─────┴─────┐        ┌─────┴─────┐
                    │ Type Check│        │ Unit Tests│        │  Staging  │
                    │ Lint      │        │ E2E Tests │        │Production │
                    │ Format    │        │ Build     │        │           │
                    └───────────┘        └───────────┘        └───────────┘
```

---

## Main CI Workflow

```yaml
# .github/workflows/ci.yml

name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  NODE_VERSION: '20'

jobs:
  # ─────────────────────────────────────────────────────────────────────────────
  # Quality Checks
  # ─────────────────────────────────────────────────────────────────────────────
  quality:
    name: Quality Checks
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Type check
        run: npm run type-check

      - name: Lint
        run: npm run lint

      - name: Format check
        run: npm run format:check

  # ─────────────────────────────────────────────────────────────────────────────
  # Unit Tests
  # ─────────────────────────────────────────────────────────────────────────────
  test-unit:
    name: Unit Tests
    runs-on: ubuntu-latest
    needs: quality

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run unit tests
        run: npm run test -- --run --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./coverage/lcov.info
          fail_ci_if_error: false

  # ─────────────────────────────────────────────────────────────────────────────
  # Build
  # ─────────────────────────────────────────────────────────────────────────────
  build:
    name: Build
    runs-on: ubuntu-latest
    needs: quality

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build
        env:
          VITE_API_BASE_URL: ${{ vars.VITE_API_BASE_URL }}

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/
          retention-days: 7

  # ─────────────────────────────────────────────────────────────────────────────
  # E2E Tests
  # ─────────────────────────────────────────────────────────────────────────────
  test-e2e:
    name: E2E Tests
    runs-on: ubuntu-latest
    needs: build

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: build
          path: dist/

      - name: Run E2E tests
        run: npm run test:e2e
        env:
          CI: true

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 7
```

---

## Deployment Workflow

```yaml
# .github/workflows/deploy.yml

name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

concurrency:
  group: deploy-${{ github.ref }}
  cancel-in-progress: false

jobs:
  # ─────────────────────────────────────────────────────────────────────────────
  # Deploy to Staging
  # ─────────────────────────────────────────────────────────────────────────────
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || github.event.inputs.environment == 'staging'
    environment:
      name: staging
      url: https://staging.example.com

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build for staging
        run: npm run build
        env:
          VITE_API_BASE_URL: ${{ vars.VITE_API_BASE_URL }}
          VITE_ENABLE_ANALYTICS: 'false'

      # Example: Deploy to Vercel
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: ./dist

      # Example: Deploy to AWS S3 + CloudFront
      # - name: Configure AWS credentials
      #   uses: aws-actions/configure-aws-credentials@v4
      #   with:
      #     aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
      #     aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      #     aws-region: us-east-1
      #
      # - name: Deploy to S3
      #   run: aws s3 sync dist/ s3://${{ vars.S3_BUCKET_STAGING }} --delete
      #
      # - name: Invalidate CloudFront
      #   run: aws cloudfront create-invalidation --distribution-id ${{ vars.CF_DISTRIBUTION_STAGING }} --paths "/*"

  # ─────────────────────────────────────────────────────────────────────────────
  # Deploy to Production
  # ─────────────────────────────────────────────────────────────────────────────
  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: deploy-staging
    if: github.event.inputs.environment == 'production'
    environment:
      name: production
      url: https://example.com

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build for production
        run: npm run build
        env:
          VITE_API_BASE_URL: ${{ vars.VITE_API_BASE_URL }}
          VITE_ENABLE_ANALYTICS: 'true'

      - name: Deploy to Vercel (Production)
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
          working-directory: ./dist
```

---

## PR Preview Deployments

```yaml
# .github/workflows/preview.yml

name: Preview

on:
  pull_request:
    types: [opened, synchronize, reopened]

concurrency:
  group: preview-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  deploy-preview:
    name: Deploy Preview
    runs-on: ubuntu-latest
    environment:
      name: preview
      url: ${{ steps.deploy.outputs.url }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build
        env:
          VITE_API_BASE_URL: ${{ vars.VITE_API_BASE_URL_PREVIEW }}

      - name: Deploy Preview
        id: deploy
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: ./dist

      - name: Comment PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## 🚀 Preview Deployment\n\n✅ Deployed to: ${{ steps.deploy.outputs.url }}`
            })
```

---

## Required Secrets & Variables

### Repository Secrets

```bash
# Vercel (if using Vercel)
VERCEL_TOKEN=xxx
VERCEL_ORG_ID=xxx
VERCEL_PROJECT_ID=xxx

# AWS (if using S3/CloudFront)
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx

# Code coverage (optional)
CODECOV_TOKEN=xxx
```

### Environment Variables

Configure in GitHub Settings → Environments:

```bash
# Staging environment
VITE_API_BASE_URL=https://api-staging.example.com

# Production environment
VITE_API_BASE_URL=https://api.example.com
```

---

## Branch Protection Rules

Configure in GitHub Settings → Branches → Add rule:

### Main Branch

```
Branch name pattern: main

☑ Require a pull request before merging
  ☑ Require approvals: 1
  ☑ Dismiss stale pull request approvals when new commits are pushed

☑ Require status checks to pass before merging
  ☑ Require branches to be up to date before merging
  Required checks:
    - Quality Checks
    - Unit Tests
    - Build
    - E2E Tests

☑ Require conversation resolution before merging

☐ Do not allow bypassing the above settings
```

---

## Workflow Triggers Summary

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| CI | Push to main/develop, PRs | Quality gates |
| Deploy | Push to main, manual | Staging/production deployment |
| Preview | PR opened/updated | PR preview environments |

---

## Local CI Simulation

Run the same checks locally before pushing:

```bash
# Run all checks (mirrors CI)
npm run check

# Or individually
npm run type-check
npm run lint
npm run format:check
npm run test -- --run
npm run build
```

---

## Caching Strategy

The workflows use npm caching via `actions/setup-node`:

```yaml
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'  # Caches ~/.npm based on package-lock.json
```

For Playwright browsers (E2E):

```yaml
- name: Cache Playwright browsers
  uses: actions/cache@v4
  with:
    path: ~/.cache/ms-playwright
    key: playwright-${{ runner.os }}-${{ hashFiles('package-lock.json') }}

- name: Install Playwright browsers
  run: npx playwright install --with-deps chromium
```

---

## Troubleshooting

### Build Fails on CI but Works Locally

```bash
# Ensure dependencies match exactly
rm -rf node_modules package-lock.json
npm install
npm run build
```

### E2E Tests Flaky

```yaml
# Add retries in playwright.config.ts
retries: process.env.CI ? 2 : 0,

# Run with more workers locally, fewer in CI
workers: process.env.CI ? 1 : undefined,
```

### Environment Variables Missing

```bash
# Check variable is set in GitHub environment
# Settings → Environments → [env] → Environment variables

# Use vars. for non-secret values
env:
  VITE_API_BASE_URL: ${{ vars.VITE_API_BASE_URL }}

# Use secrets. for sensitive values
env:
  API_KEY: ${{ secrets.API_KEY }}
```
