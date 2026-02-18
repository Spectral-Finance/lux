# Rust Integration in Lux

Lux provides comprehensive Rust/Cargo integration through the `Lux.Cargo` module, enabling
Cargo package management, dependency resolution, build system integration, version management,
and package caching for Rust projects within the Lux framework.

## Prerequisites

Install the Rust toolchain via [rustup](https://rustup.rs):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

The `mix setup` task automatically checks for Cargo and Rust availability.

## Quick Start

### Evaluating Rust Code

```elixir
# Simple evaluation — creates a temp project, compiles, runs, and cleans up
{:ok, "4"} = Lux.Cargo.eval("fn main() { println!(\"{}\", 2 + 2); }")
```

### Using the ~RUST Sigil

```elixir
require Lux.Cargo
import Lux.Cargo

result = rust do
  ~RUST"""
  fn main() {
      let sum: i32 = (1..=10).sum();
      println!("{}", sum);
  }
  """
end
# => {:ok, "55"}
```

### With Dependencies

```elixir
{:ok, output} = Lux.Cargo.eval("""
use serde_json::json;

fn main() {
    let data = json!({"framework": "Lux", "language": "Rust"});
    println!("{}", data);
}
""", dependencies: %{"serde_json" => "1.0"})
```

## Project Management

### Initializing

```elixir
# Library project
{:ok, path} = Lux.Cargo.init("/tmp/my_lib")

# Binary project
{:ok, path} = Lux.Cargo.init("/tmp/my_app", type: :bin)

# Custom Rust edition
{:ok, path} = Lux.Cargo.init("/tmp/legacy", edition: "2018")
```

### Dependencies

```elixir
:ok = Lux.Cargo.add_dependency(path, "serde", "1.0")
:ok = Lux.Cargo.add_dependency(path, "tokio", "1.0", features: ["full"])
:ok = Lux.Cargo.remove_dependency(path, "serde")
{:ok, _} = Lux.Cargo.update_dependencies(path)
{:ok, deps} = Lux.Cargo.list_dependencies(path)
```

### Cargo.toml

```elixir
# Parse
{:ok, %{name: _, version: _, edition: _, dependencies: _}} = Lux.Cargo.parse_cargo_toml(path)

# Generate
toml = Lux.Cargo.generate_cargo_toml("my_crate", "1.0.0", "2021", %{"serde" => "1.0"})
```

## Build System

```elixir
{:ok, _} = Lux.Cargo.build(path)                        # debug
{:ok, _} = Lux.Cargo.build(path, release: true)         # release
{:ok, _} = Lux.Cargo.build(path, features: ["async"])   # with features
{:ok, _} = Lux.Cargo.test(path)                         # run tests
{:ok, _} = Lux.Cargo.check(path)                        # fast check
```

## Version Management

```elixir
{:ok, %{cargo: _, rustc: _}} = Lux.Cargo.toolchain_version()
{:ok, crates} = Lux.Cargo.search_crate("serde", limit: 5)
{:ok, exists?} = Lux.Cargo.check_crate_version("serde", "1.0.193")
```

## Package Caching

```elixir
{:ok, cache_path} = Lux.Cargo.ensure_cache()
{:ok, bytes} = Lux.Cargo.cache_size()
env = Lux.Cargo.setup_cache_env()    # %{"CARGO_HOME" => "..."}
:ok = Lux.Cargo.clear_cache()
```

## Architecture

The `Lux.Cargo` module wraps the `cargo` CLI tool, executing commands via `System.cmd/3`.
Key design decisions:

- **Package caching**: A shared `CARGO_HOME` under the Lux cache directory avoids
  redundant registry downloads across projects.
- **Eval isolation**: `eval/2` creates temporary Cargo projects with unique names,
  compiles, captures stdout, and cleans up — ensuring no side effects.
- **Graceful degradation**: All functions return `{:error, _}` tuples when Cargo is
  not installed, allowing applications to handle the absence gracefully.
- **Build system integration**: The `mix setup` task checks for Cargo/Rust availability
  as an optional step, keeping the framework usable without Rust.

For detailed API documentation, see `Lux.Cargo` in the HexDocs.
For interactive examples, see the [Rust LiveBook guide](language_support/rust.livemd).
