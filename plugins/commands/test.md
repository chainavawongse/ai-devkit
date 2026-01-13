---
description: Run project tests using just command abstraction with language-specific fallbacks
---

# Run Tests

Run the appropriate tests for this project, preferring `just test` for consistency with the plugin workflows.

## Usage

```bash
/test                # Run all tests
/test --coverage     # Run with coverage report
/test <path>         # Run tests for specific file/directory
/test --watch        # Run in watch mode (if supported)
```

## Process

### Step 1: Check for Just Command (Preferred)

```bash
# Check if justfile exists
if [ -f justfile ] || [ -f Justfile ]; then
    just test
    exit $?
fi
```

**Why just?** plugin uses `just` commands to make workflows stack-agnostic. All verification uses the same interface regardless of language.

### Step 2: Detect Project Type (Fallback)

If no justfile, detect and run appropriate command:

| Project Type | Detection | Command |
|--------------|-----------|---------|
| Node.js | `package.json` | `npm test` or `yarn test` or `bun test` |
| Python | `pyproject.toml`, `setup.py`, `requirements.txt` | `pytest` or `python -m pytest` |
| .NET | `*.csproj`, `*.sln` | `dotnet test` |
| Ruby | `Gemfile` | `bundle exec rspec` or `rake test` |
| Go | `go.mod` | `go test ./...` |
| Rust | `Cargo.toml` | `cargo test` |
| Make | `Makefile` | `make test` |

### Step 3: Run Tests

```bash
# Execute detected command
# Capture exit code
# Parse output for failures
```

### Step 4: Report Results

**On Success:**

```
All tests passed (42 tests in 3.2s)
```

**On Failure:**

```
Test Failures

Failed tests:
- test_user_authentication (tests/auth_test.py:45)
  AssertionError: Expected status 200, got 401

- test_payment_processing (tests/payment_test.py:89)
  TimeoutError: Database connection timed out

Files to examine:
- src/auth/handler.py
- src/payment/processor.py

Next steps:
1. Review failed test output above
2. Check related source files
3. Run individual test: pytest tests/auth_test.py::test_user_authentication -v
```

## Coverage Mode

When `--coverage` is specified:

```bash
# Just command
just test-coverage

# Or fallback by language
# Node.js
npm run test:coverage

# Python
pytest --cov=src --cov-report=html

# .NET
dotnet test --collect:"XPlat Code Coverage"

# Go
go test -cover ./...
```

## Watch Mode

When `--watch` is specified:

```bash
# Node.js
npm test -- --watch

# Python (pytest-watch)
ptw

# .NET
dotnet watch test
```

## Integration with the plugin

**Used by skills:**

- `test-driven-development` - RED-GREEN-REFACTOR cycle
- `executing-tasks` - Verification after implementation
- `executing-chores` - Verification-only workflows
- `executing-bug-fixes` - Reproduction and fix verification

**Expected just recipes:**

```justfile
# Minimal test recipe
test:
    npm test  # or pytest, dotnet test, etc.

# With coverage
test-coverage:
    npm run test:coverage
```

## Best Practices

- Always run tests before committing
- Fix failing tests before adding new ones
- Use `--coverage` periodically to check coverage
- Run full suite before PRs, subset during development
- Check both unit and integration tests

## Troubleshooting

**No test command found:**

```
No test command detected.

Checked:
- justfile (not found)
- package.json scripts.test (not found)
- pytest.ini (not found)
- *.csproj (not found)

Please configure a test command or create a justfile with a `test` recipe.
```

**Tests timing out:**

```bash
# Increase timeout
just test --timeout 120

# Or for specific runners
pytest --timeout=120
npm test -- --testTimeout=120000
```
