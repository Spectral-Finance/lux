defmodule Lux.Integrations.YouTube.CommunityManagerTest do
  use UnitCase, async: true

  alias Lux.Integrations.YouTube.CommunityManager

  @input %{
    channel: "DeFi Operators",
    goals: ["increase qualified comments", "reduce spam"],
    content_topics: ["wallet safety", "risk checklist"],
    platforms: ["x", "telegram"],
    comments: [
      %{
        id: "c1",
        author: "Mira",
        text: "Great breakdown, thanks. Can you cover wallet safety next?",
        likes: 18,
        replies: 3,
        author_subscribers: 12_000
      },
      %{
        id: "c2",
        author: "Fake Promo",
        text: "FREE airdrop giveaway click https://example.test telegram now!!!!",
        likes: 0,
        replies: 0
      },
      %{
        id: "c3",
        author: "Risk Lead",
        text: "This is wrong and broken. The gas example is terrible.",
        likes: 30,
        replies: 5,
        author_subscribers: 75_000
      }
    ],
    subscriber_events: [
      %{source: "community_post", segment: "returning viewer", hour: 14},
      %{source: "shorts", segment: "new subscriber", hour: 14},
      %{source: "external", segment: "founder", hour: 18}
    ],
    campaigns: [
      %{name: "wallet week", goal: "comments", baseline: 20, current: 48, target: 80}
    ]
  }

  test "builds a complete community report" do
    assert {:ok, report} = CommunityManager.run(@input)

    assert report.channel == "DeFi Operators"
    assert report.comment_management.summary.total_comments == 3
    assert report.comment_management.summary.spam == 1
    assert report.comment_management.summary.needs_reply >= 1
    assert length(report.comment_management.response_queue) >= 2
    assert length(report.cross_platform_promotion) == 2
    assert length(report.community_post_schedule.posts) == 2
    assert [%{status: :needs_attention}] = report.engagement_campaign_management
  end

  test "detects spam and queues moderation" do
    assert {:ok, report} = CommunityManager.run(@input)

    spam = Enum.find(report.moderation_system.queue, &(&1.id == "c2"))
    assert spam.recommended_action == :hide
    assert spam.spam_score >= 85
    assert spam.moderation_reason =~ "spam"
  end

  test "escalates high influence negative comments" do
    assert {:ok, report} = CommunityManager.run(@input)

    negative = Enum.find(report.moderation_system.queue, &(&1.id == "c3"))
    assert negative.sentiment == :negative
    assert negative.priority == :urgent
    assert negative.recommended_action == :escalate

    assert report.sentiment_analysis.alerts == [
             %{comment_id: "c3", author: "Risk Lead", reason: "negative high-influence comment"}
           ]
  end

  test "supports string keyed input" do
    input = %{
      "comments" => [
        %{"id" => "q1", "author" => "Ari", "text" => "Can you explain this?", "likes" => "3"}
      ],
      "goals" => ["answer questions"]
    }

    assert {:ok, report} = CommunityManager.run(input)
    assert report.comment_management.summary.needs_reply == 1
    assert [%{intent: :question}] = report.comment_management.response_queue
  end

  test "rejects non-map input" do
    assert {:error, "Expected a map with YouTube community data"} = CommunityManager.run([])
  end
end
