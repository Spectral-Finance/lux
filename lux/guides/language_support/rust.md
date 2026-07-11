# Rust Core Integration

Lux supports writing high-performance components and logic using Rust natively via the `Rustler` integration.
The core repository sets up the boilerplate for Native Implemented Functions (NIFs) that interact with the Erlang VM seamlessly.

## Getting Started

The native Rust code lives under the `priv/rust/lux_core` directory.

### Requirements

To compile Lux with the native features, you must have Rust and Cargo installed:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Writing a new NIF

When adding a new feature that requires Rust:

1. **Add your Rust function in `priv/rust/lux_core/src/lib.rs`**:
    ```rust
    #[rustler::nif]
    fn compute_heavy_task(env: Env, input: String) -> Term {
        let result = do_heavy_work(input);
        crate::ok_tuple!(env, result)
    }
    ```

2. **Register it at the bottom of the file**:
    ```rust
    rustler::init!("Elixir.Lux.Native");
    ```

3. **Expose the interface in Elixir**:
   Open `lib/lux/native.ex` and add the definition:
   ```elixir
   def compute_heavy_task(_input), do: :erlang.nif_error(:nif_not_loaded)
   ```

### Working with Structs

Lux provides predefined ways to translate Elixir maps/structs directly into Rust. 

To deal with custom Lux structs, map them using `NifStruct`:
```rust
use rustler::NifStruct;

#[derive(NifStruct)]
#[module = "Lux.Native.ComplexData"]
pub struct ComplexData {
    pub name: String,
}
```

### Error Handling Philosophy

We never panic the BEAM! Always use the `ok_tuple!` and `error_tuple!` macros to return tagged tuples cleanly to Elixir:

```rust
if let Err(e) = some_operation() {
    return crate::error_tuple!(env, "operation_failed");
}
```
