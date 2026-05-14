# Rust Testing in Lux

Lux includes a cargo-backed test runner for Rust projects. It is designed to work with the default `priv/rust` project path, while also supporting custom project paths for fixtures and generated projects.

## Run Rust Tests

```bash
mix rust.test
mix rust.test --project-path priv/rust
mix rust.test --filter conversion --verbose
```

The runner shells out to `cargo test`, parses cargo's result summary, and returns a compact result map:

```elixir
Lux.Rust.TestRunner.run(project_path: "priv/rust")
```

## Test Fixtures

Use `Lux.Rust.TestFixtures.with_temp_project/2` to create an isolated Rust library project for cross-language tests:

```elixir
Lux.Rust.TestFixtures.with_temp_project(fn project_path ->
  assert {:ok, result} = Lux.Rust.TestRunner.run(project_path: project_path)
  assert result.passed == 1
end)
```

## Coverage

`mix rust.test.coverage` prints a grcov command plan and the required instrumentation environment:

```bash
mix rust.test.coverage --project-path priv/rust --output cover/rust/lcov.info
```

Coverage generation is explicit because developer machines and CI images may not have `grcov` installed. The command plan can be copied into CI once the Rust project and coverage tooling are available.
