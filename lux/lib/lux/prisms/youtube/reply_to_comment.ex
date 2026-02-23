defmodule Lux.Prisms.YouTube.ReplyToComment do
  @moduledoc """
  A prism for generating personalized replies to YouTube comments.

  Creates structured reply suggestions based on comment sentiment analysis,
  channel persona, and engagement optimization patterns. Estimates the
  engagement boost from community interaction.

  ## Examples

      iex> ReplyToComment.handler(%{
      ...>   "thread_id" => "thread_123",
      ...>   "reply_text" => "Thank you for watching!",
      ...>   "channel_name" => "TechChannel"
      ...> }, %{})
      {:ok, %{
        thread_id: "thread_123",
        suggested_reply: "Thank you for watching! We appreciate your support! - TechChannel",
        reply_text: "Thank you for watching!",
        channel_name: "TechChannel",
        estimated_engagement_boost: 0.15,
        reply_type: "gratitude",
        character_count: 65,
        within_limit: true
      }}
  """

  use Lux.Prism,
    name: "Reply to YouTube Comment",
    description:
      "Generates personalized reply suggestions with engagement boost estimation for YouTube comments",
    input_schema: %{
      type: :object,
      properties: %{
        thread_id: %{
          type: :string,
          description: "The ID of the comment thread to reply to"
        },
        reply_text: %{
          type: :string,
          description: "The reply message text to send"
        },
        channel_name: %{
          type: :string,
          description: "The YouTube channel name for personalization"
        },
        original_comment: %{
          type: :string,
          description: "The original comment text for sentiment-based personalization"
        }
      },
      required: ["thread_id", "reply_text", "channel_name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        thread_id: %{type: :string, description: "The target comment thread ID"},
        suggested_reply: %{type: :string, description: "The personalized reply suggestion"},
        reply_text: %{type: :string, description: "The original reply text"},
        channel_name: %{type: :string, description: "The channel name used for personalization"},
        estimated_engagement_boost: %{
          type: :number,
          description: "Estimated engagement boost factor (0.0-1.0)"
        },
        reply_type: %{
          type: :string,
          description:
            "Classified type of reply: 'acknowledgment', 'gratitude', 'engagement', 'generic'"
        },
        character_count: %{type: :integer, description: "Character count of the suggested reply"},
        within_limit: %{
          type: :boolean,
          description: "Whether reply is within YouTube's 500 char limit"
        }
      },
      required: ["thread_id", "suggested_reply", "estimated_engagement_boost"]
    }

  @youtube_reply_limit 500

  @impl true
  def handler(
        %{"thread_id" => thread_id, "reply_text" => reply_text, "channel_name" => channel_name} =
          params,
        _agent
      ) do
    original_comment = params["original_comment"] || params[:original_comment] || ""

    reply_type = classify_reply_type(reply_text, original_comment)
    suggested_reply = build_suggested_reply(reply_text, channel_name, reply_type)
    engagement_boost = estimate_engagement_boost(reply_type, original_comment)

    char_count = String.length(suggested_reply)

    {:ok,
     %{
       thread_id: thread_id,
       suggested_reply: suggested_reply,
       reply_text: reply_text,
       channel_name: channel_name,
       estimated_engagement_boost: Float.round(engagement_boost, 3),
       reply_type: reply_type,
       character_count: char_count,
       within_limit: char_count <= @youtube_reply_limit
     }}
  end

  defp classify_reply_type(reply_text, original_comment) do
    text_lower = String.downcase(reply_text)
    original_lower = String.downcase(original_comment)

    cond do
      String.contains?(text_lower, ["thank", "appreciate", "glad"]) ->
        "gratitude"

      String.contains?(text_lower, ["question", "?", "how", "what", "when", "why"]) ->
        "engagement"

      String.contains?(original_lower, ["love", "great", "amazing", "awesome", "best"]) ->
        "acknowledgment"

      true ->
        "generic"
    end
  end

  defp build_suggested_reply(reply_text, channel_name, reply_type) do
    base = String.trim(reply_text)

    suffix =
      case reply_type do
        "gratitude" -> " We appreciate your support! - #{channel_name}"
        "engagement" -> " Let us know your thoughts! - #{channel_name}"
        "acknowledgment" -> " Thanks for the kind words! - #{channel_name}"
        _ -> " - #{channel_name}"
      end

    base <> suffix
  end

  defp estimate_engagement_boost(reply_type, original_comment) do
    base =
      case reply_type do
        "engagement" -> 0.18
        "gratitude" -> 0.15
        "acknowledgment" -> 0.12
        _ -> 0.08
      end

    original_lower = String.downcase(original_comment)

    positive_boost =
      if String.contains?(original_lower, ["love", "amazing", "great", "awesome"]),
        do: 0.05,
        else: 0.0

    min(1.0, base + positive_boost)
  end
end
