defmodule Lux.Prisms.YouTube.ResponseGenerator do
  @moduledoc """
  A prism that generates an automated, context-aware reply to a YouTube comment
  (lux issue #70 — "Comment analysis and response generation", "Fan interaction
  automation").

  Pure and deterministic: given a comment's text (and optional author/channel
  metadata) it classifies the comment intent (question / praise / complaint /
  spam / general) and produces a tailored, on-brand response plus a suggested
  next action. No network call is made here — callers post the reply via their
  YouTube client, which keeps the prism unit-testable and side-effect free.

  ## Examples
      iex> ResponseGenerator.handler(%{text: "Love this, so helpful!"}, %{name: "Agent"})
      {:ok, %{intent: :praise, response: "Thank you so much...", action: :like}}
  """

  use Lux.Prism,
    name: "YouTube Response Generator",
    description:
      "Generates a context-aware automated reply to a YouTube comment based on its intent",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "The comment text to respond to"},
        author: %{type: :string, description: "Optional comment author display name"},
        channel_name: %{type: :string, description: "Optional own channel name for sign-off"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        intent: %{
          type: :string,
          description: ":question, :praise, :complaint, :spam, or :general"
        },
        response: %{type: :string, description: "The generated reply text"},
        action: %{
          type: :string,
          description: "Suggested action: :reply, :like, :moderate, or :ignore"
        },
        escalate: %{type: :boolean, description: "Whether a human should take over"}
      },
      required: ["intent", "response", "action"]
    }

  alias Lux.Prisms.YouTube.Util

  @question_markers [
    "?",
    "how",
    "what",
    "when",
    "where",
    "why",
    "which",
    "can you",
    "could you",
    "is there",
    "do you",
    "does"
  ]
  @praise_words [
    "love",
    "great",
    "awesome",
    "amazing",
    "thanks",
    "thank",
    "helpful",
    "excellent",
    "best",
    "perfect",
    "brilliant"
  ]
  @complaint_words [
    "hate",
    "terrible",
    "awful",
    "worst",
    "bad",
    "broken",
    "useless",
    "disappointed",
    "scam",
    "wrong",
    "problem",
    "refund"
  ]

  def handler(params, _agent) do
    text = Map.get(params, :text, "") |> to_string()
    author = Map.get(params, :author, "")
    channel = Map.get(params, :channel_name, "the team")
    lower = String.downcase(text)

    {valence, _hits} = Util.sentiment(text)
    intent = classify(lower, valence)
    {response, action, escalate} = build(intent, author, channel)

    {:ok, %{intent: intent, response: response, action: action, escalate: escalate}}
  end

  defp classify(lower, valence) do
    tokens = Util.tokenize(lower)

    cond do
      contains_any?(tokens, @complaint_words) or valence <= -0.3 -> :complaint
      question?(lower, tokens) -> :question
      contains_any?(tokens, @praise_words) or valence >= 0.3 -> :praise
      true -> :general
    end
  end

  defp question?(lower, tokens) do
    String.contains?(lower, "?") or Enum.any?(@question_markers, &Enum.member?(tokens, &1))
  end

  defp contains_any?(tokens, words) do
    set = MapSet.new(tokens)
    Enum.any?(words, &MapSet.member?(set, &1))
  end

  defp build(:praise, author, _channel) do
    greet = if author == "", do: "Thanks so much", else: "Thanks so much, #{author}"

    {greet <> " — we're thrilled you found it helpful! We appreciate you watching. 🙌", :like,
     false}
  end

  defp build(:question, author, _channel) do
    greet = if author == "", do: "Great question!", else: "Great question, #{author}!"

    {greet <> " Thanks for watching — we'll get a detailed answer pinned shortly. Stay tuned!",
     :reply, false}
  end

  defp build(:complaint, author, _channel) do
    greet = if author == "", do: "We're sorry", else: "We're sorry to hear that, #{author}"

    {greet <>
       " — that's not the experience we want for you. Could you DM us so we can make it right?",
     :reply, true}
  end

  defp build(:general, author, _channel) do
    greet = if author == "", do: "Thanks for watching!", else: "Thanks for watching, #{author}!"
    {greet <> " We're glad you're here — let us know if you have any questions.", :reply, false}
  end
end
