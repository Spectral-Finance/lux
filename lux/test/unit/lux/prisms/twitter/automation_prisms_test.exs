defmodule Lux.Prisms.Twitter.AutomationPrismsTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.Automation.{
    ScheduleTweet,
    ManageCalendar,
    ProcessAutoReply,
    CurateContent,
    EvaluateEngagementRules,
    ManageFollows,
    AutomateDM
  }

  describe "Twitter Automation Prisms" do
    test "ScheduleTweet prism schedules a tweet" do
      params = %{
        text: "Automated schedule test",
        scheduled_at: DateTime.to_iso8601(DateTime.utc_now()),
        priority: "high"
      }

      assert {:ok, result} = ScheduleTweet.handler(params, %{})
      assert result.status == "pending"
      assert result.priority == "high"
      assert String.starts_with?(result.id, "sched_")
    end

    test "ManageCalendar prism adds slots and plans schedules" do
      add_params = %{
        action: "add_slot",
        day_of_week: 1,
        time: "10:00",
        topic: "defi"
      }

      assert {:ok, add_res} = ManageCalendar.handler(add_params, %{})
      assert add_res.status == "slot_added"

      plan_params = %{
        action: "plan_schedule",
        drafts: [%{text: "DeFi yield analysis", topic: :market_update}]
      }

      assert {:ok, plan_res} = ManageCalendar.handler(plan_params, %{})
      assert plan_res.status == "planned"
      assert length(plan_res.result) == 1
    end

    test "ProcessAutoReply prism evaluates and generates reply" do
      params = %{
        tweet: %{
          author_id: "u_999",
          author: %{username: "tester"},
          text: "Can someone share the docs please?"
        }
      }

      assert {:ok, result} = ProcessAutoReply.handler(params, %{})
      assert result.should_reply == true
      assert String.contains?(result.reply_text, "https://docs.lux.xyz")
    end

    test "CurateContent prism ranks candidates" do
      params = %{
        candidates: [
          %{
            id: "10",
            text: "Solana DeFi analysis",
            public_metrics: %{like_count: 50, retweet_count: 20}
          }
        ],
        min_score: 5.0
      }

      assert {:ok, result} = CurateContent.handler(params, %{})
      assert result.count == 1
      assert hd(result.ranked_items).tweet_id == "10"
    end

    test "EvaluateEngagementRules prism evaluates rules and caps" do
      rules = [
        %{
          name: "Rollup Discussion",
          conditions: %{keywords_any: ["rollup"]},
          actions: [:like]
        }
      ]

      params = %{
        tweet: %{text: "New rollup launched today"},
        rules: rules,
        daily_usage: %{like: 0}
      }

      assert {:ok, result} = EvaluateEngagementRules.handler(params, %{})
      assert result.matched_rules == ["Rollup Discussion"]
      assert :like in result.approved_actions
    end

    test "ManageFollows prism evaluates target profiles" do
      params = %{
        action: "evaluate_target",
        user: %{
          description: "Smart contract engineer building on Ethereum",
          public_metrics: %{followers_count: 1200, following_count: 300}
        },
        target_keywords: ["smart contract", "ethereum"]
      }

      assert {:ok, result} = ManageFollows.handler(params, %{})
      assert result.status == "evaluated"
      assert result.result.should_follow == true
    end

    test "AutomateDM prism generates welcome message" do
      params = %{
        action: "welcome",
        user: %{username: "new_supporter"}
      }

      assert {:ok, result} = AutomateDM.handler(params, %{})
      assert result.status == "welcome_generated"
      assert String.contains?(result.text, "@new_supporter")
    end
  end
end
