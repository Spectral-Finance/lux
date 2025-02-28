# Testing Guide

## Overview
The Lux test suite is organized into two main categories:
- **Unit Tests**: Fast, isolated tests that don't require external services
- **Integration Tests**: Tests that interact with external services (e.g., OpenAI, Alchemy)

⚠️ **Important**: Unit and integration tests cannot run simultaneously as they may interfere with each other's configuration. Always run them separately.

## Test Commands

```bash
# Run unit tests only
mix test.unit

# Run integration tests only (requires API keys)
mix test.integration

# Run python tests
mix python.test
```

## Test Organization

- `test/unit/` - Contains all unit tests
- `test/integration/` - Contains all integration tests
- `test/support/` - Shared test helpers and utilities

## Configuration

### Unit Tests
Unit tests use mock configurations and don't require real API keys. The configuration is loaded from:
- `test.envrc` - Base test configuration
- `test.override.envrc` - Local overrides (git-ignored)

### Integration Tests
Integration tests require actual API keys as they interact with external services. To run integration tests:

1. Create a `test.override.envrc` file (if not exists)
2. Add your API keys:
```bash
# test.override.envrc
INTEGRATION_OPENAI_API_KEY="your-openai-key"
ALCHEMY_API_KEY="your-alchemy-key"
# Add other required API keys
```

⚠️ **Security Note**: Never commit real API keys to the repository. Always use the `test.override.envrc` file which is git-ignored.

## Writing Tests

### Unit Tests
```elixir
defmodule MyModuleTest do
  use UnitCase, async: true
  # Your test code
end
```

### Integration Tests
```elixir
defmodule MyIntegrationTest do
  use IntegrationCase, async: true
  # Your test code
end
```

### API Tests
For tests that mock HTTP requests:
```elixir
defmodule MyAPITest do
  use UnitAPICase, async: true
  # Your test code
end
```

## Best Practices

1. **Test Isolation**
   - Keep unit tests independent of external services
   - Use mocks appropriately in unit tests
   - Integration tests should be clearly marked

2. **Configuration Management**
   - Use `test.override.envrc` for sensitive credentials
   - Keep mock data in unit tests realistic but simplified
   - Document any required environment variables

3. **Async Testing**
   - Most tests can run async (use `async: true`)
   - Be cautious with shared resources in integration tests
   - Consider using `async: false` for tests that modify global state

4. **Test Organization**
   - Follow the established directory structure
   - Use appropriate test case modules
   - Group related tests in describe blocks

## Continuous Integration

The CI pipeline:
1. Runs unit tests first
2. Runs integration tests if unit tests pass (TBD, as we didn't add key management in CI yet)
3. Uses secure environment variables for API keys

## Troubleshooting

### Common Issues

1. **Integration Tests Failing**
   - Check if `test.override.envrc` exists with valid API keys
   - Verify external service status
   - Check rate limits

2. **Configuration Conflicts**
   - Ensure you're not running unit and integration tests simultaneously
   - Check for conflicting environment variables

3. **Mock Issues**
   - Verify mock data matches expected format
   - Check if API responses have changed
   - Update mock data as needed

### Getting Help

- Check the test output for specific error messages
- Review the relevant test helper modules
- Consult the external service documentation
- Reach out to the team for assistance 