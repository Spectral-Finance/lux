defmodule Lux.Prisms.Languages.Rust.Testing.RunTestsPrism do
  @moduledoc """
  A prism for executing native Rust tests and returning a structured summary.
  """

  use Lux.Prism,
    name: "Run Rust Tests",
    description: "Executes Rust cargo tests and parses output into test metrics",
    input_schema: %{
      type: :object,
      properties: %{
        filter: %{
          type: :string,
          description: "Optional test name filter pattern"
        },
        dir: %{
          type: :string,
          description: "Optional custom project directory"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        passed: %{type: :integer},
        failed: %{type: :integer},
        ignored: %{type: :integer},
        total: %{type: :integer},
        success: %{type: :boolean}
      },
      required: ["passed", "failed", "total", "success"]
    }

  alias Lux.Rust.Testing.Runner

  @impl true
  def handler(inputs, _context) do
    filter = Map.get(inputs, "filter") || Map.get(inputs, :filter)
    dir = Map.get(inputs, "dir") || Map.get(inputs, :dir)

    opts = []
    opts = if filter, do: Keyword.put(opts, :filter, filter), else: opts
    opts = if dir, do: Keyword.put(opts, :dir, dir), else: opts

    case Runner.run_tests(opts) do
      {:ok, report} ->
        {:ok,
         %{
           passed: report.passed,
           failed: report.failed,
           ignored: report.ignored,
           total: report.total,
           success: report.success
         }}

      {:error, reason} ->
        {:error, "Rust test execution failed: #{inspect(reason)}"}
    end
  end
end
