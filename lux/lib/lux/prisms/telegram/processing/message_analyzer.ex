defmodule Lux.Prisms.Telegram.Processing.MessageAnalyzer do
  @moduledoc """
  A prism for analyzing Telegram message objects and extracting metadata.
  """
  use Lux.Prism,
    name: "Telegram Message Analyzer",
    description: "Analyzes a Telegram message to extract its properties and determine its type",
    input_schema: %{
      type: :object,
      properties: %{
        message: %{
          type: :object,
          description: "Telegram message object"
        }
      },
      required: ["message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_reply: %{type: :boolean},
        is_forwarded: %{type: :boolean},
        content_types: %{type: :array, items: %{type: :string}},
        sender_type: %{type: :string},
        text: %{type: :string}
      },
      required: ["content_types", "sender_type"]
    }

  def handler(%{message: message}, _agent) when is_map(message) do
    message = stringify_keys(message)
    
    is_reply = Map.has_key?(message, "reply_to_message")
    is_forwarded = Map.has_key?(message, "forward_date") or Map.has_key?(message, "forward_origin")
    
    content_types = get_content_types(message)
    sender_type = get_sender_type(message)
    
    text = message["text"] || message["caption"]
    
    {:ok, %{
      is_reply: is_reply,
      is_forwarded: is_forwarded,
      content_types: content_types,
      sender_type: sender_type,
      text: text
    }}
  end
  
  def handler(%{"message" => message}, agent) when is_map(message) do
    handler(%{message: message}, agent)
  end
  
  def handler(_params, _agent) do
    {:error, "Missing required parameter: message"}
  end
  
  defp get_content_types(message) do
    types = []
    types = if message["text"], do: ["text" | types], else: types
    types = if message["photo"], do: ["photo" | types], else: types
    types = if message["document"], do: ["document" | types], else: types
    types = if message["video"], do: ["video" | types], else: types
    types = if message["voice"], do: ["voice" | types], else: types
    types = if message["audio"], do: ["audio" | types], else: types
    types = if message["sticker"], do: ["sticker" | types], else: types
    types = if message["location"], do: ["location" | types], else: types
    types = if message["contact"], do: ["contact" | types], else: types
    
    Enum.reverse(types)
  end
  
  defp get_sender_type(message) do
    from = message["from"] || %{}
    cond do
      from["is_bot"] == true -> "bot"
      Map.has_key?(message, "sender_chat") -> "channel"
      true -> "user"
    end
  end
  
  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
