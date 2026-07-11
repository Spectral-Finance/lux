defmodule Lux.Prisms.Telegram.Processing.AnalyzeMessage do
  @moduledoc """
  Analyzes message content types and extracts metadata.
  """
  use Lux.Prism,
    name: "Analyze Telegram Message",
    description: "Analyzes message content types (text, photo, document, etc.) and extracts metadata",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :object,
          description: "The message object from Telegram update"
        }
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        content_type: %{type: :string},
        text: %{type: :string},
        has_media: %{type: :boolean},
        media_id: %{type: :string},
        is_forwarded: %{type: :boolean},
        is_reply: %{type: :boolean}
      },
      required: ["content_type"]
    }

  def handler(params, _ctx) do
    message = Map.get(params, :message) || Map.get(params, "message")

    if is_map(message) do
      content_type = determine_content_type(message)
      text = Map.get(message, "text") || Map.get(message, "caption")
      
      {has_media, media_id} = extract_media(message, content_type)
      
      is_forwarded = Map.has_key?(message, "forward_date") or Map.has_key?(message, "forward_origin")
      is_reply = Map.has_key?(message, "reply_to_message")

      result = %{
        content_type: content_type,
        text: text,
        has_media: has_media,
        media_id: media_id,
        is_forwarded: is_forwarded,
        is_reply: is_reply
      }
      
      {:ok, result}
    else
      {:error, "Invalid message object"}
    end
  end

  defp determine_content_type(message) do
    cond do
      Map.has_key?(message, "text") -> "text"
      Map.has_key?(message, "photo") -> "photo"
      Map.has_key?(message, "document") -> "document"
      Map.has_key?(message, "video") -> "video"
      Map.has_key?(message, "voice") -> "voice"
      Map.has_key?(message, "audio") -> "audio"
      Map.has_key?(message, "animation") -> "animation"
      Map.has_key?(message, "sticker") -> "sticker"
      Map.has_key?(message, "location") -> "location"
      Map.has_key?(message, "contact") -> "contact"
      Map.has_key?(message, "poll") -> "poll"
      true -> "unknown"
    end
  end

  defp extract_media(message, "photo") do
    # Photo is an array of sizes, we take the largest one (last element)
    photos = Map.get(message, "photo", [])
    case List.last(photos) do
      %{"file_id" => file_id} -> {true, file_id}
      _ -> {true, nil}
    end
  end

  defp extract_media(message, type) when type in ["document", "video", "voice", "audio", "animation", "sticker"] do
    case Map.get(message, type) do
      %{"file_id" => file_id} -> {true, file_id}
      _ -> {true, nil}
    end
  end

  defp extract_media(_message, _type), do: {false, nil}
end
