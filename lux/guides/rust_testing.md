# Rust Testing Framework Integration in Lux

Lux integrates Rust unit, integration, and coverage testing directly with Mix (`mix rust.test`) and `ExUnit` via `Lux.Rust.TestRunner` (`Spectral-Finance/lux#102`).

## Running Rust Tests via Mix

```bash
# Execute all Rust tests in priv/rust
mix rust.test

# Execute a specific Rust test
mix rust.test test_prism_trait_lifecycle

# Run with coverage reporting (via cargo tarpaulin)
mix rust.test --cov
```

## Cross-Language Fixtures and Parity Assertions in ExUnit

```elixir
alias Lux.Rust.TestRunner

{:ok, fixture} = TestRunner.create_fixture(:swap_quote, %{"amount_in" => 1000, "fee_bps" => 30})

{:ok, %{matched: true}} =
  TestRunner.assert_cross_language_parity(
    fn input -> {:ok, input["amount_in"] - 3} end,
    fn input -> {:ok, input["amount_in"] - div(input["amount_in"] * input["fee_bps"], 10_000)} end,
    fixture.payload
  )
```
