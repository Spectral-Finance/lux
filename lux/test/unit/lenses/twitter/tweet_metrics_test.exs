defmodule Lux.Lenses.Twitter.Analytics.TweetMetricsTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Twitter.Analytics.TweetMetrics

  describe "before_focus/1" do
    test "transforms tweet_ids to ids parameter and adds tweet.fields" do
      params = %{tweet_ids: "123,456", metrics: "public_metrics"}
      result = TweetMetrics.before_focus(params)

      assert Map.get(result, :ids) == "123,456"
      assert Map.get(result, :"tweet.fields") == "public_metrics"
      refute Map.has_key?(result, :tweet_ids)
      refute Map.has_key?(result, :metrics)
    end

    test "defaults to public_metrics when no metrics specified" do
      params = %{tweet_ids: "123"}
      result = TweetMetrics.before_focus(params)

      assert Map.get(result, :"tweet.fields") == "public_metrics"
    end
  end

  describe "after_focus/1" do
    test "parses tweet data into structured metrics" do
      body = %{
        "data" => [
          %{
            "id" => "123",
            "text" => "Hello world",
            "public_metrics" => %{
              "like_count" => 100,
              "retweet_count" => 50,
              "reply_count" => 25,
              "quote_count" => 10,
              "bookmark_count" => 5,
              "impression_count" => 10000
            }
          }
        ]
      }

      {:ok, result} = TweetMetrics.after_focus(body)

      assert length(result.metrics) == 1
      metric = hd(result.metrics)
      assert metric.tweet_id == "123"
      assert metric.likes == 100
      assert metric.retweets == 50
      assert metric.replies == 25
      assert metric.quotes == 10
      assert metric.bookmarks == 5
      assert metric.impressions == 10000
    end

    test "handles multiple tweets" do
      body = %{
        "data" => [
          %{"id" => "1", "public_metrics" => %{"like_count" => 10}},
          %{"id" => "2", "public_metrics" => %{"like_count" => 20}}
        ]
      }

      {:ok, result} = TweetMetrics.after_focus(body)
      assert result.count == 2
    end

    test "returns error on API errors" do
      body = %{"errors" => [%{"message" => "Unauthorized"}]}
      {:error, _} = TweetMetrics.after_focus(body)
    end
  end
end
