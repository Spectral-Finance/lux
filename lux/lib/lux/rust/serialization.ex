defprotocol Lux.Rust.Serializable do
  @moduledoc """
  Protocol for types that can be serialized to Rust.
  """

  @doc """
  Returns the Rust type definition for this data structure.
  """
  def rust_type(data)

  @doc """
  Encodes the data for Rust consumption.
  In this ETF-based implementation, it usually returns the data itself,
  as Rustler handles the encoding.
  """
  def encode(data)
end

defimpl Lux.Rust.Serializable, for: Any do
  def rust_type(_), do: :any
  def encode(data), do: data
end
