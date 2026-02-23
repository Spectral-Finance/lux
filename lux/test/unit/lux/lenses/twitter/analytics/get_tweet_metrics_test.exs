defmodule Lux.Lenses.Twitter.Analytics.GetTweetMetricsTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.Analytics.GetTweetMetrics

  @tweet_id "1234567890123456789"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "transforms tweet data with all metrics" do
      response = %{
        "data" => %{
          "id" => @tweet_id,
          "text" => "Hello, world!",
          "author_id" => "987654321",
          "created_at" => "2024-01-01T00:00:00.000Z",
          "public_metrics" => %{
            "like_count" => 150,
            "retweet_count" => 42,
            "reply_count" => 28,
            "quote_count" => 12,
            "impression_count" => 5000,
            "bookmark_count" => 30
          }
        }
      }

      assert {:ok, result} = GetTweetMetrics.after_focus(response)
      assert result.tweet_id == @tweet_id
      assert result.metrics.like_count == 150
      assert result.metrics.retweet_count == 42
      assert result.metrics.impression_count == 5000
      assert result.total_engagement == 262
      assert result.engagement_rate == 5.24
    end

    test "calculates engagement rate as 0.0 when no impressions" do
      response = %{
        "data" => %{
          "id" => @tweet_id,
          "text" => "Test",
          "public_metrics" => %{
            "like_count" => 100,
            "retweet_count" => 0,
            "reply_count" => 0,
            "quote_count" => 0,
            "impression_count" => 0
          }
        }
      }

      assert {:ok, result} = GetTweetMetrics.after_focus(response)
      assert result.engagement_rate == 0.0
    end

    test "handles missing public_metrics" do
      response = %{"data" => %{"id" => @tweet_id, "text" => "No metrics"}}

      assert {:ok, result} = GetTweetMetrics.after_focus(response)
      assert result.metrics.like_count == 0
      assert result.metrics.impression_count == 0
    end

    test "returns error for API errors" do
      response = %{"errors" => [%{"title" => "Not Found Error", "detail" => "Tweet not found"}]}
      assert {:error, %{title: "Not Found Error"}} = GetTweetMetrics.after_focus(response)
    end

    test "returns error for unexpected response" do
      assert {:error, %{title: "Unexpected response"}} = GetTweetMetrics.after_focus(%{"random" => "data"})
    end
  end
end
