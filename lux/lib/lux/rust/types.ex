defmodule Lux.Rust.Types do
  @moduledoc """
  Bidirectional type mapping between Elixir and Rust types.

  This module is the type-system companion for Rustler NIF integration. It
  provides pure-Elixir utilities for converting, validating, and serializing
  values that cross the Elixir/Rust boundary without requiring actual NIFs to
  be compiled.

  ## Type mapping

  | Elixir            | Rust                                |
  |-------------------|-------------------------------------|
  | `integer`         | `i8 / i32 / i64 / u8 / u32 / u64`  |
  | `float`           | `f32 / f64`                         |
  | `boolean`         | `bool`                              |
  | `binary`          | `String / Vec<u8>`                  |
  | `atom`            | enum variant (string repr)          |
  | `list`            | `Vec<T>`                            |
  | `map`             | `HashMap<String, V>` or struct      |
  | `tuple`           | tuple                               |
  | `nil`             | `Option::None`                      |

  ## Quick start

      iex> Lux.Rust.Types.start_link()
      {:ok, _pid}

      iex> {:ok, v} = Lux.Rust.Types.to_rust(42, :i64)
      iex> v
      %{type: :i64, value: 42}

      iex> {:ok, result} = Lux.Rust.Types.from_rust(%{type: :i64, value: 42})
      iex> result
      42

  ## Struct definitions

      iex> Lux.Rust.Types.define_struct(:point, %{x: :f64, y: :f64})
      :ok
      iex> Lux.Rust.Types.validate_struct(:point, %{x: 1.0, y: 2.5})
      {:ok, %{x: 1.0, y: 2.5}}

  ## Enum definitions

      iex> Lux.Rust.Types.define_enum(:direction, [:north, :south, :east, :west])
      :ok
      iex> Lux.Rust.Types.validate_enum(:direction, :north)
      {:ok, :north}

  ## Serialization

      iex> Lux.Rust.Types.serialize(%{x: 1, y: 2})
      {:ok, ~s({"x":1,"y":2})}

      iex> Lux.Rust.Types.deserialize(~s({"x":1,"y":2}))
      {:ok, %{"x" => 1, "y" => 2}}
  """

  use GenServer

  require Logger

  @table :lux_rust_types

  @integer_types [:i8, :i16, :i32, :i64, :u8, :u16, :u32, :u64, :isize, :usize]
  @float_types [:f32, :f64]
  @string_types [:string, :str, :vec_u8]
  @scalar_types @integer_types ++ @float_types ++ [:bool, :char] ++ @string_types

  @type rust_type ::
          :i8
          | :i16
          | :i32
          | :i64
          | :u8
          | :u16
          | :u32
          | :u64
          | :isize
          | :usize
          | :f32
          | :f64
          | :bool
          | :char
          | :string
          | :str
          | :vec_u8
          | {:vec, rust_type()}
          | {:option, rust_type()}
          | {:tuple, [rust_type()]}
          | {:map, rust_type(), rust_type()}
          | {:struct, atom()}
          | {:enum, atom()}

  @type typed_value :: %{type: rust_type(), value: term()}
  @type struct_schema :: %{required(atom()) => rust_type()}
  @type enum_variants :: [atom() | String.t()]

  # ── GenServer lifecycle ──────────────────────────────────────────────────────

  @doc """
  Starts the `Lux.Rust.Types` process which owns the ETS schema registry.

  The process is normally started by `Lux.Application`. You may call this
  directly in tests or scripts that need an isolated registry.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])
    {:ok, %{table: table}}
  end

  # ── Type conversion: Elixir → Rust ──────────────────────────────────────────

  @doc """
  Converts an Elixir value to a Rust-compatible typed representation.

  The second argument is the target Rust type. For scalar values the type
  guides validation; for compound types (`:vec`, `:option`, `:tuple`,
  `:struct`, `:enum`) it drives recursive conversion.

  Returns `{:ok, %{type: rust_type, value: converted}}` on success or
  `{:error, reason}` when the value does not match the requested type.

  ## Examples

      iex> Lux.Rust.Types.to_rust(255, :u8)
      {:ok, %{type: :u8, value: 255}}

      iex> Lux.Rust.Types.to_rust(3.14, :f64)
      {:ok, %{type: :f64, value: 3.14}}

      iex> Lux.Rust.Types.to_rust(nil, {:option, :i32})
      {:ok, %{type: {:option, :i32}, value: nil}}

      iex> Lux.Rust.Types.to_rust([1, 2, 3], {:vec, :i32})
      {:ok, %{type: {:vec, :i32}, value: [%{type: :i32, value: 1}, %{type: :i32, value: 2}, %{type: :i32, value: 3}]}}
  """
  @spec to_rust(term(), rust_type()) :: {:ok, typed_value()} | {:error, String.t()}
  def to_rust(nil, {:option, _inner_type}), do: {:ok, %{type: {:option, _inner_type}, value: nil}}

  def to_rust(value, {:option, inner_type}) do
    case to_rust(value, inner_type) do
      {:ok, inner} -> {:ok, %{type: {:option, inner_type}, value: inner}}
      error -> error
    end
  end

  def to_rust(value, {:vec, elem_type}) when is_list(value) do
    value
    |> Enum.reduce_while({:ok, []}, fn elem, {:ok, acc} ->
      case to_rust(elem, elem_type) do
        {:ok, converted} -> {:cont, {:ok, [converted | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, %{type: {:vec, elem_type}, value: Enum.reverse(reversed)}}
      error -> error
    end
  end

  def to_rust(value, {:vec, _}) when not is_list(value) do
    {:error, "expected list for Vec<T>, got #{inspect(value)}"}
  end

  def to_rust(value, {:tuple, types}) when is_tuple(value) do
    elems = Tuple.to_list(value)

    if length(elems) != length(types) do
      {:error, "tuple arity mismatch: expected #{length(types)}, got #{length(elems)}"}
    else
      elems
      |> Enum.zip(types)
      |> Enum.reduce_while({:ok, []}, fn {elem, t}, {:ok, acc} ->
        case to_rust(elem, t) do
          {:ok, converted} -> {:cont, {:ok, [converted | acc]}}
          error -> {:halt, error}
        end
      end)
      |> case do
        {:ok, reversed} ->
          {:ok, %{type: {:tuple, types}, value: Enum.reverse(reversed)}}

        error ->
          error
      end
    end
  end

  def to_rust(value, {:map, key_type, val_type}) when is_map(value) do
    value
    |> Enum.reduce_while({:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, ck} <- to_rust(k, key_type),
           {:ok, cv} <- to_rust(v, val_type) do
        {:cont, {:ok, Map.put(acc, ck, cv)}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, converted} -> {:ok, %{type: {:map, key_type, val_type}, value: converted}}
      error -> error
    end
  end

  def to_rust(value, {:struct, name}) when is_map(value) do
    case validate_struct(name, value) do
      {:ok, validated} -> {:ok, %{type: {:struct, name}, value: validated}}
      error -> error
    end
  end

  def to_rust(value, {:enum, name}) when is_atom(value) or is_binary(value) do
    case validate_enum(name, value) do
      {:ok, validated} -> {:ok, %{type: {:enum, name}, value: validated}}
      error -> error
    end
  end

  def to_rust(value, type) when type in @integer_types do
    convert_integer(value, type)
  end

  def to_rust(value, type) when type in @float_types do
    convert_float(value, type)
  end

  def to_rust(value, :bool) when is_boolean(value) do
    {:ok, %{type: :bool, value: value}}
  end

  def to_rust(value, :bool) do
    {:error, "expected boolean for bool, got #{inspect(value)}"}
  end

  def to_rust(value, :char) when is_integer(value) and value >= 0 and value <= 0x10FFFF do
    {:ok, %{type: :char, value: value}}
  end

  def to_rust(value, :char) do
    {:error, "expected unicode codepoint integer for char, got #{inspect(value)}"}
  end

  def to_rust(value, type) when type in [:string, :str] and is_binary(value) do
    {:ok, %{type: type, value: value}}
  end

  def to_rust(value, type) when type in [:string, :str] and is_atom(value) do
    {:ok, %{type: type, value: Atom.to_string(value)}}
  end

  def to_rust(value, type) when type in [:string, :str] do
    {:error, "expected binary or atom for #{type}, got #{inspect(value)}"}
  end

  def to_rust(value, :vec_u8) when is_binary(value) do
    {:ok, %{type: :vec_u8, value: :binary.bin_to_list(value)}}
  end

  def to_rust(value, :vec_u8) when is_list(value) do
    if Enum.all?(value, &(is_integer(&1) and &1 >= 0 and &1 <= 255)) do
      {:ok, %{type: :vec_u8, value: value}}
    else
      {:error, "vec_u8 elements must be integers 0..255"}
    end
  end

  def to_rust(value, :vec_u8) do
    {:error, "expected binary or byte list for vec_u8, got #{inspect(value)}"}
  end

  def to_rust(value, type) do
    {:error, "cannot convert #{inspect(value)} to #{inspect(type)}"}
  end

  # ── Type conversion: Rust → Elixir ──────────────────────────────────────────

  @doc """
  Converts a Rust typed value (as produced by `to_rust/2`) back to a plain
  Elixir term.

  ## Examples

      iex> Lux.Rust.Types.from_rust(%{type: :i64, value: 42})
      {:ok, 42}

      iex> Lux.Rust.Types.from_rust(%{type: :bool, value: true})
      {:ok, true}

      iex> Lux.Rust.Types.from_rust(%{type: {:option, :f32}, value: nil})
      {:ok, nil}

      iex> Lux.Rust.Types.from_rust(%{type: :vec_u8, value: [104, 105]})
      {:ok, "hi"}
  """
  @spec from_rust(typed_value()) :: {:ok, term()} | {:error, String.t()}
  def from_rust(%{type: {:option, _}, value: nil}), do: {:ok, nil}

  def from_rust(%{type: {:option, _inner}, value: inner}), do: from_rust(inner)

  def from_rust(%{type: {:vec, _}, value: items}) when is_list(items) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case from_rust(item) do
        {:ok, v} -> {:cont, {:ok, [v | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  def from_rust(%{type: {:tuple, _}, value: items}) when is_list(items) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case from_rust(item) do
        {:ok, v} -> {:cont, {:ok, [v | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, List.to_tuple(Enum.reverse(reversed))}
      error -> error
    end
  end

  def from_rust(%{type: {:map, _, _}, value: pairs}) when is_map(pairs) do
    pairs
    |> Enum.reduce_while({:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, ek} <- from_rust(k),
           {:ok, ev} <- from_rust(v) do
        {:cont, {:ok, Map.put(acc, ek, ev)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  def from_rust(%{type: {:struct, _name}, value: fields}) when is_map(fields) do
    {:ok, fields}
  end

  def from_rust(%{type: {:enum, _name}, value: variant}) do
    {:ok, variant}
  end

  def from_rust(%{type: :vec_u8, value: bytes}) when is_list(bytes) do
    {:ok, :binary.list_to_bin(bytes)}
  end

  def from_rust(%{type: type, value: value}) when type in @scalar_types do
    {:ok, value}
  end

  def from_rust(other) do
    {:error, "unrecognised typed value: #{inspect(other)}"}
  end

  # ── Struct registry ──────────────────────────────────────────────────────────

  @doc """
  Registers a named struct schema in the ETS registry.

  `fields` is a map from field name atoms to `t:rust_type/0` values.  Once
  defined, the schema can be referenced as `{:struct, name}` in type
  annotations and used with `validate_struct/2`.

  ## Examples

      iex> Lux.Rust.Types.define_struct(:point, %{x: :f64, y: :f64})
      :ok
  """
  @spec define_struct(atom(), struct_schema()) :: :ok
  def define_struct(name, fields) when is_atom(name) and is_map(fields) do
    ensure_table()
    :ets.insert(@table, {{:struct, name}, fields})
    :ok
  end

  @doc """
  Validates a map against a previously registered struct schema.

  All fields declared in the schema must be present in `value`.  Extra keys
  are allowed (they are passed through unchanged) so that Rust-side
  `#[serde(flatten)]` patterns remain supported.

  Returns `{:ok, value}` when valid, `{:error, reason}` otherwise.

  ## Examples

      iex> Lux.Rust.Types.define_struct(:point, %{x: :f64, y: :f64})
      :ok
      iex> Lux.Rust.Types.validate_struct(:point, %{x: 1.0, y: 2.5})
      {:ok, %{x: 1.0, y: 2.5}}
      iex> Lux.Rust.Types.validate_struct(:point, %{x: "bad"})
      {:error, _}
  """
  @spec validate_struct(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def validate_struct(name, value) when is_atom(name) and is_map(value) do
    ensure_table()

    case :ets.lookup(@table, {:struct, name}) do
      [] ->
        {:error, "unknown struct: #{name}"}

      [{{:struct, ^name}, schema}] ->
        validate_fields(name, schema, value)
    end
  end

  # ── Enum registry ────────────────────────────────────────────────────────────

  @doc """
  Registers a named enum with a fixed set of variants.

  Variants may be atoms or binaries; atoms are normalised to their string
  representation for comparison so that `:north` and `"north"` are treated
  as equivalent.

  ## Examples

      iex> Lux.Rust.Types.define_enum(:direction, [:north, :south, :east, :west])
      :ok
  """
  @spec define_enum(atom(), enum_variants()) :: :ok
  def define_enum(name, variants) when is_atom(name) and is_list(variants) do
    ensure_table()
    normalised = Enum.map(variants, &normalise_variant/1)
    :ets.insert(@table, {{:enum, name}, normalised})
    :ok
  end

  @doc """
  Validates a value against a previously registered enum.

  ## Examples

      iex> Lux.Rust.Types.define_enum(:direction, [:north, :south])
      :ok
      iex> Lux.Rust.Types.validate_enum(:direction, :north)
      {:ok, :north}
      iex> Lux.Rust.Types.validate_enum(:direction, :up)
      {:error, _}
  """
  @spec validate_enum(atom(), atom() | String.t()) :: {:ok, atom() | String.t()} | {:error, String.t()}
  def validate_enum(name, value) when is_atom(name) do
    ensure_table()

    case :ets.lookup(@table, {:enum, name}) do
      [] ->
        {:error, "unknown enum: #{name}"}

      [{{:enum, ^name}, variants}] ->
        candidate = normalise_variant(value)

        if candidate in variants do
          {:ok, value}
        else
          {:error, "#{inspect(value)} is not a valid variant of #{name}. Valid variants: #{inspect(variants)}"}
        end
    end
  end

  # ── Serialization ────────────────────────────────────────────────────────────

  @doc """
  Serializes a value to JSON using Jason when available, falling back to
  `:erlang.term_to_binary/1` for non-JSON-encodable terms.

  The `:format` option controls the output:
    * `:json` (default) — JSON string via Jason
    * `:binary` — Erlang external term format

  ## Examples

      iex> Lux.Rust.Types.serialize(%{x: 1, y: 2})
      {:ok, _json_string}

      iex> Lux.Rust.Types.serialize({:ok, 42}, format: :binary)
      {:ok, _binary}
  """
  @spec serialize(term(), keyword()) :: {:ok, String.t() | binary()} | {:error, String.t()}
  def serialize(value, opts \\ []) do
    format = Keyword.get(opts, :format, :json)
    do_serialize(value, format)
  end

  @doc """
  Deserializes a value produced by `serialize/2`.

  The `:format` option must match the one used during serialization.

  ## Examples

      iex> {:ok, json} = Lux.Rust.Types.serialize(%{"a" => 1})
      iex> Lux.Rust.Types.deserialize(json)
      {:ok, %{"a" => 1}}
  """
  @spec deserialize(String.t() | binary(), keyword()) :: {:ok, term()} | {:error, String.t()}
  def deserialize(data, opts \\ []) do
    format = Keyword.get(opts, :format, :json)
    do_deserialize(data, format)
  end

  # ── Convenience: list registered names ──────────────────────────────────────

  @doc """
  Returns all struct names currently registered in the schema registry.

  ## Examples

      iex> Lux.Rust.Types.define_struct(:foo, %{a: :i32})
      :ok
      iex> :foo in Lux.Rust.Types.registered_structs()
      true
  """
  @spec registered_structs() :: [atom()]
  def registered_structs do
    ensure_table()

    :ets.match(@table, {{:struct, :"$1"}, :_})
    |> List.flatten()
  end

  @doc """
  Returns all enum names currently registered in the schema registry.

  ## Examples

      iex> Lux.Rust.Types.define_enum(:color, [:red, :green])
      :ok
      iex> :color in Lux.Rust.Types.registered_enums()
      true
  """
  @spec registered_enums() :: [atom()]
  def registered_enums do
    ensure_table()

    :ets.match(@table, {{:enum, :"$1"}, :_})
    |> List.flatten()
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set, {:read_concurrency, true}])
      _ -> @table
    end
  end

  defp convert_integer(value, type) when is_integer(value) do
    {min, max} = integer_range(type)

    if value >= min and value <= max do
      {:ok, %{type: type, value: value}}
    else
      {:error, "#{value} is out of range for #{type} (#{min}..#{max})"}
    end
  end

  defp convert_integer(value, type) do
    {:error, "expected integer for #{type}, got #{inspect(value)}"}
  end

  defp convert_float(value, type) when is_float(value) or is_integer(value) do
    {:ok, %{type: type, value: value / 1}}
  end

  defp convert_float(value, type) do
    {:error, "expected number for #{type}, got #{inspect(value)}"}
  end

  defp integer_range(:i8), do: {-128, 127}
  defp integer_range(:i16), do: {-32_768, 32_767}
  defp integer_range(:i32), do: {-2_147_483_648, 2_147_483_647}
  defp integer_range(:i64), do: {-9_223_372_036_854_775_808, 9_223_372_036_854_775_807}
  defp integer_range(:u8), do: {0, 255}
  defp integer_range(:u16), do: {0, 65_535}
  defp integer_range(:u32), do: {0, 4_294_967_295}
  defp integer_range(:u64), do: {0, 18_446_744_073_709_551_615}
  defp integer_range(:isize), do: {-9_223_372_036_854_775_808, 9_223_372_036_854_775_807}
  defp integer_range(:usize), do: {0, 18_446_744_073_709_551_615}

  defp validate_fields(struct_name, schema, value) do
    schema
    |> Enum.reduce_while({:ok, value}, fn {field, field_type}, {:ok, acc} ->
      case Map.fetch(acc, field) do
        :error ->
          {:halt, {:error, "struct #{struct_name} missing required field: #{field}"}}

        {:ok, field_val} ->
          case to_rust(field_val, field_type) do
            {:ok, _} -> {:cont, {:ok, acc}}
            {:error, reason} -> {:halt, {:error, "struct #{struct_name}.#{field}: #{reason}"}}
          end
      end
    end)
  end

  defp normalise_variant(v) when is_atom(v), do: Atom.to_string(v)
  defp normalise_variant(v) when is_binary(v), do: v

  defp do_serialize(value, :json) do
    case Jason.encode(value) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, "JSON serialization failed: #{inspect(reason)}"}
    end
  end

  defp do_serialize(value, :binary) do
    {:ok, :erlang.term_to_binary(value)}
  rescue
    e -> {:error, "binary serialization failed: #{Exception.message(e)}"}
  end

  defp do_serialize(_value, format) do
    {:error, "unsupported serialization format: #{inspect(format)}"}
  end

  defp do_deserialize(data, :json) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, term} -> {:ok, term}
      {:error, reason} -> {:error, "JSON deserialization failed: #{inspect(reason)}"}
    end
  end

  defp do_deserialize(data, :binary) when is_binary(data) do
    {:ok, :erlang.binary_to_term(data)}
  rescue
    e -> {:error, "binary deserialization failed: #{Exception.message(e)}"}
  end

  defp do_deserialize(_data, format) do
    {:error, "unsupported deserialization format: #{inspect(format)}"}
  end
end
