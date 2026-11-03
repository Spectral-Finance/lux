# Cargo Package Management Integration Guide

This guide explains how to manage Rust dependencies and build configurations in Lux using Cargo.

---

## 1. Overview & Architecture

Lux provides native integration with the Cargo build tool and package manager for the Rust core runtime in `priv/rust`. This enables agents to dynamically declare dependencies, audit crate versions, trigger native compilation, and optimize package caching.

```
+-----------------------------------------------------------------------+
|                              Lux Agent                                |
+-----------------------------------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | CargoDependencyPipelineBeam               |
             +-------------------------------------------+
               /                 |                     \
              v                  v                      v
    +-------------------+ +-------------------+ +-------------------+
    | AddDependencyPrism| | AuditPrism        | | BuildPrism        |
    | (Update TOML)     | | (Inspect Crates)  | | (Compile Project) |
    +-------------------+ +-------------------+ +-------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.Rust.Cargo                            |
             | - Cargo.toml Parsing & Formatting         |
             | - Dependency Resolution                   |
             | - Cargo Build Invocation                  |
             | - CARGO_HOME Cache Management             |
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | priv/rust/Cargo.toml                      |
             +-------------------------------------------+
```

---

## 2. Programmatic Dependency Management

### Adding a Dependency

Add or update a crate dependency with version and optional feature flags:

```elixir
alias Lux.Rust.Cargo

# Simple version constraint
:ok = Cargo.add_dependency("hex", version: "0.4.3")

# With specific feature flags
:ok = Cargo.add_dependency("tokio", version: "1.38", features: ["full", "sync"])
```

### Listing Declared Dependencies

```elixir
{:ok, deps} = Cargo.list_dependencies()

Enum.each(deps, fn d ->
  IO.puts("#{d.name}: version #{d.version}, features: #{inspect(d.features)}")
end)
```

### Removing a Dependency

```elixir
:ok = Cargo.remove_dependency("hex")
```

---

## 3. Build System Integration

Invoke native compilation with release profiles:

```elixir
alias Lux.Rust.Cargo

{:ok, result} = Cargo.build(release: true)
IO.puts("Build mode: #{result.mode}")
```

---

## 4. Package Caching

Inspect the host's Cargo cache environment:

```elixir
info = Lux.Rust.Cargo.cache_info()
IO.puts("Cargo Home: #{info.cargo_home}")
IO.puts("Registry Cache Exists: #{info.registry_cache_exists}")
```

---

## 5. Dedicated Prisms

### `Lux.Prisms.Languages.Rust.Cargo.AddDependencyPrism`
```elixir
{:ok, res} = Lux.Prisms.Languages.Rust.Cargo.AddDependencyPrism.handler(%{
  "crate" => "sha2",
  "version" => "0.10.8"
}, %{})
```

### `Lux.Prisms.Languages.Rust.Cargo.RemoveDependencyPrism`
```elixir
{:ok, res} = Lux.Prisms.Languages.Rust.Cargo.RemoveDependencyPrism.handler(%{
  "crate" => "sha2"
}, %{})
```

### `Lux.Prisms.Languages.Rust.Cargo.BuildPrism`
```elixir
{:ok, res} = Lux.Prisms.Languages.Rust.Cargo.BuildPrism.handler(%{
  "release" => true
}, %{})
```

### `Lux.Prisms.Languages.Rust.Cargo.AuditPrism`
```elixir
{:ok, res} = Lux.Prisms.Languages.Rust.Cargo.AuditPrism.handler(%{}, %{})
IO.puts("Dependencies found: #{res.dependencies_count}")
```

---

## 6. End-to-End Dependency Pipeline Beam

The `Lux.Beams.Languages.Rust.Cargo.CargoDependencyPipelineBeam` automates the dependency management lifecycle:
1. Adds the requested crate to `Cargo.toml`.
2. Audits dependency declarations.
3. Triggers native Cargo build.
4. Verifies cache status.

```elixir
{:ok, result, log} = Lux.Beams.Languages.Rust.Cargo.CargoDependencyPipelineBeam.run(%{
  crate: "regex",
  version: "1.10",
  release: true
})

IO.puts("Compiled: #{result.compiled}")
```

---

## 7. Testing

Run all Cargo package management unit tests:

```bash
mix test test/unit/lux/languages/cargo_test.exs
mix test test/unit/lux/prisms/languages/cargo_prisms_test.exs
mix test test/unit/lux/beams/languages/cargo_beam_test.exs
```
