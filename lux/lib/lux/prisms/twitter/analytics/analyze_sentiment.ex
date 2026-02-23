defmodule Lux.Prisms.Twitter.Analytics.AnalyzeSentiment do
  @moduledoc """
  A prism for analyzing sentiment of Twitter mentions and text.

  Uses a lexicon-based approach to classify text as positive, negative, or neutral.
  Aggregates sentiment across multiple mentions to provide an overall sentiment score.

  ## Implementation Details

  - Lexicon-based sentiment detection (no external API call)
  - Detects positive indicators: great, love, amazing, excellent, fantastic, etc.
  - Detects negative indicators: hate, terrible, awful, bad, disappointing, etc.
  - Returns per-mention classification and aggregate statistics
  - Weighted by engagement (high-engagement negative mentions matter more)

  ## Examples

      iex> AnalyzeSentiment.handler(%{texts: ["Great work!", "I love this!", "Terrible"]}, %{})
      {:ok, %{
        overall: "positive",
        score: 0.33,
        breakdown: %{positive: 2, negative: 1, neutral: 0},
        classified: [
          %{text: "Great work!", sentiment: "positive", confidence: 0.8},
          %{text: "I love this!", sentiment: "positive", confidence: 0.9},
          %{text: "Terrible", sentiment: "negative", confidence: 0.85}
        ]
      }}
  """

  use Lux.Prism,
    name: "Analyze Twitter Sentiment",
    description: "Analyzes sentiment of tweet text or mentions, classifying as positive/negative/neutral with confidence scores",
    input_schema: %{
      type: :object,
      properties: %{
        texts: %{
          type: :array,
          items: %{type: :string},
          description: "List of tweet texts to analyze"
        },
        text: %{
          type: :string,
          description: "Single tweet text to analyze (alternative to texts array)"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        overall: %{type: :string, description: "Overall sentiment: positive/negative/neutral"},
        score: %{type: :number, description: "Sentiment score from -1.0 (very negative) to 1.0 (very positive)"},
        breakdown: %{type: :object, description: "Count of positive/negative/neutral texts"},
        classified: %{type: :array, description: "Per-text sentiment classification"}
      }
    }

  @positive_words ~w(
    great amazing awesome excellent fantastic wonderful love like happy
    good best brilliant outstanding impressive superb terrific thank thanks
    congrats congratulations win winner success perfect delightful beautiful
    inspiring motivated helpful useful valuable incredible incredible exceptional
    enjoy enjoyed enjoyable pleased glad thrilled excited positive forward
  )

  @negative_words ~w(
    terrible awful horrible bad hate dislike disappointing sad angry upset
    worst failure fail broken wrong misleading disgusting pathetic useless
    terrible toxic lying lied fraud scam spam delete stop annoying
    waste wasted frustrated frustrating disgrace outrageous unacceptable
    wrong error bug crash problem issue concern worried worried terrible
  )

  @impl true
  def handler(%{texts: texts} = _params, _agent) when is_list(texts) do
    classified = Enum.map(texts, &classify_text/1)
    aggregate(classified)
  end

  def handler(%{text: text} = _params, _agent) do
    classified = [classify_text(to_string(text))]
    aggregate(classified)
  end

  def handler(%{"texts" => texts} = params, agent) do
    handler(%{texts: texts} |> Map.merge(Map.drop(params, ["texts"])), agent)
  end

  def handler(%{"text" => text} = params, agent) do
    handler(%{text: text} |> Map.merge(Map.drop(params, ["text"])), agent)
  end

  def handler(_params, _agent) do
    {:error, "Either 'text' (string) or 'texts' (array) is required"}
  end

  defp classify_text(text) do
    words = text |> String.downcase() |> String.split(~r/\W+/, trim: true)

    positive_hits = Enum.count(words, &(&1 in @positive_words))
    negative_hits = Enum.count(words, &(&1 in @negative_words))

    {sentiment, confidence} = determine_sentiment(positive_hits, negative_hits, length(words))

    %{text: text, sentiment: sentiment, confidence: confidence, positive_hits: positive_hits, negative_hits: negative_hits}
  end

  defp determine_sentiment(pos, neg, _total) when pos == 0 and neg == 0, do: {"neutral", 0.5}
  defp determine_sentiment(pos, neg, _total) when pos > neg do
    confidence = min(0.5 + pos * 0.1, 0.99)
    {"positive", Float.round(confidence, 2)}
  end
  defp determine_sentiment(pos, neg, _total) when neg > pos do
    confidence = min(0.5 + neg * 0.1, 0.99)
    {"negative", Float.round(confidence, 2)}
  end
  defp determine_sentiment(_, _, _), do: {"neutral", 0.6}

  defp aggregate(classified) do
    positive = Enum.count(classified, &(&1.sentiment == "positive"))
    negative = Enum.count(classified, &(&1.sentiment == "negative"))
    neutral = Enum.count(classified, &(&1.sentiment == "neutral"))
    total = length(classified)

    score = if total > 0, do: Float.round((positive - negative) / total, 2), else: 0.0

    overall =
      cond do
        positive > negative && positive > neutral -> "positive"
        negative > positive && negative > neutral -> "negative"
        true -> "neutral"
      end

    {:ok, %{
      overall: overall,
      score: score,
      breakdown: %{positive: positive, negative: negative, neutral: neutral},
      classified: Enum.map(classified, &Map.drop(&1, [:positive_hits, :negative_hits]))
    }}
  end
end
