defmodule Lux.Integrations.Twitter.Analytics.EngagementTrackerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Analytics.EngagementTracker

  describe "aggregate_metrics/1" do
    test "correctly aggregates impressions, engagements, and calculates rates" do
      tweets = [
        %{
          "id" => "tx_1",
          "public_metrics" => %{
            "like_count" => 100,
            "retweet_count" => 40,
            "reply_count" => 10,
            "quote_count" => 5,
            "bookmark_count" => 5,
            "impression_count" => 2000
          }
        },
        %{
          "id" => "tx_2",
          "public_metrics" => %{
            "like_count" => 200,
            "retweet_count" => 60,
            "reply_count" => 20,
            "quote_count" => 5,
            "bookmark_count" => 15,
            "impression_count" => 3000
          }
        }
      ]

      result = EngagementTracker.aggregate_metrics(tweets)

      assert result.likes == 300
      assert result.retweets == 100
      assert result.replies == 30
      assert result.quotes == 10
      assert result.bookmarks == 20
      assert result.impressions == 5000
      assert result.total_engagements == 460
      # 460 / 5000 = 0.092
      assert result.engagement_rate == 0.092
      # (100 + 10) / 460 = 0.2391
      assert result.virality_score == 0.2391
    end

    test "handles empty tweets list gracefully" do
      result = EngagementTracker.aggregate_metrics([])
      assert result.total_engagements == 0
      assert result.engagement_rate == 0.0
      assert result.virality_score == 0.0
    end
  end

  describe "rank_top_tweets/2" do
    test "ranks tweets in descending order of engagement" do
      tweets = [
        %{"id" => "low", "public_metrics" => %{"like_count" => 5, "retweet_count" => 1}},
        %{"id" => "high", "public_metrics" => %{"like_count" => 500, "retweet_count" => 100}},
        %{"id" => "mid", "public_metrics" => %{"like_count" => 50, "retweet_count" => 10}}
      ]

      ranked = EngagementTracker.rank_top_tweets(tweets, 2)
      assert length(ranked) == 2
      assert hd(ranked)["id"] == "high"
      assert Enum.at(ranked, 1)["id"] == "mid"
    end
  end

  describe "fetch_and_analyze/2" do
    test "fetches tweets via mock client and returns analytics" do
      plug = fn conn ->
        assert conn.request_path == "/users/user_123/tweets"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "data" => [
              %{
                "id" => "t1",
                "text" => "Tweet 1",
                "public_metrics" => %{"like_count" => 50, "retweet_count" => 10, "impression_count" => 1000}
              }
            ]
          })
        )
      end

      {:ok, result} = EngagementTracker.fetch_and_analyze("user_123", %{plug: plug})
      assert result.tweet_count == 1
      assert result.metrics.likes == 50
      assert length(result.top_tweets) == 1
    end
  end
end
