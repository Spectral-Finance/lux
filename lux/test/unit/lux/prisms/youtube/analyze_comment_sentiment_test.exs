defmodule Lux.Prisms.YouTube.AnalyzeCommentSentimentTest do
  @moduledoc """
  Test suite for the AnalyzeCommentSentiment prism.
  These tests verify the prism's ability to:
  - Classify comments as positive, negative, or neutral
  - Compute aggregate sentiment scores
  - Detect spam when requested
  - Handle edge cases like empty lists
  """

  use UnitCase, async: true
  alias Lux.Prisms.YouTube.AnalyzeCommentSentiment

  describe "handler/2" do
    test "analyzes positive comments" do
      assert {:ok, result} =
               AnalyzeCommentSentiment.handler(
                 %{"comments" => ["Great video! Love it!", "Amazing content, thank you!"]},
                 %{}
               )

      assert result.overall_sentiment == "positive"
      assert result.positive_count == 2
      assert result.negative_count == 0
      assert result.sentiment_score > 0.1
    end

    test "analyzes negative comments" do
      assert {:ok, result} =
               AnalyzeCommentSentiment.handler(
                 %{"comments" => ["Terrible video, waste of time.", "Awful and boring content."]},
                 %{}
               )

      assert result.overall_sentiment == "negative"
      assert result.negative_count == 2
      assert result.positive_count == 0
      assert result.sentiment_score < -0.1
    end

    test "analyzes neutral comments" do
      assert {:ok, result} =
               AnalyzeCommentSentiment.handler(
                 %{"comments" => ["I watched the video.", "This is a comment."]},
                 %{}
               )

      assert result.overall_sentiment == "neutral"
      assert result.neutral_count == 2
    end

    test "detects spam when include_spam_detection is true" do
      assert {:ok, result} =
               AnalyzeCommentSentiment.handler(
                 %{
                   "comments" => [
                     "Great content!",
                     "Subscribe to me for free money now!"
                   ],
                   "include_spam_detection" => true
                 },
                 %{}
               )

      assert length(result.spam_detected) == 1
      assert "Subscribe to me for free money now!" in result.spam_detected
    end

    test "does not detect spam when include_spam_detection is false" do
      assert {:ok, result} =
               AnalyzeCommentSentiment.handler(
                 %{
                   "comments" => ["Subscribe to me for free money!"],
                   "include_spam_detection" => false
                 },
                 %{}
               )

      assert result.spam_detected == []
    end

    test "handles empty comment list" do
      assert {:ok, result} =
               AnalyzeCommentSentiment.handler(
                 %{"comments" => []},
                 %{}
               )

      assert result.overall_sentiment == "neutral"
      assert result.sentiment_score == 0.0
      assert result.positive_count == 0
      assert result.negative_count == 0
      assert result.neutral_count == 0
    end

    test "returns per-comment analysis" do
      assert {:ok, result} =
               AnalyzeCommentSentiment.handler(
                 %{"comments" => ["Great!", "Terrible!"]},
                 %{}
               )

      assert length(result.comment_analysis) == 2
      [first, second] = result.comment_analysis
      assert first.sentiment == "positive"
      assert second.sentiment == "negative"
      assert is_float(first.score)
      assert is_float(second.score)
    end

    test "sentiment_score is within -1.0 to 1.0 range" do
      assert {:ok, result} =
               AnalyzeCommentSentiment.handler(
                 %{
                   "comments" => [
                     "Great amazing wonderful excellent awesome video!",
                     "Terrible awful horrible garbage trash waste!"
                   ]
                 },
                 %{}
               )

      assert result.sentiment_score >= -1.0
      assert result.sentiment_score <= 1.0
    end
  end

  describe "schema validation" do
    test "validates required input fields" do
      prism = AnalyzeCommentSentiment.view()
      assert "comments" in prism.input_schema.required
    end

    test "validates output schema required fields" do
      prism = AnalyzeCommentSentiment.view()

      required = prism.output_schema.required
      assert "overall_sentiment" in required
      assert "sentiment_score" in required
      assert "positive_count" in required
      assert "negative_count" in required
      assert "neutral_count" in required
    end
  end
end
