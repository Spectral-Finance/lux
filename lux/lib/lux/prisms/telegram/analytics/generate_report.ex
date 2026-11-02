defmodule Lux.Prisms.Telegram.Analytics.GenerateReport do
  @moduledoc """
  A prism for generating formatted Markdown or HTML analytics reports with ASCII visual charts.
  """

  use Lux.Prism,
    name: "Generate Telegram Analytics Report",
    description: "Builds executive analytics reports with visual ASCII bar charts, progress meters, and summaries",
    input_schema: %{
      type: :object,
      properties: %{
        analytics: %{type: :object, description: "Combined analytics map"},
        format: %{type: :string, description: "'markdown' or 'html'"}
      },
      required: ["analytics"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        format: %{type: :string},
        report: %{type: :string}
      },
      required: ["format", "report"]
    }

  alias Lux.Integrations.Telegram.Analytics.ReportGenerator

  def handler(params, _agent) when is_map(params) do
    analytics = Map.get(params, :analytics) || Map.get(params, "analytics") || params
    format = to_string(Map.get(params, :format) || Map.get(params, "format", "markdown"))

    report =
      case format do
        "html" -> ReportGenerator.generate_html_report(analytics)
        _ -> ReportGenerator.generate_markdown_report(analytics)
      end

    {:ok,
     %{
       format: format,
       report: report
     }}
  end

  def handler(_, _), do: {:error, "Invalid input: expected analytics map"}
end
