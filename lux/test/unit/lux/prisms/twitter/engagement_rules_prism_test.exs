defmodule Lux.Prisms.Twitter.EngagementRulesPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.Twitter.EngagementRulesPrism

  describe "run/1" do
    test "evaluates like action with keyword match" do
      assert {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "like",
        tweet_id: "12345",
        tweet_text: "Amazing DeFi protocol launch! #web3",
        rules: [
          %{type: "keyword_match", keywords: ["defi", "web3"]}
        ]
      })

      assert result[:action_taken] == "like"
      assert result[:should_execute] == true
      assert result[:rule_matched] == "keyword_match"
    end

    test "evaluates follow action with follower count rule" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "follow",
        user_id: "67890",
        author_followers: 500,
        rules: [
          %{type: "follower_count", min_followers: 100, max_followers: 1000}
        ]
      })

      assert result[:action_taken] == "follow"
      assert result[:should_execute] == true
      assert result[:rule_matched] == "follower_count"
    end

    test "rejects follow when above max followers" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "follow",
        user_id: "67890",
        author_followers: 50000,
        rules: [
          %{type: "follower_count", min_followers: 100, max_followers: 1000}
        ]
      })

      assert result[:should_execute] == false
      assert result[:reason] == "above_max_followers"
    end

    test "evaluates engagement threshold rule" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "retweet",
        tweet_id: "12345",
        engagement_count: 150,
        rules: [
          %{type: "engagement_threshold", min_engagement: 100}
        ]
      })

      assert result[:should_execute] == true
      assert result[:rule_matched] == "engagement_threshold"
    end

    test "rejects action when below engagement threshold" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "retweet",
        tweet_id: "12345",
        engagement_count: 5,
        rules: [
          %{type: "engagement_threshold", min_engagement: 100}
        ]
      })

      assert result[:should_execute] == false
      assert result[:reason] == "below_engagement_threshold"
    end

    test "respects blacklist rule" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "like",
        tweet_id: "12345",
        tweet_text: "This is a spam message with scam content",
        rules: [
          %{type: "blacklist", blacklist: ["spam", "scam"]}
        ]
      })

      assert result[:should_execute] == false
      assert result[:reason] == "blacklisted_content"
    end

    test "respects whitelist rule" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "like",
        tweet_id: "12345",
        tweet_text: "Great DeFi analysis",
        rules: [
          %{type: "whitelist", whitelist: ["defi", "analysis"]}
        ]
      })

      assert result[:should_execute] == true
      assert result[:rule_matched] == "whitelist"
    end

    test "respects following limit" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "follow",
        user_id: "67890",
        current_following_count: 5000,
        max_following: 5000,
        author_followers: 500,
        rules: [
          %{type: "follower_count", min_followers: 100}
        ]
      })

      assert result[:should_execute] == false
      assert result[:reason] == "following_limit_reached"
    end

    test "dry_run prevents action execution" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "like",
        tweet_id: "12345",
        tweet_text: "Great DeFi content",
        dry_run: true,
        rules: [
          %{type: "keyword_match", keywords: ["defi"]}
        ]
      })

      assert result[:should_execute] == true
      assert result[:action_executed] == false
    end

    test "score is between 0 and 1" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "like",
        tweet_id: "12345",
        tweet_text: "Test content",
        rules: [
          %{type: "keyword_match", keywords: ["test"]}
        ]
      })

      assert result[:score] >= 0.0
      assert result[:score] <= 1.0
    end

    test "generates recommendations" do
      {:ok, result} = Lux.Prisms.Twitter.EngagementRulesPrism.run(%{
        action: "like",
        tweet_id: "12345",
        tweet_text: "Test",
        rules: []
      })

      assert is_list(result[:recommendations])
    end

    test "has correct prism metadata" do
      assert Lux.Prisms.Twitter.EngagementRulesPrism.__meta__(:name) == "Engagement Rules"
    end

    test "input schema has required fields" do
      schema = Lux.Prisms.Twitter.EngagementRulesPrism.__input_schema__()
      assert "action" in schema[:required]
    end

    test "action has enum constraint" do
      schema = Lux.Prisms.Twitter.EngagementRulesPrism.__input_schema__()
      action_prop = schema[:properties]["action"]
      assert action_prop[:enum] != nil
      assert "follow" in action_prop[:enum]
      assert "like" in action_prop[:enum]
      assert "retweet" in action_prop[:enum]
    end
  end
end
