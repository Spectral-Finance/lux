defmodule SamplePrism do
  @moduledoc """
  A sample prism module used for testing.
  """
  use Lux.Prism,
    id: "sample-prism",
    name: "Sample Prism",
    description: "A test prism for reflection tests",
    input_schema: TestSchema,
    output_schema: TestSchema,
    examples: [
      """
      iex(1)> SamplePrism.handler(123)
      {:ok, %{message: "test"}}
      """,
      """
      iex(2)> SamplePrism.handler(:test_input)
      {:ok, %{message: "test"}}
      """
    ]

  def handler(_params, _context) do
    {:ok, %{message: "test"}}
  end
end
