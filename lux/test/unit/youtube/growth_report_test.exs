defmodule Lux.Prisms.Youtube.AnalyticsTest do
  use ExUnit.Case, async: true

  describe "GrowthReport/1" do
    test "generates comprehensive growth report" do
      params = %{channel_id: "UC1234567890", category: "tech"}
      result = Lux.Prisms.Youtube.Analytics.GrowthReport.handler(params, %{name: "TestAgent"})
      assert {:ok, %{channel_id: "UC1234567890", report_type: "growth_analytics"}} = result
    end

    test "includes competitors when provided" do
      params = %{channel_id: "UC1234567890", competitor_ids: ["UC0987654321"]}
      result = Lux.Prisms.Youtube.Analytics.GrowthReport.handler(params, %{name: "TestAgent"})
      assert {:ok, %{channel_id: "UC1234567890"}} = result
    end
  end
end
