defmodule Lux.Prisms.YouTube.AnalyzeCommentSentiment do
  @moduledoc """
  A prism for analyzing sentiment across multiple YouTube comments.

  Performs lexicon-based sentiment analysis on a batch of comment texts,
  classifying each as positive, negative, or neutral. Optionally detects
  spam using pattern matching. Returns aggregate statistics and per-comment
  analysis.

  ## Examples

      iex> AnalyzeCommentSentiment.handler(%{
      ...>   "comments" => ["Great video! Love it!", "Terrible content, waste of time."]
      ...> }, %{})
      {:ok, %{
        overall_sentiment: "neutral",
        sentiment_score: 0.0,
        positive_count: 1,
        negative_count: 1,
        neutral_count: 0,
        spam_detected: [],
        comment_analysis: [...]
      }}
  """

  use Lux.Prism,
    name: "Analyze YouTube Comment Sentiment",
    description:
      "Analyzes sentiment of YouTube comments with positive/negative/neutral classification and optional spam detection",
    input_schema: %{
      type: :object,
      properties: %{
        comments: %{
          type: :array,
          items: %{type: :string},
          description: "List of comment texts to analyze"
        },
        include_spam_detection: %{
          type: :boolean,
          description: "Whether to include spam detection scoring",
          default: false
        }
      },
      required: ["comments"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        overall_sentiment: %{
          type: :string,
          description:
            "Aggregate sentiment across all comments: 'positive', 'negative', or 'neutral'"
        },
        sentiment_score: %{
          type: :number,
          description: "Average sentiment score across all comments (-1.0 to 1.0)"
        },
        positive_count: %{type: :integer, description: "Number of positive comments"},
        negative_count: %{type: :integer, description: "Number of negative comments"},
        neutral_count: %{type: :integer, description: "Number of neutral comments"},
        spam_detected: %{
          type: :array,
          items: %{type: :string},
          description:
            "List of comment texts identified as spam (if spam detection enabled)"
        },
        comment_analysis: %{
          type: :array,
          description: "Per-comment sentiment analysis results"
        }
      },
      required: [
        "overall_sentiment",
        "sentiment_score",
        "positive_count",
        "negative_count",
        "neutral_count"
      ]
    }

  @positive_words ~w(
    great love amazing excellent awesome good thank best wonderful
    fantastic brilliant helpful perfect nice enjoyed incredible outstanding
    superb terrific splendid magnificent marvelous phenomenal
  )

  @negative_words ~w(
    bad terrible awful worst hate dislike disappointing boring
    waste spam fake stupid annoying poor horrible dreadful atrocious
    pathetic useless garbage trash mediocre inferior
  )

  @spam_patterns [
    "subscribe to me",
    "check out my channel",
    "buy now",
    "click here",
    "free money",
    "make money fast",
    "visit my profile",
    "follow me back",
    "sub4sub",
    "sub for sub",
    "like and subscribe",
    "giveaway link"
  ]

  @impl true
  def handler(%{"comments" => comments} = params, _agent) do
    include_spam = params["include_spam_detection"] || false

    analyzed =
      Enum.map(comments, fn comment ->
        score = analyze_sentiment(comment)

        %{
          text: comment,
          sentiment: classify_sentiment(score),
          score: Float.round(score, 3),
          is_spam: if(include_spam, do: detect_spam(comment), else: false)
        }
      end)

    positive = Enum.count(analyzed, &(&1.sentiment == "positive"))
    negative = Enum.count(analyzed, &(&1.sentiment == "negative"))
    neutral = length(analyzed) - positive - negative

    overall_score =
      if length(analyzed) > 0 do
        Enum.sum(Enum.map(analyzed, & &1.score)) / length(analyzed)
      else
        0.0
      end

    spam_detected =
      if include_spam do
        analyzed |> Enum.filter(& &1.is_spam) |> Enum.map(& &1.text)
      else
        []
      end

    {:ok,
     %{
       overall_sentiment: classify_sentiment(overall_score),
       sentiment_score: Float.round(overall_score, 3),
       positive_count: positive,
       negative_count: negative,
       neutral_count: neutral,
       spam_detected: spam_detected,
       comment_analysis: analyzed
     }}
  end

  defp analyze_sentiment(text) do
    text_lower = String.downcase(text)

    pos_count = Enum.count(@positive_words, &String.contains?(text_lower, &1))
    neg_count = Enum.count(@negative_words, &String.contains?(text_lower, &1))

    cond do
      pos_count > neg_count -> min(1.0, 0.3 + pos_count * 0.2)
      neg_count > pos_count -> max(-1.0, -0.3 - neg_count * 0.2)
      true -> 0.0
    end
  end

  defp classify_sentiment(score) when score > 0.1, do: "positive"
  defp classify_sentiment(score) when score < -0.1, do: "negative"
  defp classify_sentiment(_), do: "neutral"

  defp detect_spam(text) do
    text_lower = String.downcase(text)
    Enum.any?(@spam_patterns, &String.contains?(text_lower, &1))
  end
end
