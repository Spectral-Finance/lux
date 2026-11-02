defmodule Lux.Integrations.Twitter.Analytics.SentimentAnalyzerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Analytics.SentimentAnalyzer

  describe "analyze_text/1" do
    test "classifies positive message with bullish tokens and emojis" do
      text = "Lux is an awesome breakthrough in AI! Super bullish and loving it 🚀🔥"
      result = SentimentAnalyzer.analyze_text(text)

      assert result.classification == :positive
      assert result.score > 0.3
      assert "awesome" in result.positive_tokens
      assert "bullish" in result.positive_tokens
    end

    test "classifies negative message with critical tokens" do
      text = "This project is a complete scam and total disaster. Worst bug ever 😡"
      result = SentimentAnalyzer.analyze_text(text)

      assert result.classification == :negative
      assert result.score < -0.3
      assert "scam" in result.negative_tokens
      assert "disaster" in result.negative_tokens
    end

    test "classifies neutral statement" do
      text = "The repository was updated today at 12:00 UTC."
      result = SentimentAnalyzer.analyze_text(text)

      assert result.classification == :neutral
      assert result.score == 0.0
    end
  end

  describe "analyze_batch/1" do
    test "summarizes batch sentiment distribution" do
      mentions = [
        "Lux is awesome and bullish! 🚀",
        "Just a regular update post.",
        "Terrible bug, broken implementation 😡"
      ]

      summary = SentimentAnalyzer.analyze_batch(mentions)

      assert summary.total == 3
      assert summary.positive_count == 1
      assert summary.neutral_count == 1
      assert summary.negative_count == 1
      assert summary.positive_percentage == 33.3
      assert summary.negative_percentage == 33.3
    end
  end
end
