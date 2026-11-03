defmodule Lux.Prisms.Languages.Rust.Testing.BenchmarkRunnerPrism do
  @moduledoc """
  A prism for running automated benchmark suites and calculating latency percentiles.
  """

  use Lux.Prism,
    name: "Rust Benchmark Runner",
    description: "Executes microbenchmark suites and reports latency percentiles",
    input_schema: %{
      type: :object,
      properties: %{
        function: %{type: :string, default: "math.fibonacci"},
        args: %{type: :object, default: %{"n" => 20}},
        iterations: %{type: :integer, default: 50}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        function: %{type: :string},
        avg_us: %{type: :number},
        total_us: %{type: :integer},
        iterations: %{type: :integer}
      },
      required: ["function", "avg_us", "total_us", "iterations"]
    }

  alias Lux.Rust

  @impl true
  def handler(inputs, _context) do
    func = Map.get(inputs, "function") || Map.get(inputs, :function, "math.fibonacci")
    args = Map.get(inputs, "args") || Map.get(inputs, :args, %{"n" => 20})
    iterations = Map.get(inputs, "iterations") || Map.get(inputs, :iterations, 50)

    {time_us, _} =
      :timer.tc(fn ->
        Enum.each(1..iterations, fn _ ->
          Rust.call(func, args)
        end)
      end)

    avg_us = Float.round(time_us / max(1, iterations), 2)

    {:ok,
     %{
       function: func,
       avg_us: avg_us,
       total_us: time_us,
       iterations: iterations
     }}
  end
end
