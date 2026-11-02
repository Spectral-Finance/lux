defmodule Lux.Integrations.Twitter.Analytics.SentimentAnalyzer do
  @moduledoc """
  Heuristic and lexicon-based sentiment analysis engine for Twitter mentions and replies.
  Calculates normalized compound sentiment scores (-1.0 to 1.0) and aggregates
  sentiment distribution across social conversations.
  """

  @positive_words MapSet.new([
                    "bullish", "moon", "great", "excellent", "gem", "love", "awesome",
                    "innovative", "building", "lfg", "based", "superb", "impressive",
                    "breakthrough", "fast", "clean", "best", "solid", "win", "amazing",
                    "growth", "legendary", "proud", "congrats", "good"
                  ])

  @negative_words MapSet.new([
                    "bearish", "scam", "rug", "trash", "terrible", "slow", "broken",
                    "bug", "crash", "dump", "hate", "worst", "fail", "bad", "loss",
                    "exploit", "hack", "fake", "disaster", "horrible", "avoid", "poor"
                  ])

  @positive_emojis ["🚀", "🔥", "💎", "❤️", "👏", "👍", "🎉", "📈", "✨"]
  @negative_emojis ["💩", "😡", "👎", "📉", "🤮", "💀", "⚠️", "🚨"]

  @type sentiment_score :: %{
          score: float(),
          classification: :positive | :neutral | :negative,
          positive_tokens: list(String.t()),
          negative_tokens: list(String.t())
        }

  @type batch_summary :: %{
          total: non_neg_integer(),
          positive_count: non_neg_integer(),
          neutral_count: non_neg_integer(),
          negative_count: non_neg_integer(),
          positive_percentage: float(),
          negative_percentage: float(),
          avg_compound_score: float()
        }

  @doc """
  Analyzes the sentiment of a single tweet string or map.
  """
  @spec analyze_text(String.t() | map()) :: sentiment_score()
  def analyze_text(%{text: text}), do: analyze_text(text)
  def analyze_text(%{"text" => text}), do: analyze_text(text)

  def analyze_text(text) when is_binary(text) do
    tokens =
      text
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9_\s]/, " ")
      |> String.split()

    pos_tokens = Enum.filter(tokens, &MapSet.member?(@positive_words, &1))
    neg_tokens = Enum.filter(tokens, &MapSet.member?(@negative_words, &1))

    # Emoji scoring
    pos_emoji_count = Enum.count(@positive_emojis, &String.contains?(text, &1))
    neg_emoji_count = Enum.count(@negative_emojis, &String.contains?(text, &1))

    pos_score = length(pos_tokens) + pos_emoji_count * 1.5
    neg_score = length(neg_tokens) + neg_emoji_count * 1.5
    total = pos_score + neg_score

    compound =
      if total > 0 do
        Float.round((pos_score - neg_score) / (total + 1.0), 3)
      else
        0.0
      end

    classification =
      cond do
        compound > 0.15 -> :positive
        compound < -0.15 -> :negative
        true -> :neutral
      end

    %{
      score: compound,
      classification: classification,
      positive_tokens: pos_tokens,
      negative_tokens: neg_tokens
    }
  end

  def analyze_text(_), do: %{score: 0.0, classification: :neutral, positive_tokens: [], negative_tokens: []}

  @doc """
  Analyzes a batch of tweets or mentions, returning distribution metrics.
  """
  @spec analyze_batch(list(String.t() | map())) :: batch_summary()
  def analyze_batch([]) do
    %{
      total: 0,
      positive_count: 0,
      neutral_count: 0,
      negative_count: 0,
      positive_percentage: 0.0,
      negative_percentage: 0.0,
      avg_compound_score: 0.0
    }
  end

  def analyze_batch(items) when is_list(items) do
    scores = Enum.map(items, &analyze_text/1)
    total = length(scores)

    pos_count = Enum.count(scores, &(&1.classification == :positive))
    neut_count = Enum.count(scores, &(&1.classification == :neutral))
    neg_count = Enum.count(scores, &(&1.classification == :negative))

    total_score = Enum.reduce(scores, 0.0, fn s, acc -> acc + s.score end)
    avg_score = Float.round(total_score / total, 3)

    %{
      total: total,
      positive_count: pos_count,
      neutral_count: neut_count,
      negative_count: neg_count,
      positive_percentage: Float.round((pos_count / total) * 100.0, 1),
      negative_percentage: Float.round((neg_count / total) * 100.0, 1),
      avg_compound_score: avg_score
    }
  end
end
