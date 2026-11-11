defmodule Lux.Rust.TypeSystem do
  @moduledoc """
  Advanced bidirectional type system mapping and Serde serialization between Elixir and Rust (#101).
  """

  @primitive_map %{
    :i8 => :integer,
    :i16 => :integer,
    :i32 => :integer,
    :i64 => :integer,
    :u8 => :non_neg_integer,
    :u16 => :non_neg_integer,
    :u32 => :non_neg_integer,
    :u64 => :non_neg_integer,
    :f32 => :float,
    :f64 => :float,
    :bool => :boolean,
    :string => :binary
  }

  @doc """
  Maps a Rust type descriptor (`:u64`, `{:vec, :string}`, `{:option, :f64}`, `{:struct, fields}`, `{:enum, variants}`)
  into an Elixir/JSON-Schema compatible specification.
  """
  def to_elixir_type(rust_type) when is_atom(rust_type) do
    case Map.fetch(@primitive_map, rust_type) do
      {:ok, t} -> {:ok, t}
      :error -> {:error, {:unsupported_rust_primitive, rust_type}}
    end
  end

  def to_elixir_type({:vec, inner}) do
    with {:ok, mapped} <- to_elixir_type(inner), do: {:ok, {:list, mapped}}
  end

  def to_elixir_type({:option, inner}) do
    with {:ok, mapped} <- to_elixir_type(inner), do: {:ok, {:nullable, mapped}}
  end

  def to_elixir_type({:struct, fields}) when is_map(fields) do
    Enum.reduce_while(fields, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      case to_elixir_type(v) do
        {:ok, mv} -> {:cont, {:ok, Map.put(acc, k, mv)}}
        err -> {:halt, err}
      end
    end)
  end

  @doc """
  Serializes an Elixir tagged tuple (`{:ok, val}` / `{:variant, payload}`) into Serde's externally-tagged enum map.
  """
  def encode_serde_enum({variant, payload}) when is_atom(variant) do
    {:ok, %{Atom.to_string(variant) => payload}}
  end

  @doc """
  Deserializes a Serde externally-tagged enum map back into an Elixir `{variant_atom, payload}` tuple.
  """
  def decode_serde_enum(map) when is_map(map) and map_size(map) == 1 do
    [{k, v}] = Map.to_list(map)
    {:ok, {String.to_atom(to_string(k)), v}}
  end
end
