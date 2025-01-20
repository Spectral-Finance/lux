defmodule Lux.Factory do
  @moduledoc """
  Factory for conveniently creating test data.
  """

  alias Lux.UUID

  def build(:signal) do
    %Lux.Signal{
      id: UUID.generate(),
      payload: %{text: "Hello, world!"},
      timestamp: DateTime.utc_now(),
      metadata: %{},
      schema_id: nil,
      sender: nil,
      recipient: nil
    }
  end

  def build(factory_name, attrs \\ %{}) do
    factory_name |> build() |> struct!(attrs)
  end
end
