# Lines 1-17 of lux/lib/lux/prisms/rust_type_system_prism.ex
defmodule Lux.Rust.TypeSystemPrism do
  @moduledoc "Rust type system prism"

  import :erlang

  defstruct [:type_name, :fields]

  def new(type_name, fields) do
    %__MODULE__{type_name: type_name, fields: fields}
  end

  def to_rust_type(%__MODULE__{type_name: type_name, fields: fields}) do
    nif_call(:rust_nifs, :to_rust_type, [type_name, fields])
  end

  def from_rust_type(rust_value) do
    nif_call(:rust_nifs, :from_rust_type, [rust_value])
  end
end

def map_types(type_map) do
  Enum.map(type_map, fn {key, value} ->
    nif_call(:rust_nifs, :map_type, [key, value])
  end)
end