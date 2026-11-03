defmodule Lux.Beams.Languages.Rust.Testing.RustTestSuiteBeam do
  @moduledoc """
  A beam orchestrating the native Rust test execution pipeline:
  1. Generates test fixtures and input vectors.
  2. Runs Cargo native tests with test filtering.
  3. Evaluates test coverage metrics.

  ## Example Usage

  ```elixir
  {:ok, result, execution_log} = Lux.Beams.Languages.Rust.Testing.RustTestSuiteBeam.run(%{
    fixture_name: "vectors",
    size: 10
  })
  ```
  """

  use Lux.Beam,
    name: "Rust Test Suite Pipeline",
    description: "Orchestrates fixture generation, Cargo test execution, and test metrics evaluation",
    input_schema: %{
      type: :object,
      properties: %{
        fixture_name: %{
          type: :string,
          default: "vectors"
        },
        size: %{
          type: :integer,
          default: 5
        },
        filter: %{
          type: :string
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean},
        passed: %{type: :integer},
        coverage_percentage: %{type: :number}
      },
      required: ["success", "passed"]
    },
    generate_execution_log: true

  alias Lux.Prisms.Languages.Rust.Testing.CoveragePrism
  alias Lux.Prisms.Languages.Rust.Testing.FixturePrism
  alias Lux.Prisms.Languages.Rust.Testing.RunTestsPrism

  sequence do
    # Step 1: Generate test fixture
    step(:generate_fixture, FixturePrism, %{
      fixture_name: [:input, :fixture_name],
      size: [:input, :size]
    })

    # Step 2: Run Cargo test suite
    step(:execute_tests, RunTestsPrism, %{
      filter: [:input, :filter]
    })

    # Step 3: Evaluate test metrics & coverage
    step(:evaluate_coverage, CoveragePrism, %{
      passed: [:steps, :execute_tests, :passed],
      total: [:steps, :execute_tests, :total]
    })
  end
end
