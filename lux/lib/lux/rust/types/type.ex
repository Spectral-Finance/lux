defmodule Lux.Rust.Types.Type do
  @moduledoc """
  A named, reusable type definition at the Elixir <-> Rust boundary.

  A `%Lux.Rust.Types.Type{}` bundles a Rust type name with the shape needed to
  (de)serialize and to generate Rust source:

    * `:kind` - `:struct`, `:enum`, or `:alias`
    * `:fields` - keyword list of `name => rust_type` for structs
    * `:variants` - keyword list of `name => rust_type | :unit` for enums
    * `:spec` - the underlying `t:Lux.Rust.Types.Serializer.rust_type/0` for aliases
    * `:tag` / `:derives` / `:doc` - code generation metadata

  Definitions are built with `Lux.Rust.Types.define/2`.
  """

  @enforce_keys [:name, :kind]
  defstruct [
    :name,
    :kind,
    :spec,
    :doc,
    fields: [],
    variants: [],
    tag: :external,
    derives: []
  ]

  @type kind :: :struct | :enum | :alias

  @type t :: %__MODULE__{
          name: String.t(),
          kind: kind(),
          spec: Lux.Rust.Types.Serializer.rust_type() | nil,
          doc: String.t() | nil,
          fields: keyword(Lux.Rust.Types.Serializer.rust_type()),
          variants: keyword(Lux.Rust.Types.Serializer.rust_type() | :unit),
          tag: :external | :internal | {:adjacent, String.t(), String.t()},
          derives: [String.t()]
        }
end
