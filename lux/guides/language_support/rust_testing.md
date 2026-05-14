# Rust Testing Support

Lux can run Rust tests from Mix while keeping the Elixir side testable without
requiring a Rust toolchain.

## Run Rust tests

```bash
mix rust.test
mix rust.test --project-root priv/rust
mix rust.test parser --no-capture
mix rust.test --coverage --coverage-output cover/rust
```

`mix test.rust` is an alias for `mix rust.test`.

## Build a test plan

```elixir
plan =
  Lux.Rust.build_test_plan("priv/rust",
    filter: "normalizes_labels",
    no_capture: true,
    coverage: true
  )

plan.command
plan.args
plan.env
```

The plan is pure data, so CI systems and agents can inspect the command before
executing it.

## Integrate with `mix test`

Rust tests are opt-in during ExUnit runs. Add this to `test/test_helper.exs`
when the Rust crate is required for the test suite:

```elixir
Lux.Rust.TestRunner.install_ex_unit_hook(project_root: "priv/rust")
```

Keeping the hook opt-in prevents contributors without Rust installed from
breaking ordinary Elixir unit tests.

## Fixtures

Use `Lux.Rust.Fixtures` to write files shared by Elixir and Rust tests:

```elixir
Lux.Rust.Fixtures.write_manifest!("tmp/rust-fixtures", %{
  "payloads/message.json" => Jason.encode!(%{text: "hello"})
})
```

The generated manifest records each file path, byte size, and SHA-256 hash.
Rust tests can read those files directly and compare against the manifest.

## Coverage

`mix rust.test --coverage` sets LLVM coverage environment variables:

- `CARGO_INCREMENTAL=0`
- `RUSTFLAGS=-Cinstrument-coverage`
- `LLVM_PROFILE_FILE=cover/rust/lux-rust-%p-%m.profraw`

After generating LCOV output with your preferred tool, parse it with:

```elixir
File.read!("cover/rust/lcov.info")
|> Lux.Rust.parse_lcov()
```
