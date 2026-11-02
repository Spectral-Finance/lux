defmodule Lux.Integrations.Twitter.Automation.EngagementRulesEngineTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Automation.EngagementRulesEngine

  describe "EngagementRulesEngine" do
    test "matches declarative rules against tweet content and metrics" do
      rules = [
        %{
          name: "DeFi Research",
          conditions: %{
            keywords_any: ["defi", "liquidity", "yield"],
            min_likes: 20
          },
          actions: [:like, :retweet]
        },
        %{
          name: "Gaming",
          conditions: %{keywords_any: ["unreal engine", "fps"]},
          actions: [:like]
        }
      ]

      tweet = %{
        text: "Deep dive into Uniswap V3 liquidity and defi yields",
        public_metrics: %{like_count: 50, retweet_count: 10}
      }

      assert {:ok, result} = EngagementRulesEngine.evaluate(tweet, rules)
      assert result.matched_rules == ["DeFi Research"]
      assert :like in result.approved_actions
      assert :retweet in result.approved_actions
    end

    test "throttles actions when daily caps are reached" do
      rules = [
        %{
          name: "Crypto News",
          conditions: %{keywords_any: ["bitcoin"]},
          actions: [:like, :retweet]
        }
      ]

      tweet = %{text: "Bitcoin crosses new milestone"}
      daily_usage = %{like: 50, retweet: 5}
      caps = %{like: 50, retweet: 25}

      assert {:ok, result} = EngagementRulesEngine.evaluate(tweet, rules, daily_usage, caps)
      # Like should be throttled, retweet should be approved
      assert :like in result.throttled_actions
      assert :retweet in result.approved_actions
    end

    test "records action into daily usage table" do
      usage = %{like: 5}
      updated = EngagementRulesEngine.record_action(usage, :like)
      assert updated.like == 6
    end
  end
end
