defmodule Lux.Integrations.Twitter.Automation.ContentCuratorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Automation.ContentCurator

  describe "ContentCurator" do
    test "scores tweet based on engagement metrics and author credibility" do
      viral_tweet = %{
        id: "tw_999",
        author: %{username: "vitalik", verified: true, public_metrics: %{followers_count: 5_000_000}},
        text: "The future of Ethereum scalability and rollups",
        public_metrics: %{
          like_count: 1500,
          retweet_count: 500,
          quote_count: 200,
          reply_count: 100
        },
        attachments: %{media_keys: ["m1"]}
      }

      scored = ContentCurator.score_tweet(viral_tweet)
      assert scored.score > 100.0
      assert scored.recommended_action == :quote_tweet
      assert String.contains?(scored.suggested_commentary, "@vitalik")
    end

    test "ranks content and excludes already seen tweets" do
      t1 = %{id: "1", public_metrics: %{like_count: 10, retweet_count: 5}}
      t2 = %{id: "2", public_metrics: %{like_count: 500, retweet_count: 100}}

      # t2 should rank higher than t1
      ranked = ContentCurator.rank_content([t1, t2], [], %{min_score: 1.0})
      assert length(ranked) == 2
      assert hd(ranked).tweet_id == "2"

      # seen_ids should exclude t2
      filtered = ContentCurator.rank_content([t1, t2], ["2"], %{min_score: 1.0})
      assert length(filtered) == 1
      assert hd(filtered).tweet_id == "1"
    end
  end
end
