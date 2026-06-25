defmodule Lux.Rust do
  @moduledoc """
  Rust integration module for Lux.

  Provides a centralized entry point for Rust type mapping, serialization,
  and conversion utilities. Re-exports the core type mapper and Serde field
  modules for convenient access.

  ## Usage

      # Map types
      Lux.Rust.elixir_to_rust_type(:integer)
      # => {:ok, "i64"}

      # Create schemas
      schema = Lux.Rust.struct_schema("Trade", [
        {:symbol, :string, []},
        {:price, :float, [default: 0.0]}
      ])

      # Encode/decode
      Lux.Rust.encode(%{symbol: "BTC/USD"}, schema)
  """

  @doc "Delegates to Lux.Rust.TypeMapper.elixir_to_rust_type/1"
  @spec elixir_to_rust_type(Lux.Rust.TypeMapper.primitive_type()) ::
          Lux.Rust.TypeMapper.type_result()
  defdelegate elixir_to_rust_type(type), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.rust_to_elixir_type/1"
  @spec rust_to_elixir_type(String.t()) :: Lux.Rust.TypeMapper.type_result()
  defdelegate rust_to_elixir_type(type), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.container_to_rust/2"
  @spec container_to_rust(Lux.Rust.TypeMapper.container_type(), Lux.Rust.TypeMapper.type_descriptor()) ::
          Lux.Rust.TypeMapper.type_result()
  defdelegate container_to_rust(container, inner), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.serialize_type/1"
  @spec serialize_type(Lux.Rust.TypeMapper.type_descriptor()) ::
          Lux.Rust.TypeMapper.type_result()
  defdelegate serialize_type(descriptor), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.deserialize_type/1"
  @spec deserialize_type(String.t()) :: Lux.Rust.TypeMapper.type_result()
  defdelegate deserialize_type(rust_type), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.struct_schema/2"
  @spec struct_schema(String.t(), [Lux.Rust.TypeMapper.field_descriptor()]) ::
          Lux.Rust.TypeMapper.struct_schema()
  defdelegate struct_schema(name, fields), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.serde_struct_schema/3"
  @spec serde_struct_schema(String.t(), [Lux.Rust.TypeMapper.field_descriptor()], map()) ::
          Lux.Rust.TypeMapper.struct_schema()
  defdelegate serde_struct_schema(name, fields, serde_attrs), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.enum_schema/2"
  @spec enum_schema(String.t(), [atom() | {atom(), Lux.Rust.TypeMapper.type_descriptor()}]) ::
          Lux.Rust.TypeMapper.enum_schema()
  defdelegate enum_schema(name, variants), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.serde_enum_schema/3"
  @spec serde_enum_schema(String.t(), [atom() | {atom(), Lux.Rust.TypeMapper.type_descriptor()}], map()) ::
          Lux.Rust.TypeMapper.enum_schema()
  defdelegate serde_enum_schema(name, variants, serde_attrs), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.rust_definition/1"
  @spec rust_definition(struct_or_enum :: struct() | map()) :: Lux.Rust.TypeMapper.type_result()
  defdelegate rust_definition(schema), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.encode/2"
  @spec encode(map(), Lux.Rust.TypeMapper.struct_schema()) ::
          {:ok, map()} | {:error, String.t()}
  defdelegate encode(data, schema), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.decode/2"
  @spec decode(map(), Lux.Rust.TypeMapper.struct_schema()) ::
          {:ok, map()} | {:error, String.t()}
  defdelegate decode(data, schema), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.manifest/2"
  @spec manifest([Lux.Rust.TypeMapper.struct_schema()], [Lux.Rust.TypeMapper.enum_schema()]) ::
          map()
  defdelegate manifest(structs, enums), to: Lux.Rust.TypeMapper

  @doc "Delegates to Lux.Rust.TypeMapper.generate_manifest_rust/2"
  @spec generate_manifest_rust(
          [Lux.Rust.TypeMapper.struct_schema()],
          [Lux.Rust.TypeMapper.enum_schema()]
        ) :: String.t()
  defdelegate generate_manifest_rust(structs, enums), to: Lux.Rust.TypeMapper
end
