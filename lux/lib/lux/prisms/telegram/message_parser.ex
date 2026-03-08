defmodule Lux.Prisms.Telegram.MessageParser do
  @moduledoc """
  Parses and classifies incoming Telegram messages.

  Extracts:
  - Message type (text, photo, video, document, sticker, voice, location, contact, etc.)
  - Entities (mentions, hashtags, URLs, bot commands, bold, italic, code, etc.)
  - Metadata (reply_to, forward_from, thread_id, chat type)
  """

  use Lux.Prism,
    name: "Telegram Message Parser",
    description: "Parse and classify Telegram messages, extracting entities, type, and metadata",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{type: :object, description: "Raw Telegram message object"}
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        type: %{type: :string},
        entities: %{type: :array},
        metadata: %{type: :object}
      }
    }

  @impl true
  def handler(params, _agent) do
    message = params["message"] || params[:message] || %{}

    {:ok, %{
      type: detect_type(message),
      text: message["text"] || message["caption"] || "",
      entities: parse_entities(message),
      metadata: extract_metadata(message)
    }}
  end

  @doc "Detect message content type."
  def detect_type(msg) do
    cond do
      msg["text"] -> :text
      msg["photo"] -> :photo
      msg["video"] -> :video
      msg["document"] -> :document
      msg["sticker"] -> :sticker
      msg["voice"] -> :voice
      msg["audio"] -> :audio
      msg["video_note"] -> :video_note
      msg["location"] -> :location
      msg["contact"] -> :contact
      msg["poll"] -> :poll
      msg["animation"] -> :animation
      msg["venue"] -> :venue
      msg["dice"] -> :dice
      msg["new_chat_members"] -> :new_chat_members
      msg["left_chat_member"] -> :left_chat_member
      msg["pinned_message"] -> :pinned_message
      true -> :unknown
    end
  end

  @doc "Parse message entities (mentions, commands, URLs, etc.)."
  def parse_entities(msg) do
    text = msg["text"] || msg["caption"] || ""
    entities = msg["entities"] || msg["caption_entities"] || []

    Enum.map(entities, fn entity ->
      value = String.slice(text, entity["offset"], entity["length"])
      %{
        type: entity["type"],
        offset: entity["offset"],
        length: entity["length"],
        value: value,
        url: entity["url"],
        user: entity["user"],
        language: entity["language"]
      }
    end)
  end

  @doc "Extract message metadata."
  def extract_metadata(msg) do
    %{
      message_id: msg["message_id"],
      chat_id: get_in(msg, ["chat", "id"]),
      chat_type: get_in(msg, ["chat", "type"]),
      from_id: get_in(msg, ["from", "id"]),
      from_username: get_in(msg, ["from", "username"]),
      date: msg["date"],
      reply_to_message_id: get_in(msg, ["reply_to_message", "message_id"]),
      forward_from_id: get_in(msg, ["forward_from", "id"]),
      forward_from_chat_id: get_in(msg, ["forward_from_chat", "id"]),
      is_topic_message: msg["is_topic_message"] || false,
      message_thread_id: msg["message_thread_id"],
      has_media_spoiler: msg["has_media_spoiler"] || false
    }
  end
end
