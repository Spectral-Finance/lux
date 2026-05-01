defmodule Lux.Lenses.Twitter.Analytics.HashtagPerformanceTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Twitter.Analytics.HashtagPerformance

  describe "before_focus/1" do
    test "sets default granularity to day" do
      params = %{query: "#Elixir"}
      result = HashtagPerformance.before_focus(params)

      assert Map.get(result, :granularity) == "day"
    end

    test "preserves explicit granularity" do
      params = %{query: "#Elixir", granularity: "hour"}
      result = HashtagPerformance.before_focus(params)

      assert Map.get(result, :granularity) == "hour"
    end

    test "adds default time range when not specified" do
      params = %{query: "#Elixir"}
      result = HashtagPerformance.before_focus(params)

      assert Map.has_key?(result, :start_time)
      assert Map.has_key?(result, :end_time)
    end
  end

  describe "after_focus/1" do
    test "parses tweet counts with trends" do
      body = %{
        "data" => [
          %{"start" => "2024-01-01T00:00:00Z", "end" => "2024-01-01T23:59:59Z", "tweet_count" => 150},
          %{"start" => "2024-01-02T00:00:00Z", "end" => "2024-01-02T23:59:59Z", "tweet_count" => 200}
        ],
        "meta" => %{"total_tweet_count" => 350, "granularity" => "day"}
      }

      {:ok, result} = HashtagPerformance.after_focus(body)

      assert result.total_tweets == 350
      assert length(result.trends) == 2
      assert hd(result.trends).tweet_count == 150
    end

    test "handles zero results" do
      body = %{"meta" => %{"total_tweet_count" => 0}}

      {:ok, result} = HashtagPerformance.after_focus(body)
      assert result.total_tweets == 0
    end
  end
end
