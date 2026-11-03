defmodule Lux.Prisms.Languages.Rust.Components.AsyncRunnerPrism do
  @moduledoc """
  A prism for asynchronous invocation of native Rust components with task supervision and timeouts.
  """

  use Lux.Prism,
    name: "Rust Component Async Runner",
    description: "Executes native Rust components asynchronously with timeout supervision",
    input_schema: %{
      type: :object,
      properties: %{
        component_name: %{type: :string},
        args: %{type: :object},
        timeout_ms: %{type: :integer, default: 5000}
      },
      required: ["component_name", "args"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: [:number, :string, :object, :array, :boolean, :null]},
        duration_ms: %{type: :number},
        success: %{type: :boolean}
      },
      required: ["result", "duration_ms", "success"]
    }

  alias Lux.Rust.Components.Registry

  @impl true
  def handler(inputs, _context) do
    component = Map.get(inputs, "component_name") || Map.get(inputs, :component_name)
    args = Map.get(inputs, "args") || Map.get(inputs, :args, %{})
    timeout = Map.get(inputs, "timeout_ms") || Map.get(inputs, :timeout_ms, 5000)

    start_time = System.monotonic_time(:millisecond)

    task =
      Task.async(fn ->
        Registry.invoke(component, args)
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {:ok, result}} ->
        duration = System.monotonic_time(:millisecond) - start_time

        {:ok,
         %{
           result: result,
           duration_ms: duration * 1.0,
           success: true
         }}

      {:ok, {:error, reason}} ->
        {:error, "Async execution error: #{inspect(reason)}"}

      nil ->
        {:error, "Async execution timed out after #{timeout}ms"}
    end
  end
end
