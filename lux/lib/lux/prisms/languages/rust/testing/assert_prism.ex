defmodule Lux.Prisms.Languages.Rust.Testing.AssertPrism do
  @moduledoc """
  A prism for evaluating cross-language assertions on Rust function output.
  """

  use Lux.Prism,
    name: "Rust Cross-Language Assertion",
    description: "Evaluates assertions on native Rust function execution results",
    input_schema: %{
      type: :object,
      properties: %{
        function: %{type: :string},
        args: %{type: [:object, :array, :number, :string]},
        expected: %{type: [:number, :string, :object, :array, :boolean]}
      },
      required: ["function", "expected"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        passed: %{type: :boolean},
        actual: %{type: [:number, :string, :object, :array, :boolean, :null]},
        expected: %{type: [:number, :string, :object, :array, :boolean]}
      },
      required: ["passed", "expected"]
    }

  alias Lux.Rust

  @impl true
  def handler(inputs, _context) do
    func = Map.get(inputs, "function") || Map.get(inputs, :function)
    args = Map.get(inputs, "args") || Map.get(inputs, :args, %{})
    expected = Map.get(inputs, "expected") || Map.get(inputs, :expected)

    case Rust.call(func, args) do
      {:ok, actual} ->
        passed = actual == expected
        {:ok, %{passed: passed, actual: actual, expected: expected}}

      {:error, reason} ->
        {:ok, %{passed: false, actual: inspect(reason), expected: expected}}
    end
  end
end
