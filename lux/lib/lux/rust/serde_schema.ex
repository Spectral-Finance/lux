defmodule Lux.Rust.SerdeSchema do
  @moduledoc """
  Schema-first Rust type mapping and Serde serialization helpers.

  The module keeps the Rust boundary explicit: callers describe primitives,
  containers, structs, and enums once, then use the same descriptor to generate
  Rust type definitions and validate Elixir values before crossing a native
  boundary.
  """

  import Kernel, except: [struct: 2]

  @primitive_types %{
    string: "String",
    integer: "i64",
    float: "f64",
    boolean: "bool",
    json: "serde_json::Value"
  }

  @coverage [
    :advanced_type_mapping,
    :custom_type_definitions,
    :struct_support,
    :enum_support,
    :serde_integration,
    :bidirectional_serialization
  ]

  @type descriptor :: map()
  @type schema :: map()
  @type result :: {:ok, term()} | {:error, map()}

  @doc "Builds a primitive Rust type descriptor."
  @spec primitive(atom() | String.t()) :: descriptor()
  def primitive(type) do
    type = normalize_type(type)

    %{
      kind: :primitive,
      type: type,
      rust_type: Map.fetch!(@primitive_types, type)
    }
  end

  @doc "Builds a `Vec<T>` descriptor."
  @spec list(descriptor()) :: descriptor()
  def list(item), do: %{kind: :list, item: item}

  @doc "Builds an `Option<T>` descriptor."
  @spec option(descriptor()) :: descriptor()
  def option(item), do: %{kind: :option, item: item}

  @doc "Builds a `BTreeMap<K, V>` descriptor."
  @spec map_of(descriptor(), descriptor()) :: descriptor()
  def map_of(key, value), do: %{kind: :map, key: key, value: value}

  @doc "Builds a named struct field descriptor."
  @spec field(atom() | String.t(), descriptor(), keyword()) :: map()
  def field(name, type, opts \\ []) do
    rust_name = opts |> Keyword.get(:rust_name, name) |> rust_identifier()
    wire_name = opts |> Keyword.get(:rename, to_string(name)) |> to_string()
    has_default? = Keyword.has_key?(opts, :default)

    %{
      name: name,
      rust_name: rust_name,
      wire_name: wire_name,
      type: type,
      required?: Keyword.get(opts, :required, type.kind != :option and not has_default?),
      default: Keyword.get(opts, :default),
      has_default?: has_default?,
      skip_nil?: Keyword.get(opts, :skip_nil?, false),
      serde: Keyword.get(opts, :serde, [])
    }
  end

  @doc "Builds a Rust struct schema."
  @spec struct(String.t() | atom(), [map()], keyword()) :: schema()
  def struct(name, fields, opts \\ []) when is_list(fields) do
    %{
      kind: :struct,
      name: type_name(name),
      fields: fields,
      serde: serde_options(opts),
      coverage: @coverage
    }
  end

  @doc "Builds a Rust enum variant descriptor."
  @spec variant(String.t() | atom(), descriptor() | [map()] | nil, keyword()) :: map()
  def variant(name, payload \\ nil, opts \\ []) do
    variant_kind =
      cond do
        is_nil(payload) -> :unit
        is_list(payload) -> :struct
        true -> :tuple
      end

    %{
      name: type_name(name),
      tag: opts |> Keyword.get(:tag, name) |> to_string(),
      kind: variant_kind,
      payload: payload
    }
  end

  @doc "Builds a Rust enum schema with Serde adjacent tagging by default."
  @spec enum(String.t() | atom(), [map()], keyword()) :: schema()
  def enum(name, variants, opts \\ []) when is_list(variants) do
    %{
      kind: :enum,
      name: type_name(name),
      variants: variants,
      serde:
        serde_options(opts |> Keyword.put_new(:tag, "type") |> Keyword.put_new(:content, "data")),
      coverage: @coverage
    }
  end

  @doc "Returns the Rust type expression for a descriptor or schema."
  @spec rust_type(descriptor() | schema()) :: String.t()
  def rust_type(%{kind: :primitive, rust_type: rust_type}), do: rust_type
  def rust_type(%{kind: :list, item: item}), do: "Vec<#{rust_type(item)}>"
  def rust_type(%{kind: :option, item: item}), do: "Option<#{rust_type(item)}>"

  def rust_type(%{kind: :map, key: key, value: value}),
    do: "std::collections::BTreeMap<#{rust_type(key)}, #{rust_type(value)}>"

  def rust_type(%{kind: kind, name: name}) when kind in [:struct, :enum], do: name

  @doc "Generates a Serde-ready Rust definition for a struct or enum schema."
  @spec rust_definition(schema()) :: String.t()
  def rust_definition(%{kind: :struct} = schema) do
    fields =
      schema.fields
      |> Enum.map(&rust_field_definition/1)
      |> Enum.join("\n")

    [
      derive_clause(),
      schema_serde_attribute(schema.serde),
      "pub struct #{schema.name} {",
      fields,
      "}"
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  def rust_definition(%{kind: :enum} = schema) do
    variants =
      schema.variants
      |> Enum.map(&rust_variant_definition/1)
      |> Enum.join("\n")

    [
      derive_clause(),
      schema_serde_attribute(schema.serde),
      "pub enum #{schema.name} {",
      variants,
      "}"
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
  end

  @doc "Encodes an Elixir value into a JSON-safe value following the schema."
  @spec encode(descriptor() | schema(), term()) :: result()
  def encode(schema, value), do: encode_value(schema, value)

  @doc "Decodes a JSON-safe value into an Elixir value following the schema."
  @spec decode(descriptor() | schema(), term()) :: result()
  def decode(schema, value), do: decode_value(schema, value)

  @doc "Returns a compact manifest that can be sent to Rust code generators."
  @spec manifest(schema()) :: map()
  def manifest(%{kind: :struct} = schema) do
    %{
      name: schema.name,
      kind: schema.kind,
      rust_type: rust_type(schema),
      serde: schema.serde,
      fields:
        Enum.map(schema.fields, fn field ->
          %{
            name: field.rust_name,
            wire_name: field.wire_name,
            rust_type: rust_type(field.type),
            required?: field.required?
          }
        end),
      coverage: schema.coverage
    }
  end

  def manifest(%{kind: :enum} = schema) do
    %{
      name: schema.name,
      kind: schema.kind,
      rust_type: rust_type(schema),
      serde: schema.serde,
      variants:
        Enum.map(schema.variants, fn variant ->
          %{
            name: variant.name,
            tag: variant.tag,
            kind: variant.kind
          }
        end),
      coverage: schema.coverage
    }
  end

  @doc "Infers a descriptor for a JSON-compatible Elixir value."
  @spec infer(term()) :: descriptor()
  def infer(value) when is_binary(value), do: primitive(:string)
  def infer(value) when is_integer(value), do: primitive(:integer)
  def infer(value) when is_float(value), do: primitive(:float)
  def infer(value) when is_boolean(value), do: primitive(:boolean)
  def infer(nil), do: option(primitive(:json))

  def infer([head | _tail]), do: list(infer(head))
  def infer([]), do: list(primitive(:json))

  def infer(value) when is_map(value),
    do: map_of(primitive(:string), primitive(:json))

  defp encode_value(%{kind: :primitive, type: :string}, value) when is_binary(value),
    do: {:ok, value}

  defp encode_value(%{kind: :primitive, type: :integer}, value) when is_integer(value),
    do: {:ok, value}

  defp encode_value(%{kind: :primitive, type: :float}, value) when is_number(value),
    do: {:ok, value * 1.0}

  defp encode_value(%{kind: :primitive, type: :boolean}, value) when is_boolean(value),
    do: {:ok, value}

  defp encode_value(%{kind: :primitive, type: :json}, value), do: {:ok, value}

  defp encode_value(%{kind: :primitive, type: type}, value),
    do: type_error("expected #{type}", value)

  defp encode_value(%{kind: :list, item: item}, values) when is_list(values) do
    map_result(values, &encode_value(item, &1))
  end

  defp encode_value(%{kind: :list}, value), do: type_error("expected list", value)

  defp encode_value(%{kind: :option}, nil), do: {:ok, nil}
  defp encode_value(%{kind: :option, item: item}, value), do: encode_value(item, value)

  defp encode_value(%{kind: :map, key: key, value: value_type}, value) when is_map(value) do
    value
    |> Enum.map(fn {entry_key, entry_value} ->
      with {:ok, encoded_key} <- encode_map_key(key, entry_key),
           {:ok, encoded_value} <- encode_value(value_type, entry_value) do
        {:ok, {encoded_key, encoded_value}}
      end
    end)
    |> collect_pairs()
  end

  defp encode_value(%{kind: :map}, value), do: type_error("expected map", value)

  defp encode_value(%{kind: :struct} = schema, value) when is_map(value) do
    schema.fields
    |> Enum.reduce_while({:ok, %{}}, fn field, {:ok, encoded} ->
      case field_value(value, field) do
        {:ok, nil} when field.skip_nil? ->
          {:cont, {:ok, encoded}}

        {:ok, nil} ->
          {:cont, {:ok, Map.put(encoded, field.wire_name, nil)}}

        {:ok, field_value} ->
          case encode_value(field.type, field_value) do
            {:ok, field_encoded} ->
              {:cont, {:ok, Map.put(encoded, field.wire_name, field_encoded)}}

            {:error, error} ->
              {:halt, {:error, Map.put(error, :field, field.wire_name)}}
          end

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp encode_value(%{kind: :struct}, value), do: type_error("expected struct map", value)

  defp encode_value(%{kind: :enum} = schema, value) do
    with {:ok, variant, payload} <- enum_input(schema, value),
         {:ok, encoded_payload} <- encode_variant_payload(variant, payload) do
      tag = schema.serde.tag
      content = schema.serde.content

      encoded =
        case variant.kind do
          :unit -> %{tag => variant.tag}
          _ -> %{tag => variant.tag, content => encoded_payload}
        end

      {:ok, encoded}
    end
  end

  defp decode_value(%{kind: :primitive} = type, value), do: encode_value(type, value)

  defp decode_value(%{kind: :list, item: item}, values) when is_list(values) do
    map_result(values, &decode_value(item, &1))
  end

  defp decode_value(%{kind: :list}, value), do: type_error("expected list", value)

  defp decode_value(%{kind: :option}, nil), do: {:ok, nil}
  defp decode_value(%{kind: :option, item: item}, value), do: decode_value(item, value)

  defp decode_value(%{kind: :map, value: value_type}, value) when is_map(value) do
    value
    |> Enum.map(fn {entry_key, entry_value} ->
      with {:ok, decoded_value} <- decode_value(value_type, entry_value) do
        {:ok, {entry_key, decoded_value}}
      end
    end)
    |> collect_pairs()
  end

  defp decode_value(%{kind: :map}, value), do: type_error("expected map", value)

  defp decode_value(%{kind: :struct} = schema, value) when is_map(value) do
    schema.fields
    |> Enum.reduce_while({:ok, %{}}, fn field, {:ok, decoded} ->
      case wire_value(value, field) do
        {:ok, nil} ->
          {:cont, {:ok, Map.put(decoded, field.name, nil)}}

        {:ok, field_value} ->
          case decode_value(field.type, field_value) do
            {:ok, field_decoded} -> {:cont, {:ok, Map.put(decoded, field.name, field_decoded)}}
            {:error, error} -> {:halt, {:error, Map.put(error, :field, field.wire_name)}}
          end

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp decode_value(%{kind: :struct}, value), do: type_error("expected struct map", value)

  defp decode_value(%{kind: :enum} = schema, value) when is_map(value) do
    tag = schema.serde.tag
    content = schema.serde.content
    variant_tag = Map.get(value, tag)
    variant = Enum.find(schema.variants, &(&1.tag == variant_tag or &1.name == variant_tag))

    cond do
      is_nil(variant) ->
        {:error, %{code: :unknown_variant, message: "unknown enum variant", variant: variant_tag}}

      variant.kind == :unit ->
        {:ok, {variant_key(variant), nil}}

      true ->
        with {:ok, decoded_payload} <- decode_variant_payload(variant, Map.get(value, content)) do
          {:ok, {variant_key(variant), decoded_payload}}
        end
    end
  end

  defp decode_value(%{kind: :enum}, value), do: type_error("expected enum map", value)

  defp encode_variant_payload(%{kind: :unit}, _payload), do: {:ok, nil}

  defp encode_variant_payload(%{kind: :tuple, payload: descriptor}, payload),
    do: encode_value(descriptor, payload)

  defp encode_variant_payload(%{kind: :struct, name: name, payload: fields}, payload) do
    schema = struct(name, fields)
    encode_value(schema, payload)
  end

  defp decode_variant_payload(%{kind: :tuple, payload: descriptor}, payload),
    do: decode_value(descriptor, payload)

  defp decode_variant_payload(%{kind: :struct, name: name, payload: fields}, payload) do
    schema = struct(name, fields)
    decode_value(schema, payload || %{})
  end

  defp enum_input(schema, {variant_name, payload}) do
    find_variant(schema, variant_name, payload)
  end

  defp enum_input(schema, %{variant: variant_name, value: payload}) do
    find_variant(schema, variant_name, payload)
  end

  defp enum_input(schema, value) when is_map(value) do
    tag = schema.serde.tag
    content = schema.serde.content
    find_variant(schema, Map.get(value, tag), Map.get(value, content))
  end

  defp enum_input(_schema, value), do: type_error("expected enum tuple or tagged map", value)

  defp find_variant(schema, variant_name, payload) do
    variant_name = to_string(variant_name || "")

    case Enum.find(schema.variants, &(&1.tag == variant_name or &1.name == variant_name)) do
      nil ->
        {:error,
         %{code: :unknown_variant, message: "unknown enum variant", variant: variant_name}}

      variant ->
        {:ok, variant, payload}
    end
  end

  defp field_value(value, field) do
    cond do
      Map.has_key?(value, field.name) ->
        {:ok, Map.fetch!(value, field.name)}

      Map.has_key?(value, field.wire_name) ->
        {:ok, Map.fetch!(value, field.wire_name)}

      field.has_default? ->
        {:ok, field.default}

      field.required? ->
        {:error,
         %{code: :missing_field, message: "missing required field", field: field.wire_name}}

      true ->
        {:ok, nil}
    end
  end

  defp wire_value(value, field) do
    cond do
      Map.has_key?(value, field.wire_name) ->
        {:ok, Map.fetch!(value, field.wire_name)}

      field.has_default? ->
        {:ok, field.default}

      field.required? ->
        {:error,
         %{code: :missing_field, message: "missing required field", field: field.wire_name}}

      true ->
        {:ok, nil}
    end
  end

  defp encode_map_key(%{kind: :primitive, type: :string}, key), do: {:ok, to_string(key)}

  defp encode_map_key(%{kind: :primitive, type: :integer}, key) when is_integer(key),
    do: {:ok, key}

  defp encode_map_key(_type, key), do: type_error("expected supported map key", key)

  defp map_result(values, mapper) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, mapped} ->
      case mapper.(value) do
        {:ok, item} -> {:cont, {:ok, [item | mapped]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, mapped} -> {:ok, Enum.reverse(mapped)}
      error -> error
    end
  end

  defp collect_pairs(results) do
    Enum.reduce_while(results, {:ok, %{}}, fn
      {:ok, {key, value}}, {:ok, acc} -> {:cont, {:ok, Map.put(acc, key, value)}}
      {:error, error}, _acc -> {:halt, {:error, error}}
    end)
  end

  defp rust_field_definition(field) do
    attrs =
      field
      |> field_serde_attributes()
      |> Enum.map(&"    #{&1}")

    definition = "    pub #{field.rust_name}: #{rust_type(field.type)},"

    (attrs ++ [definition])
    |> Enum.join("\n")
  end

  defp rust_variant_definition(%{kind: :unit} = variant), do: "    #{variant.name},"

  defp rust_variant_definition(%{kind: :tuple} = variant),
    do: "    #{variant.name}(#{rust_type(variant.payload)}),"

  defp rust_variant_definition(%{kind: :struct} = variant) do
    fields =
      variant.payload
      |> Enum.map(&"        pub #{&1.rust_name}: #{rust_type(&1.type)},")
      |> Enum.join("\n")

    "    #{variant.name} {\n#{fields}\n    },"
  end

  defp field_serde_attributes(field) do
    attrs = []

    attrs =
      if field.wire_name != field.rust_name,
        do: ["rename = \"#{field.wire_name}\"" | attrs],
        else: attrs

    attrs = if field.has_default?, do: ["default" | attrs], else: attrs

    attrs =
      if field.skip_nil?,
        do: ["skip_serializing_if = \"Option::is_none\"" | attrs],
        else: attrs

    attrs = Enum.reverse(attrs ++ Enum.map(field.serde, &to_string/1))

    case attrs do
      [] -> []
      attrs -> ["#[serde(#{Enum.join(attrs, ", ")})]"]
    end
  end

  defp schema_serde_attribute(serde) do
    attrs =
      []
      |> append_attr(:rename_all, serde[:rename_all])
      |> append_attr(:tag, serde[:tag])
      |> append_attr(:content, serde[:content])

    case attrs do
      [] -> ""
      attrs -> "#[serde(#{Enum.join(attrs, ", ")})]"
    end
  end

  defp append_attr(attrs, _key, nil), do: attrs
  defp append_attr(attrs, key, value), do: attrs ++ ["#{key} = \"#{value}\""]

  defp derive_clause do
    "#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]"
  end

  defp serde_options(opts) do
    opts
    |> Keyword.take([:rename_all, :tag, :content])
    |> Map.new()
  end

  defp normalize_type(type) do
    type = type |> to_string() |> String.downcase() |> String.to_existing_atom()

    if Map.has_key?(@primitive_types, type) do
      type
    else
      raise ArgumentError, "unsupported primitive type: #{type}"
    end
  rescue
    ArgumentError -> raise ArgumentError, "unsupported primitive type: #{inspect(type)}"
  end

  defp type_name(name) do
    name
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> Macro.camelize()
  end

  defp rust_identifier(name) do
    name
    |> to_string()
    |> Macro.underscore()
    |> String.replace(~r/[^a-z0-9_]/, "_")
  end

  defp variant_key(variant) do
    variant.name
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp type_error(expected, value) do
    {:error,
     %{
       code: :type_mismatch,
       message: expected,
       actual: inspect(value)
     }}
  end
end
