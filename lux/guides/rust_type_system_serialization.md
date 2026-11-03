# Rust Type System and Serialization Guide

This guide covers advanced type mapping, struct and enum conversion, Serde integration, and bidirectional serialization between Elixir and native Rust in Lux.

---

## 1. Overview & Architecture

Lux provides high-fidelity type translation between Elixir terms and Rust data structures using Serde. This architecture allows complex domain models (such as trading orders, blockchain receipts, and multi-signature envelopes) to cross the language boundary with zero loss of type safety.

```
+-----------------------------------------------------------------------+
|                              Lux Agent                                |
+-----------------------------------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | TypeSerializationBeam                     |
             +-------------------------------------------+
               /                 |                     \
              v                  v                      v
    +-------------------+ +-------------------+ +-------------------+
    | SerializePrism    | | DeserializePrism  | | CustomSchemaPrism |
    | (Elixir -> Serde) | | (Serde -> Elixir) | | (Generate Rust)   |
    +-------------------+ +-------------------+ +-------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.Rust.Types.Serializer                 |
             | - Struct Metadata (`__struct__`)          |
             | - Tagged Enums (`__enum__`, `payload`)    |
             | - Serde JSON / Map Bidirectional Support  |
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Rust Native Types (priv/rust/src/types.rs)|
             | - LuxValue / LuxStruct / LuxEnum          |
             | - Serde `#[derive(Serialize, Deserialize)]|
             +-------------------------------------------+
```

---

## 2. Type Mapping Specification

| Elixir Type | Serde Intermediate | Rust Target |
|---|---|---|
| `integer()` | `Value::Number(i64)` | `i64` |
| `float()` | `Value::Number(f64)` | `f64` |
| `boolean()` | `Value::Bool` | `bool` |
| `binary()` / `String.t()` | `Value::String` | `String` / `&str` |
| `%{__struct__: Mod, ...}` | `{"__struct__": "Mod", ...}` | `LuxStruct` or typed struct |
| `{:ok, val}` / `{:tag, val}` | `{"__enum__": "tag", "payload": val}` | `LuxEnum` or typed enum |
| `:atom` | `{"__enum__": "atom"}` | Unit enum variant |
| `list()` | `Value::Array` | `Vec<T>` |
| `map()` | `Value::Object` | `HashMap<String, T>` |
| `nil` | `Value::Null` | `Option<T>` (`None`) |

---

## 3. Bidirectional Serialization

### Serializing Structs

```elixir
defmodule UserProfile do
  defstruct [:id, :email, :balance]
end

user = %UserProfile{id: "usr_1", email: "user@lux.org", balance: 1500.0}

{:ok, json_str} = Lux.Rust.Types.Serializer.serialize(user, format: :json)
```

### Deserializing back to Elixir Structs

```elixir
{:ok, %UserProfile{} = restored} = Lux.Rust.Types.Serializer.deserialize(json_str)
```

### Tagged Tuples as Enums

```elixir
tagged = {:error, "insufficient_liquidity"}
{:ok, map} = Lux.Rust.Types.Serializer.serialize(tagged)
# %{"__enum__" => "error", "payload" => "insufficient_liquidity"}
```

---

## 4. Generating Rust Schemas from Elixir

The `SchemaGenerator` automatically creates Rust structs and enums with Serde derives:

```elixir
alias Lux.Rust.Types.SchemaGenerator

code = SchemaGenerator.generate_struct("TradeOrder", %{
  "order_id" => "string",
  "price" => "float",
  "size" => "float",
  "is_buy" => "boolean"
})

# Generates:
# #[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
# #[serde(rename_all = "snake_case")]
# pub struct TradeOrder {
#     pub order_id: String,
#     pub price: f64,
#     pub size: f64,
#     pub is_buy: bool,
# }
```

---

## 5. Dedicated Prisms

- `Lux.Prisms.Languages.Rust.Types.SerializePrism`: Serializes Elixir structures into Serde maps or JSON.
- `Lux.Prisms.Languages.Rust.Types.DeserializePrism`: Restores Serde JSON or maps into Elixir data and structs.
- `Lux.Prisms.Languages.Rust.Types.CustomSchemaPrism`: Generates Rust struct or enum source code from schema definitions.
- `Lux.Prisms.Languages.Rust.Types.EnumBridgePrism`: Marshals Elixir tagged tuples to Serde enum representations.
- `Lux.Prisms.Languages.Rust.Types.ValidatePrism`: Asserts roundtrip data fidelity.

---

## 6. Pipeline Beam

The `Lux.Beams.Languages.Rust.Types.TypeSerializationBeam` orchestrates end-to-end roundtripping:

```elixir
{:ok, result, log} = Lux.Beams.Languages.Rust.Types.TypeSerializationBeam.run(%{
  data: %{"token" => "USDC", "amount" => 1000.0},
  type_name: "DepositEvent",
  fields_schema: %{"token" => "string", "amount" => "float"}
})

IO.puts("Roundtrip verified: #{result.is_match}")
IO.puts("Generated Rust Code:\n#{result.rust_code}")
```

---

## 7. Testing

Run all type system and serialization unit tests:

```bash
mix test test/unit/lux/languages/rust_type_serialization_test.exs
mix test test/unit/lux/prisms/languages/rust_type_prisms_test.exs
mix test test/unit/lux/beams/languages/rust_type_beam_test.exs
```
