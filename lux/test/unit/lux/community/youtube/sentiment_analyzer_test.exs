defmodule Lux.Community.YouTube.SentimentAnalyzerTest do
  use ExUnit.Case, async: true

  alias Lux.Community.YouTube.SentimentAnalyzer

  describe "analyze_comment/1" do
    test "classifies positive praise correctly" do
      result = SentimentAnalyzer.analyze_comment("This is the best and most incredible tutorial! Loved it.")
      assert result.classification == :positive
      assert result.score > 0.5
      assert result.intent == :praise
      assert "best" in result.keywords
    end

    test "classifies negative feedback and complaints" do
      result = SentimentAnalyzer.analyze_comment("The audio is broken and the video was confusing garbage.")
      assert result.classification == :negative
      assert result.score < -0.3
      assert result.intent in [:complaint, :neutral]
    end

    test "identifies questions / inquiries" do
      result = SentimentAnalyzer.analyze_comment("How do we deploy this to AWS ECS?")
      assert result.intent == :inquiry
    end

    test "identifies content suggestions" do
      result = SentimentAnalyzer.analyze_comment("Please make a video on Elixir Broadway next!")
      assert result.intent == :suggestion
    end
  end

  describe "analyze_batch/1" do
    test "computes consensus verdict across comments list" do
      comments = [
        "Amazing video, subscribed!",
        "Great explanation, very clear.",
        "Loved the code structure!",
        "Could you explain how to test this?"
      ]

      batch = SentimentAnalyzer.analyze_batch(comments)
      assert batch.total_analyzed == 4
      assert batch.positive_percentage >= 70.0
      assert batch.sentiment_verdict == :mostly_positive or batch.sentiment_verdict == :overwhelmingly_positive
      assert batch.inquiry_count == 1
    end
  end
end
