defmodule Lux.Prisms.TwitterAnalyticsPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.TwitterAnalyticsPrism

  describe "handler/2 actions" do
    test "tracks engagement metrics via prism" do
      tweets = [
        %{"public_metrics" => %{"like_count" => 100, "retweet_count" => 20, "impression_count" => 1000}}
      ]

      {:ok, res} =
        TwitterAnalyticsPrism.run(%{
          action: "track_engagement",
          payload: %{tweets: tweets}
        })

      assert res.action == "track_engagement"
      assert res.result.likes == 100
      assert res.result.total_engagements == 120
    end

    test "analyzes sentiment via prism" do
      {:ok, res} =
        TwitterAnalyticsPrism.run(%{
          action: "analyze_sentiment",
          payload: %{text: "Lux is absolutely amazing and bullish! 🚀"}
        })

      assert res.action == "analyze_sentiment"
      assert res.result.classification == :positive
    end

    test "executes full audit via prism" do
      tweets = [
        %{
          "id" => "t1",
          "text" => "Innovating with #Lux and #Agents 🚀",
          "public_metrics" => %{"like_count" => 200, "retweet_count" => 50, "impression_count" => 5000}
        }
      ]

      mentions = ["Great work on Lux!"]

      {:ok, res} =
        TwitterAnalyticsPrism.run(%{
          action: "run_full_audit",
          payload: %{tweets: tweets, mentions: mentions}
        })

      assert res.action == "run_full_audit"
      assert res.result.metrics.likes == 200
      assert is_binary(res.result.report)
      assert length(res.result.hashtags) == 2
    end
  end
end
