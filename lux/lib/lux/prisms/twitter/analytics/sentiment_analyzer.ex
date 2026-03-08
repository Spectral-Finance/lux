defmodule Lux.Prisms.Twitter.Analytics.SentimentAnalyzer do
  @moduledoc """
  Basic sentiment analysis for Twitter mentions and tweets.

  Uses keyword-based scoring with configurable word lists.
  """

  @positive_words ~w(love great awesome amazing good excellent best happy wonderful fantastic brilliant beautiful perfect cool nice)
  @negative_words ~w(hate bad terrible awful worst horrible poor ugly stupid broken fail sucks disappointing)

  @doc "Analyze sentiment of a text. Returns :positive, :negative, or :neutral with score."
  def analyze(text) when is_binary(text) do
    words = text |> String.downcase() |> String.split(~r/\W+/, trim: true)

    pos = Enum.count(words, &(&1 in @positive_words))
    neg = Enum.count(words, &(&1 in @negative_words))
    total = length(words)

    score = if total > 0, do: (pos - neg) / total, else: 0.0

    sentiment = cond do
      score > 0.05 -> :positive
      score < -0.05 -> :negative
      true -> :neutral
    end

    %{
      sentiment: sentiment,
      score: Float.round(score, 4),
      positive_count: pos,
      negative_count: neg,
      word_count: total
    }
  end

  @doc "Analyze sentiment of multiple texts and aggregate."
  def analyze_batch(texts) when is_list(texts) do
    results = Enum.map(texts, &analyze/1)

    total = length(results)
    positive = Enum.count(results, &(&1.sentiment == :positive))
    negative = Enum.count(results, &(&1.sentiment == :negative))
    neutral = Enum.count(results, &(&1.sentiment == :neutral))
    avg_score = if total > 0, do: Enum.sum(Enum.map(results, & &1.score)) / total, else: 0.0

    %{
      total: total,
      positive: positive,
      negative: negative,
      neutral: neutral,
      avg_score: Float.round(avg_score, 4),
      distribution: %{
        positive: if(total > 0, do: Float.round(positive / total * 100, 1), else: 0.0),
        negative: if(total > 0, do: Float.round(negative / total * 100, 1), else: 0.0),
        neutral: if(total > 0, do: Float.round(neutral / total * 100, 1), else: 0.0)
      }
    }
  end
end
