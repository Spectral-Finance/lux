defmodule Lux.Rust.Types do
  @moduledoc """
  Type conversion and normalization system between Elixir data structures and Rust types.
  """

  @doc """
  Converts an Elixir term into a JSON/Rust-compatible value.
  Atoms are converted to strings, keywords to maps, tuples to lists.
  """
  @spec to_rust_compatible(term()) :: term()
  def to_rust_compatible(nil), do: nil
  def to_rust_compatible(val) when is_boolean(val), do: val
  def to_rust_compatible(val) when is_integer(val), do: val
  def to_rust_compatible(val) when is_float(val), do: val
  def to_rust_compatible(val) when is_binary(val), do: val
  def to_rust_compatible(val) when is_atom(val), do: Atom.to_string(val)
  def to_rust_compatible(val) when is_list(val) do
    if Keyword.keyword?(val) do
      val |> Enum.into(%{}) |> to_rust_compatible()
    else
      Enum.map(val, &to_rust_compatible/1)
    end
  end
  def to_rust_compatible(val) when is_map(val) do
    Map.new(val, fn {k, v} ->
      key = if is_atom(k), do: Atom.to_string(k), else: to_string(k)
      {key, to_rust_compatible(v)}
    end)
  end
  def to_rust_compatible(val) when is_tuple(val) do
    val |> Tuple.to_list() |> to_rust_compatible()
  end
  def to_rust_compatible(other), do: inspect(other)

  @doc """
  Normalizes result returned from Rust execution into idiomatic Elixir terms.
  """
  @spec from_rust_result(term()) :: term()
  def from_rust_result(val) when is_map(val) do
    Map.new(val, fn {k, v} -> {k, from_rust_result(v)} end)
  end
  def from_rust_result(val) when is_list(val) do
    Enum.map(val, &from_rust_result/1)
  end
  def from_rust_result(other), do: other
end
