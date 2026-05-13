defmodule Lux.Integrations.YouTube.CommunityManagerTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.YouTube.CommunityManager

  describe "analyze_comment/1" do
    test "classifies sentiment, intent, spam, and moderation decisions" do
      praise =
        CommunityManager.analyze_comment(%{
          id: "comment-1",
          author_channel_id: "author-1",
          text: "Great and helpful video!"
        })

      assert praise.sentiment == :positive
      assert praise.intent == :praise
      assert praise.moderation.action == :allow

      spam =
        CommunityManager.analyze_comment(%{
          id: "comment-2",
          text: "free crypto investment guaranteed whatsapp"
        })

      assert spam.intent == :spam
      assert spam.spam_score == 1.0
      assert spam.moderation.action == :hide
    end
  end

  describe "response_suggestion/2" do
    test "suggests replies for questions and avoids hidden comments" do
      question =
        CommunityManager.response_suggestion(
          %{id: "comment-1", text: "How do I deploy this?"},
          %{answer: "start with the release checklist"}
        )

      assert question.should_reply? == true
      assert question.response =~ "release checklist"

      spam = CommunityManager.response_suggestion(%{id: "comment-2", text: "free crypto whatsapp"})
      assert spam.should_reply? == false
      assert spam.moderation_action == :hide
    end
  end

  describe "moderation_queue/1" do
    test "builds moderation actions for comment batches" do
      queue =
        CommunityManager.moderation_queue([
          %{id: "clean", text: "Thanks"},
          %{id: "bad", text: "This is useless"}
        ])

      assert [%{action: :allow}, %{action: :review, reason: :negative_sentiment}] = queue
    end
  end

  describe "schedule_post/1" do
    test "builds community post schedule records" do
      post =
        CommunityManager.schedule_post(%{
          id: "post-1",
          text: "Vote on the next tutorial",
          scheduled_at: "2026-05-14T12:00:00Z",
          poll_options: ["OAuth", "Analytics"],
          campaign_id: "campaign-1"
        })

      assert post.id == "post-1"
      assert post.state == :scheduled
      assert post.poll_options == ["OAuth", "Analytics"]
      assert post.campaign_id == "campaign-1"
    end
  end

  describe "interaction_patterns/1" do
    test "summarizes repeat authors and event mix" do
      patterns =
        CommunityManager.interaction_patterns([
          %{author_channel_id: "a", type: :comment},
          %{author_channel_id: "a", type: :reply},
          %{author_channel_id: "b", type: :comment}
        ])

      assert patterns.unique_authors == 2
      assert patterns.repeat_authors == 1
      assert [%{author_channel_id: "a", interaction_count: 2} | _] = patterns.top_authors
      assert patterns.event_mix.comment == 2
      assert patterns.event_mix.reply == 1
    end
  end

  describe "promotion_plan/1 and campaign/1" do
    test "builds promotion tasks and full campaigns" do
      plan = CommunityManager.promotion_plan(%{title: "New video", url: "https://youtu.be/1"})
      assert Enum.any?(plan, &(&1.platform == :x and &1.timing == :launch))
      assert Enum.any?(plan, &(&1.platform == :newsletter))

      campaign =
        CommunityManager.campaign(%{
          campaign_id: "campaign-1",
          title: "New video",
          url: "https://youtu.be/1",
          comments: [%{id: "comment-1", author_channel_id: "a", text: "Great video!"}],
          community_posts: [%{text: "What next?", scheduled_at: "2026-05-14T12:00:00Z"}]
        })

      assert campaign.campaign_id == "campaign-1"
      assert [%{action: :allow}] = campaign.moderation_queue
      assert [%{should_reply?: true}] = campaign.responses
      assert [%{state: :scheduled}] = campaign.community_posts
      assert campaign.interactions.unique_authors == 1
      assert length(campaign.promotion) == 3
    end
  end
end
