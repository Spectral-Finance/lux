# Rust Testing Framework Integration Guide

This guide explains the native Rust testing framework in Lux, enabling seamless execution of Cargo tests, integration with Mix, cross-language assertion helpers, and coverage metrics.

---

## 1. Overview & Architecture

Testing native Rust code requires bridging Cargo's test runner with Elixir's ExUnit infrastructure. Lux provides a unified test runner, Mix task, assertion macros, and test pipeline beams.

```
+-----------------------------------------------------------------------+
|                              Lux Agent                                |
+-----------------------------------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | RustTestSuiteBeam                         |
             +-------------------------------------------+
               /                 |                     \
              v                  v                      v
    +-------------------+ +-------------------+ +-------------------+
    | FixturePrism      | | RunTestsPrism     | | CoveragePrism     |
    | (Test Datasets)   | | (Cargo Test Run)  | | (Pass/Fail Stats) |
    +-------------------+ +-------------------+ +-------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.Rust.Testing.Runner                   |
             | - Cargo Test Invocation                   |
             | - Test Output Regex Parser                |
             | - TestReport Generation                   |
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Cargo Test Harness (priv/rust)            |
             |  cargo test -- --nocapture                |
             +-------------------------------------------+
```

---

## 2. Running Tests from Mix

Execute all native Rust tests directly from your terminal:

```bash
# Run all native Rust tests
mix lux.test.rust

# Filter tests by module or function name
mix lux.test.rust --filter math
```

---

## 3. Cross-Language ExUnit Assertions

Use `Lux.Rust.Testing.Case` in your ExUnit test suites:

```elixir
defmodule MyApp.RustIntegrationTest do
  use Lux.Rust.Testing.Case

  test "calculates fibonacci correctly" do
    assert_rust_call("math.fibonacci", %{"n" => 10}, 55)
  end

  test "verifies argument validation errors" do
    assert_rust_error("math.fibonacci", %{"n" => -1}, :invalid_argument)
  end
end
```

---

## 4. Programmatic Test Runner

Run tests programmatically in agents or CI/CD pipelines:

```elixir
alias Lux.Rust.Testing.Runner

{:ok, report} = Runner.run_tests()

IO.puts("Tests Passed: #{report.passed}")
IO.puts("Tests Failed: #{report.failed}")
IO.puts("Suite Status: #{if report.success, do: "SUCCESS", else: "FAILURE"}")
```

---

## 5. Dedicated Prisms

- `Lux.Prisms.Languages.Rust.Testing.RunTestsPrism`: Executes Cargo tests and returns structured report.
- `Lux.Prisms.Languages.Rust.Testing.CoveragePrism`: Evaluates test pass ratios against configurable thresholds.
- `Lux.Prisms.Languages.Rust.Testing.FixturePrism`: Generates test fixtures (vectors, matrices, cryptographic keys).
- `Lux.Prisms.Languages.Rust.Testing.AssertPrism`: Evaluates assertions against native Rust functions.
- `Lux.Prisms.Languages.Rust.Testing.BenchmarkRunnerPrism`: Runs microbenchmarks across multiple iterations.

---

## 6. End-to-End Test Suite Beam

The `Lux.Beams.Languages.Rust.Testing.RustTestSuiteBeam` automates test setup, execution, and coverage analysis:

```elixir
{:ok, result, log} = Lux.Beams.Languages.Rust.Testing.RustTestSuiteBeam.run(%{
  fixture_name: "vectors",
  size: 10
})

IO.puts("Test Suite Passed: #{result.success}")
IO.puts("Coverage: #{result.coverage_percentage}%")
```

---

## 7. Testing

Run all Rust testing framework unit tests:

```bash
mix test test/unit/lux/languages/rust_testing_test.exs
mix test test/unit/lux/prisms/languages/rust_testing_prisms_test.exs
mix test test/unit/lux/beams/languages/rust_testing_beam_test.exs
```
