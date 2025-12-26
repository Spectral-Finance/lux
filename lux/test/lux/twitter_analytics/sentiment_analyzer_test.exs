defmodule Lux.TwitterAnalytics.SentimentAnalyzerTest do
  use ExUnit.Case, async: true

  alias Lux.TwitterAnalytics.SentimentAnalyzer

  describe "analyze/1" do
    test "returns :positive for positive text" do
      assert :positive = SentimentAnalyzer.analyze("I love this amazing product!")
      assert :positive = SentimentAnalyzer.analyze("This is awesome and great")
      assert :positive = SentimentAnalyzer.analyze("Happy excited wonderful day")
    end

    test "returns :negative for negative text" do
      assert :negative = SentimentAnalyzer.analyze("I hate this terrible product")
      assert :negative = SentimentAnalyzer.analyze("This is awful and horrible")
      assert :negative = SentimentAnalyzer.analyze("Sad disappointed frustrated")
    end

    test "returns :neutral for neutral text" do
      assert :neutral = SentimentAnalyzer.analyze("The weather today")
      assert :neutral = SentimentAnalyzer.analyze("It happened yesterday")
      assert :neutral = SentimentAnalyzer.analyze("Meeting at 3pm")
    end

    test "handles negation correctly" do
      assert :negative = SentimentAnalyzer.analyze("not good at all")
      assert :positive = SentimentAnalyzer.analyze("not bad actually")
      assert :positive = SentimentAnalyzer.analyze("never terrible always great")
    end

    test "returns :neutral for nil" do
      assert :neutral = SentimentAnalyzer.analyze(nil)
    end

    test "returns :neutral for empty string" do
      assert :neutral = SentimentAnalyzer.analyze("")
    end

    test "handles mixed sentiment" do
      # More positive words
      assert :positive = SentimentAnalyzer.analyze("I love this but it has some bad parts")

      # More negative words
      assert :negative = SentimentAnalyzer.analyze("terrible awful with one good thing")
    end

    test "handles punctuation and capitalization" do
      assert :positive = SentimentAnalyzer.analyze("LOVE THIS!!! AMAZING!!!")
      assert :negative = SentimentAnalyzer.analyze("hate, terrible, awful.")
    end
  end

  describe "analyze_detailed/1" do
    test "returns detailed sentiment scores for positive text" do
      result = SentimentAnalyzer.analyze_detailed("I love this amazing product")

      assert result.sentiment == :positive
      assert result.positive_score > 0
      assert result.negative_score == 0
      assert result.total_words > 0
    end

    test "returns detailed sentiment scores for negative text" do
      result = SentimentAnalyzer.analyze_detailed("I hate this terrible product")

      assert result.sentiment == :negative
      assert result.positive_score == 0
      assert result.negative_score > 0
      assert result.total_words > 0
    end

    test "returns detailed sentiment scores for neutral text" do
      result = SentimentAnalyzer.analyze_detailed("The weather today")

      assert result.sentiment == :neutral
      assert result.positive_score == 0
      assert result.negative_score == 0
      assert result.total_words > 0
    end

    test "handles negation in detailed analysis" do
      result = SentimentAnalyzer.analyze_detailed("not good at all")

      assert result.sentiment == :negative
      # "not good" should count as negative due to negation
      assert result.negative_score > 0
    end
  end
end
