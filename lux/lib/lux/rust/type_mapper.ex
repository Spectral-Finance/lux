defmodule Lux.Rust.TypeMapper do
  @moduledoc "Advanced type mapping between Elixir and Rust."
  use Lux.Types
  alias Lux.Rust.SerdeField
  @type primitive_type :: :integer | :float | :boolean | :string | :bytes | :char
  @type container_type :: :vec | :option | :hash_map | :tuple | :array
  @type serde_metadata :: %{
          optional(:rename) => atom(),
          optional(:rename_all) => atom(),
          optional(:tag) => String.t(),
          optional(:content) => String.t(),
          optional(:default) => term(),
          optional(:skip_serializing_if) => String.t(),
          optional(:skip_deserializing) => boolean()
        }
  @type field_descriptor :: {atom(), primitive_type | container_type | atom(), serde_metadata()}
  @type type_descriptor ::
          {:primitive, primitive_type()}
          | {:container, container_type(), type_descriptor() | nil}
          | {:struct, String.t(), [field_descriptor()]}
          | {:enum, String.t(), [atom() | {atom(), [type_descriptor()] | field_descriptor()}]}
  @typedoc "Result of a type mapping operation."
  @type type_result :: {:ok, String.t()} | {:error, String.t()}

  @doc "Maps an Elixir type atom to its Rust type string representation."
  @spec elixir_to_rust_type(primitive_type()) :: type_result()
  def elixir_to_rust_type(:integer), do: {:ok, "i64"}
  def elixir_to_rust_type(:float), do: {:ok, "f64"}
  def elixir_to_rust_type(:boolean), do: {:ok, "bool"}
  def elixir_to_rust_type(:string), do: {:ok, "String"}
  def elixir_to_rust_type(:bytes), do: {:ok, "Vec<u8>"}
  def elixir_to_rust_type(:char), do: {:ok, "char"}
  def elixir_to_rust_type(type), do: {:error, "Unknown Elixir type: :#{inspect(type)}"}

  @doc "Maps a Rust type string to its Elixir type atom."
  @spec rust_to_elixir_type(String.t()) :: type_result()
  def rust_to_elixir_type("i64"), do: {:ok, :integer}
  def rust_to_elixir_type("i32"), do: {:ok, :integer}
  def rust_to_elixir_type("u64"), do: {:ok, :integer}
  def rust_to_elixir_type("u32"), do: {:ok, :integer}
  def rust_to_elixir_type("f64"), do: {:ok, :float}
  def rust_to_elixir_type("f32"), do: {:ok, :float}
  def rust_to_elixir_type("bool"), do: {:ok, :boolean}
  def rust_to_elixir_type("String"), do: {:ok, :string}
  def rust_to_elixir_type("char"), do: {:ok, :char}
  def rust_to_elixir_type("Vec<u8>"), do: {:ok, :bytes}
  def rust_to_elixir_type("Vec<#{_rest}>" = _type), do: {:ok, :vec}
  def rust_to_elixir_type("HashMap<#{_k}, #{_v}>"), do: {:ok, :hash_map}
  def rust_to_elixir_type("Option<#{_inner}>"), do: {:ok, :option}
  def rust_to_elixir_type(type), do: {:error, "Unknown Rust type: #{type}"}

  @doc "Converts an Elixir container type to its Rust equivalent."
  @spec container_to_rust(container_type(), type_descriptor()) :: type_result()
  def container_to_rust(:vec, {:primitive, prim}) do
    with {:ok, s} <- elixir_to_rust_type(prim), do: {:ok, "Vec<#{s}>"}
  end

  def container_to_rust(:vec, inner) when is_tuple(inner) do
    with {:ok, inner_str} <- deserialize_type_descriptor(inner),
         do: {:ok, "Vec<#{inner_str}>"}
  end

  def container_to_rust(:option, {:primitive, prim}) do
    with {:ok, s} <- elixir_to_rust_type(prim), do: {:ok, "Option<#{s}>"}
  end

  def container_to_rust(:option, inner) when is_tuple(inner) do
    with {:ok, inner_str} <- deserialize_type_descriptor(inner),
         do: {:ok, "Option<#{inner_str}>"}
  end

  def container_to_rust(:hash_map, {:primitive, :string}),
    do: {:ok, "HashMap<String, String>"}

  def container_to_rust(:hash_map, inner) when is_tuple(inner) do
    with {:ok, val_str} <- deserialize_type_descriptor(inner),
         do: {:ok, "HashMap<String, #{val_str}>"}
  end

  def container_to_rust(container, _),
    do: {:error, "Unsupported container type: #{inspect(container)}"}

  @doc "Converts a Rust container type string back to Elixir."
  @spec container_from_rust(String.t()) :: type_result()
  def container_from_rust("Vec<#{_inner}>" = full_type) do
    inner = full_type |> String.trim_trailing(">") |> String.trim_leading("Vec<")
    case rust_to_elixir_type(inner) do
      {:ok, prim} -> {:ok, {:container, :vec, {:primitive, prim}}}
      {:error, _} -> {:ok, {:container, :vec, {:type, inner}}}
    end
  end

  def container_from_rust("Option<#{_inner}>" = full_type) do
    inner = full_type |> String.trim_trailing(">") |> String.trim_leading("Option<")
    case rust_to_elixir_type(inner) do
      {:ok, prim} -> {:ok, {:container, :option, {:primitive, prim}}}
      {:error, _} -> {:ok, {:container, :option, {:type, inner}}}
    end
  end

  def container_from_rust("HashMap<#{_k}, #{_v}>" = _full_type),
    do: {:ok, {:container, :hash_map, {:type, "HashMap"}}}

  def container_from_rust(_), do: {:error, "Not a container type"}

  @typedoc "A struct schema describing a Rust struct with typed fields and Serde metadata."
  @type struct_schema :: %{
          name: String.t(),
          fields: [SerdeField.t()],
          serde_attrs: SerdeField.serde_attrs()
        }

  @doc "Creates a struct schema from a name and a list of field descriptors."
  @spec struct_schema(String.t(), [field_descriptor()]) :: struct_schema()
  def struct_schema(name, fields) when is_binary(name) and is_list(fields) do
    %{
      name: name,
      fields: Enum.map(fields, &SerdeField.from_descriptor/1),
      serde_attrs: %{}
    }
  end

  @doc "Creates a struct schema with custom Serde attributes."
  @spec serde_struct_schema(String.t(), [field_descriptor()], map()) :: struct_schema()
  def serde_struct_schema(name, fields, serde_attrs)
      when is_binary(name) and is_list(fields) and is_map(serde_attrs) do
    %{
      name: name,
      fields: Enum.map(fields, &SerdeField.from_descriptor/1),
      serde_attrs: serde_attrs
    }
  end

  @doc "Generates the corresponding Rust struct definition from a schema."
  @spec rust_definition(struct_schema()) :: type_result()
  def rust_definition(%{name: name, fields: fields, serde_attrs: serde_attrs}) do
    derive_attrs = generate_derive_attrs(serde_attrs)
    field_defs = Enum.map(fields, &SerdeField.to_rust_field/1)
    rust_code = [derive_attrs, "pub struct #{name} {"] ++ field_defs ++ ["}"] |> Enum.join("\n")
    {:ok, rust_code}
  end

  defp generate_derive_attrs(serde_attrs) do
    derives = ["Serialize", "Deserialize", "Debug"]
    serde_parts = serde_attrs |> Enum.map(fn {k, v} -> "#{k} = \"#{v}\"" end)

    if Enum.empty?(serde_parts) do
      "#[derive(#{Enum.join(derives, ", ")})]"
    else
      serde_line = "#[serde(#{Enum.join(serde_parts, ", ")})]"
      "#[derive(#{Enum.join(derives, ", ")})]\n#{serde_line}"
    end
  end

  @typedoc "An enum schema describing a Rust enum with variants."
  @type enum_variant ::
          {:unit, atom()}
          | {:tuple, atom(), type_descriptor()}
          | {:struct, atom(), [field_descriptor()]}

  @type enum_schema :: %{
          name: String.t(),
          variants: [enum_variant()],
          serde_attrs: SerdeField.serde_attrs()
        }

  @doc "Creates an enum schema from a name and a list of variants."
  @spec enum_schema(String.t(), [atom() | {atom(), type_descriptor()}]) :: enum_schema()
  def enum_schema(name, variants) when is_binary(name) and is_list(variants) do
    parsed =
      Enum.map(variants, fn
        v when is_atom(v) -> {:unit, v}
        {v, desc} when is_atom(v) and is_tuple(desc) -> {:tuple, v, desc}
      end)

    %{name: name, variants: parsed, serde_attrs: %{}}
  end

  @doc "Creates an enum schema with Serde attributes."
  @spec serde_enum_schema(
          String.t(),
          [atom() | {atom(), type_descriptor()}],
          map()
        ) :: enum_schema()
  def serde_enum_schema(name, variants, serde_attrs)
      when is_binary(name) and is_list(variants) and is_map(serde_attrs) do
    parsed =
      Enum.map(variants, fn
        v when is_atom(v) -> {:unit, v}
        {v, desc} when is_atom(v) and is_tuple(desc) -> {:tuple, v, desc}
      end)

    %{name: name, variants: parsed, serde_attrs: serde_attrs}
  end

  @doc "Generates the corresponding Rust enum definition from a schema."
  @spec rust_definition(enum_schema()) :: type_result()
  def rust_definition(%{name: name, variants: variants, serde_attrs: serde_attrs}) do
    derive_attrs = generate_enum_derive_attrs(serde_attrs)
    variant_defs = Enum.map(variants, &enum_variant_to_rust/1)
    rust_code = [derive_attrs, "pub enum #{name} {"] ++ variant_defs ++ ["}"] |> Enum.join("\n")
    {:ok, rust_code}
  end

  defp generate_enum_derive_attrs(serde_attrs) do
    derives = ["Serialize", "Deserialize", "Debug"]
    serde_parts = serde_attrs |> Enum.map(fn {k, v} -> "#{k} = \"#{v}\"" end)

    if Enum.empty?(serde_parts) do
      "#[derive(#{Enum.join(derives, ", ")})]"
    else
      serde_line = "#[serde(#{Enum.join(serde_parts, ", ")})]"
      "#[derive(#{Enum.join(derives, ", ")})]\n#{serde_line}"
    end
  end

  defp enum_variant_to_rust({:unit, name}) do
    "    #{name |> Atom.to_string() |> camelize()},"
  end

  defp enum_variant_to_rust({:tuple, name, descriptor}) do
    with {:ok, rust_type} <- deserialize_type_descriptor(descriptor) do
      "    #{name |> Atom.to_string() |> camelize()}(#{rust_type}),"
    end
  end

  defp enum_variant_to_rust({:struct, name, fields}) do
    variant = name |> Atom.to_string() |> camelize()
    field_defs = Enum.map(fields, &SerdeField.to_rust_field/1)
    ["    #{variant} {"] ++ field_defs ++ ["    },"] |> Enum.join("\n")
  end

  defp camelize(str), do: str |> String.split("_") |> Enum.map_join(&String.capitalize(&1))

  @doc "Encodes an Elixir map to a Rust-compatible wire format using a struct schema."
  @spec encode(map(), struct_schema()) :: {:ok, map()} | {:error, String.t()}
  def encode(%{} = data, %{fields: fields, serde_attrs: serde_attrs}) do
    renamed = build_rename_map(fields, serde_attrs)
    result = Enum.reduce(fields, data, &apply_default/2) |> rename_keys(renamed)
    {:ok, result}
  end

  def encode(data, _), do: {:error, "encode/2 expects a map as the first argument"}

  @doc "Decodes a Rust wire-format map back to an Elixir-friendly map."
  @spec decode(map(), struct_schema()) :: {:ok, map()} | {:error, String.t()}
  def decode(%{} = data, %{fields: fields}) do
    reverse =
      Enum.map(fields, fn f ->
        {SerdeField.rust_name(f), SerdeField.elixir_name(f)}
      end)
      |> Map.new()

    result =
      Enum.reduce(data, %{}, fn {key, value}, acc ->
        elixir_key = Map.get(reverse, key, String.to_atom(key))
        Map.put(acc, elixir_key, value)
      end)

    {:ok, result}
  end

  def decode(data, _), do: {:error, "decode/2 expects a map as the first argument"}

  @doc "Serializes a type descriptor to its Rust type string."
  @spec serialize_type(type_descriptor()) :: type_result()
  def serialize_type({:primitive, prim}), do: elixir_to_rust_type(prim)

  def serialize_type({:container, cont, inner}) when is_atom(cont) do
    case inner do
      nil -> {:ok, container_name(cont)}
      desc when is_tuple(desc) -> container_to_rust(cont, desc)
      _ -> {:error, "Invalid container inner type"}
    end
  end

  def serialize_type({:struct, name, _}), do: {:ok, name}
  def serialize_type({:enum, name, _}), do: {:ok, name}
  def serialize_type({:type, rust_str}), do: {:ok, rust_str}
  def serialize_type(_), do: {:error, "Cannot serialize unsupported type descriptor"}

  @doc "Deserializes a Rust type string back to an Elixir type descriptor."
  @spec deserialize_type(String.t()) :: type_result()
  def deserialize_type(rust_type) when is_binary(rust_type), do: do_deserialize_type(rust_type)

  defp do_deserialize_type("i64"), do: {:ok, {:primitive, :integer}}
  defp do_deserialize_type("i32"), do: {:ok, {:primitive, :integer}}
  defp do_deserialize_type("u64"), do: {:ok, {:primitive, :integer}}
  defp do_deserialize_type("u32"), do: {:ok, {:primitive, :integer}}
  defp do_deserialize_type("f64"), do: {:ok, {:primitive, :float}}
  defp do_deserialize_type("f32"), do: {:ok, {:primitive, :float}}
  defp do_deserialize_type("bool"), do: {:ok, {:primitive, :boolean}}
  defp do_deserialize_type("String"), do: {:ok, {:primitive, :string}}
  defp do_deserialize_type("char"), do: {:ok, {:primitive, :char}}
  defp do_deserialize_type("Vec<u8>"), do: {:ok, {:primitive, :bytes}}

  defp do_deserialize_type("Vec<#{_inner}>" = full) do
    inner = full |> String.trim_trailing(">") |> String.trim_leading("Vec<")
    with {:ok, desc} <- do_deserialize_type(inner), do: {:ok, {:container, :vec, desc}}
  end

  defp do_deserialize_type("Option<#{_inner}>" = full) do
    inner = full |> String.trim_trailing(">") |> String.trim_leading("Option<")
    with {:ok, desc} <- do_deserialize_type(inner), do: {:ok, {:container, :option, desc}}
  end

  defp do_deserialize_type("HashMap<#{_k}, #{_v}>" = full) do
    inner =
      full
      |> String.trim_trailing(">")
      |> String.trim_leading("HashMap<")
      |> String.split(", ")

    with [k, v] <- inner,
         {:ok, kd} <- do_deserialize_type(k),
         {:ok, vd} <- do_deserialize_type(v),
         do: {:ok, {:container, :hash_map, {kd, vd}}}

    else
      _ -> {:ok, {:container, :hash_map, nil}}
    end
  end

  defp do_deserialize_type(type), do: {:ok, {:type, type}}

  defp apply_default(field, data) do
    case Map.get(Map.get(field, :serde_attrs, %{}), :default) do
      nil -> data
      val ->
        key = Map.get(field, :name)
        if Map.has_key?(data, key), do: data, else: Map.put(data, key, val)
    end
  end

  defp rename_keys(data, rename_map) do
    Enum.reduce(rename_map, data, fn {elixir_key, rust_key}, acc ->
      case Map.pop(acc, elixir_key) do
        {nil, _} -> acc
        {value, _} -> Map.put(acc, rust_key, value)
      end
    end)
  end

  defp build_rename_map(fields, _),
    do:
      Enum.map(fields, fn f ->
        {SerdeField.elixir_name(f), SerdeField.rust_name(f)}
      end)
      |> Map.new()

  defp container_name(:vec), do: "Vec<T>"
  defp container_name(:option), do: "Option<T>"
  defp container_name(:hash_map), do: "HashMap<K, V>"
  defp container_name(:tuple), do: "(T1, T2)"
  defp container_name(:array), do: "[T; N]"

  defp deserialize_type_descriptor({:primitive, prim}), do: elixir_to_rust_type(prim)

  defp deserialize_type_descriptor({:container, cont, inner}),
    do: container_to_rust(cont, inner)

  defp deserialize_type_descriptor({:struct, name, _}), do: {:ok, name}
  defp deserialize_type_descriptor({:enum, name, _}), do: {:ok, name}
  defp deserialize_type_descriptor({:type, rust_str}), do: {:ok, rust_str}

  defp deserialize_type_descriptor(_),
    do: {:error, "Cannot deserialize unsupported type descriptor"}

  @doc "Generates a complete type manifest containing all struct and enum schemas."
  @spec manifest([struct_schema()], [enum_schema()]) :: map()
  def manifest(struct_schemas \\ [], enum_schemas \\ []) do
    %{
      version: "1.0.0",
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      structs: struct_schemas,
      enums: enum_schemas,
      rust_code: generate_manifest_rust(struct_schemas, enum_schemas)
    }
  end

  @doc "Generates Rust code for the entire manifest."
  @spec generate_manifest_rust([struct_schema()], [enum_schema()]) :: String.t()
  def generate_manifest_rust(struct_schemas, enum_schemas) do
    struct_defs =
      struct_schemas
      |> Enum.map(fn s ->
        case rust_definition(s) do
          {:ok, code} -> code <> "\n"
          {:error, _} -> ""
        end
      end)
      |> Enum.join("\n")

    enum_defs =
      enum_schemas
      |> Enum.map(fn e ->
        case rust_definition(e) do
          {:ok, code} -> code <> "\n"
          {:error, _} -> ""
        end
      end)
      |> Enum.join("\n")

    [
      "// Auto-generated Rust type definitions by Lux.Rust.TypeMapper",
      "// Do not edit manually",
      "",
      struct_defs,
      enum_defs
    ]
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end
end
