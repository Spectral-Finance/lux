defmodule Lux.Prisms.YouTube.CommentModeration do
  @moduledoc """
  A prism that analyzes a YouTube comment for sentiment and spam, and decides
  a moderation action (lux issue #70 — "Sentiment analysis", "Spam detection
  and moderation", "Moderation system").

  Pure and deterministic: given a comment thread item (as returned by
  `commentThreads.list`) it returns a sentiment label + score, a spam
  probability with the reasons that triggered it, and a recommended
  moderation action (`keep` / `hold` / `hide` / `remove`). No network call is
  made here — callers fetch the comment via their YouTube client and pass it
  in, which keeps the prism unit-testable and side-effect free.

  ## Examples
      iex> CommentModeration.handler(%{
      ...>   id: "thread1",
      ...>   snippet: %{topLevelComment: %{snippet: %{textDisplay: "Love this, so helpful!"}}}
      ...> }, %{name: "Agent"})
      {:ok, %{sentiment: :positive, sentiment_score: 1.0, spam_score: 0.0,
             action: :keep, reasons: []}}
  """

  use Lux.Prism,
    name: "YouTube Comment Moderation",
    description:
      "Analyzes a YouTube comment for sentiment and spam and recommends a moderation action",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "The comment thread ID"},
        snippet: %{
          type: :object,
          description: "commentThreads.list snippet (topLevelComment.snippet.textDisplay)"
        }
      },
      required: ["id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        comment_id: %{type: :string, description: "The comment thread ID"},
        text: %{type: :string, description: "The comment text analyzed"},
        sentiment: %{type: :string, description: ":positive, :neutral, or :negative"},
        sentiment_score: %{type: :number, description: "Average valence in [-1.0, 1.0]"},
        spam_score: %{type: :number, description: "Heuristic spam probability in [0.0, 1.0]"},
        action: %{type: :string, description: ":keep, :hold, :hide, or :remove"},
        reasons: %{type: :array, description: "Human-readable reasons for the decision"}
      },
      required: ["comment_id", "sentiment", "spam_score", "action"]
    }

  alias Lux.Prisms.YouTube.Util

  # Heuristic spam signals. Each is {name, weight} and contributes to a
  # bounded spam score. Transparent and auditable — no opaque model.
  @spam_links ~r/https?:\/\/|www\.|bit\.ly|t\.me\//
  @max_reasons 6

  def handler(params, _agent) do
    text = extract_text(params)
    {valence, _hits} = Util.sentiment(text)
    sentiment = classify_sentiment(valence)

    {spam_score, reasons} = spam_signals(text)
    action = decide_action(sentiment, spam_score)

    result = %{
      comment_id: Map.get(params, :id, ""),
      text: text,
      sentiment: sentiment,
      sentiment_score: Util.round_to(valence, 4),
      spam_score: Util.round_to(spam_score, 4),
      action: action,
      reasons: reasons
    }

    {:ok, result}
  end

  defp extract_text(params) do
    params
    |> Map.get(:snippet, %{})
    |> get_in([Access.key(:topLevelComment, %{}), :snippet, :textDisplay])
    |> case do
      nil -> ""
      t when is_binary(t) -> t
      _ -> ""
    end
  end

  defp classify_sentiment(v) when v >= 0.15, do: :positive
  defp classify_sentiment(v) when v <= -0.15, do: :negative
  defp classify_sentiment(_), do: :neutral

  defp spam_signals(text) do
    lower = String.downcase(text)
    words = Util.tokenize(text)
    n_words = length(words)

    checks = [
      {Regex.match?(@spam_links, lower), "contains a link"},
      {n_words > 0 and count_exclamations(text) >= 3, "excessive exclamation"},
      {n_words > 0 and upper_ratio(text) > 0.7 and n_words >= 4, "all-caps shouting"},
      {n_words > 0 and repeated_char_ratio(text) > 0.3, "repeated characters"},
      {contains_any?(lower, [
         "buy now",
         "click here",
         "subscribe",
         "giveaway",
         "free money",
         "dm me",
         "check my",
         "promo",
         "discount code"
       ]), "promotional phrasing"},
      {n_words > 60, "unusually long comment"}
    ]

    {hits, reasons} =
      checks
      |> Enum.reduce({0, []}, fn
        {true, reason}, {h, rs} -> {h + 1, rs ++ [reason]}
        {false, _}, acc -> acc
      end)

    score = min(1.0, hits * 0.25)
    {score, Enum.take(reasons, @max_reasons)}
  end

  defp count_exclamations(text), do: Regex.scan(~r/!/, text) |> length()

  defp upper_ratio(text) do
    letters = Regex.scan(~r/[A-Za-z]/, text) |> List.flatten()

    case length(letters) do
      0 ->
        0.0

      n ->
        uppers = Enum.count(letters, &(String.upcase(&1) == &1))
        uppers / n
    end
  end

  defp repeated_char_ratio(text) do
    case Regex.scan(~r/(.)\1\1/, text) do
      [] -> 0.0
      hits -> min(1.0, length(hits) * 0.2)
    end
  end

  defp contains_any?(lower, needles) do
    Enum.any?(needles, &String.contains?(lower, &1))
  end

  defp decide_action(_sentiment, spam) when spam >= 0.75, do: :remove
  defp decide_action(_sentiment, spam) when spam >= 0.5, do: :hide
  defp decide_action(:negative, _spam), do: :hold
  defp decide_action(_sentiment, spam) when spam >= 0.25, do: :hold
  defp decide_action(_sentiment, _spam), do: :keep
end
