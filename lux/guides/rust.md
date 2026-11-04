# Rust Component Definition Support in Lux

Lux supports defining high-performance native Prisms and Beams in Rust via `Lux.Rust` and the native crate in `priv/rust`.

## Features

1. **Component Definition & Trait System Integration**:
   - Register native `:prism` or `:beam` components with explicit trait contracts (`:prism`, `:beam`, `:async_executor`, `:zero_copy`, `:stateful_lifecycle`).
   - Convert any Rust component into a standard `Lux.Prism` via `Lux.Rust.to_prism/1`.

2. **Async/Await Execution**:
   - Execute Rust components non-blockingly from Elixir via `Lux.Rust.eval_async/2` and `Lux.Rust.await_result/2`.

3. **Performance Optimization & Artifact Caching**:
   - Source hashes (`SHA-256`) are indexed in ETS (`:lux_rust_artifact_cache`) with LTO and `opt-level = 3` release profiles.

4. **Component Lifecycle Management**:
   - Full state tracking across `:registered`, `:initialized`, `:running`, and `:stopped` states via `Lux.Rust.get_component/1` and `Lux.Rust.terminate_component/1`.

## Usage Example

```elixir
require Lux.Rust
import Lux.Rust, only: [sigil_RS: 2]

{:ok, comp} =
  Lux.Rust.define_component(:orderbook_imbalance,
    name: "Orderbook Imbalance Calculator",
    kind: :prism,
    traits: [:prism, :async_executor, :zero_copy],
    source: ~RS"""
    pub async fn handle(input: Value) -> Result<Value, String> {
        Ok(input)
    }
    """
  )

{:ok, prism} = Lux.Rust.to_prism(comp)
task = Lux.Rust.eval_async(:orderbook_imbalance, variables: %{bids: 120.5, asks: 85.0})
{:ok, result} = Lux.Rust.await_result(task)
```
