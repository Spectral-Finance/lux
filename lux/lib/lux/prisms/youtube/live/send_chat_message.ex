defmodule Lux.Prisms.YouTube.Live.SendChatMessage do
  @moduledoc """
  Sends a text message to a YouTube live chat.
  """

  use Lux.Prism,
    name: "Send YouTube Live Chat Message",
    description: "Sends a text message to a live broadcast chat",
    input_schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{type: :string, description: "YouTube liveChatId"},
        message: %{type: :string, description: "Message text to send"}
      },
      required: ["live_chat_id", "message"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveStream

  def handler(params, _agent) do
    with {:ok, live_chat_id} <- required(params, :live_chat_id),
         {:ok, message} <- required(params, :message) do
      body = %{
        snippet: %{
          liveChatId: live_chat_id,
          type: "textMessageEvent",
          textMessageDetails: %{
            messageText: message
          }
        }
      }

      opts = [
        token: params[:token],
        params: %{part: "snippet"},
        json: body,
        plug: params[:plug]
      ]

      case Client.request(:post, "/liveChat/messages", opts) do
        {:ok, response} -> {:ok, LiveStream.normalize_chat_message(response)}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp required(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
