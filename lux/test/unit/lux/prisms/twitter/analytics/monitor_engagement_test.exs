defmodule Lux.Prisms.Twitter.Analytics.MonitorEngagementTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Twitter.Analytics.MonitorEngagement

  @agent_ctx %{name: "TestAgent"}

  describe "handler/2 — threshold monitoring" do
    test "returns ok status when all metrics are within thresholds" do
      assert {:ok, result} = MonitorEngagement.handler(%{
        metrics: %{like_count: 500, retweet_count: 100},
        thresholds: %{like_count: %{min: 100, max: 10_000}, retweet_count: %{min: 10}}
      }, @agent_ctx)
      assert result.status == "ok"
      assert result.alerts == []
      assert result.metrics_checked == 2
    end

    test "triggers alert when metric exceeds max threshold" do
      assert {:ok, result} = MonitorEngagement.handler(%{
        metrics: %{like_count: 50_000},
        thresholds: %{like_count: %{max: 10_000}}
      }, @agent_ctx)
      assert result.status == "alert"
      assert length(result.alerts) == 1
      alert = List.first(result.alerts)
      assert alert.metric == "like_count"
      assert alert.type == "above_max"
      assert alert.value == 50_000
      assert alert.threshold == 10_000
    end

    test "triggers alert when metric is below min threshold" do
      assert {:ok, result} = MonitorEngagement.handler(%{
        metrics: %{like_count: 5},
        thresholds: %{like_count: %{min: 100}}
      }, @agent_ctx)
      assert result.status == "alert"
      alert = List.first(result.alerts)
      assert alert.type == "below_min"
      assert alert.severity == "low"
    end

    test "triggers multiple alerts for multiple threshold violations" do
      assert {:ok, result} = MonitorEngagement.handler(%{
        metrics: %{like_count: 5, retweet_count: 200_000},
        thresholds: %{like_count: %{min: 100}, retweet_count: %{max: 10_000}}
      }, @agent_ctx)
      assert result.status == "alert"
      assert length(result.alerts) == 2
    end

    test "includes tweet_id in result when provided" do
      assert {:ok, result} = MonitorEngagement.handler(%{
        metrics: %{like_count: 100},
        thresholds: %{like_count: %{min: 50}},
        tweet_id: "1234567890"
      }, @agent_ctx)
      assert result.tweet_id == "1234567890"
    end

    test "handles empty thresholds gracefully" do
      assert {:ok, result} = MonitorEngagement.handler(%{
        metrics: %{like_count: 100},
        thresholds: %{}
      }, @agent_ctx)
      assert result.status == "ok"
      assert result.metrics_checked == 0
    end

    test "accepts string keys" do
      assert {:ok, result} = MonitorEngagement.handler(%{
        "metrics" => %{"like_count" => 5000},
        "thresholds" => %{"like_count" => %{"min" => 100, "max" => 100_000}}
      }, @agent_ctx)
      assert result.status == "ok"
    end
  end
end
