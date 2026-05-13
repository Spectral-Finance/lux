defmodule Lux.Integrations.Twitter.AutomationTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Twitter.Automation

  describe "schedule_post/3" do
    test "builds scheduled post queue items" do
      created_at = ~U[2026-05-13 00:00:00Z]

      item =
        Automation.schedule_post("launch update", "2026-05-14T12:00:00Z", %{
          id: "post-1",
          account_id: "account-1",
          tags: ["launch"],
          created_at: created_at
        })

      assert item.id == "post-1"
      assert item.type == :post
      assert item.state == :pending
      assert item.content == "launch update"
      assert item.scheduled_at == "2026-05-14T12:00:00Z"
      assert item.account_id == "account-1"
      assert item.created_at == created_at
    end
  end

  describe "enqueue_action/3 and transition/3" do
    test "builds action queue items and transitions state" do
      item =
        Automation.enqueue_action(:reply, %{tweet_id: "tweet-1", text: "thanks"}, %{
          id: "reply-1",
          priority: :high,
          max_attempts: 5
        })

      assert item.state == :pending
      assert item.priority == :high
      assert item.max_attempts == 5

      updated_at = ~U[2026-05-13 01:00:00Z]

      assert {:ok, completed} =
               Automation.transition(item, :completed, %{
                 updated_at: updated_at,
                 result: %{tweet_id: "reply-tweet"}
               })

      assert completed.state == :completed
      assert completed.updated_at == updated_at
      assert completed.result.tweet_id == "reply-tweet"
    end

    test "rejects unsupported states" do
      assert Automation.transition(%{}, :paused) == {:error, "Unsupported Twitter automation state: paused"}
    end
  end

  describe "evaluate_rules/2" do
    test "returns matching engagement actions" do
      event = %{
        text: "please help with billing",
        author_id: "user-1",
        like_count: 12,
        tweet_id: "tweet-1"
      }

      actions =
        Automation.evaluate_rules(event, [
          %{
            id: "support-reply",
            conditions: %{
              text: %{operator: :contains, value: "billing"},
              like_count: %{operator: :>=, value: 10}
            },
            action: :reply,
            payload: %{reply_to_tweet_id: {:event, :tweet_id}, text: "We can help."},
            priority: :high
          },
          %{
            id: "ignore-small",
            conditions: %{like_count: %{operator: :>, value: 100}},
            action: :repost
          }
        ])

      assert [
               %{
                 rule_id: "support-reply",
                 action: :reply,
                 priority: :high,
                 payload: %{reply_to_tweet_id: "tweet-1", text: "We can help."}
               }
             ] = actions
    end
  end

  describe "action_plan/2" do
    test "builds tweet, repost, follow, and DM action plans" do
      assert {:ok, tweet} =
               Automation.action_plan(:create_tweet, %{
                 text: "Thanks!",
                 reply_to_tweet_id: "tweet-1",
                 idempotency_key: "reply:tweet-1"
               })

      assert tweet.method == :post
      assert tweet.endpoint == "/2/tweets"
      assert tweet.payload == %{text: "Thanks!", reply: %{in_reply_to_tweet_id: "tweet-1"}}
      assert tweet.idempotency_key == "reply:tweet-1"

      assert {:ok, repost} = Automation.action_plan(:repost, %{user_id: "user-1", tweet_id: "tweet-1"})
      assert repost.endpoint == "/2/users/user-1/retweets"
      assert repost.payload == %{tweet_id: "tweet-1"}

      assert {:ok, follow} = Automation.action_plan(:follow, %{user_id: "user-1", target_user_id: "user-2"})
      assert follow.endpoint == "/2/users/user-1/following"
      assert follow.payload == %{target_user_id: "user-2"}

      assert {:ok, dm} = Automation.action_plan(:direct_message, %{participant_id: "user-2", text: "hello"})
      assert dm.endpoint == "/2/dm_conversations/with/user-2/messages"
      assert dm.payload == %{text: "hello"}
    end
  end

  describe "calendar_summary/1" do
    test "groups scheduled content by day and status" do
      items = [
        %{scheduled_at: "2026-05-14T12:00:00Z", state: :pending, tags: ["launch"]},
        %{scheduled_at: "2026-05-14T13:00:00Z", state: :completed, tags: ["launch", "docs"]},
        %{scheduled_at: "2026-05-15T12:00:00Z", state: :failed, tags: ["support"]}
      ]

      assert [
               %{day: "2026-05-14", total: 2, pending: 1, completed: 1, failed: 0, tags: ["docs", "launch"]},
               %{day: "2026-05-15", total: 1, pending: 0, completed: 0, failed: 1, tags: ["support"]}
             ] = Automation.calendar_summary(items)
    end
  end
end
