defmodule Lux.Prisms.Telegram.Analytics.BuildReport do
  @moduledoc """
  Builds a compact report payload from Telegram analytics metrics.
  """

  use Lux.Prism,
    name: "Build Telegram Analytics Report",
    description:
      "Formats Telegram analytics into a compact summary with sections and visualization data",
    input_schema: %{
      type: :object,
      properties: %{
        updates: %{type: :array, description: "Raw Telegram updates or normalized events"},
        report: %{type: :object, description: "Optional precomputed analytics report"},
        title: %{type: :string, description: "Optional report title"}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string},
        summary: %{type: :object},
        sections: %{type: :array},
        visualizations: %{type: :object}
      },
      required: ["title", "summary", "sections", "visualizations"]
    }

  alias Lux.Integrations.Telegram.Analytics

  @impl true
  def handler(params, _agent) do
    report = fetch_param(params, :report) || Analytics.report(fetch_param(params, :updates) || [])
    title = fetch_param(params, :title) || "Telegram analytics report"

    {:ok, Analytics.report_payload(report, %{title: title})}
  end

  defp fetch_param(params, key) when is_map(params),
    do:
      if(Map.has_key?(params, key),
        do: Map.get(params, key),
        else: Map.get(params, Atom.to_string(key))
      )
end
