defmodule Lux.Twitter.Analytics.Sentiment do
  @moduledoc """
  Sentiment analysis engine for Twitter mentions, replies, and community discourse.
  """

  @positive_words ~w(great amazing awesome excellent love bullish profit moon good win congrats innovative breakthrough superior)
  @negative_words ~w(bad poor terrible awful hate bearish loss dump rug scam crash error fail drop exploit scammer)

  @type sentiment_result :: %{
          text: String.t(),
          polarity: float(),
          classification: :positive | :neutral | :negative,
          confidence: float(),
          matched_words: list(String.t())
        }

  @doc """
  Analyzes the sentiment of a single mention or tweet text.
  """
  @spec analyze_text(String.t()) :: sentiment_result()
  def analyze_text(text) do
    tokens =
      text
      |> String.downcase()
      |> String.replace(~r/[^\w\s]/u, "")
      |> String.split(~r/\s+/, trim: true)

    pos_matches = Enum.filter(tokens, &(&1 in @positive_words))
    neg_matches = Enum.filter(tokens, &(&1 in @negative_words))

    pos_score = length(pos_matches)
    neg_score = length(neg_matches)
    total_matches = pos_score + neg_score

    {polarity, classification, confidence} =
      cond do
        total_matches == 0 ->
          {0.0, :neutral, 0.6}

        pos_score > neg_score ->
          p = Float.round((pos_score - neg_score) / (pos_score + neg_score), 2)
          {p, :positive, Float.round(pos_score / (length(tokens) + 1) * 3, 2) |> min(0.99)}

        neg_score > pos_score ->
          p = Float.round((pos_score - neg_score) / (pos_score + neg_score), 2)
          {p, :negative, Float.round(neg_score / (length(tokens) + 1) * 3, 2) |> min(0.99)}

        true ->
          {0.0, :neutral, 0.75}
      end

    %{
      text: text,
      polarity: polarity,
      classification: classification,
      confidence: confidence,
      matched_words: pos_matches ++ neg_matches
    }
  end

  @doc """
  Analyzes a batch of mentions and aggregates sentiment distribution.
  """
  @spec aggregate_sentiment(list(String.t())) :: map()
  def aggregate_sentiment(texts) when is_list(texts) do
    results = Enum.map(texts, &analyze_text/1)
    total = length(results)

    pos_count = Enum.count(results, &(&1.classification == :positive))
    neg_count = Enum.count(results, &(&1.classification == :negative))
    neu_count = Enum.count(results, &(&1.classification == :neutral))

    avg_polarity =
      if total > 0 do
        Float.round(Enum.sum(Enum.map(results, & &1.polarity)) / total, 2)
      else
        0.0
      end

    %{
      total_analyzed: total,
      positive_count: pos_count,
      negative_count: neg_count,
      neutral_count: neu_count,
      positive_ratio: if(total > 0, do: Float.round(pos_count / total, 2), else: 0.0),
      negative_ratio: if(total > 0, do: Float.round(neg_count / total, 2), else: 0.0),
      average_polarity: avg_polarity
    }
  end
end
