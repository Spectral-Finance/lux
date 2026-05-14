defmodule YouTubeCommunityManagerTest do
  use ExUnit.Case, async: true

  @moduletag :integration

  alias Lux.Integrations.YouTube.CommunityManager

  test "demonstrates comment management and moderation workflow" do
    assert {:ok, report} =
             CommunityManager.run(%{
               channel: "Protocol Brief",
               goals: ["raise qualified discussion", "protect viewers from scams"],
               content_topics: ["weekly Q&A", "wallet safety checklist", "market recap"],
               platforms: ["x", "discord", "newsletter"],
               comments: [
                 %{
                   id: "a",
                   author: "Builder",
                   text: "Awesome. Please add hardware wallet examples.",
                   likes: 9
                 },
                 %{
                   id: "b",
                   author: "Scam",
                   text: "Guaranteed free money giveaway https://bad.test"
                 },
                 %{
                   id: "c",
                   author: "Ops",
                   text: "Bad take. This example is wrong?",
                   likes: 20,
                   replies: 8
                 }
               ],
               subscriber_events: [
                 %{source: "video", segment: "operator", hour: 9},
                 %{source: "community_post", segment: "operator", hour: 9},
                 %{source: "newsletter", segment: "founder", hour: 15}
               ],
               campaigns: [
                 %{
                   name: "hardware wallet week",
                   goal: "qualified comments",
                   baseline: 10,
                   current: 44,
                   target: 40
                 }
               ]
             })

    assert report.comment_management.summary.total_comments == 3
    assert Enum.any?(report.moderation_system.queue, &(&1.recommended_action == :hide))
    assert Enum.any?(report.moderation_system.queue, &(&1.recommended_action == :escalate))
    assert length(report.community_post_schedule.posts) == 3
    assert length(report.cross_platform_promotion) == 3
    assert [%{status: :complete}] = report.engagement_campaign_management
  end
end
