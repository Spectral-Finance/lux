defmodule Lux.Prisms.Twitter.Automation.PlanEngagementTest do
  use UnitCase, async: true

  alias Lux.Prisms.Twitter.Automation.PlanEngagement

  describe "handler/2" do
    test "returns a complete automation plan" do
      assert {:ok, result} =
               PlanEngagement.handler(
                 %{
                   now: "2026-06-06T09:00:00Z",
                   content_calendar: [
                     %{id: "launch", text: "Lux can plan social engagement safely."}
                   ],
                   mentions: [
                     %{
                       id: "m1",
                       author: "builder",
                       text: "I am testing Lux automation",
                       followers: 2_000
                     }
                   ],
                   rules: [
                     %{
                       id: "reply-lux",
                       type: "auto_reply",
                       keywords: ["lux automation"],
                       reply_template: "Thanks {{author}}, the plan is ready."
                     }
                   ],
                   queue_policy: %{min_spacing_seconds: 600}
                 },
                 %{name: "AutomationAgent"}
               )

      assert [%{id: "launch", status: "scheduled"}] = result.scheduled_posts
      assert [%{type: "reply", status: "queued"}] = result.engagement_actions
      assert length(result.queue) == 2
      assert result.performance.queue_depth == 2
    end

    test "surfaces validation errors from the automation engine" do
      assert {:error, "Expected a map of automation inputs"} =
               PlanEngagement.handler([], %{name: "AutomationAgent"})
    end
  end

  describe "schema validation" do
    test "declares the expected input schema" do
      prism = PlanEngagement.view()

      assert Map.has_key?(prism.input_schema.properties, :content_calendar)
      assert Map.has_key?(prism.input_schema.properties, :mentions)
      assert Map.has_key?(prism.input_schema.properties, :rules)
      assert Map.has_key?(prism.input_schema.properties, :queue_policy)
      assert Map.has_key?(prism.input_schema.properties, :now)
    end

    test "declares the expected output schema" do
      prism = PlanEngagement.view()

      assert prism.output_schema.required == [
               "scheduled_posts",
               "engagement_actions",
               "queue",
               "content_calendar",
               "moderation",
               "performance"
             ]

      assert Map.has_key?(prism.output_schema.properties, :scheduled_posts)
      assert Map.has_key?(prism.output_schema.properties, :engagement_actions)
      assert Map.has_key?(prism.output_schema.properties, :queue)
      assert Map.has_key?(prism.output_schema.properties, :content_calendar)
      assert Map.has_key?(prism.output_schema.properties, :moderation)
      assert Map.has_key?(prism.output_schema.properties, :performance)
    end
  end
end
