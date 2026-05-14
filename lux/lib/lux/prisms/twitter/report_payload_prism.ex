defmodule Lux.Prisms.Twitter.ReportPayloadPrism do
  @moduledoc """
  Builds dashboard-ready Twitter/X report payloads.
  """

  use Lux.Prism,
    name: "Twitter Report Payload",
    description:
      "Builds dashboard-ready Twitter/X report and chart payloads from normalized events"

  alias Lux.Integrations.Twitter.Analytics

  def handler(input, _ctx) do
    report = Analytics.build_report(input)

    {:ok,
     %{
       generated_at: report.generated_at,
       summary: report.summary,
       charts: report.charts,
       top_hashtags: Enum.take(report.hashtags, 5)
     }}
  end
end
