defmodule Lux.Prisms.YouTube.ModerateComment do
  @moduledoc """
  A prism for moderating YouTube comments.

  Analyzes comment text and produces a structured moderation decision
  with spam detection, toxicity analysis, and confidence scoring.
  Supports actions: "approve", "reject", or "hold" for manual review.

  ## Examples

      iex> ModerateComment.handler(%{
      ...>   "comment_id" => "comment_123",
      ...>   "comment_text" => "Subscribe to me for free money!",
      ...>   "action" => "reject"
      ...> }, %{})
      {:ok, %{
        comment_id: "comment_123",
        action: "reject",
        moderation_result: "rejected",
        reasons: ["spam_detected", "promotional_content"],
        confidence: 0.92,
        is_spam: true,
        is_toxic: false
      }}
  """

  use Lux.Prism,
    name: "Moderate YouTube Comment",
    description:
      "Analyzes and moderates YouTube comments with spam detection and confidence scoring",
    input_schema: %{
      type: :object,
      properties: %{
        comment_id: %{
          type: :string,
          description: "The ID of the comment to moderate"
        },
        comment_text: %{
          type: :string,
          description: "The text content of the comment to analyze"
        },
        action: %{
          type: :string,
          description: "Moderation action: 'approve', 'reject', or 'hold'",
          enum: ["approve", "reject", "hold"]
        }
      },
      required: ["comment_id", "comment_text", "action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        comment_id: %{type: :string, description: "The moderated comment ID"},
        action: %{type: :string, description: "The requested moderation action"},
        moderation_result: %{
          type: :string,
          description: "Final moderation outcome: 'approved', 'rejected', or 'held'"
        },
        reasons: %{
          type: :array,
          items: %{type: :string},
          description: "List of reasons for the moderation decision"
        },
        confidence: %{
          type: :number,
          description: "Confidence score for the moderation decision (0.0-1.0)"
        },
        is_spam: %{type: :boolean, description: "Whether spam patterns were detected"},
        is_toxic: %{type: :boolean, description: "Whether toxic content was detected"}
      },
      required: ["comment_id", "action", "moderation_result", "reasons", "confidence"]
    }

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
    "first comment",
    "like and subscribe",
    "giveaway"
  ]

  @toxic_patterns [
    "hate",
    "stupid",
    "idiot",
    "moron",
    "kill yourself",
    "shut up",
    "worthless",
    "garbage",
    "trash"
  ]

  @impl true
  def handler(
        %{"comment_id" => comment_id, "comment_text" => comment_text, "action" => action},
        _agent
      ) do
    text_lower = String.downcase(comment_text)

    spam_matches = Enum.filter(@spam_patterns, &String.contains?(text_lower, &1))
    toxic_matches = Enum.filter(@toxic_patterns, &String.contains?(text_lower, &1))

    is_spam = length(spam_matches) > 0
    is_toxic = length(toxic_matches) > 0

    reasons = build_reasons(spam_matches, toxic_matches, action)
    confidence = calculate_confidence(spam_matches, toxic_matches, action)

    moderation_result =
      case action do
        "approve" ->
          if is_spam or is_toxic, do: "held", else: "approved"

        "reject" ->
          "rejected"

        "hold" ->
          "held"
      end

    {:ok,
     %{
       comment_id: comment_id,
       action: action,
       moderation_result: moderation_result,
       reasons: reasons,
       confidence: Float.round(confidence, 3),
       is_spam: is_spam,
       is_toxic: is_toxic
     }}
  end

  defp build_reasons(spam_matches, toxic_matches, action) do
    reasons = []

    reasons =
      if length(spam_matches) > 0,
        do: ["spam_detected", "promotional_content" | reasons],
        else: reasons

    reasons =
      if length(toxic_matches) > 0,
        do: ["toxic_content" | reasons],
        else: reasons

    reasons =
      if action == "approve" and length(spam_matches) == 0 and length(toxic_matches) == 0,
        do: ["content_meets_guidelines" | reasons],
        else: reasons

    reasons =
      if action == "hold" and length(spam_matches) == 0 and length(toxic_matches) == 0,
        do: ["manual_review_requested" | reasons],
        else: reasons

    Enum.uniq(reasons)
  end

  defp calculate_confidence(spam_matches, toxic_matches, action) do
    base =
      case action do
        "reject" -> 0.85
        "approve" -> 0.80
        "hold" -> 0.70
      end

    spam_boost = min(length(spam_matches) * 0.05, 0.15)
    toxic_boost = min(length(toxic_matches) * 0.05, 0.10)

    min(1.0, base + spam_boost + toxic_boost)
  end
end
