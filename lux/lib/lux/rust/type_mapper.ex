defmodule Lux.Rust.TypeMapper do
  @moduledoc """
  Maps Lux/Elixir data shapes to Rust type declarations and serde payloads.

  The mapper is deliberately runtime-light: it produces deterministic Rust type
  strings, struct/enum definitions, and JSON-safe values that can be handed to a
  Rust NIF, port, or generated Cargo project.
  """

  @primitive_types %{
    string: "String",
    integer: "i64",
    float: "f64",
    boolean: "bool",
    binary: "Vec<u8>",
    atom: "String",
    any: "serde_json::Value"
  }

  @type type_spec ::
          atom()
          | {:option, type_spec()}
          | {:list, type_spec()}
          | {:array, type_spec()}
          | {:map, type_spec()}
          | {:map, type_spec(), type_spec()}
          | {:struct, String.t() | atom(), [field_spec()]}
          | {:enum, String.t() | atom(), [variant_spec()]}

  @type field_spec ::
          {String.t() | atom(), type_spec()}
          | {String.t() | atom(), type_spec(), keyword()}
          | map()

  @type variant_spec :: String.t() | atom() | {String.t() | atom(), type_spec()} | map()

  @doc """
  Builds a normalized descriptor for a Rust-compatible type.
  """
  @spec describe(type_spec()) :: map()
  def describe(type) when is_atom(type) do
    case Map.fetch(@primitive_types, type) do
      {:ok, rust} -> %{kind: :primitive, source: type, rust: rust}
      :error -> %{kind: :custom, source: type, rust: classify_name(type)}
    end
  end

  def describe({:option, inner}) do
    inner = describe(inner)
    %{kind: :option, inner: inner, rust: "Option<#{inner.rust}>"}
  end

  def describe({collection, inner}) when collection in [:list, :array] do
    inner = describe(inner)
    %{kind: :list, inner: inner, rust: "Vec<#{inner.rust}>"}
  end

  def describe({:map, value_type}) do
    value = describe(value_type)

    %{
      kind: :map,
      key: describe(:string),
      value: value,
      rust: "std::collections::HashMap<String, #{value.rust}>"
    }
  end

  def describe({:map, key_type, value_type}) do
    key = describe(key_type)
    value = describe(value_type)

    %{
      kind: :map,
      key: key,
      value: value,
      rust: "std::collections::HashMap<#{key.rust}, #{value.rust}>"
    }
  end

  def describe({:struct, name, fields}) do
    normalized_fields = Enum.map(fields, &normalize_field/1)

    %{
      kind: :struct,
      name: classify_name(name),
      fields: normalized_fields,
      rust: classify_name(name)
    }
  end

  def describe({:enum, name, variants}) do
    normalized_variants = Enum.map(variants, &normalize_variant/1)

    %{
      kind: :enum,
      name: classify_name(name),
      variants: normalized_variants,
      rust: classify_name(name)
    }
  end

  @doc """
  Returns only the Rust type string for a type specification.
  """
  @spec rust_type(type_spec()) :: String.t()
  def rust_type(type), do: describe(type).rust

  @doc """
  Renders a serde-enabled Rust struct definition.
  """
  @spec struct_definition(String.t() | atom(), [field_spec()], keyword()) :: String.t()
  def struct_definition(name, fields, opts \\ []) do
    derive =
      Keyword.get(opts, :derive, ["Debug", "Clone", "serde::Serialize", "serde::Deserialize"])

    body =
      fields
      |> Enum.map(&normalize_field/1)
      |> Enum.map_join("\n", fn field ->
        serde_attrs =
          field
          |> serde_field_attributes()
          |> Enum.map_join("", &"    #{&1}\n")

        "#{serde_attrs}    pub #{field.rust_name}: #{field.type.rust},"
      end)

    """
    #[derive(#{Enum.join(derive, ", ")})]
    pub struct #{classify_name(name)} {
    #{body}
    }
    """
    |> String.trim()
  end

  @doc """
  Renders a serde-enabled Rust enum definition.
  """
  @spec enum_definition(String.t() | atom(), [variant_spec()], keyword()) :: String.t()
  def enum_definition(name, variants, opts \\ []) do
    derive =
      Keyword.get(opts, :derive, ["Debug", "Clone", "serde::Serialize", "serde::Deserialize"])

    body =
      variants
      |> Enum.map(&normalize_variant/1)
      |> Enum.map_join("\n", fn
        %{type: nil} = variant ->
          "    #{variant.rust_name},"

        variant ->
          "    #{variant.rust_name}(#{variant.type.rust}),"
      end)

    """
    #[derive(#{Enum.join(derive, ", ")})]
    #[serde(tag = "type", content = "data")]
    pub enum #{classify_name(name)} {
    #{body}
    }
    """
    |> String.trim()
  end

  @doc """
  Converts an Elixir value into a JSON/serde-safe payload for a type spec.
  """
  @spec encode_value(type_spec(), term()) :: {:ok, term()} | {:error, term()}
  def encode_value({:option, _inner}, nil), do: {:ok, nil}

  def encode_value({:option, inner}, value), do: encode_value(inner, value)

  def encode_value({collection, inner}, values)
      when collection in [:list, :array] and is_list(values) do
    encode_list(inner, values)
  end

  def encode_value({collection, _inner}, value) when collection in [:list, :array] do
    {:error, {:expected_list, value}}
  end

  def encode_value({:map, value_type}, values) when is_map(values) do
    values
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, encoded} <- encode_value(value_type, value) do
        {:cont, {:ok, Map.put(acc, to_string(key), encoded)}}
      else
        {:error, reason} -> {:halt, {:error, {:map_value, key, reason}}}
      end
    end)
  end

  def encode_value({:map, _value_type}, value), do: {:error, {:expected_map, value}}

  def encode_value({:map, key_type, value_type}, values) when is_map(values) do
    values
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, encoded_key} <- encode_value(key_type, key),
           {:ok, encoded_value} <- encode_value(value_type, value) do
        {:cont, {:ok, Map.put(acc, encoded_key, encoded_value)}}
      else
        {:error, reason} -> {:halt, {:error, {:map_entry, key, reason}}}
      end
    end)
  end

  def encode_value({:map, _key_type, _value_type}, value), do: {:error, {:expected_map, value}}

  def encode_value({:struct, _name, fields}, values) when is_map(values) do
    fields
    |> Enum.map(&normalize_field/1)
    |> Enum.reduce_while({:ok, %{}}, fn field, {:ok, acc} ->
      value = get_field_value(values, field.elixir_name)

      cond do
        value == :missing and field.required? ->
          {:halt, {:error, {:missing_field, field.elixir_name}}}

        value == :missing ->
          {:cont, {:ok, acc}}

        true ->
          case encode_value(field.type_spec, value) do
            {:ok, encoded} -> {:cont, {:ok, Map.put(acc, field.serde_name, encoded)}}
            {:error, reason} -> {:halt, {:error, {:field, field.elixir_name, reason}}}
          end
      end
    end)
  end

  def encode_value({:struct, _name, _fields}, value), do: {:error, {:expected_struct_map, value}}

  def encode_value({:enum, _name, variants}, value) do
    variants = Enum.map(variants, &normalize_variant/1)
    encode_enum_value(variants, value)
  end

  def encode_value(:string, value) when is_binary(value), do: {:ok, value}
  def encode_value(:integer, value) when is_integer(value), do: {:ok, value}
  def encode_value(:float, value) when is_float(value), do: {:ok, value}
  def encode_value(:float, value) when is_integer(value), do: {:ok, value / 1}
  def encode_value(:boolean, value) when is_boolean(value), do: {:ok, value}
  def encode_value(:binary, value) when is_binary(value), do: {:ok, Base.encode64(value)}
  def encode_value(:atom, value) when is_atom(value), do: {:ok, Atom.to_string(value)}
  def encode_value(:any, value), do: {:ok, value}
  def encode_value(type, value), do: {:error, {:type_mismatch, type, value}}

  @doc """
  Decodes a serde payload into an Elixir value.

  Atom decoding intentionally returns strings unless an enum spec constrains the
  allowed atoms. This avoids creating atoms from untrusted Rust/JSON input.
  """
  @spec decode_value(type_spec(), term()) :: {:ok, term()} | {:error, term()}
  def decode_value({:option, _inner}, nil), do: {:ok, nil}

  def decode_value({:option, inner}, value), do: decode_value(inner, value)

  def decode_value({collection, inner}, values)
      when collection in [:list, :array] and is_list(values) do
    decode_list(inner, values)
  end

  def decode_value({collection, _inner}, value) when collection in [:list, :array] do
    {:error, {:expected_list, value}}
  end

  def decode_value({:map, value_type}, values) when is_map(values) do
    decode_string_key_map(value_type, values)
  end

  def decode_value({:map, key_type, value_type}, values) when is_map(values) do
    values
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      with {:ok, decoded_key} <- decode_value(key_type, key),
           {:ok, decoded_value} <- decode_value(value_type, value) do
        {:cont, {:ok, Map.put(acc, decoded_key, decoded_value)}}
      else
        {:error, reason} -> {:halt, {:error, {:map_entry, key, reason}}}
      end
    end)
  end

  def decode_value({:map, _value_type}, value), do: {:error, {:expected_map, value}}
  def decode_value({:map, _key_type, _value_type}, value), do: {:error, {:expected_map, value}}

  def decode_value({:struct, _name, fields}, values) when is_map(values) do
    fields
    |> Enum.map(&normalize_field/1)
    |> Enum.reduce_while({:ok, %{}}, fn field, {:ok, acc} ->
      value = Map.get(values, field.serde_name, :missing)

      cond do
        value == :missing and field.required? ->
          {:halt, {:error, {:missing_field, field.serde_name}}}

        value == :missing ->
          {:cont, {:ok, acc}}

        true ->
          case decode_value(field.type_spec, value) do
            {:ok, decoded} -> {:cont, {:ok, Map.put(acc, field.elixir_name, decoded)}}
            {:error, reason} -> {:halt, {:error, {:field, field.serde_name, reason}}}
          end
      end
    end)
  end

  def decode_value({:struct, _name, _fields}, value), do: {:error, {:expected_struct_map, value}}

  def decode_value({:enum, _name, variants}, value) do
    variants = Enum.map(variants, &normalize_variant/1)
    decode_enum_value(variants, value)
  end

  def decode_value(:string, value) when is_binary(value), do: {:ok, value}
  def decode_value(:integer, value) when is_integer(value), do: {:ok, value}
  def decode_value(:float, value) when is_number(value), do: {:ok, value / 1}
  def decode_value(:boolean, value) when is_boolean(value), do: {:ok, value}
  def decode_value(:binary, value) when is_binary(value), do: Base.decode64(value)
  def decode_value(:atom, value) when is_binary(value), do: {:ok, value}
  def decode_value(:any, value), do: {:ok, value}
  def decode_value(type, value), do: {:error, {:type_mismatch, type, value}}

  defp encode_list(inner, values) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case encode_value(inner, value) do
        {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> reverse_list_result()
  end

  defp decode_list(inner, values) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
      case decode_value(inner, value) do
        {:ok, decoded} -> {:cont, {:ok, [decoded | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> reverse_list_result()
  end

  defp reverse_list_result({:ok, values}), do: {:ok, Enum.reverse(values)}
  defp reverse_list_result(error), do: error

  defp decode_string_key_map(value_type, values) do
    values
    |> Enum.reduce_while({:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case decode_value(value_type, value) do
        {:ok, decoded} -> {:cont, {:ok, Map.put(acc, key, decoded)}}
        {:error, reason} -> {:halt, {:error, {:map_value, key, reason}}}
      end
    end)
  end

  defp encode_enum_value(variants, value) when is_atom(value) or is_binary(value) do
    variant = Enum.find(variants, &(variant_key(&1) == to_string(value)))

    if variant && is_nil(variant.type) do
      {:ok, %{"type" => variant.serde_name}}
    else
      {:error, {:unknown_variant, value}}
    end
  end

  defp encode_enum_value(variants, {name, value}) do
    variant = Enum.find(variants, &(variant_key(&1) == to_string(name)))

    cond do
      is_nil(variant) ->
        {:error, {:unknown_variant, name}}

      is_nil(variant.type) ->
        {:error, {:unit_variant_has_payload, name}}

      true ->
        with {:ok, encoded} <- encode_value(variant.type_spec, value) do
          {:ok, %{"type" => variant.serde_name, "data" => encoded}}
        end
    end
  end

  defp encode_enum_value(_variants, value), do: {:error, {:expected_enum, value}}

  defp decode_enum_value(variants, %{"type" => type} = value) do
    variant = Enum.find(variants, &(&1.serde_name == type))

    cond do
      is_nil(variant) ->
        {:error, {:unknown_variant, type}}

      is_nil(variant.type) ->
        {:ok, variant.elixir_name}

      Map.has_key?(value, "data") ->
        with {:ok, decoded} <- decode_value(variant.type_spec, value["data"]) do
          {:ok, {variant.elixir_name, decoded}}
        end

      true ->
        {:error, {:missing_variant_data, type}}
    end
  end

  defp decode_enum_value(_variants, value), do: {:error, {:expected_tagged_enum, value}}

  defp normalize_field(%{name: name, type: type} = field) do
    normalize_field({name, type, Map.to_list(Map.delete(Map.delete(field, :name), :type))})
  end

  defp normalize_field(%{"name" => name, "type" => type} = field) do
    opts =
      field
      |> Map.delete("name")
      |> Map.delete("type")
      |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)

    normalize_field({name, type, opts})
  end

  defp normalize_field({name, type}), do: normalize_field({name, type, []})

  defp normalize_field({name, type, opts}) do
    rust_name = snake_name(name)
    serde_name = opts[:serde_name] || to_string(name)

    %{
      elixir_name: atom_name(name),
      rust_name: rust_name,
      serde_name: serde_name,
      type_spec: type,
      type: describe(type),
      required?: Keyword.get(opts, :required, true),
      default?: Keyword.get(opts, :default, false)
    }
  end

  defp normalize_variant(%{name: name} = variant) do
    type = Map.get(variant, :type)
    opts = variant |> Map.delete(:name) |> Map.delete(:type) |> Map.to_list()
    normalize_variant({name, type, opts})
  end

  defp normalize_variant(%{"name" => name} = variant) do
    type = Map.get(variant, "type")

    opts =
      variant
      |> Map.delete("name")
      |> Map.delete("type")
      |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)

    normalize_variant({name, type, opts})
  end

  defp normalize_variant({name, type}), do: normalize_variant({name, type, []})

  defp normalize_variant(name) when is_atom(name) or is_binary(name),
    do: normalize_variant({name, nil, []})

  defp normalize_variant({name, nil, opts}) do
    %{
      elixir_name: atom_name(name),
      rust_name: classify_name(name),
      serde_name: opts[:serde_name] || to_string(name),
      type_spec: nil,
      type: nil
    }
  end

  defp normalize_variant({name, type, opts}) do
    %{
      elixir_name: atom_name(name),
      rust_name: classify_name(name),
      serde_name: opts[:serde_name] || to_string(name),
      type_spec: type,
      type: describe(type)
    }
  end

  defp serde_field_attributes(field) do
    []
    |> maybe_add(
      field.serde_name != field.rust_name,
      ~s|#[serde(rename = "#{field.serde_name}")]|
    )
    |> maybe_add(
      not field.required?,
      ~s|#[serde(default, skip_serializing_if = "Option::is_none")]|
    )
    |> maybe_add(field.default?, ~s|#[serde(default)]|)
    |> Enum.reverse()
  end

  defp maybe_add(attrs, true, attr), do: [attr | attrs]
  defp maybe_add(attrs, false, _attr), do: attrs

  defp get_field_value(values, key) do
    Map.get(values, key, Map.get(values, to_string(key), :missing))
  end

  defp variant_key(variant), do: to_string(variant.elixir_name)

  defp atom_name(name) when is_atom(name), do: name
  defp atom_name(name) when is_binary(name), do: String.to_atom(name)

  defp snake_name(name) do
    name
    |> to_string()
    |> Macro.underscore()
  end

  defp classify_name(name) do
    name
    |> to_string()
    |> Macro.camelize()
  end
end
