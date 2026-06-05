defmodule Lux.Prisms.Twitter.GenerateAnalyticsReportTest do
  use UnitCase, async: true

  alias Lux.Prisms.Twitter.GenerateAnalyticsReport

  describe "handler/2" do
    test "returns a Twitter analytics report" do
      assert {:ok, report} =
               GenerateAnalyticsReport.handler(
                 %{
                   account_id: "lux",
                   tweets: [
                     %{id: "t1", text: "great update", impressions: 100, likes: 8, replies: 2}
                   ],
                   mentions: [],
                   follower_snapshots: [
                     %{timestamp: "2026-06-01", count: 20},
                     %{timestamp: "2026-06-02", count: 22}
                   ]
                 },
                 %{name: "TestAgent"}
               )

      assert report.account_id == "lux"
      assert report.metrics.engagements == 10
      assert report.metrics.engagement_rate == 0.1
      assert report.follower_growth.delta == 2
    end
  end

  describe "schema validation" do
    test "exposes input and output schemas" do
      prism = GenerateAnalyticsReport.view()

      assert prism.input_schema.required == ["tweets"]
      assert Map.has_key?(prism.input_schema.properties, :tweets)
      assert Map.has_key?(prism.input_schema.properties, :mentions)
      assert Map.has_key?(prism.output_schema.properties, :metrics)
      assert Map.has_key?(prism.output_schema.properties, :alerts)
    end
  end
end
