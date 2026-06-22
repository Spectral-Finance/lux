# Rust Type System and Serialization

Lux provides advanced type mapping and bidirectional serialization between Elixir and Rust using Rustler and Serde. This allows developers to seamlessly exchange complex type definitions without dealing with the low-level erlang NIF C APIs.

## Overview

The `Lux.TypeSystem` module demonstrates:
1. **Custom Type Definitions:** Mapping Elixir structs to Rust structs.
2. **Enum & Struct Support:** Automatic translation of Elixir atoms into Rust enums and Elixir maps/structs into Rust structs using Rustler's `NifStruct` and `NifEnum`.
3. **Serde Integration:** Rust-side bidirectional serialization. Using Serde, you can convert complex Elixir structures directly to and from JSON.
4. **Bidirectional Conversion:** Passing data from Elixir to Rust, modifying it natively, and returning updated data structures.

## Example: Complex Type Conversions

Here is an example demonstrating complex type conversions across the Elixir/Rust boundary.

### 1. Defining the Structure

In **Rust** (`lux_types/src/lib.rs`):

```rust
use rustler::{NifStruct, NifEnum};
use serde::{Deserialize, Serialize};

#[derive(NifEnum, Serialize, Deserialize, Debug, PartialEq)]
pub enum ComplexType {
    String,
    Integer,
    Boolean,
    Float,
    List,
    Map,
    Custom,
}

#[derive(NifStruct, Serialize, Deserialize, Debug, PartialEq)]
#[module = "Lux.TypeSystem.ComplexStruct"]
pub struct ComplexStruct {
    pub id: i64,
    pub name: String,
    pub type_def: ComplexType,
    pub metadata: String,
    pub is_active: bool,
}
```

In **Elixir** (`lib/lux/type_system.ex`):

```elixir
defmodule Lux.TypeSystem.ComplexStruct do
  defstruct [:id, :name, :type_def, :metadata, :is_active]
  
  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          type_def: atom(),
          metadata: String.t(),
          is_active: boolean()
        }
end
```

### 2. Bidirectional Serde Serialization

```elixir
struct_data = %Lux.TypeSystem.ComplexStruct{
  id: 123,
  name: "Test Type",
  type_def: :Custom,
  metadata: "{\"key\":\"value\"}",
  is_active: true
}

# Serialize Elixir struct -> Rust NIF -> JSON
json = Lux.TypeSystem.serialize_to_json(struct_data)

# Deserialize JSON -> Rust NIF (Serde) -> Elixir struct
{:ok, struct_data} = Lux.TypeSystem.deserialize_from_json(json)
```

### 3. Modifying Native Types

You can pass the struct into Rust and get back the updated version:

```elixir
# Elixir struct -> Rust NIF modification -> Elixir struct
updated = Lux.TypeSystem.process_complex_type(struct_data)
```

## Adding to Your Own Project

To leverage this system in your own Rustler NIFs inside Lux:
1. Derive `NifStruct` and `Serialize`/`Deserialize` on your Rust structs.
2. Ensure the `#[module = "Elixir.Your.Module"]` correctly maps to your Elixir `defstruct`.
3. Call native functions by mapping them using `rustler::init!`.
