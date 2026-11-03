defmodule Lux.Prisms.Languages.Rust.Testing.CoveragePrism do
  @moduledoc """
  A prism that calculates and evaluates test coverage ratios.
  """

  use Lux.Prism,
    name: "Rust Test Coverage",
    description: "Calculates pass ratios and test coverage metrics",
    input_schema: %{
      type: :object,
      properties: %{
        passed: %{type: :integer, default: 0},
        total: %{type: :integer, default: 0},
        min_coverage: %{type: :number, default: 80.0}
      },
      required: ["passed", "total"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        coverage_percentage: %{type: :number},
        meets_threshold: %{type: :boolean},
        status: %{type: :string}
      },
      required: ["coverage_percentage", "meets_threshold", "status"]
    }

  @impl true
  def handler(inputs, _context) do
    passed = Map.get(inputs, "passed") || Map.get(inputs, :passed, 0)
    total = Map.get(inputs, "total") || Map.get(inputs, :total, 0)
    min_cov = Map.get(inputs, "min_coverage") || Map.get(inputs, :min_coverage, 80.0)

    percentage =
      if total > 0 do
        Float.round((passed / total) * 100.0, 2)
      else
        100.0
      end

    meets = percentage >= min_cov

    {:ok,
     %{
       coverage_percentage: percentage,
       meets_threshold: meets,
       status: if(meets, do: "pass", else: "fail")
     }}
  end
end
