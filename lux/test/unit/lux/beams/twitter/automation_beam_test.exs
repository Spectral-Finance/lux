defmodule Lux.Beams.Twitter.AutomationBeamTest do
  use ExUnit.Case, async: true

  alias Lux.Beams.Twitter.AutomationBeam

  describe "AutomationBeam" do
    test "processes tweet through engagement rules and auto-reply" do
      tweet = %{
        author_id: "author_42",
        author: %{username: "vitalik_fan"},
        text: "Where are the docs for building with Lux?",
        public_metrics: %{like_count: 30, retweet_count: 5}
      }

      rules = [
        %{
          name: "Doc Queries",
          conditions: %{keywords_any: ["docs"]},
          actions: [:like]
        }
      ]

      assert {:ok, result} =
               AutomationBeam.process_tweet(tweet,
                 rules: rules,
                 daily_usage: %{like: 10}
               )

      assert result.engagement_evaluation.matched_rules == ["Doc Queries"]
      assert :like in result.engagement_evaluation.approved_actions
      assert result.auto_reply.should_reply == true
      assert String.contains?(result.auto_reply.reply_text, "https://docs.lux.xyz")
    end
  end
end
