defmodule Lux.Rust.TypeSystem do
  @moduledoc """
  Pure-Elixir Rust type system and serialization for cross-language data exchange.

  Provides bidirectional mapping between Elixir types and Rust-FFI compatible types,
  supporting custom type definitions, struct/enum serialization, Serde-compatible
  encoding, and compact binary formats without requiring native Rustler compilation.
  """

  # ── Type Mapping ──────────────────────────────────────────────────────────

  @type_mapping %{
    "i8" => :integer,
    "i16" => :integer,
    "i32" => :integer,
    "i64" => :integer,
    "u8" => :integer,
    "u16" => :integer,
    "u32" => :integer,
    "u64" => :integer,
    "f32" => :float,
    "f64" => :float,
    "bool" => :boolean,
    "String" => :string,
    "Vec" => :list,
    "Option" => :nullable,
    "Result" => {:tuple, 2}
  }

  @doc """
  Maps a Rust type string to its corresponding Elixir type.
  """
  def map_rust_type(rust_type) when is_binary(rust_type) do
    base = String.replace(rust_type, ~r/<.*>/, "") |> String.trim()

    case Map.get(@type_mapping, base) do
      nil ->
        if String.starts_with?(base, "Vec<") or String.starts_with?(rust_type, "[") do
          {:list_type, extract_inner_type(rust_type)}
        else
          {:custom, base}
        end

      mapped ->
        {:ok, mapped}
    end
  end

  def map_rust_type(rust_type), do: {:error, "Expected binary type, got: #{inspect(rust_type)}"}

  defp extract_inner_type(<<"Vec<", rest::binary>>) do
    rest |> String.replace_suffix(">", "") |> String.trim()
  end

  defp extract_inner_type(type_str) do
    case Regex.run(~r/\[(.*?);/, type_str) do
      [_, inner] -> String.trim(inner)
      nil -> type_str
    end
  end

  @doc """
  Maps an Elixir term to the closest Rust type name.
  """
  def to_rust_type(value) when is_integer(value), do: "i64"
  def to_rust_type(value) when is_float(value), do: "f64"
  def to_rust_type(value) when is_boolean(value), do: "bool"
  def to_rust_type(value) when is_binary(value), do: "String"
  def to_rust_type(value) when is_atom(value) and not is_boolean(value), do: "String"
  def to_rust_type(value) when is_list(value), do: "Vec<#{to_rust_type(List.first(value) || "String")}>"
  def to_rust_type(value) when is_map(value), do: "HashMap<String, String>"
  def to_rust_type(nil), do: "Option"

  # ── Custom Type Definitions ───────────────────────────────────────────────

  defmodule TypeDef do
    @moduledoc """
    Defines a custom Rust type with field mappings and Serde attributes.
    """
    defstruct [:name, :fields, :serde_attrs, :derives]

    @type t :: %__MODULE__{
            name: String.t(),
            fields: [{String.t(), String.t()}],
            serde_attrs: keyword(),
            derives: [String.t()]
          }

    def new(name, fields, opts \\ []) do
      %__MODULE__{
        name: name,
        fields: fields,
        serde_attrs: Keyword.get(opts, :serde_attrs, []),
        derives: Keyword.get(opts, :derives, ["Debug", "Clone", "Serialize", "Deserialize"])
      }
    end
  end

  defmodule EnumDef do
    @moduledoc """
    Defines a Rust enum with variants, optionally carrying data.
    """
    defstruct [:name, :variants, :derives]

    @type variant :: {name :: String.t(), fields :: [String.t()] | nil}
    @type t :: %__MODULE__{
            name: String.t(),
            variants: [variant()],
            derives: [String.t()]
          }

    def new(name, variants, opts \\ []) do
      %__MODULE__{
        name: name,
        variants: variants,
        derives: Keyword.get(opts, :derives, ["Debug", "Clone", "Serialize", "Deserialize"])
      }
    end
  end

  @doc """
  Generates a Rust `struct` definition string from a TypeDef.
  """
  def generate_struct(%TypeDef{name: name, fields: fields, derives: derives}) do
    derives_str =
      derives
      |> Enum.map(&"##{&1}")
      |> Enum.join(", ")

    fields_str =
      fields
      |> Enum.map(fn {fname, ftype} ->
        "    pub #{fname}: #{ftype},"
      end)
      |> Enum.join("\n")

    """
    #[derive(#{derives_str})]
    pub struct #{name} {
    #{fields_str}
    }
    """
  end

  @doc """
  Generates a Rust `enum` definition string from an EnumDef.
  """
  def generate_enum(%EnumDef{name: name, variants: variants, derives: derives}) do
    derives_str =
      derives
      |> Enum.map(&"##{&1}")
      |> Enum.join(", ")

    variants_str =
      variants
      |> Enum.map(fn
        {vname, nil} -> "    #{vname},"
        {vname, fields} when is_list(fields) ->
          field_str = fields |> Enum.map(&"#{&1}") |> Enum.join(", ")
          "    #{vname}(#{field_str}),"
      end)
      |> Enum.join("\n")

    """
    #[derive(#{derives_str})]
    pub enum #{name} {
    #{variants_str}
    }
    """
  end

  # ── Struct / Enum Support ─────────────────────────────────────────────────

  @doc """
  Converts an Elixir struct to Rust-compatible serialized form.
  """
  def struct_to_rust(%mod{} = struct) do
    mod_name = mod |> Module.split() |> Enum.join("::")

    fields =
      struct
      |> Map.from_struct()
      |> Enum.map(fn {key, val} ->
        {Atom.to_string(key), elixir_to_rust_value(val)}
      end)

    %{__type__: mod_name, __fields__: fields}
  end

  @doc """
  Converts a Rust-compatible map back into an Elixir struct.
  """
  def rust_to_struct(%{__type__: type, __fields__: fields}) do
    mod =
      type
      |> String.split("::")
      |> Module.concat()

    field_map =
      fields
      |> Enum.reduce(%{}, fn {key, val}, acc ->
        Map.put(acc, String.to_existing_atom(key), rust_to_elixir_value(val))
      end)

    struct(mod, field_map)
  rescue
    _ -> {:error, "Could not reconstruct struct for type: #{type}"}
  end

  def rust_to_struct(other), do: {:error, "Expected type map, got: #{inspect(other)}"}

  @doc """
  Converts an Elixir atom/enum value to Rust enum format.
  """
  def enum_to_rust(value, variants) when is_atom(value) do
    variant_str = String.upcase(Atom.to_string(value))

    if variant_str in variants do
      {:ok, %{__enum__: variant_str}}
    else
      {:error, "Variant #{variant_str} not found in #{inspect(variants)}"}
    end
  end

  def enum_to_rust(value, _variants), do: {:error, "Expected atom, got: #{inspect(value)}"}

  @doc """
  Converts a Rust enum back to Elixir atom.
  """
  def rust_to_enum(%{__enum__: variant}) do
    {:ok, String.downcase(variant) |> String.to_atom()}
  end

  def rust_to_enum(other), do: {:error, "Expected enum map, got: #{inspect(other)}"}

  # ── Serde Integration ─────────────────────────────────────────────────────

  @doc """
  Serializes Elixir data into Serde-compatible JSON with type annotations.
  Supports :json, :binary, :compact, and :bincode formats.
  """
  def serialize(value, target_type \\ "json")

  def serialize(value, "json") do
    annotated = annotate_types(value)
    case Jason.encode(annotated) do
      {:ok, encoded} -> {:ok, encoded}
      error -> error
    end
  end

  def serialize(value, "binary") do
    annotated = annotate_types(value)

    case Jason.encode_to_iodata(annotated) do
      {:ok, iodata} -> {:ok, IO.iodata_to_binary(iodata)}
      error -> error
    end
  end

  def serialize(value, "compact") do
    compact_encode(value)
  end

  def serialize(value, "bincode") do
    to_bincode(value)
  end

  def serialize(_value, target_type) do
    {:error, "Unknown target type: #{target_type}"}
  end

  @doc """
  Deserializes data from Serde-compatible formats back to Elixir terms.
  """
  def deserialize(data, source_type \\ "json")

  def deserialize(data, "json") when is_binary(data) do
    with {:ok, decoded} <- Jason.decode(data) do
      {:ok, deannotate_types(decoded)}
    end
  end

  def deserialize(data, "binary") when is_binary(data) do
    with {:ok, decoded} <- Jason.decode(data) do
      {:ok, deannotate_types(decoded)}
    end
  end

  def deserialize(data, "compact") when is_binary(data) do
    compact_decode(data)
  end

  def deserialize(data, "bincode") when is_binary(data) do
    from_bincode(data)
  end

  def deserialize(_data, source_type) do
    {:error, "Unknown source type: #{source_type}"}
  end

  # ── Bidirectional Conversion ──────────────────────────────────────────────

  @doc """
  Converts an Elixir value to a Rust-FFI-compatible representation.
  """
  def elixir_to_rust_value(value) when is_integer(value), do: %{__type__: "i64", __value__: value}
  def elixir_to_rust_value(value) when is_float(value), do: %{__type__: "f64", __value__: value}
  def elixir_to_rust_value(value) when is_boolean(value), do: %{__type__: "bool", __value__: value}
  def elixir_to_rust_value(value) when is_binary(value), do: %{__type__: "String", __value__: value}
  def elixir_to_rust_value(value) when is_atom(value), do: %{__type__: "String", __value__: Atom.to_string(value)}
  def elixir_to_rust_value(nil), do: %{__type__: "Option", __value__: nil}

  def elixir_to_rust_value(list) when is_list(list) do
    elem_type = if list == [], do: "String", else: to_rust_type(hd(list))
    %{__type__: "Vec<#{elem_type}>", __value__: Enum.map(list, &elixir_to_rust_value/1)}
  end

  def elixir_to_rust_value(map) when is_map(map) do
    serialized =
      map
      |> Enum.map(fn {k, v} -> {to_string(k), elixir_to_rust_value(v)} end)
      |> Map.new()

    %{__type__: "HashMap<String, String>", __value__: serialized}
  end

  @doc """
  Converts a Rust-FFI-compatible representation back to an Elixir value.
  """
  def rust_to_elixir_value(%{__type__: "i64", __value__: val}), do: val
  def rust_to_elixir_value(%{__type__: "f64", __value__: val}), do: val
  def rust_to_elixir_value(%{__type__: "bool", __value__: val}), do: val
  def rust_to_elixir_value(%{__type__: "String", __value__: val}), do: val
  def rust_to_elixir_value(%{__type__: "Option", __value__: val}), do: val

  def rust_to_elixir_value(%{__type__: "Vec<" <> _, __value__: vals}) when is_list(vals) do
    Enum.map(vals, &rust_to_elixir_value/1)
  end

  def rust_to_elixir_value(%{__type__: "HashMap" <> _, __value__: vals}) when is_map(vals) do
    vals
    |> Enum.map(fn {k, v} -> {k, rust_to_elixir_value(v)} end)
    |> Map.new()
  end

  def rust_to_elixir_value(%{__type__: custom, __value__: val}) do
    {:custom, custom, val}
  end

  def rust_to_elixir_value(other), do: other

  # ── Private Helpers ───────────────────────────────────────────────────────

  defp annotate_types(value) when is_integer(value), do: %{"__serde_type" => "i64", "value" => value}
  defp annotate_types(value) when is_float(value), do: %{"__serde_type" => "f64", "value" => value}
  defp annotate_types(value) when is_boolean(value), do: %{"__serde_type" => "bool", "value" => value}
  defp annotate_types(value) when is_binary(value), do: %{"__serde_type" => "string", "value" => value}
  defp annotate_types(value) when is_atom(value), do: %{"__serde_type" => "string", "value" => Atom.to_string(value)}
  defp annotate_types(nil), do: %{"__serde_type" => "null", "value" => nil}

  defp annotate_types(list) when is_list(list) do
    %{"__serde_type" => "array", "items" => Enum.map(list, &annotate_types/1)}
  end

  defp annotate_types(map) when is_map(map) do
    items =
      map
      |> Enum.map(fn {k, v} -> %{"key" => annotate_types(k), "value" => annotate_types(v)} end)

    %{"__serde_type" => "map", "items" => items}
  end

  defp deannotate_types(%{"__serde_type" => _, "value" => val}), do: val

  defp deannotate_types(%{"__serde_type" => "array", "items" => items}) do
    Enum.map(items, &deannotate_types/1)
  end

  defp deannotate_types(%{"__serde_type" => "map", "items" => items}) do
    items
    |> Enum.reduce(%{}, fn %{"key" => k, "value" => v}, acc ->
      Map.put(acc, deannotate_types(k), deannotate_types(v))
    end)
  end

  defp deannotate_types(other), do: other

  defp compact_encode(value) do
    # Compact binary encoding: tags each value with a single-byte type prefix
    encoded = compact_encode_value(value)
    {:ok, encoded}
  end

  defp compact_encode_value(value) when is_integer(value), do: <<0x01, value::64-signed>>
  defp compact_encode_value(value) when is_float(value), do: <<0x02, value::64-float>>
  defp compact_encode_value(value) when is_boolean(value), do: <<0x03, if(value, do: 1, else: 0)>>
  defp compact_encode_value(value) when is_binary(value), do: <<0x04, byte_size(value)::32, value::binary>>
  defp compact_encode_value(nil), do: <<0x00>>

  defp compact_encode_value(list) when is_list(list) do
    items = Enum.map(list, &compact_encode_value/1)
    <<0x05, length(list)::32, items::binary>>
  end

  defp compact_encode_value(map) when is_map(map) do
    items =
      Enum.reduce(map, <<>>, fn {k, v}, acc ->
        acc <> compact_encode_value(k) <> compact_encode_value(v)
      end)

    <<0x06, map_size(map)::32, items::binary>>
  end

  defp compact_decode(data) do
    case compact_decode_value(data) do
      {value, ""} -> {:ok, value}
      {value, _rest} -> {:ok, value}
      error -> error
    end
  rescue
    e -> {:error, "Compact decode error: #{Exception.message(e)}"}
  end

  defp compact_decode_value(<<0x00, rest::binary>>), do: {nil, rest}
  defp compact_decode_value(<<0x01, value::64-signed, rest::binary>>), do: {value, rest}
  defp compact_decode_value(<<0x02, value::64-float, rest::binary>>), do: {value, rest}
  defp compact_decode_value(<<0x03, 0, rest::binary>>), do: {false, rest}
  defp compact_decode_value(<<0x03, 1, rest::binary>>), do: {true, rest}

  defp compact_decode_value(<<0x04, len::32, value::binary-size(len), rest::binary>>),
    do: {value, rest}

  defp compact_decode_value(<<0x05, len::32, rest::binary>>) do
    {items, rest} = decode_n(len, rest, [])
    {Enum.reverse(items), rest}
  end

  defp compact_decode_value(<<0x06, len::32, rest::binary>>) do
    {pairs, rest} = decode_map_pairs(len, rest, %{})
    {pairs, rest}
  end

  defp compact_decode_value(_other), do: {:error, "Unknown compact type tag"}

  defp decode_n(0, rest, acc), do: {acc, rest}

  defp decode_n(n, rest, acc) when n > 0 do
    {item, rest} = compact_decode_value(rest)
    decode_n(n - 1, rest, [item | acc])
  end

  defp decode_map_pairs(0, rest, acc), do: {acc, rest}

  defp decode_map_pairs(n, rest, acc) do
    {k, rest} = compact_decode_value(rest)
    {v, rest} = compact_decode_value(rest)
    decode_map_pairs(n - 1, rest, Map.put(acc, k, v))
  end

  defp to_bincode(value) do
    # Simple bincode-like encoding (little-endian tagged format)
    try do
      {:ok, bincode_encode_value(value)}
    rescue
      e -> {:error, "Bincode encoding error: #{Exception.message(e)}"}
    end
  end

  defp bincode_encode_value(value) when is_integer(value), do: <<0x00, value::64-signed-little>>
  defp bincode_encode_value(value) when is_float(value), do: <<0x01, value::64-float-little>>
  defp bincode_encode_value(value) when is_boolean(value), do: <<0x02, if(value, do: 1, else: 0)>>
  defp bincode_encode_value(value) when is_binary(value), do: <<0x03, byte_size(value)::64-little, value::binary>>
  defp bincode_encode_value(nil), do: <<0x04>>

  defp bincode_encode_value(list) when is_list(list) do
    items = Enum.map_join(list, &bincode_encode_value/1)
    <<0x05, length(list)::64-little, items::binary>>
  end

  defp bincode_encode_value(map) when is_map(map) do
    items =
      Enum.reduce(map, <<>>, fn {k, v}, acc ->
        acc <> bincode_encode_value(k) <> bincode_encode_value(v)
      end)

    <<0x06, map_size(map)::64-little, items::binary>>
  end

  defp from_bincode(data) do
    case bincode_decode_value(data) do
      {value, ""} -> {:ok, value}
      {value, _rest} -> {:ok, value}
      error -> error
    end
  rescue
    e -> {:error, "Bincode decode error: #{Exception.message(e)}"}
  end

  defp bincode_decode_value(<<0x00, value::64-signed-little, rest::binary>>), do: {value, rest}
  defp bincode_decode_value(<<0x01, value::64-float-little, rest::binary>>), do: {value, rest}
  defp bincode_decode_value(<<0x02, 0, rest::binary>>), do: {false, rest}
  defp bincode_decode_value(<<0x02, 1, rest::binary>>), do: {true, rest}

  defp bincode_decode_value(<<0x03, len::64-little, value::binary-size(len), rest::binary>>),
    do: {value, rest}

  defp bincode_decode_value(<<0x04, rest::binary>>), do: {nil, rest}

  defp bincode_decode_value(<<0x05, len::64-little, rest::binary>>) do
    {items, rest} = bincode_decode_n(len, rest, [])
    {Enum.reverse(items), rest}
  end

  defp bincode_decode_value(<<0x06, len::64-little, rest::binary>>) do
    {pairs, rest} = bincode_decode_map_pairs(len, rest, %{})
    {pairs, rest}
  end

  defp bincode_decode_value(_other), do: {:error, "Unknown bincode type tag"}

  defp bincode_decode_n(0, rest, acc), do: {acc, rest}

  defp bincode_decode_n(n, rest, acc) when n > 0 do
    {item, rest} = bincode_decode_value(rest)
    bincode_decode_n(n - 1, rest, [item | acc])
  end

  defp bincode_decode_map_pairs(0, rest, acc), do: {acc, rest}

  defp bincode_decode_map_pairs(n, rest, acc) do
    {k, rest} = bincode_decode_value(rest)
    {v, rest} = bincode_decode_value(rest)
    bincode_decode_map_pairs(n - 1, rest, Map.put(acc, k, v))
  end
end
