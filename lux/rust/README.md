# Lux Rust Testing Framework

A comprehensive testing framework for Rust code within the Lux multi-agent framework.

## Overview

This module provides:

- **Rust Test Runner** - Custom test runner for Lux Rust components
- **Mix Integration** - Seamless integration with `mix test`
- **Coverage Reporting** - Comprehensive coverage tracking and reporting
- **Cross-Language Utilities** - Test utilities for Elixir/Python/Rust integration
- **Fixtures and Helpers** - Reusable test fixtures and assertion helpers

## Installation

1. Ensure Rust is installed:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. Build the Rust project:
   ```bash
   cd lux/priv/python/rust
   cargo build
   ```

## Usage

### Running Tests

```bash
# Run all tests
cargo test

# Run with coverage
cargo test -- --nocapture --coverage

# Run specific test
cargo test test_name
```

### Mix Integration

```bash
# From the lux directory
mix rust.test

# With coverage
mix rust.test --coverage
```

### Elixir Integration

```elixir
# Run Rust tests from Elixir
{:ok, results} = Lux.RustTest.run_rust_tests()

# Run with coverage
{:ok, report} = Lux.RustTest.coverage_report()
```

## Test Structure

```
lux/priv/python/rust/
├── src/
│   ├── lib.rs              # Main library
│   ├── test_framework.rs   # Test runner and assertions
│   ├── fixtures.rs         # Test fixtures and helpers
│   ├── coverage.rs         # Coverage tracking
│   └── runner.rs           # CLI test runner
├── tests/
│   ├── integration_tests.rs # Integration tests
│   └── examples_tests.rs    # Example tests
├── Cargo.toml              # Rust dependencies
└── docs/
    └── README.md           # This file
```

## Writing Tests

### Basic Test

```rust
use lux_rs::*;

#[test]
fn my_test() {
    assert_eq!(1 + 1, 2);
}
```

### With Custom Runner

```rust
use lux_rs::*;

#[test]
fn test_with_runner() {
    let mut runner = LuxTestRunner::new(TestSuiteConfig::default());
    let result = runner.run_test("my_test", || {
        // Test logic
        Ok(())
    });
    
    assert!(result.passed);
}
```

### Using Fixtures

```rust
use lux_rs::*;

#[test]
fn test_with_fixtures() {
    let config = sample_agent_config();
    let message = sample_message();
    
    // Use fixtures in tests
    assert!(!config.id.is_empty());
}
```

## Coverage

Coverage reports are generated in JSON format:

```bash
cargo test -- --coverage
cat target/coverage.json
```

Example output:
```json
{
  "total_lines": 100,
  "covered_lines": 85,
  "coverage_percentage": 85.0,
  "file_coverage": {
    "src/lib.rs": {
      "coverage_percentage": 90.0,
      "covered_lines": 45,
      "total_lines": 50
    }
  }
}
```

## Integration with Elixir Tests

Rust tests can be run alongside Elixir tests:

```elixir
# In your test setup
ExUnit.after_spawn(fn ->
  {:ok, _} = Lux.RustTest.run_rust_tests()
end)
```

## License

MIT
