# Rust Core Integration Setup Guide

This guide details the native Rust core integration in the Lux framework, providing high-performance native code execution, bidirectional type conversions, memory safety guarantees, and panic isolation.

---

## 1. Overview & Architecture

Rust support in Lux enables compute-intensive tasks (such as cryptography, zero-knowledge proofs, vectorized math, and high-frequency trading simulations) to run at bare-metal native speed while ensuring memory safety and error isolation.

```
+-----------------------------------------------------------------------+
|                              Lux Agent                                |
+-----------------------------------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.Beams.Languages.RustExecutionBeam     |
             +-------------------------------------------+
               /                 |                     \
              v                  v                      v
    +-------------------+ +-------------------+ +-------------------+
    | TypeBridgePrism   | | ExecutePrism      | | BenchmarkPrism    |
    | (Elixir -> Rust)  | | (Call Function)   | | (Microsecond TC)  |
    +-------------------+ +-------------------+ +-------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.Rust (`~RS` Sigil / `call/3`)         |
             | - Bidirectional Type Marshalling          |
             | - Structured `Lux.Rust.Error`             |
             | - Catch-unwind Panic Isolation            |
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Rust Crate (`priv/rust/`)                 |
             |  src/lib.rs (JSON / NIF Entrypoint)       |
             |  src/types.rs (LuxValue Conversion)       |
             |  src/error.rs (RustError Hierarchy)       |
             |  src/bridge.rs (Function Registry)        |
             +-------------------------------------------+
```

---

## 2. Project Structure (`priv/rust`)

The native Rust codebase is maintained under `priv/rust`:

```
priv/rust/
├── Cargo.toml          # Rust package manifest
├── README.md           # Crate overview & build instructions
└── src/
    ├── lib.rs          # Dispatcher and JSON IPC interface
    ├── types.rs        # LuxValue type conversions (FromLuxValue, ToLuxValue)
    ├── error.rs        # Structured RustError enum with thiserror
    └── bridge.rs       # FunctionRegistry with panic isolation (catch_unwind)
```

---

## 3. Type Conversion System

`Lux.Rust.Types` bridges between Elixir dynamic terms and Rust strongly-typed values:

| Elixir Type | JSON / Bridge Intermediate | Rust Native Type |
|---|---|---|
| `integer()` | `Value::Number(i64)` | `i64` / `u64` |
| `float()` | `Value::Number(f64)` | `f64` |
| `boolean()` | `Value::Bool` | `bool` |
| `binary()` / `String.t()` | `Value::String` | `String` / `&str` |
| `atom()` | `Value::String` | `String` |
| `list()` | `Value::Array` | `Vec<LuxValue>` |
| `map()` / `keyword()` | `Value::Object` | `HashMap<String, LuxValue>` |
| `nil` | `Value::Null` | `Option<T>` (`None`) |

---

## 4. Writing Rust Code

### Using the `~RS` Sigil & `rust` Macro

```elixir
require Lux.Rust
import Lux.Rust

result = rust variables: %{a: 100, b: 250} do
  ~RS"""
  pub fn main(args: Map) -> i64 {
      args["a"] + args["b"]
  }
  """
end

# {:ok, 350}
```

### Calling Registered Native Functions

```elixir
# Fibonacci calculation in native Rust
{:ok, fib50} = Lux.Rust.call("math.fibonacci", %{"n" => 50})

# Vector dot product
{:ok, dot} = Lux.Rust.call("math.dot_product", %{
  "a" => [1.0, 2.0, 3.0],
  "b" => [4.0, 5.0, 6.0]
})
```

---

## 5. Memory Safety & Panic Isolation

The Rust runtime encapsulates execution inside `std::panic::catch_unwind(AssertUnwindSafe(...))`. If a native Rust routine encounters an unexpected panic, the panic is caught and converted into a structured `{:error, %Lux.Rust.Error{type: :panic, message: "..."}}`, preventing the BEAM VM from crashing.

---

## 6. Dedicated Prisms

### `Lux.Prisms.Languages.Rust.ExecutePrism`
Direct function invocation:

```elixir
{:ok, res} = Lux.Prisms.Languages.Rust.ExecutePrism.handler(%{
  "function" => "math.fibonacci",
  "args" => %{"n" => 20}
}, %{})
```

### `Lux.Prisms.Languages.Rust.TypeBridgePrism`
Type conversion and validation:

```elixir
{:ok, res} = Lux.Prisms.Languages.Rust.TypeBridgePrism.handler(%{
  "payload" => %{symbol: :BTC, price: 95_000.0}
}, %{})
```

### `Lux.Prisms.Languages.Rust.BenchmarkPrism`
Measures execution time in microseconds:

```elixir
{:ok, bench} = Lux.Prisms.Languages.Rust.BenchmarkPrism.handler(%{
  "function" => "math.fibonacci",
  "args" => %{"n" => 30},
  "iterations" => 100
}, %{})

IO.puts("Average time: #{bench.avg_time_us} µs")
```

---

## 7. Pipeline Beam

The `Lux.Beams.Languages.Rust.RustExecutionBeam` provides a unified execution lifecycle:

```elixir
{:ok, result, log} = Lux.Beams.Languages.Rust.RustExecutionBeam.run(%{
  function: "math.fibonacci",
  args: %{"n" => 25},
  iterations: 50
})

IO.puts("Result: #{result.result}")
IO.puts("Benchmark Avg: #{result.avg_time_us} µs")
```

---

## 8. Testing

Run all unit tests:

```bash
mix test test/unit/lux/languages/rust_test.exs
mix test test/unit/lux/prisms/languages/rust_prisms_test.exs
mix test test/unit/lux/beams/languages/rust_beam_test.exs
```
