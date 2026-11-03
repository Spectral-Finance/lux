defmodule Lux.Beams.Languages.Rust.RustExecutionBeam do
  @moduledoc """
  A beam orchestrating high-performance native Rust execution:
  1. Validates and bridges data types across the Elixir/Rust boundary.
  2. Executes native Rust functions with memory safety and panic isolation.
  3. Computes execution latency metrics.

  ## Example Usage

  ```elixir
  {:ok, result, execution_log} = Lux.Beams.Languages.Rust.RustExecutionBeam.run(%{
    function: "math.fibonacci",
    args: %{"n" => 30},
    iterations: 100
  })
  ```
  """

  use Lux.Beam,
    name: "Rust Execution Pipeline",
    description: "Orchestrates type conversion, native Rust execution, and performance benchmarking",
    input_schema: %{
      type: :object,
      properties: %{
        function: %{
          type: :string,
          description: "Registered Rust function name",
          default: "math.fibonacci"
        },
        args: %{
          type: :object,
          description: "Arguments for the Rust function"
        },
        iterations: %{
          type: :integer,
          default: 50
        }
      },
      required: ["function", "args"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        result: %{type: [:number, :string, :object, :array, :boolean, :null]},
        total_time_us: %{type: :integer},
        avg_time_us: %{type: :number}
      },
      required: ["result"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Languages.Rust.BenchmarkPrism
  alias Lux.Prisms.Languages.Rust.ExecutePrism
  alias Lux.Prisms.Languages.Rust.TypeBridgePrism

  sequence do
    # Step 1: Type validation & conversion
    step(:type_validation, TypeBridgePrism, %{
      payload: [:input, :args]
    })

    # Step 2: Native execution
    step(:execution, ExecutePrism, %{
      function: [:input, :function],
      args: [:steps, :type_validation, :compatible_payload]
    })

    # Step 3: Performance benchmark
    step(:benchmarking, BenchmarkPrism, %{
      function: [:input, :function],
      args: [:steps, :type_validation, :compatible_payload],
      iterations: [:input, :iterations]
    })
  end
end
