# Rust Component Definition Support in Lux

Lux provides high-performance native component authoring in Rust, allowing developers to implement compute-intensive Prisms and Beams with near zero-cost abstractions, memory safety, and native concurrency.

---

## 1. Core Architecture

Rust components in Lux bridge native Rust traits to the Elixir runtime via high-performance Erlang Port / NIF interfaces. Components implement standard trait definitions and register themselves into a shared component registry.

```
+-----------------------------------------------------------+
|                     Elixir Runtime                        |
|                                                           |
|   +-----------------------+     +---------------------+   |
|   |  NativePrism Macro    |     | Component Registry  |   |
|   +-----------------------+     +---------------------+   |
|               |                            |              |
|               +------------+  +------------+              |
|                            |  |                           |
|   +---------------------------------------------------+   |
|   |     RustComponentPipelineBeam (Orchestration)     |   |
|   +---------------------------------------------------+   |
+-----------------------------|-----------------------------+
                              | IPC / NIF Bridge
+-----------------------------v-----------------------------+
|                     Native Rust Core                      |
|                                                           |
|   +-------------------+             +-----------------+   |
|   |  LuxPrism Trait   |             |  LuxBeam Trait  |   |
|   +-------------------+             +-----------------+   |
|             \                               /             |
|              +-----------------------------+              |
|                            |                              |
|             +-------------------------------+             |
|             |       ComponentRegistry       |             |
|             +-------------------------------+             |
+-----------------------------------------------------------+
```

---

## 2. Rust Trait Definitions

Native components implement the standard `LuxPrism` and `LuxBeam` traits in `lux/priv/rust/src/components.rs`:

```rust
use crate::components::{LuxPrism, ComponentContext};
use serde_json::{json, Value};

pub struct MatrixMultiplyPrism;

impl LuxPrism for MatrixMultiplyPrism {
    fn name(&self) -> &str {
        "RustMatrixMultiply"
    }

    fn description(&self) -> &str {
        "SIMD-accelerated matrix multiplication"
    }

    fn input_schema(&self) -> Value {
        json!({
            "type": "object",
            "properties": {
                "a": { "type": "array" },
                "b": { "type": "array" }
            },
            "required": ["a", "b"]
        })
    }

    fn output_schema(&self) -> Value {
        json!({
            "type": "object",
            "properties": {
                "result": { "type": "array" }
            },
            "required": ["result"]
        })
    }

    fn execute(&self, input: Value, _ctx: &ComponentContext) -> Result<Value, String> {
        // High-performance SIMD execution
        Ok(json!({ "result": [42.0] }))
    }
}
```

---

## 3. Defining Elixir Prisms with `NativePrism`

To expose a native Rust component as a first-class Lux Prism in Elixir, use the `Lux.Rust.Components.NativePrism` macro:

```elixir
defmodule MyApp.Prisms.MatrixMultiply do
  use Lux.Rust.Components.NativePrism,
    rust_component: "RustMatrixMultiply"
end

# Execution
{:ok, result} = MyApp.Prisms.MatrixMultiply.handler(%{
  "a" => [1.0, 2.0],
  "b" => [3.0, 4.0]
}, %{})
```

---

## 4. Prisms for Component Management

The Lux Rust module ships with 5 dedicated prisms:

1. **`Lux.Prisms.Languages.Rust.Components.RegistryPrism`**:
   Discovers and filters registered native Rust components.
2. **`Lux.Prisms.Languages.Rust.Components.SchemaSyncPrism`**:
   Validates JSON schemas between Elixir type definitions and Rust components.
3. **`Lux.Prisms.Languages.Rust.Components.InvokePrism`**:
   Invokes a native Rust component synchronously.
4. **`Lux.Prisms.Languages.Rust.Components.AsyncRunnerPrism`**:
   Executes native Rust components with task supervision and configurable timeout budgets.
5. **`Lux.Prisms.Languages.Rust.Components.LifecyclePrism`**:
   Manages lifecycle stages: `:init`, `:teardown`, and `:health`.

---

## 5. Beam Pipeline Orchestration

Use `Lux.Beams.Languages.Rust.Components.RustComponentPipelineBeam` to execute native Rust components within agent workflows:

```elixir
{:ok, result} = Lux.Beams.Languages.Rust.Components.RustComponentPipelineBeam.run(%{
  component_name: "RustFastHasher",
  args: %{"data" => "test string"},
  context: %{}
})
```
