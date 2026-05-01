defmodule Lux.Lenses.Youtube.AnalyticsTest do
  use ExUnit.Case, async: true

  describe "ChannelMetrics/1" do
    test "fetches channel metrics with valid channel_id" do
      params = %{channel_id: "UC1234567890"}
      result = Lux.Lenses.Youtube.Analytics.ChannelMetrics.handler(params, %{name: "TestAgent"})
      assert {:ok, %{channel_id: "UC1234567890"}} = result
    end

    test "returns error with invalid channel_id" do
      result = Lux.Lenses.Youtube.Analytics.ChannelMetrics.handler(%{channel_id: "INVALID"}, %{name: "TestAgent"})
      assert {:error, _} = result
    end
  end

  describe "VideoPerformance/1" do
    test "fetches video performance with valid video_id" do
      params = %{video_id: "abc123def45"}
      result = Lux.Lenses.Youtube.Analytics.VideoPerformance.handler(params, %{name: "TestAgent"})
      assert {:ok, %{video_id: "abc123def45"}} = result
    end
  end

  describe "CompetitorAnalysis/1" do
    test "analyzes competitors with valid channel_ids" do
      params = %{channel_id: "UC1234567890", competitor_ids: ["UC0987654321"]}
      result = Lux.Lenses.Youtube.Analytics.CompetitorAnalysis.handler(params, %{name: "TestAgent"})
      assert {:ok, %{channel_id: "UC1234567890"}} = result
    end
  end

  describe "GrowthTrends/1" do
    test "analyzes growth trends with valid channel_id" do
      params = %{channel_id: "UC1234567890", period: "30d"}
      result = Lux.Lenses.Youtube.Analytics.GrowthTrends.handler(params, %{name: "TestAgent"})
      assert {:ok, %{channel_id: "UC1234567890"}} = result
    end

    test "uses default period when not specified" do
      params = %{channel_id: "UC1234567890"}
      result = Lux.Lenses.Youtube.Analytics.GrowthTrends.handler(params, %{name: "TestAgent"})
      assert {:ok, _} = result
    end
  end

  describe "RevenueOptimization/1" do
    test "analyzes revenue with valid channel_id" do
      params = %{channel_id: "UC1234567890", category: "tech"}
      result = Lux.Lenses.Youtube.Analytics.RevenueOptimization.handler(params, %{name: "TestAgent"})
      assert {:ok, %{channel_id: "UC1234567890"}} = result
    end
  end

  describe "AudienceRetention/1" do
    test "analyzes retention with valid channel_id" do
      params = %{channel_id: "UC1234567890"}
      result = Lux.Lenses.Youtube.Analytics.AudienceRetention.handler(params, %{name: "TestAgent"})
      assert {:ok, %{channel_id: "UC1234567890"}} = result
    end
  end
end
