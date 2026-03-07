# Rust Integration Guide

Lux provides high-performance integration with Rust using the `~RUST` sigil and a robust type system.

## Performance Optimization

Unlike other integrations that use JSON, Lux uses **Erlang Term Format (ETF)** for Rust communication. This provides:
1. **Lower Latency**: No overhead for JSON encoding/decoding.
2. **Type Safety**: Seamless mapping between Elixir atoms/maps and Rust structs/enums.

## Type System

You can define the expected structure for data exchange:

```elixir
alias Lux.Rust.Type

schema = {:struct, [
  id: :i64,
  name: :string,
  active: :bool
]}

# Validate data before calling Rust
Type.valid?(%{id: 1, name: "Agent 1", active: true}, schema) # => true
```

## Inline Rust Example

```elixir
defmodule MyAgent do
  require Lux.Rust

  def execute_fast(data) do
    Lux.Rust.python variables: %{input: data} do
      ~RUST'''
      fn main(input: Term) -> Result<Term, Error> {
          // Process input natively
          Ok(input)
      }
      '''
    end
  end
end
```

## Advanced Serialization

Implement the `Lux.Rust.Serializable` protocol for your domain objects:

```elixir
defimpl Lux.Rust.Serializable, for: MyApp.CustomAgent do
  def rust_type(_), do: {:struct, [id: :string, memory: :map]}
  def encode(data), do: Map.take(data, [:id, :memory])
end
```
