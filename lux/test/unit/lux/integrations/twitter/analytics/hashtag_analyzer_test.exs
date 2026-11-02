defmodule Lux.Integrations.Twitter.Analytics.HashtagAnalyzerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Analytics.HashtagAnalyzer

  describe "extract_hashtags/1" do
    test "extracts and normalizes unique hashtags" do
      text = "Building the future of #AI and #Web3 with #ai frameworks!"
      tags = HashtagAnalyzer.extract_hashtags(text)

      assert length(tags) == 2
      assert "#ai" in tags
      assert "#web3" in tags
    end
  end

  describe "analyze_hashtags/1" do
    test "aggregates frequency and engagements across tweets" do
      tweets = [
        %{
          id: "t1",
          text: "Massive launch for #DeFi and #Web3",
          public_metrics: %{"like_count" => 100, "retweet_count" => 20, "reply_count" => 5}
        },
        %{
          id: "t2",
          text: "Continuous upgrades in #Web3",
          public_metrics: %{"like_count" => 200, "retweet_count" => 50, "reply_count" => 10}
        }
      ]

      result = HashtagAnalyzer.analyze_hashtags(tweets)

      assert length(result) == 2
      top_tag = hd(result)
      assert top_tag.tag == "#web3"
      assert top_tag.count == 2
      # (100 + 20 + 5) + (200 + 50 + 10) = 125 + 260 = 385
      assert top_tag.total_engagements == 385
      assert top_tag.top_tweet_id == "t2"
    end
  end
end
