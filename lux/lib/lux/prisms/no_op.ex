defmodule Lux.Prisms.NoOp do
  @moduledoc """
  A no-operation prism that simply returns its input or an empty map if no input.
  Used as a placeholder in conditional branches where no action is needed.

  ## Example

      iex> Lux.Prisms.NoOp.run(%{value: 42})
      {:ok, %{value: 42}}

      iex> Lux.Prisms.NoOp.run(%{})
      {:ok, %{}}
  """

  use Lux.Prism,
    name: "No Operation",
    description: "A pass-through prism that performs no operation",
    input_schema: %{
      type: :object,
      properties: %{},
      additionalProperties: true
    },
    output_schema: %{
      type: :object,
      properties: %{},
      additionalProperties: true
    }

  def handler(input, _ctx) do
    {:ok, input}
  end
end
