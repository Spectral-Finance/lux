defmodule Lux.Prisms.Languages.Rust.BenchmarkPrism do
  @moduledoc """
  A prism for benchmarking native Rust execution latency and throughput.
  """

  use Lux.Prism,
    name: "Rust Native Benchmark",
    description: "Measures execution time in microseconds for native Rust functions",
    input_schema: %{
      type: :object,
      properties: %{
        iterations: %{
          type: :integer,
          description: "Number of benchmark iterations",
          default: 100
        },
        function: %{
          type: :string,
          default: "math.fibonacci"
        },
        args: %{
          type: [:object, :integer],
          default: %{"n" => 25}
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        function: %{type: :string},
        total_time_us: %{type: :integer},
        avg_time_us: %{type: :number},
        iterations: %{type: :integer},
        result: %{type: [:number, :object, :string]}
      },
      required: ["function", "total_time_us", "avg_time_us", "iterations"]
    }

  alias Lux.Rust

  @impl true
  def handler(inputs, _context) do
    iterations = Map.get(inputs, "iterations") || Map.get(inputs, :iterations, 100)
    func = Map.get(inputs, "function") || Map.get(inputs, :function, "math.fibonacci")
    args = Map.get(inputs, "args") || Map.get(inputs, :args, %{"n" => 25})

    {time_us, result} =
      :timer.tc(fn ->
        Enum.reduce(1..iterations, nil, fn _, _acc ->
          {:ok, res} = Rust.call(func, args)
          res
        end)
      end)

    avg_us = Float.round(time_us / max(1, iterations), 2)

    {:ok,
     %{
       function: func,
       total_time_us: time_us,
       avg_time_us: avg_us,
       iterations: iterations,
       result: result
     }}
  end
end
