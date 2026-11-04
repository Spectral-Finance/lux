defmodule Lux.Prisms.Twitter.Analytics.GenerateReportPrism do
  @moduledoc """
  A prism that compiles Twitter metrics, sentiment, hashtag reach, and alerts into reports.
  """

  use Lux.Prism,
    name: "Twitter Generate Report Prism",
    description: "Compiles complete Twitter analytics report in Markdown and JSON formats",
    input_schema: %{
      type: :object,
      properties: %{
        metrics: %{type: :object},
        sentiment_summary: %{type: :object},
        hashtag_stats: %{type: :object},
        alerts: %{type: :array, default: []}
      },
      required: ["metrics"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        report_markdown: %{type: :string},
        report_json: %{type: :object},
        success: %{type: :boolean}
      },
      required: ["report_markdown", "report_json", "success"]
    }

  alias Lux.Twitter.Analytics.ReportGenerator

  @impl true
  def handler(inputs, _context) do
    metrics = Map.get(inputs, "metrics") || Map.get(inputs, :metrics, %{})
    sentiment = Map.get(inputs, "sentiment_summary") || Map.get(inputs, :sentiment_summary, %{})
    hashtags = Map.get(inputs, "hashtag_stats") || Map.get(inputs, :hashtag_stats, %{})
    alerts = Map.get(inputs, "alerts") || Map.get(inputs, :alerts, [])

    markdown = ReportGenerator.generate_markdown_report(metrics, sentiment, hashtags, alerts)
    json = ReportGenerator.generate_json_report(metrics, sentiment, hashtags, alerts)

    {:ok,
     %{
       report_markdown: markdown,
       report_json: json,
       success: true
     }}
  end
end
