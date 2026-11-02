defmodule Lux.Community.YouTube.SentimentAnalyzer do
  @moduledoc """
  Sentiment and intent analysis engine tailored for YouTube viewer comments.

  Provides:
  - Polarity scoring from -1.0 (strongly negative) to +1.0 (strongly positive)
  - Intent classification (:praise, :inquiry, :complaint, :suggestion, :neutral)
  - Batch sentiment distribution & community engagement telemetry
  - Topic / keyword extraction for audience sentiment trends
  """

  @positive_lexicon ~w(
    great awesome love fantastic helpful best amazing masterpiece brilliant
    thank thanks incredible goat masterpiece good clear enjoyed subscribed
    informative insightful clean legendary beautiful outstanding
  )

  @negative_lexicon ~w(
    terrible horrible worst waste bad boring clickbait dislike scam broken
    wrong hate useless trash unhelpful disappointed confusing garbage misleading
    laggy awful unwatchable stupid
  )

  @inquiry_markers ~w(? how why what when where which can could explain is it)
  @complaint_markers ~w(audio volume too loud quiet quiet mic lag bug stutter freeze)
  @suggestion_markers ~w(please make could you consider suggestion next video feature)

  @type sentiment_result :: %{
          score: float(),
          classification: :positive | :neutral | :negative,
          intent: :praise | :inquiry | :complaint | :suggestion | :neutral,
          confidence: float(),
          keywords: list(String.t())
        }

  @type batch_summary :: %{
          total_analyzed: non_neg_integer(),
          average_sentiment_score: float(),
          positive_percentage: float(),
          neutral_percentage: float(),
          negative_percentage: float(),
          inquiry_count: non_neg_integer(),
          sentiment_verdict: :overwhelmingly_positive | :mostly_positive | :mixed | :critical
        }

  @doc """
  Analyzes sentiment, polarity score, and primary intent for a single comment.
  """
  @spec analyze_comment(String.t()) :: sentiment_result()
  def analyze_comment(text) when is_binary(text) do
    cleaned = String.downcase(text)
    words = String.split(cleaned, ~r/[^\w\d_]+/, trim: true)

    pos_matches = Enum.filter(words, &(&1 in @positive_lexicon))
    neg_matches = Enum.filter(words, &(&1 in @negative_lexicon))

    pos_count = length(pos_matches)
    neg_count = length(neg_matches)
    total_matches = pos_count + neg_count

    score =
      if total_matches == 0 do
        0.0
      else
        Float.round((pos_count - neg_count) / total_matches, 3)
      end

    classification =
      cond do
        score >= 0.25 -> :positive
        score <= -0.25 -> :negative
        true -> :neutral
      end

    intent = detect_intent(cleaned, words, classification)

    confidence =
      cond do
        total_matches >= 3 -> 0.95
        total_matches == 2 -> 0.85
        total_matches == 1 -> 0.70
        true -> 0.50
      end

    %{
      score: score,
      classification: classification,
      intent: intent,
      confidence: confidence,
      keywords: pos_matches ++ neg_matches
    }
  end

  @doc """
  Analyzes a batch of comments and compiles high-level channel community metrics.
  """
  @spec analyze_batch(list(String.t() | map())) :: batch_summary()
  def analyze_batch([]) do
    %{
      total_analyzed: 0,
      average_sentiment_score: 0.0,
      positive_percentage: 0.0,
      neutral_percentage: 0.0,
      negative_percentage: 0.0,
      inquiry_count: 0,
      sentiment_verdict: :mixed
    }
  end

  def analyze_batch(comments) when is_list(comments) do
    results =
      Enum.map(comments, fn item ->
        text = if is_map(item), do: Map.get(item, :text, Map.get(item, "text", "")), else: to_string(item)
        analyze_comment(text)
      end)

    total = length(results)
    sum_scores = Enum.reduce(results, 0.0, fn r, acc -> acc + r.score end)
    avg_score = Float.round(sum_scores / total, 3)

    pos_count = Enum.count(results, &(&1.classification == :positive))
    neu_count = Enum.count(results, &(&1.classification == :neutral))
    neg_count = Enum.count(results, &(&1.classification == :negative))
    inq_count = Enum.count(results, &(&1.intent == :inquiry))

    pos_pct = Float.round((pos_count / total) * 100, 1)
    neu_pct = Float.round((neu_count / total) * 100, 1)
    neg_pct = Float.round((neg_count / total) * 100, 1)

    verdict =
      cond do
        pos_pct >= 75.0 -> :overwhelmingly_positive
        pos_pct >= 55.0 -> :mostly_positive
        neg_pct >= 40.0 -> :critical
        true -> :mixed
      end

    %{
      total_analyzed: total,
      average_sentiment_score: avg_score,
      positive_percentage: pos_pct,
      neutral_percentage: neu_pct,
      negative_percentage: neg_pct,
      inquiry_count: inq_count,
      sentiment_verdict: verdict
    }
  end

  defp detect_intent(text, words, classification) do
    has_question = String.contains?(text, "?") or Enum.any?(words, &(&1 in @inquiry_markers))
    has_complaint = Enum.any?(words, &(&1 in @complaint_markers))
    has_suggestion = Enum.any?(words, &(&1 in @suggestion_markers))

    cond do
      has_complaint -> :complaint
      has_suggestion -> :suggestion
      has_question -> :inquiry
      classification == :positive -> :praise
      true -> :neutral
    end
  end
end
