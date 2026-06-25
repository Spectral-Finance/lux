defmodule Lux.Rust.Types do
  @moduledoc """
  Rust Type System and Serialization for Lux ($450).

  Provides type mapping between Elixir and Rust NIFs,
  Serde-compatible serialization helpers, and type validation.

  ## Supported Type Mappings

  | Rust Type         | Elixir Type            |
  |-------------------|------------------------|
  | String / &str     | binary()               |
  | i64 / u64         | integer()              |
  | f64               | float()                |
  | bool              | boolean()              |
  | Vec<T>            | list()                 |
  | HashMap<K,V>      | map()                  |
  | Option<T>         | T | nil                |
  | Result<T,E>       | {:ok, T} | {:error, E}  |
  """

  @doc "Validates a value matches the expected Rust-compatible type atom."
  @spec valid_type?(term(), atom()) :: boolean()
  def valid_type?(value, :string),  do: is_binary(value)
  def valid_type?(value, :i64),     do: is_integer(value) and value >= -9_223_372_036_854_775_808 and value <= 9_223_372_036_854_775_807
  def valid_type?(value, :u64),     do: is_integer(value) and value >= 0 and value <= 18_446_744_073_709_551_615
  def valid_type?(value, :f64),     do: is_float(value) or is_integer(value)
  def valid_type?(value, :bool),    do: is_boolean(value)
  def valid_type?(value, :vec),     do: is_list(value)
  def valid_type?(value, :map),     do: is_map(value)
  def valid_type?(nil, {:option, _}), do: true
  def valid_type?(v, {:option, t}), do: valid_type?(v, t)
  def valid_type?(_, _),            do: false

  @doc "Coerces an Elixir value to a Rust-compatible representation."
  @spec coerce(term(), atom()) :: {:ok, term()} | {:error, String.t()}
  def coerce(value, :string) when is_binary(value), do: {:ok, value}
  def coerce(value, :string) when is_atom(value),   do: {:ok, Atom.to_string(value)}
  def coerce(value, :f64) when is_integer(value),   do: {:ok, value / 1}
  def coerce(value, :f64) when is_float(value),     do: {:ok, value}
  def coerce(value, :i64) when is_integer(value),   do: {:ok, value}
  def coerce(value, :u64) when is_integer(value) and value >= 0, do: {:ok, value}
  def coerce(nil, {:option, _}),                    do: {:ok, nil}
  def coerce(value, {:option, t}),                  do: coerce(value, t)
  def coerce(value, type),
    do: {:error, "Cannot coerce #{inspect(value)} to Rust type :#{type}"}

  @doc "Serialises a map to a JSON-compatible structure safe for NIF boundary."
  @spec to_nif_safe(map()) :: map()
  def to_nif_safe(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      key = if is_atom(k), do: Atom.to_string(k), else: k
      {key, to_nif_safe_value(v)}
    end)
  end

  defp to_nif_safe_value(v) when is_map(v),    do: to_nif_safe(v)
  defp to_nif_safe_value(v) when is_list(v),   do: Enum.map(v, &to_nif_safe_value/1)
  defp to_nif_safe_value(v) when is_atom(v),   do: Atom.to_string(v)
  defp to_nif_safe_value(v),                   do: v
end
