defmodule Lux.Rust.Type do
  @moduledoc """
  Defines the type system for Elixir-Rust interop.
  """

  @type t ::
          :string
          | :i64
          | :f64
          | :bool
          | {:list, t()}
          | {:map, key :: t(), value :: t()}
          | {:tuple, [t()]}
          | {:enum, [atom()]} # Rust-style simple enum
          | {:struct, [{field :: atom(), type :: t()}]} # Named struct

  @doc """
  Validates if an Elixir value matches a Rust type definition.
  """
  def valid?(value, :string) when is_binary(value), do: true
  def valid?(value, :i64) when is_integer(value), do: true
  def valid?(value, :f64) when is_float(value) or is_integer(value), do: true
  def valid?(value, :bool) when is_boolean(value), do: true
  def valid?(value, {:list, inner_type}) when is_list(value) do
    Enum.all?(value, &valid?(&1, inner_type))
  end
  def valid?(value, {:map, key_type, val_type}) when is_map(value) do
    Enum.all?(value, fn {k, v} -> valid?(k, key_type) and valid?(v, val_type) end)
  end
  def valid?(value, {:enum, variants}) when is_atom(value) do
    value in variants
  end
  def valid?(value, {:struct, fields}) when is_map(value) or is_list(value) do
    Enum.all?(fields, fn {field, type} -> 
      val = if is_map(value), do: Map.get(value, field) || Map.get(value, to_string(field)), else: Keyword.get(value, field)
      valid?(val, type)
    end)
  end
  def valid?(_value, _type), do: false
  def valid?(_value, _type), do: false
end
