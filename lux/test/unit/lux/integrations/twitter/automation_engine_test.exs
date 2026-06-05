defmodule Lux.Integrations.Twitter.AutomationEngineTest do
  use UnitCase, async: true

  alias Lux.Integrations.Twitter.AutomationEngine

  describe "plan/1" do
    test "schedules valid content and rejects unsafe calendar items" do
      long_text = String.duplicate("a", 281)

      assert {:ok, result} =
               AutomationEngine.plan(%{
                 now: "2026-06-06T09:00:00Z",
                 content_calendar: [
                   %{id: "launch", text: "Lux agents can coordinate social workflows.", priority: 80},
                   %{id: "too-long", text: long_text},
                   %{id: "empty", text: "   "}
                 ],
                 queue_policy: %{min_spacing_seconds: 120}
               })

      assert Enum.find(result.scheduled_posts, &(&1.id == "launch")).status == "scheduled"
      assert Enum.find(result.scheduled_posts, &(&1.id == "too-long")).reason == "exceeds_280_characters"
      assert Enum.find(result.scheduled_posts, &(&1.id == "empty")).reason == "empty_content"
      assert length(result.queue) == 1
      assert result.performance.queue_depth == 1
      assert result.performance.moderation_count == 2
    end

    test "creates rule-based engagement actions and routes risky replies to review" do
      assert {:ok, result} =
               AutomationEngine.plan(%{
                 now: "2026-06-06T09:00:00Z",
                 mentions: [
                   %{
                     id: "m1",
                     author: "alice",
                     text: "Can Lux help with agent workflow scheduling?",
                     followers: 1_500,
                     received_at: "2026-06-06T09:01:00Z"
                   },
                   %{
                     id: "m2",
                     author: "promo",
                     text: "Lux giveaway free money click here",
                     followers: 50,
                     received_at: "2026-06-06T09:02:00Z"
                   }
                 ],
                 rules: [
                   %{
                     id: "reply-workflow",
                     type: "auto_reply",
                     keywords: ["agent workflow", "lux"],
                     reply_template: "Thanks {{author}}, here is a Lux starter plan.",
                     priority: 70
                   },
                   %{
                     id: "follow-builders",
                     type: "follow_candidate",
                     keywords: ["lux"],
                     min_followers: 1000,
                     priority: 60
                   }
                 ],
                 queue_policy: %{min_spacing_seconds: 300}
               })

      reply = Enum.find(result.engagement_actions, &(&1.id == "engagement-m1-reply-workflow"))
      follow = Enum.find(result.engagement_actions, &(&1.id == "engagement-m1-follow-builders"))
      risky = Enum.find(result.engagement_actions, &(&1.id == "engagement-m2-reply-workflow"))

      assert reply.type == "reply"
      assert reply.text == "Thanks alice, here is a Lux starter plan."
      assert reply.status == "queued"
      assert follow.type == "follow"
      assert follow.status == "queued"
      assert risky.status == "needs_review"
      assert length(result.queue) == 2
      assert result.performance.moderation_count == 1

      follow_queue_item = Enum.find(result.queue, &(&1.action == "follow"))
      assert follow_queue_item.surface == "relationship_write"
      assert follow_queue_item.requires_review == true
      assert follow_queue_item.backoff_seconds == 1800
    end

    test "enforces quiet hours and per-surface hourly rate limits in the queue" do
      assert {:ok, result} =
               AutomationEngine.plan(%{
                 now: "2026-06-06T21:55:00Z",
                 content_calendar: [
                   %{id: "post-1", text: "First planned post.", scheduled_for: "2026-06-06T22:00:00Z"},
                   %{id: "post-2", text: "Second planned post.", scheduled_for: "2026-06-06T22:05:00Z"},
                   %{id: "post-3", text: "Third planned post.", scheduled_for: "2026-06-06T22:10:00Z"}
                 ],
                 queue_policy: %{
                   min_spacing_seconds: 60,
                   max_actions_per_hour: 2,
                   quiet_hours: %{start_hour: 22, end_hour: 7},
                   surface_limits: %{
                     "tweet_write" => %{max_actions_per_hour: 2, backoff_seconds: 1200}
                   }
                 }
               })

      assert Enum.map(result.queue, & &1.rate_limit_bucket) == [
               "2026-06-07T07",
               "2026-06-07T07",
               "2026-06-07T08"
             ]

      assert Enum.all?(result.queue, fn item ->
               {:ok, run_at, _offset} = DateTime.from_iso8601(item.run_at)
               run_at.hour in 7..21
             end)

      assert result.performance.surface_buckets == %{
               "tweet_write:2026-06-07T07" => 2,
               "tweet_write:2026-06-07T08" => 1
             }

      assert Enum.all?(result.queue, &(&1.backoff_seconds == 1200))
    end

    test "returns a helpful error for invalid datetime input" do
      assert {:error, "Invalid ISO8601 datetime: not-a-date"} =
               AutomationEngine.plan(%{now: "not-a-date"})
    end
  end
end
