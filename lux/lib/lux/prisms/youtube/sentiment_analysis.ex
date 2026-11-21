defmodule Lux.Prisms.YouTube.SentimentAnalysis do
  @moduledoc """
  A prism that aggregates sentiment across a batch of YouTube comments
  (lux issue #70 — "Sentiment analysis implementation").

  Pure and deterministic: given a list of comment threads (as returned by
  `commentThreads.list`) it computes per-comment valence plus a channel-level
  summary — overall sentiment label, positive/neutral/negative proportions,
  average valence, and the most positively/negatively received comments.
  No network call is made here — callers fetch comments via their YouTube
  client and pass them in.

  ## Examples
      iex> SentimentAnalysis.handler(%{
      ...>   comments: [
      ...>     %{id: "c1", text: "This is fantastic and so helpful"},
      ...>     %{id: "c2", text: "terrible, worst video ever"}
      ...>   ]
      ...> }, %{name: "Agent"})
      {:ok, %{overall: :mixed, total: 2, positive: 1, negative: 1, neutral: 0}}
  """

  use Lux.Prism,
    name: "YouTube Sentiment Analysis",
    description:
      "Aggregates sentiment across a batch of YouTube comments and returns a channel-level summary",
    input_schema: %{
      type: :object,
      properties: %{
        comments: %{
          type: :array,
          description:
            "List of comment maps, each with :id and :text (or a commentThreads.list item)",
          items: %{type: :object}
        }
      },
      required: ["comments"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total: %{type: :integer, description: "Number of comments analyzed"},
        positive: %{type: :integer, description: "Count of positive comments"},
        neutral: %{type: :integer, description: "Count of neutral comments"},
        negative: %{type: :integer, description: "Count of negative comments"},
        overall: %{type: :string, description: ":positive, :negative, :neutral, or :mixed"},
        average_sentiment: %{type: :number, description: "Mean valence in [-1.0, 1.0]"},
        positive_ratio: %{type: :number, description: "Fraction of positive comments"},
        negative_ratio: %{type: :number, description: "Fraction of negative comments"},
        top_positive: %{type: :array, description: "Up to 3 most positive comments"},
        top_negative: %{type: :array, description: "Up to 3 most negative comments"}
      },
      required: ["total", "overall", "average_sentiment"]
    }

  alias Lux.Prisms.YouTube.Util

  def handler(params, _agent) do
    comments = Map.get(params, :comments, [])

    scored =
      comments
      |> Enum.map(&score_comment/1)
      |> Enum.sort_by(& &1.score, :desc)

    total = length(scored)
    pos = Enum.count(scored, &(&1.label == :positive))
    neg = Enum.count(scored, &(&1.label == :negative))
    neu = total - pos - neg

    avg = scored |> Enum.map(& &1.score) |> Util.mean()

    result = %{
      total: total,
      positive: pos,
      neutral: neu,
      negative: neg,
      overall: overall_label(pos, neg, neu, avg),
      average_sentiment: Util.round_to(avg, 4),
      positive_ratio: Util.round_to(Util.safe_div(pos, total), 4),
      negative_ratio: Util.round_to(Util.safe_div(neg, total), 4),
      top_positive: scored |> Enum.take(3) |> Enum.map(& &1.id),
      top_negative: scored |> Enum.reverse() |> Enum.take(3) |> Enum.map(& &1.id)
    }

    {:ok, result}
  end

  defp score_comment(comment) do
    text = extract_text(comment)
    {valence, _hits} = Util.sentiment(text)
    %{id: Map.get(comment, :id, ""), text: text, score: valence, label: label(valence)}
  end

  defp extract_comment_text(comment) when is_map(comment) do
    cond do
      is_binary(Map.get(comment, :text)) ->
        Map.get(comment, :text)

      is_binary(Map.get(comment, "text")) ->
        Map.get(comment, "text")

      true ->
        comment
        |> get_in([Access.key(:snippet, %{}), :topLevelComment, :snippet, :textDisplay])
        |> case do
          nil -> ""
          t when is_binary(t) -> t
          _ -> ""
        end
    end
  end

  defp extract_comment_text(_), do: ""

  # Alias kept for clarity in score_comment/1
  defp extract_text(comment), do: extract_comment_text(comment)

  defp label(v) when v >= 0.15, do: :positive
  defp label(v) when v <= -0.15, do: :negative
  defp label(_), do: :neutral

  defp overall_label(_pos, _neg, _neu, avg) when avg >= 0.15, do: :positive
  defp overall_label(_pos, _neg, _neu, avg) when avg <= -0.15, do: :negative

  defp overall_label(pos, neg, neu, _avg) do
    # If both strong positive and negative presence with little neutral -> mixed
    if pos > 0 and neg > 0 and neu == 0 do
      :mixed
    else
      :neutral
    end
  end
end
