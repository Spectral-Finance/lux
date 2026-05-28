defmodule Lux.Rust.FFI do
  @moduledoc """
  Bidirectional type conversion between Elixir and Rust-compatible NIF terms.

  All functions are pure Elixir — no compiled NIFs are required.  The module
  converts Elixir values to tagged representations that match Rustler's default
  term encoding, and decodes those representations back into plain Elixir terms.

  ## Type mapping

  | Elixir value         | Rust / NIF representation                     |
  |----------------------|-----------------------------------------------|
  | `integer`            | `%{type: :integer, value: n}`                 |
  | `float`              | `%{type: :float, value: f}`                   |
  | `true / false`       | `%{type: :boolean, value: b}`                 |
  | `binary`             | `%{type: :binary, value: s}`                  |
  | `atom`               | `%{type: :atom, value: "atom_string"}`        |
  | `nil`                | `%{type: :nil, value: nil}`                   |
  | `list`               | `%{type: :list, value: [encoded, ...]}`       |
  | `map`                | `%{type: :map, value: %{encoded => encoded}}` |

  ## Examples

      iex> Lux.Rust.FFI.to_erlang_term(42)
      {:ok, %{type: :integer, value: 42}}

      iex> {:ok, encoded} = Lux.Rust.FFI.to_erlang_term("hello")
      iex> Lux.Rust.FFI.from_erlang_term(encoded)
      {:ok, "hello"}

      iex> Lux.Rust.FFI.encode_for_nif(255, :u8)
      {:ok, %{type: :integer, value: 255}}

      iex> Lux.Rust.FFI.decode_nif_result(%{type: :boolean, value: true})
      {:ok, true}
  """

  @integer_types [:i8, :i16, :i32, :i64, :u8, :u16, :u32, :u64, :isize, :usize]
  @float_types [:f32, :f64]

  @type encoded_term ::
          %{type: :integer, value: integer()}
          | %{type: :float, value: float()}
          | %{type: :boolean, value: boolean()}
          | %{type: :binary, value: String.t()}
          | %{type: :atom, value: String.t()}
          | %{type: :nil, value: nil}
          | %{type: :list, value: [encoded_term()]}
          | %{type: :map, value: %{encoded_term() => encoded_term()}}

  @type nif_type ::
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
          | :string
          | :binary

  # ── Elixir → encoded term ────────────────────────────────────────────────────

  @doc """
  Converts an Elixir value to a tagged map that represents the value as a
  Rust-compatible NIF term.

  Supported types: integers, floats, booleans, binaries, atoms, nil, lists,
  and maps with any combination of those types as keys and values.

  Returns `{:ok, encoded}` or `{:error, reason}`.

  ## Examples

      iex> Lux.Rust.FFI.to_erlang_term(42)
      {:ok, %{type: :integer, value: 42}}

      iex> Lux.Rust.FFI.to_erlang_term(nil)
      {:ok, %{type: :nil, value: nil}}

      iex> Lux.Rust.FFI.to_erlang_term([1, 2])
      {:ok, %{type: :list, value: [%{type: :integer, value: 1}, %{type: :integer, value: 2}]}}
  """
  @spec to_erlang_term(term()) :: {:ok, encoded_term()} | {:error, String.t()}
  def to_erlang_term(nil), do: {:ok, %{type: :nil, value: nil}}

  def to_erlang_term(value) when is_boolean(value) do
    {:ok, %{type: :boolean, value: value}}
  end

  def to_erlang_term(value) when is_integer(value) do
    {:ok, %{type: :integer, value: value}}
  end

  def to_erlang_term(value) when is_float(value) do
    {:ok, %{type: :float, value: value}}
  end

  def to_erlang_term(value) when is_binary(value) do
    {:ok, %{type: :binary, value: value}}
  end

  def to_erlang_term(value) when is_atom(value) do
    {:ok, %{type: :atom, value: Atom.to_string(value)}}
  end

  def to_erlang_term(value) when is_list(value) do
    value
    |> Enum.reduce_while({:ok, []}, fn elem, {:ok, acc} ->
      case to_erlang_term(elem) do
        {:ok, encoded} -> {:cont, {:ok, [encoded | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, %{type: :list, value: Enum.reverse(reversed)}}
      error -> error
    end
  end

  def to_erlang_term(value) when is_map(value) do
    value
    |> Enum.reduce_while({:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, ek} <- to_erlang_term(k),
           {:ok, ev} <- to_erlang_term(v) do
        {:cont, {:ok, Map.put(acc, ek, ev)}}
      else
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, encoded_map} -> {:ok, %{type: :map, value: encoded_map}}
      error -> error
    end
  end

  def to_erlang_term(value) do
    {:error, "unsupported value for NIF encoding: #{inspect(value)}"}
  end

  # ── encoded term → Elixir ────────────────────────────────────────────────────

  @doc """
  Converts an encoded term (as produced by `to_erlang_term/1`) back to a plain
  Elixir value.

  Returns `{:ok, value}` or `{:error, reason}`.

  ## Examples

      iex> Lux.Rust.FFI.from_erlang_term(%{type: :integer, value: 7})
      {:ok, 7}

      iex> Lux.Rust.FFI.from_erlang_term(%{type: :atom, value: "ok"})
      {:ok, :ok}
  """
  @spec from_erlang_term(encoded_term()) :: {:ok, term()} | {:error, String.t()}
  def from_erlang_term(%{type: :nil}), do: {:ok, nil}

  def from_erlang_term(%{type: :boolean, value: v}) when is_boolean(v), do: {:ok, v}

  def from_erlang_term(%{type: :integer, value: v}) when is_integer(v), do: {:ok, v}

  def from_erlang_term(%{type: :float, value: v}) when is_number(v), do: {:ok, v / 1}

  def from_erlang_term(%{type: :binary, value: v}) when is_binary(v), do: {:ok, v}

  def from_erlang_term(%{type: :atom, value: v}) when is_binary(v) do
    {:ok, String.to_existing_atom(v)}
  rescue
    ArgumentError -> {:ok, String.to_atom(v)}
  end

  def from_erlang_term(%{type: :list, value: items}) when is_list(items) do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case from_erlang_term(item) do
        {:ok, decoded} -> {:cont, {:ok, [decoded | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  def from_erlang_term(%{type: :map, value: pairs}) when is_map(pairs) do
    pairs
    |> Enum.reduce_while({:ok, %{}}, fn {k, v}, {:ok, acc} ->
      with {:ok, dk} <- from_erlang_term(k),
           {:ok, dv} <- from_erlang_term(v) do
        {:cont, {:ok, Map.put(acc, dk, dv)}}
      else
        error -> {:halt, error}
      end
    end)
  end

  def from_erlang_term(other) do
    {:error, "unrecognised encoded term: #{inspect(other)}"}
  end

  # ── Type-checked NIF encoding ─────────────────────────────────────────────────

  @doc """
  Encodes `value` for use as a NIF function argument, validating that it
  matches the declared `nif_type`.

  Returns `{:ok, encoded}` or `{:error, reason}`.

  ## Examples

      iex> Lux.Rust.FFI.encode_for_nif(255, :u8)
      {:ok, %{type: :integer, value: 255}}

      iex> Lux.Rust.FFI.encode_for_nif(3.14, :f64)
      {:ok, %{type: :float, value: 3.14}}

      iex> Lux.Rust.FFI.encode_for_nif("hello", :string)
      {:ok, %{type: :binary, value: "hello"}}

      iex> Lux.Rust.FFI.encode_for_nif("bad", :u8)
      {:error, _reason}
  """
  @spec encode_for_nif(term(), nif_type()) :: {:ok, encoded_term()} | {:error, String.t()}
  def encode_for_nif(value, type) when type in @integer_types and is_integer(value) do
    {min, max} = integer_range(type)

    if value >= min and value <= max do
      {:ok, %{type: :integer, value: value}}
    else
      {:error, "#{value} is out of range for #{type} (#{min}..#{max})"}
    end
  end

  def encode_for_nif(value, type) when type in @integer_types do
    {:error, "expected integer for #{type}, got #{inspect(value)}"}
  end

  def encode_for_nif(value, type) when type in @float_types and is_number(value) do
    {:ok, %{type: :float, value: value / 1}}
  end

  def encode_for_nif(value, type) when type in @float_types do
    {:error, "expected number for #{type}, got #{inspect(value)}"}
  end

  def encode_for_nif(value, :bool) when is_boolean(value) do
    {:ok, %{type: :boolean, value: value}}
  end

  def encode_for_nif(value, :bool) do
    {:error, "expected boolean for bool, got #{inspect(value)}"}
  end

  def encode_for_nif(value, :string) when is_binary(value) do
    {:ok, %{type: :binary, value: value}}
  end

  def encode_for_nif(value, :string) when is_atom(value) do
    {:ok, %{type: :binary, value: Atom.to_string(value)}}
  end

  def encode_for_nif(value, :string) do
    {:error, "expected binary or atom for string, got #{inspect(value)}"}
  end

  def encode_for_nif(value, :binary) when is_binary(value) do
    {:ok, %{type: :binary, value: value}}
  end

  def encode_for_nif(value, :binary) do
    {:error, "expected binary for binary, got #{inspect(value)}"}
  end

  def encode_for_nif(value, type) do
    {:error, "unsupported nif_type #{inspect(type)} for value #{inspect(value)}"}
  end

  # ── NIF result decoding ───────────────────────────────────────────────────────

  @doc """
  Decodes a NIF return value back to a plain Elixir term.

  Handles both tagged encoded maps (produced via the FFI encoding pipeline) and
  raw Elixir values returned directly by Rustler NIFs.

  Returns `{:ok, decoded}` or `{:error, reason}`.

  ## Examples

      iex> Lux.Rust.FFI.decode_nif_result(%{type: :boolean, value: true})
      {:ok, true}

      iex> Lux.Rust.FFI.decode_nif_result(42)
      {:ok, 42}
  """
  @spec decode_nif_result(term()) :: {:ok, term()} | {:error, String.t()}
  def decode_nif_result(%{type: _} = encoded), do: from_erlang_term(encoded)

  def decode_nif_result({:ok, value}), do: {:ok, value}

  def decode_nif_result({:error, reason}) when is_binary(reason) do
    {:error, reason}
  end

  def decode_nif_result({:error, reason}), do: {:error, inspect(reason)}

  def decode_nif_result(value) when is_integer(value), do: {:ok, value}
  def decode_nif_result(value) when is_float(value), do: {:ok, value}
  def decode_nif_result(value) when is_boolean(value), do: {:ok, value}
  def decode_nif_result(value) when is_binary(value), do: {:ok, value}
  def decode_nif_result(value) when is_atom(value), do: {:ok, value}
  def decode_nif_result(value) when is_list(value), do: {:ok, value}
  def decode_nif_result(value) when is_map(value), do: {:ok, value}

  def decode_nif_result(value) do
    {:error, "cannot decode NIF result: #{inspect(value)}"}
  end

  # ── Private helpers ───────────────────────────────────────────────────────────

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
end
