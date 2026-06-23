# Cargo Package Management Integration

`Lux.Cargo` provides a high-level Elixir interface for managing Rust/Cargo packages
and build lifecycle within Lux projects.

## Installation

Cargo is automatically available if you have [Rust](https://rustup.rs) installed.
Run the Mix setup task to verify:

```bash
mix lux.cargo.setup
```

## Usage

### Generating a `Cargo.toml`

```elixir
toml = Lux.Cargo.generate_toml("my_project", [{"serde", "1.0"}, {"tokio", "1"}])
File.write!("priv/rust/my_project/Cargo.toml", toml)
```

### Parsing an existing `Cargo.toml`

```elixir
{:ok, parsed} = Lux.Cargo.read_toml("priv/rust/my_project/Cargo.toml")
IO.inspect(parsed.dependencies)
# => %{"serde" => "1.0", "tokio" => "1"}
```

### Adding a Dependency

```elixir
{:ok, _updated_toml} = Lux.Cargo.add_dependency(
  "priv/rust/my_project/Cargo.toml",
  "anyhow",
  "1.0"
)
```

### Resolving Dependencies

```elixir
{:ok, deps} = Lux.Cargo.resolve_dependencies("priv/rust/my_project/Cargo.toml")
# => [%{name: "serde", version: "1.0", resolved: true}, ...]
```

### Building a Rust Project

```elixir
{:ok, output} = Lux.Cargo.build("priv/rust/my_project")
# => {:ok, "   Compiling my_project v0.1.0 ..."}

# Release build
{:ok, _} = Lux.Cargo.build("priv/rust/my_project", release: true)
```

### Package Caching

```elixir
# Ensure the cache directory exists
{:ok, cache_path} = Lux.Cargo.ensure_cache()

# Set up CARGO_HOME environment variable
env = Lux.Cargo.setup_cache_env()
# => %{"CARGO_HOME" => "/tmp/lux_cargo_cache/cargo_home"}

# Check cache size
{:ok, size_bytes} = Lux.Cargo.cache_size()

# Clear all cached packages
:ok = Lux.Cargo.clear_cache()
```

## Configuration

The cache directory defaults to `<System.tmp_dir!()>/lux_cargo_cache`. It can be
customised by overriding the `CARGO_HOME` env variable in your config.

## Version Management

```elixir
{:ok, cargo_ver} = Lux.Cargo.cargo_version()
# => {:ok, "cargo 1.76.0 (...)"}

{:ok, rustc_ver} = Lux.Cargo.rustc_version()
# => {:ok, "rustc 1.76.0 (...)"}
```
