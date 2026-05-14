defmodule Lux.Integrations.Twitter.AutomationTest do
  use UnitCase, async: true

  alias Lux.Integrations.Twitter.Automation

  describe "schedule_content/2" do
    test "prioritizes drafts and builds calendar summaries" do
      result =
        Automation.schedule_content(
          [
            %{id: "low", text: "later", priority: 1, campaign: "launch"},
            %{id: "high", text: "first", priority: 10, campaign: "launch"},
            %{id: "long", text: String.duplicate("x", 281), priority: 2, campaign: "ops"}
          ],
          start_at: "2026-05-14T09:00:00Z",
          interval_minutes: 30,
          per_day_limit: 2
        )

      assert Enum.map(result.scheduled, & &1.id) == ["high", "long", "low"]

      assert Enum.map(result.scheduled, & &1.scheduled_at) == [
               "2026-05-14T09:00:00Z",
               "2026-05-14T09:30:00Z",
               "2026-05-15T09:00:00Z"
             ]

      assert :over_character_limit in Enum.at(result.scheduled, 1).warnings
      assert result.calendar.total_days == 2
      assert result.summary.scheduled_items == 3
    end
  end

  describe "evaluate_rules/3" do
    test "matches rules into deduplicated safe action plans" do
      result =
        Automation.evaluate_rules(
          [
            %{
              id: "m1",
              type: :mention,
              text: "Lux is great",
              author_id: "u1",
              author_handle: "alice",
              author_followers: 500
            },
            %{
              id: "m2",
              type: :mention,
              text: "ignore self",
              author_id: "bot",
              author_followers: 1_000
            }
          ],
          [
            %{
              name: "reply to praise",
              action: :reply,
              response_template: "Thanks @{{author_handle}}",
              conditions: %{
                event_type: :mention,
                text_contains: ["great"],
                min_followers: 100,
                not_from_self: true
              }
            }
          ],
          self_author_ids: ["bot"]
        )

      assert [%{action: :reply, target_id: "m1", text: "Thanks @alice", requires_review: false}] =
               result.actions

      assert result.summary.matched_actions == 1
      assert result.summary.by_action == [%{value: :reply, count: 1}]
    end
  end

  describe "queue_actions/2" do
    test "deduplicates actions and gates sensitive actions for review" do
      result =
        Automation.queue_actions(
          [
            %{action: :reply, target_id: "1", text: "hi", priority: 5},
            %{action: :reply, target_id: "1", text: "hi", priority: 5},
            %{action: :direct_message, target_id: "2", text: "dm", priority: 9}
          ],
          now: "2026-05-14T10:00:00Z",
          per_window_limit: 1,
          window_minutes: 15
        )

      assert Enum.map(result.queued, & &1.target_id) == ["2", "1"]

      assert Enum.map(result.queued, & &1.run_at) == [
               "2026-05-14T10:00:00Z",
               "2026-05-14T10:15:00Z"
             ]

      assert hd(result.queued).queue_status == :needs_review
      assert result.summary.input_actions == 3
      assert result.summary.queue_depth == 2
      assert result.summary.needs_review == 1
    end
  end
end
