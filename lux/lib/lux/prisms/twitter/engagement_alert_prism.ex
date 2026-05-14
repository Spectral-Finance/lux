defmodule Lux.Prisms.Twitter.EngagementAlertPrism do
  @moduledoc """
  Evaluates Twitter/X engagement monitoring thresholds.
  """

  use Lux.Prism,
    name: "Twitter Engagement Alerts",
    description:
      "Evaluates alert thresholds for Twitter/X engagement, follower growth, sentiment, and hashtags"

  alias Lux.Integrations.Twitter.Analytics

  def handler(input, _ctx) do
    report = Analytics.build_report(input)
    {:ok, %{alerts: report.alerts, summary: report.summary}}
  end
end
