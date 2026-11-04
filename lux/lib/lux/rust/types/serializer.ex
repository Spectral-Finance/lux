defmodule Lux.Rust.Types.Serializer do
  @moduledoc """
  Bidirectional serialization between Elixir terms and the JSON-shaped
  representation produced by Rust's [`serde`](https://serde.rs) ecosystem.

  The serializer models the Elixir <-> Rust boundary without requiring a native
  Rust build: values are lifted to a *Serde wire* value (a JSON-compatible term)
  and lowered back again. This mirrors how `serde_json` represents the standard
  Rust data model:

    * `bool` -> Elixir boolean
    * signed/unsigned integers -> Elixir integer (range validated per type)
    * `f32`/`f64` -> Elixir float
    * `String`/`&str` -> Elixir binary (UTF-8 validated)
    * `char` -> single code point Elixir binary
    * `Option<T>` -> `nil` (or the wrapped value)
    * `Vec<T>`/slices -> Elixir list
    * tuples `(A, B)` -> Elixir tuple (encoded as a JSON array)
    * `HashMap<K, V>`/structs -> Elixir map with string keys (`__struct__` dropped)
    * enums -> atoms (unit variants) or `{variant, payload}` tagged tuples

  Encoding and decoding are explicit about failures: every function returns
  `{:ok, value}` or `{:error, reason}` where `reason` is a typed tuple. Untrusted
  wire input is never interned into new atoms, so decoding a JSON object always
  yields string keys and only declared enum variants become atoms.

  ## Examples

      iex> Lux.Rust.Types.Serializer.encode(42)
      {:ok, 42}

      iex> Lux.Rust.Types.Serializer.decode(%{"Ok" => 7}, {:enum, [ok: :i64]})
      {:ok, {:ok, 7}}
  """

  @typedoc "A Serde-compatible wire value."
  @type wire ::
          nil
          | boolean()
          | integer()
          | float()
          | String.t()
          | [wire()]
          | %{optional(String.t()) => wire()}

  @typedoc "A description of a Rust type used to drive (de)serialization."
  @type rust_type ::
          :bool
          | :i8
          | :i16
          | :i32
          | :i64
          | :i128
          | :u8
          | :u16
          | :u32
          | :u64
          | :u128
          | :f32
          | :f64
          | :string
          | :char
          | :atom
          | {:option, rust_type()}
          | {:vec, rust_type()}
          | {:list, rust_type()}
          | {:map, rust_type(), rust_type()}
          | {:tuple, [rust_type()]}
          | {:struct, keyword(rust_type()) | module()}
          | {:enum, keyword()}

  @typedoc "A typed serialization failure."
  @type reason ::
          {:unsupported_type, term()}
          | {:integer_out_of_range, integer()}
          | {:invalid_utf8, term()}
          | {:invalid_map_key, term()}
          | {:invalid_char, term()}
          | {:invalid_type, rust_type() | atom(), term()}
          | {:missing_field, atom() | String.t()}
          | {:unexpected_field, atom() | String.t()}
          | {:unexpected_null, atom() | String.t()}
          | {:unknown_variant, String.t()}
          | {:invalid_wire_value, term()}
          | {:non_round_trippable, term(), term()}

  @integer_ranges %{
    i8: {-128, 127},
    i16: {-32_768, 32_767},
    i32: {-2_147_483_648, 2_147_483_647},
    i64: {-9_223_372_036_854_775_808, 9_223_372_036_854_775_807},
    i128:
      {-170_141_183_460_469_231_731_687_303_715_884_105_728,
       170_141_183_460_469_231_731_687_303_715_884_105_727},
    u8: {0, 255},
    u16: {0, 65_535},
    u32: {0, 4_294_967_295},
    u64: {0, 18_446_744_073_709_551_615},
    u128: {0, 340_282_366_920_938_463_463_374_607_431_768_211_455}
  }

  @integer_types Map.keys(@integer_ranges)
  @float_types [:f32, :f64]
  @sequence_types [:vec, :list]

  @doc """
  Encodes an Elixir term into its Serde wire representation.

  Without a type specification the type is inferred from the Elixir value.
  """
  @spec encode(term()) :: {:ok, wire()} | {:error, reason()}
  def encode(term), do: encode(term, nil)

  @doc """
  Encodes an Elixir term using an explicit Rust `type` specification.

  The type drives validation (integer ranges, option/variant shapes, struct
  field sets) that cannot be inferred from the runtime value alone.
  """
  @spec encode(term(), rust_type() | nil) :: {:ok, wire()} | {:error, reason()}
  def encode(term, type), do: do_encode(term, type)

  @doc "Same as `encode/2` but raises on failure."
  @spec encode!(term(), rust_type() | nil) :: wire()
  def encode!(term, type \\ nil) do
    case encode(term, type) do
      {:ok, wire} ->
        wire

      {:error, reason} ->
        raise ArgumentError,
              "cannot encode #{inspect(term)} as #{inspect(type)}: #{inspect(reason)}"
    end
  end

  @doc """
  Decodes a Serde wire value back into an Elixir term.

  Without a type specification the type is inferred from the wire value. String
  keys are preserved (they are never interned into atoms).
  """
  @spec decode(wire()) :: {:ok, term()} | {:error, reason()}
  def decode(wire), do: decode(wire, nil)

  @doc """
  Decodes a Serde wire value using an explicit Rust `type` specification.

  Enum variants declared in the specification are lowered back to atoms; no other
  atoms are created from the wire input.
  """
  @spec decode(wire(), rust_type() | nil) :: {:ok, term()} | {:error, reason()}
  def decode(wire, type), do: do_decode(wire, type)

  @doc "Same as `decode/2` but raises on failure."
  @spec decode!(wire(), rust_type() | nil) :: term()
  def decode!(wire, type \\ nil) do
    case decode(wire, type) do
      {:ok, term} ->
        term

      {:error, reason} ->
        raise ArgumentError,
              "cannot decode #{inspect(wire)} as #{inspect(type)}: #{inspect(reason)}"
    end
  end

  @doc """
  Encodes a term to a JSON string using `Jason` (the same representation
  `serde_json` produces).
  """
  @spec to_json(term(), rust_type() | nil) :: {:ok, String.t()} | {:error, term()}
  def to_json(term, type \\ nil) do
    with {:ok, wire} <- encode(term, type) do
      Jason.encode(wire)
    end
  end

  @doc "Decodes a JSON string into an Elixir term."
  @spec from_json(String.t(), rust_type() | nil) :: {:ok, term()} | {:error, term()}
  def from_json(json, type \\ nil) when is_binary(json) do
    with {:ok, wire} <- Jason.decode(json) do
      decode(wire, type)
    end
  end

  @doc """
  Encodes and then decodes a term, returning `{:ok, term}` when the round trip
  is faithful or `{:error, reason}` otherwise.

  This is a convenient invariant check for custom type definitions.
  """
  @spec round_trip(term(), rust_type() | nil) :: {:ok, term()} | {:error, term()}
  def round_trip(term, type \\ nil) do
    with {:ok, wire} <- encode(term, type),
         {:ok, decoded} <- decode(wire, type) do
      if decoded == term do
        {:ok, decoded}
      else
        {:error, {:non_round_trippable, term, decoded}}
      end
    end
  end

  # ------------------------------------------------------------------
  # Encoding
  # ------------------------------------------------------------------

  defp do_encode(nil, type), do: encode_nil_value(type)
  defp do_encode(value, nil), do: encode_inferred(value)
  defp do_encode(value, :bool) when is_boolean(value), do: {:ok, value}
  defp do_encode(value, :bool), do: type_error(:bool, value)
  defp do_encode(value, type) when type in @integer_types, do: encode_integer(value, type)
  defp do_encode(value, type) when type in @float_types and is_float(value), do: {:ok, value}

  defp do_encode(value, type) when type in @float_types and is_integer(value),
    do: {:ok, value * 1.0}

  defp do_encode(value, type) when type in @float_types, do: type_error(type, value)
  defp do_encode(value, :string) when is_binary(value), do: encode_utf8(value)
  defp do_encode(value, :string), do: type_error(:string, value)
  defp do_encode(value, :atom) when is_atom(value), do: {:ok, Atom.to_string(value)}
  defp do_encode(value, :atom), do: type_error(:atom, value)
  defp do_encode(value, :char) when is_binary(value), do: encode_char(value)
  defp do_encode(value, :char), do: type_error(:char, value)
  defp do_encode(value, {:option, type}), do: do_encode(value, type)

  defp do_encode(value, {container, type}) when container in @sequence_types and is_list(value) do
    encode_sequence(value, type)
  end

  defp do_encode(value, {container, _type}) when container in @sequence_types do
    type_error(container, value)
  end

  defp do_encode(value, {:map, key_type, value_type}) when is_map(value) do
    encode_map(value, key_type, value_type)
  end

  defp do_encode(value, {:map, _key_type, _value_type}), do: type_error(:map, value)

  defp do_encode(value, {:tuple, types}) when is_tuple(value) do
    if tuple_size(value) == length(types) do
      value |> Tuple.to_list() |> Enum.zip(types) |> encode_pairs()
    else
      type_error(:tuple, value)
    end
  end

  defp do_encode(value, {:tuple, _types}), do: type_error(:tuple, value)

  defp do_encode(%{__struct__: _} = struct, {:struct, module}) when is_atom(module) do
    encode_struct(struct, module)
  end

  defp do_encode(value, {:struct, fields}) when is_map(value), do: encode_fields(value, fields)
  defp do_encode(value, {:struct, _fields}), do: type_error(:struct, value)
  defp do_encode(value, {:enum, variants}), do: encode_enum(value, variants)
  defp do_encode(value, type), do: type_error(type, value)

  defp encode_nil_value(nil), do: {:ok, nil}
  defp encode_nil_value({:option, _type}), do: {:ok, nil}
  defp encode_nil_value(type), do: {:error, {:unexpected_null, type}}

  defp encode_inferred(nil), do: {:ok, nil}
  defp encode_inferred(value) when is_boolean(value), do: {:ok, value}
  defp encode_inferred(value) when is_integer(value), do: encode_integer(value, :i64)
  defp encode_inferred(value) when is_float(value), do: {:ok, value}
  defp encode_inferred(value) when is_binary(value), do: encode_utf8(value)
  defp encode_inferred(value) when is_atom(value), do: {:ok, Atom.to_string(value)}

  defp encode_inferred(%{__struct__: _} = struct),
    do: struct |> Map.from_struct() |> encode_inferred_map()

  defp encode_inferred(value) when is_map(value), do: encode_inferred_map(value)

  defp encode_inferred({variant, value}) when is_atom(variant),
    do: encode_enum({variant, value}, nil)

  defp encode_inferred(value) when is_tuple(value), do: value |> Tuple.to_list() |> encode_lists()
  defp encode_inferred(value) when is_list(value), do: encode_lists(value)
  defp encode_inferred(value), do: {:error, {:unsupported_type, value}}

  defp encode_integer(value, _type) when not is_integer(value), do: type_error(:integer, value)

  defp encode_integer(value, type) do
    {min, max} = Map.fetch!(@integer_ranges, type)

    if value >= min and value <= max do
      {:ok, value}
    else
      {:error, {:integer_out_of_range, value}}
    end
  end

  defp encode_utf8(value) do
    if String.valid?(value), do: {:ok, value}, else: {:error, {:invalid_utf8, value}}
  end

  defp encode_char(value) do
    if String.valid?(value) and String.length(value) == 1 do
      {:ok, value}
    else
      {:error, {:invalid_char, value}}
    end
  end

  defp encode_sequence(value, type) do
    value |> Enum.map(&{&1, type}) |> encode_pairs()
  end

  defp encode_lists(value) do
    value |> Enum.map(&{&1, nil}) |> encode_pairs()
  end

  defp encode_pairs(pairs) do
    Enum.reduce_while(pairs, {:ok, []}, fn {value, type}, {:ok, acc} ->
      case do_encode(value, type) do
        {:ok, wire} -> {:cont, {:ok, [wire | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> finish_sequence()
  end

  defp finish_sequence({:ok, acc}), do: {:ok, Enum.reverse(acc)}
  defp finish_sequence({:error, _reason} = error), do: error

  defp encode_map(value, key_type, value_type) do
    Enum.reduce_while(value, {:ok, %{}}, fn {key, val}, {:ok, acc} ->
      with {:ok, wire_key} <- encode_key(key, key_type),
           {:ok, wire_val} <- do_encode(val, value_type) do
        {:cont, {:ok, Map.put(acc, wire_key, wire_val)}}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp encode_inferred_map(value), do: encode_map(value, nil, nil)

  defp encode_key(key, nil) when is_binary(key), do: {:ok, key}
  defp encode_key(key, nil) when is_atom(key), do: {:ok, Atom.to_string(key)}
  defp encode_key(key, nil), do: {:error, {:invalid_map_key, key}}
  defp encode_key(key, :string) when is_binary(key), do: encode_utf8(key)
  defp encode_key(key, :string), do: {:error, {:invalid_map_key, key}}
  defp encode_key(key, :atom) when is_atom(key), do: {:ok, Atom.to_string(key)}
  defp encode_key(key, _type), do: {:error, {:invalid_map_key, key}}

  defp encode_struct(struct, module) do
    fields = module |> struct() |> Map.from_struct() |> Map.keys() |> Enum.map(&{&1, nil})
    encode_fields(struct, fields)
  end

  defp encode_fields(value, fields) do
    value = if is_struct(value), do: Map.from_struct(value), else: value
    field_names = Enum.map(fields, fn {name, _type} -> name end)

    case missing_field(value, field_names) do
      nil ->
        case extra_field(value, field_names) do
          nil -> encode_known_fields(value, fields)
          extra -> {:error, {:unexpected_field, extra}}
        end

      missing ->
        {:error, {:missing_field, missing}}
    end
  end

  defp missing_field(value, field_names) do
    Enum.find(field_names, fn name -> match?(:error, fetch_field(value, name)) end)
  end

  defp extra_field(value, field_names) do
    allowed = MapSet.new(field_names ++ Enum.map(field_names, &Atom.to_string/1))
    Enum.find(Map.keys(value), fn key -> key not in allowed end)
  end

  defp fetch_field(value, name) do
    cond do
      Map.has_key?(value, name) -> {:ok, Map.fetch!(value, name)}
      Map.has_key?(value, Atom.to_string(name)) -> {:ok, Map.fetch!(value, Atom.to_string(name))}
      true -> :error
    end
  end

  defp encode_known_fields(value, fields) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {name, type}, {:ok, acc} ->
      {:ok, field_value} = fetch_field(value, name)

      case do_encode(field_value, type) do
        {:ok, wire} -> {:cont, {:ok, Map.put(acc, Atom.to_string(name), wire)}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp encode_enum(value, variants) do
    case value do
      {variant, payload} when is_atom(variant) -> encode_variant(variant, payload, variants)
      variant when is_atom(variant) -> encode_unit_variant(variant, variants)
      other -> type_error(:enum, other)
    end
  end

  defp encode_unit_variant(variant, nil), do: {:ok, Macro.camelize(Atom.to_string(variant))}

  defp encode_unit_variant(variant, variants) do
    case Keyword.get(variants, variant) do
      nil -> {:error, {:unknown_variant, Atom.to_string(variant)}}
      :unit -> {:ok, Macro.camelize(Atom.to_string(variant))}
      other -> type_error(other, variant)
    end
  end

  defp encode_variant(variant, payload, nil) do
    with {:ok, wire} <- encode_inferred(payload) do
      {:ok, %{Macro.camelize(Atom.to_string(variant)) => wire}}
    end
  end

  defp encode_variant(variant, payload, variants) do
    case Keyword.get(variants, variant) do
      nil -> {:error, {:unknown_variant, Atom.to_string(variant)}}
      :unit -> {:ok, Macro.camelize(Atom.to_string(variant))}
      type -> encode_tagged_variant(variant, payload, type)
    end
  end

  defp encode_tagged_variant(variant, payload, type) do
    with {:ok, wire} <- do_encode(payload, type) do
      {:ok, %{Macro.camelize(Atom.to_string(variant)) => wire}}
    end
  end

  defp type_error(type, value), do: {:error, {:invalid_type, type, value}}

  # ------------------------------------------------------------------
  # Decoding
  # ------------------------------------------------------------------

  defp do_decode(nil, nil), do: {:ok, nil}
  defp do_decode(nil, {:option, _type}), do: {:ok, nil}
  defp do_decode(nil, type), do: {:error, {:unexpected_null, type}}
  defp do_decode(wire, nil), do: decode_inferred(wire)
  defp do_decode(wire, :bool) when is_boolean(wire), do: {:ok, wire}
  defp do_decode(wire, :bool), do: type_error(:bool, wire)
  defp do_decode(wire, type) when type in @integer_types, do: decode_integer(wire, type)
  defp do_decode(wire, type) when type in @float_types and is_number(wire), do: {:ok, wire * 1.0}
  defp do_decode(wire, type) when type in @float_types, do: type_error(type, wire)
  defp do_decode(wire, :string) when is_binary(wire), do: encode_utf8(wire)
  defp do_decode(wire, :string), do: type_error(:string, wire)
  defp do_decode(wire, :atom) when is_binary(wire), do: encode_utf8(wire)
  defp do_decode(wire, :atom), do: type_error(:atom, wire)
  defp do_decode(wire, :char) when is_binary(wire), do: encode_char(wire)
  defp do_decode(wire, :char), do: type_error(:char, wire)
  defp do_decode(wire, {:option, type}), do: do_decode(wire, type)

  defp do_decode(wire, {container, type}) when container in @sequence_types and is_list(wire) do
    decode_sequence(wire, type)
  end

  defp do_decode(wire, {container, _type}) when container in @sequence_types,
    do: type_error(container, wire)

  defp do_decode(wire, {:map, key_type, value_type}) when is_map(wire) do
    decode_map(wire, key_type, value_type)
  end

  defp do_decode(wire, {:map, _key_type, _value_type}), do: type_error(:map, wire)

  defp do_decode(wire, {:tuple, types}) when is_list(wire) do
    if length(wire) == length(types) do
      case wire |> Enum.zip(types) |> decode_pairs() do
        {:ok, values} -> {:ok, List.to_tuple(values)}
        error -> error
      end
    else
      type_error(:tuple, wire)
    end
  end

  defp do_decode(wire, {:tuple, _types}), do: type_error(:tuple, wire)

  defp do_decode(wire, {:struct, module}) when is_atom(module) and is_map(wire),
    do: decode_struct(wire, module)

  defp do_decode(wire, {:struct, fields}) when is_map(wire), do: decode_fields(wire, fields)
  defp do_decode(wire, {:struct, _fields}), do: type_error(:struct, wire)
  defp do_decode(wire, {:enum, variants}), do: decode_enum(wire, variants)
  defp do_decode(wire, type), do: type_error(type, wire)

  defp decode_inferred(nil), do: {:ok, nil}
  defp decode_inferred(wire) when is_boolean(wire), do: {:ok, wire}
  defp decode_inferred(wire) when is_integer(wire), do: {:ok, wire}
  defp decode_inferred(wire) when is_float(wire), do: {:ok, wire}
  defp decode_inferred(wire) when is_binary(wire), do: encode_utf8(wire)
  defp decode_inferred(wire) when is_list(wire), do: decode_sequence(wire, nil)
  defp decode_inferred(wire) when is_map(wire), do: decode_map(wire, nil, nil)
  defp decode_inferred(wire), do: {:error, {:invalid_wire_value, wire}}

  defp decode_integer(wire, _type) when not is_integer(wire), do: type_error(:integer, wire)

  defp decode_integer(wire, type) do
    {min, max} = Map.fetch!(@integer_ranges, type)

    if wire >= min and wire <= max do
      {:ok, wire}
    else
      {:error, {:integer_out_of_range, wire}}
    end
  end

  defp decode_sequence(wire, type) do
    wire |> Enum.map(&{&1, type}) |> decode_pairs()
  end

  defp decode_pairs(pairs) do
    Enum.reduce_while(pairs, {:ok, []}, fn {wire, type}, {:ok, acc} ->
      case do_decode(wire, type) do
        {:ok, term} -> {:cont, {:ok, [term | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> finish_sequence()
  end

  defp decode_map(wire, key_type, value_type) do
    Enum.reduce_while(wire, {:ok, %{}}, fn {key, val}, {:ok, acc} ->
      with {:ok, term_key} <- decode_key(key, key_type),
           {:ok, term_val} <- do_decode(val, value_type) do
        {:cont, {:ok, Map.put(acc, term_key, term_val)}}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp decode_key(key, _type) when is_binary(key), do: encode_utf8(key)
  defp decode_key(key, _type), do: {:error, {:invalid_map_key, key}}

  defp decode_struct(wire, module) do
    fields = module |> struct() |> Map.from_struct() |> Map.keys() |> Enum.map(&{&1, nil})

    case decode_fields(wire, fields) do
      {:ok, map} -> {:ok, struct(module, map)}
      error -> error
    end
  end

  defp decode_fields(wire, fields) do
    field_names = Enum.map(fields, fn {name, _type} -> name end)
    allowed = MapSet.new(Enum.map(field_names, &Atom.to_string/1))

    case find_extra_key(Map.keys(wire), allowed) do
      nil -> decode_present_fields(wire, fields, field_names)
      extra -> {:error, {:unexpected_field, extra}}
    end
  end

  defp decode_present_fields(wire, fields, field_names) do
    case find_missing_key(wire, field_names) do
      nil -> decode_field_values(wire, fields)
      missing -> {:error, {:missing_field, missing}}
    end
  end

  defp find_extra_key(keys, allowed), do: Enum.find(keys, fn key -> key not in allowed end)

  defp find_missing_key(wire, field_names) do
    Enum.find(field_names, fn name -> not Map.has_key?(wire, Atom.to_string(name)) end)
  end

  defp decode_field_values(wire, fields) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {name, type}, {:ok, acc} ->
      case do_decode(Map.get(wire, Atom.to_string(name)), type) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp decode_enum(wire, variants) when is_binary(wire) do
    unit_names =
      for {variant, :unit} <- variants,
          into: %{},
          do: {Macro.camelize(Atom.to_string(variant)), variant}

    case Map.fetch(unit_names, wire) do
      {:ok, variant} -> {:ok, variant}
      :error -> {:error, {:unknown_variant, wire}}
    end
  end

  defp decode_enum(wire, variants) when is_map(wire) and map_size(wire) == 1 do
    [{name, payload}] = Map.to_list(wire)
    decode_named_variant(name, payload, variants)
  end

  defp decode_enum(wire, _variants), do: {:error, {:invalid_wire_value, wire}}

  defp decode_named_variant(name, payload, variants) do
    case Enum.find(variants, fn {variant, _type} ->
           Macro.camelize(Atom.to_string(variant)) == name
         end) do
      nil -> {:error, {:unknown_variant, name}}
      {_variant, :unit} -> {:error, {:invalid_wire_value, name}}
      {variant, type} -> decode_tagged_variant(variant, payload, type)
    end
  end

  defp decode_tagged_variant(variant, payload, type) do
    case do_decode(payload, type) do
      {:ok, value} -> {:ok, {variant, value}}
      error -> error
    end
  end
end
