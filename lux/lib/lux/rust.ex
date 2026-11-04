defmodule Lux.Rust do
  @moduledoc """
  Rust interoperability for Lux.

  This namespace hosts Lux's first-class Rust integration. The current focus is
  the type system and serialization layer that lets Elixir and Rust exchange
  structured data across the `serde`-compatible wire format without a native
  build step.

  ## Components

    * `Lux.Rust.Types` - public facade (encode/decode, type mapping, custom
      type definitions and code generation).
    * `Lux.Rust.Types.Serializer` - bidirectional Elixir <-> Serde conversion.
    * `Lux.Rust.Types.SchemaGenerator` - generates Rust `struct`/`enum`
      definitions with `#[derive(Serialize, Deserialize)]`.
    * `Lux.Rust.Types.Type` - the custom type definition struct.

  ## Example

      iex> alias Lux.Rust.Types
      iex> type = {:struct, [name: :string, price: {:option, :f64}]}
      iex> Types.encode(%{name: "widget", price: 9.99}, type)
      {:ok, %{"name" => "widget", "price" => 9.99}}

  See the [Rust integration guide](language_support/rust.livemd) for complex
  conversion examples.
  """

  @doc "Returns the version of the Rust type system layer."
  @spec version() :: String.t()
  def version, do: "0.1.0"
end
