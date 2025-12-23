# .NET/C# module justfile
# Uses dotnet CLI commands

# Show available commands
default:
    @just --list

# Restore dependencies
install:
    dotnet restore

# Format code
format:
    dotnet format

# Lint/analyze code
lint:
    dotnet format --verify-no-changes
    dotnet build --no-restore -warnaserror

# Run unit tests (optionally specify project or filter)
test FILTER="":
    dotnet test --no-build --verbosity normal {{FILTER}}

# Run integration tests
test-integration:
    dotnet test --no-build --filter "Category=Integration"

# Run all tests with coverage
test-full:
    dotnet test --no-build --collect:"XPlat Code Coverage" --results-directory ./coverage

# Run tests in watch mode
test-watch:
    dotnet watch test

# Build for debug
build:
    dotnet build

# Build for release
build-release: lint test
    dotnet build --configuration Release

# Publish for deployment
publish:
    dotnet publish --configuration Release --output ./publish

# Run the application
run:
    dotnet run

# Run with watch (hot reload)
dev:
    dotnet watch run

# Clean build artifacts
clean:
    dotnet clean
    rm -rf bin/ obj/ publish/ coverage/ TestResults/

# Add EF Core migration
ef-add NAME:
    dotnet ef migrations add {{NAME}}

# Apply EF Core migrations
ef-update:
    dotnet ef database update

# Generate EF Core migration script
ef-script:
    dotnet ef migrations script --idempotent --output ./migrations.sql
