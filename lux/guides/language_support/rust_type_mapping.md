# Rust Type Mapping in Lux

Lux includes a small type mapper for Rust interop. It converts Lux/Elixir data
shapes into Rust type declarations and JSON-safe serde payloads without tying the
core framework to one specific NIF, port, or code-generation strategy.

## Type Specs

Primitive types map to serde-friendly Rust types:

```elixir
Lux.Rust.TypeMapper.rust_type(:string)
# "String"

Lux.Rust.TypeMapper.rust_type({:list, {:option, :integer}})
# "Vec<Option<i64>>"
```

Supported primitives are `:string`, `:integer`, `:float`, `:boolean`, `:binary`,
`:atom`, and `:any`. Containers support `{:option, type}`, `{:list, type}`,
`{:array, type}`, `{:map, value_type}`, and `{:map, key_type, value_type}`.

## Struct Definitions

Struct specs describe fields once and can render Rust definitions or encode
payloads:

```elixir
artifact = {
  :struct,
  :research_artifact,
  [
    {:id, :string},
    {:revision, :integer},
    {:tags, {:list, :string}},
    {:metadata, {:map, :string}},
    {:checksum, {:option, :string}, required: false}
  ]
}

Lux.Rust.TypeMapper.struct_definition(:research_artifact, elem(artifact, 2))
```

Generated structs include `Debug`, `Clone`, `serde::Serialize`, and
`serde::Deserialize` derives by default. Field options support `:serde_name`,
`:required`, and `:default`.

## Enum Definitions

Tagged enum specs support unit variants and payload variants:

```elixir
state = {:enum, :artifact_state, [:draft, :published, {:rejected, :string}]}

Lux.Rust.TypeMapper.enum_definition(:artifact_state, elem(state, 2))
```

Enums render with `#[serde(tag = "type", content = "data")]` so Rust and Elixir
can exchange stable tagged payloads.

## Serde Payloads

`encode_value/2` converts Elixir values into JSON-safe Rust/serde payloads.
`decode_value/2` converts those payloads back into Elixir maps, lists, and
tagged enum tuples:

```elixir
{:ok, encoded} =
  Lux.Rust.TypeMapper.encode_value(artifact, %{
    id: "artifact-1",
    revision: 3,
    tags: ["paper", "dataset"],
    metadata: %{doi: "10.000/example"},
    checksum: nil
  })

{:ok, decoded} = Lux.Rust.TypeMapper.decode_value(artifact, encoded)
```

Atom decoding intentionally returns strings for unconstrained `:atom` specs to
avoid creating atoms from untrusted Rust or JSON input. Enum specs decode to
known atoms because the allowed variants are declared up front.
