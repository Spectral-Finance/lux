defmodule Lux.Prisms.Languages.Rust.ExecutePrism do
  @moduledoc """
  A prism for executing native Rust functions or expressions with variable bindings.
  """

  use Lux.Prism,
    name: "Rust Native Execution",
    description: "Executes native Rust functions or expressions with type conversion",
    input_schema: %{
      type: :object,
      properties: %{
        function: %{
          type: :string,
          description: "Registered Rust function name (e.g. 'math.add', 'math.fibonacci')",
          default: "math.add"
        },
        args: %{
          type: [:object, :array, :number, :string],
          description: "Arguments or variables to pass to the function"
        }
      },
      required: ["function"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: [:number, :string, :object, :array, :boolean, :null]},
        function: %{type: :string},
        success: %{type: :boolean}
      },
      required: ["result", "function", "success"]
    }

  alias Lux.Rust

  @impl true
  def handler(inputs, _context) do
    func = Map.get(inputs, "function") || Map.get(inputs, :function, "math.add")
    args = Map.get(inputs, "args") || Map.get(inputs, :args, %{})

    case Rust.call(func, args) do
      {:ok, result} ->
        {:ok,
         %{
           result: result,
           function: func,
           success: true
         }}

      {:error, %Rust.Error{} = err} ->
        {:error, "Rust execution failed: #{err.message}"}
    end
  end
end
