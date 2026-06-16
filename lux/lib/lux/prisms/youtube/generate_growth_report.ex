defmodule Lux.Prisms.YouTube.GenerateGrowthReport do
  @moduledoc """
  Generates a YouTube analytics and growth report.
  """

  use Lux.Prism,
    name: "Generate YouTube Growth Report",
    description:
      "Builds YouTube analytics, growth prediction, revenue optimization, retention, and audit output",
    input_schema: %{
      type: :object,
      properties: %{
        snapshots: %{type: :array, description: "YouTube metric snapshots"},
        horizon_days: %{type: :integer, description: "Forecast horizon in days"}
      },
      required: ["snapshots"]
    },
    output_schema: %{
      type: :object,
      properties: %{report: %{type: :object}},
      required: ["report"]
    }

  alias Lux.Integrations.YouTube.AnalyticsGrowth

  @impl true
  def handler(params, _ctx) do
    snapshots = Map.get(params, :snapshots, Map.get(params, "snapshots", []))
    horizon_days = Map.get(params, :horizon_days, Map.get(params, "horizon_days", 30))

    with {:ok, report} <- AnalyticsGrowth.report(snapshots, horizon_days: horizon_days) do
      {:ok, %{report: report}}
    end
  end
end
