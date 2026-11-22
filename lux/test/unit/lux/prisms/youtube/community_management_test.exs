defmodule Lux.Prisms.YouTube.CommentModerationTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.CommentModeration

  defp comment(text) do
    %{id: "t1", snippet: %{topLevelComment: %{snippet: %{textDisplay: text}}}}
  end

  test "positive comment is kept" do
    assert {:ok, r} = CommentModeration.handler(comment("Love this, so helpful and great!"), %{})
    assert r.sentiment == :positive
    assert r.action == :keep
    assert r.spam_score == 0.0
  end

  test "spammy comment with link is removed" do
    text = "BUY NOW!!! click here http://bit.ly/scam free money"
    assert {:ok, r} = CommentModeration.handler(comment(text), %{})
    assert r.action == :remove
    assert r.spam_score >= 0.75
    assert "contains a link" in r.reasons
  end

  test "all-caps shouting raises spam score" do
    text = "THIS IS SO AMAZING WOW GREAT VIDEO"
    assert {:ok, r} = CommentModeration.handler(comment(text), %{})
    assert r.spam_score > 0.0
  end

  test "negative comment is held for review" do
    assert {:ok, r} = CommentModeration.handler(comment("this is terrible and useless"), %{})
    assert r.sentiment == :negative
    assert r.action == :hold
  end

  test "handles missing snippet gracefully" do
    assert {:ok, r} = CommentModeration.handler(%{id: "x"}, %{})
    assert r.text == ""
    assert r.sentiment == :neutral
    assert r.action == :keep
  end
end

defmodule Lux.Prisms.YouTube.SentimentAnalysisTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.SentimentAnalysis

  test "aggregates sentiment across comments" do
    comments = [
      %{id: "c1", text: "This is fantastic and so helpful"},
      %{id: "c2", text: "terrible, worst video ever"},
      %{id: "c3", text: "the video about things"}
    ]

    assert {:ok, r} = SentimentAnalysis.handler(%{comments: comments}, %{})
    assert r.total == 3
    assert r.positive >= 1
    assert r.negative >= 1
  end

  test "empty batch returns zeroed summary" do
    assert {:ok, r} = SentimentAnalysis.handler(%{comments: []}, %{})
    assert r.total == 0
    assert r.overall == :neutral
    assert r.average_sentiment == 0.0
  end

  test "all-positive batch is positive overall" do
    comments = [
      %{id: "a", text: "love it, great, awesome"},
      %{id: "b", text: "excellent and brilliant"}
    ]

    assert {:ok, r} = SentimentAnalysis.handler(%{comments: comments}, %{})
    assert r.overall == :positive
    assert r.positive == 2
  end
end

defmodule Lux.Prisms.YouTube.ResponseGeneratorTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.ResponseGenerator

  test "praise gets a thank-you reply and a like action" do
    assert {:ok, r} = ResponseGenerator.handler(%{text: "Love this, so helpful!"}, %{})
    assert r.intent == :praise
    assert r.action == :like
    assert r.escalate == false
    assert String.contains?(r.response, "Thanks")
  end

  test "question gets a reply intent" do
    assert {:ok, r} = ResponseGenerator.handler(%{text: "How do I do this?"}, %{})
    assert r.intent == :question
    assert r.action == :reply
  end

  test "complaint escalates to a human" do
    assert {:ok, r} = ResponseGenerator.handler(%{text: "This is broken and useless"}, %{})
    assert r.intent == :complaint
    assert r.escalate == true
  end

  test "personalizes with author name" do
    assert {:ok, r} = ResponseGenerator.handler(%{text: "great video", author: "Sam"}, %{})
    assert String.contains?(r.response, "Sam")
  end
end

defmodule Lux.Prisms.YouTube.CommunityPostSchedulerTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.CommunityPostScheduler

  test "schedules each post with a slot" do
    posts = [%{text: "New tutorial out now!"}, %{text: "Poll: what next?"}]

    assert {:ok, r} =
             CommunityPostScheduler.handler(%{posts: posts, start_date: "2026-11-22"}, %{})

    assert r.count == 2
    assert length(r.scheduled) == 2
    Enum.each(r.scheduled, fn p -> assert String.contains?(p.scheduled_at, "T") end)
  end

  test "classifies post types" do
    posts = [%{text: "Vote in our poll: which color?"}]
    assert {:ok, r} = CommunityPostScheduler.handler(%{posts: posts}, %{})
    assert hd(r.scheduled).type == :poll
  end

  test "promotion posts get cross-promo suggestions" do
    posts = [%{text: "New video out now"}]
    assert {:ok, r} = CommunityPostScheduler.handler(%{posts: posts}, %{})
    post = hd(r.scheduled)
    assert post.type == :promotion
    assert "Instagram" in post.cross_promo
  end

  test "empty posts returns zero count" do
    assert {:ok, r} = CommunityPostScheduler.handler(%{posts: []}, %{})
    assert r.count == 0
  end
end
