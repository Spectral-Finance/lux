defmodule Lux.Prisms.Twitter.Analytics.SentimentAnalyzerTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Twitter.Analytics.SentimentAnalyzer

  test "positive sentiment" do
    result = SentimentAnalyzer.analyze("This is amazing and wonderful!")
    assert result.sentiment == :positive
    assert result.score > 0
    assert result.positive_count >= 2
  end

  test "negative sentiment" do
    result = SentimentAnalyzer.analyze("This is terrible and horrible")
    assert result.sentiment == :negative
    assert result.score < 0
  end

  test "neutral sentiment" do
    result = SentimentAnalyzer.analyze("The weather is normal today")
    assert result.sentiment == :neutral
  end

  test "empty text" do
    result = SentimentAnalyzer.analyze("")
    assert result.sentiment == :neutral
    assert result.score == 0.0
  end

  test "batch analysis" do
    texts = [
      "This is amazing!",
      "Terrible experience",
      "Just a regular day",
      "Love this product, it's great!"
    ]
    result = SentimentAnalyzer.analyze_batch(texts)
    assert result.total == 4
    assert result.positive >= 1
    assert result.negative >= 1
    assert result.distribution.positive + result.distribution.negative + result.distribution.neutral == 100.0
  end

  test "batch empty list" do
    result = SentimentAnalyzer.analyze_batch([])
    assert result.total == 0
  end

  test "mixed sentiment text" do
    result = SentimentAnalyzer.analyze("I love the design but hate the price, terrible value")
    assert result.positive_count >= 1
    assert result.negative_count >= 1
  end

  test "all positive words" do
    result = SentimentAnalyzer.analyze("great awesome amazing excellent wonderful")
    assert result.sentiment == :positive
    assert result.positive_count == 5
    assert result.negative_count == 0
  end

  test "all negative words" do
    result = SentimentAnalyzer.analyze("bad terrible awful horrible poor")
    assert result.sentiment == :negative
    assert result.negative_count == 5
  end

  test "word count accuracy" do
    result = SentimentAnalyzer.analyze("one two three four five")
    assert result.word_count == 5
  end

  test "case insensitive" do
    result = SentimentAnalyzer.analyze("AMAZING GREAT LOVE")
    assert result.sentiment == :positive
  end

  test "batch distribution sums to 100" do
    texts = ["great", "bad", "ok", "amazing", "terrible", "fine"]
    result = SentimentAnalyzer.analyze_batch(texts)
    sum = result.distribution.positive + result.distribution.negative + result.distribution.neutral
    assert_in_delta sum, 100.0, 0.2
  end

  test "batch all same sentiment" do
    texts = ["great", "amazing", "wonderful", "excellent"]
    result = SentimentAnalyzer.analyze_batch(texts)
    assert result.positive == 4
    assert result.negative == 0
    assert result.distribution.positive == 100.0
  end
end
