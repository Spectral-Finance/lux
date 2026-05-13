defmodule Lux.Prisms.YouTube.Live.SendChatMessage do
  @moduledoc """
  Sends a text message to a YouTube live chat.
  """

  use Lux.Prism,
    name: "Send YouTube Live Chat Message",
    description: "Sends a text message into a YouTube live chat",
    input_schema: %{
      type: :object,
      properties: %{
        live_chat_id: %{type: :string, description: "Live chat ID"},
        text: %{type: :string, description: "Message text"},
        token: %{type: :string, description: "Optional OAuth2 access token"}
      },
      required: ["live_chat_id", "text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        sent: %{type: :boolean, description: "Whether the message was sent"},
        message_id: %{type: :string, description: "Created live chat message ID"},
        live_chat_id: %{type: :string, description: "Live chat ID"},
        text: %{type: :string, description: "Message text"}
      },
      required: ["sent", "live_chat_id", "text"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, live_chat_id} <- validate_string(params, :live_chat_id),
         {:ok, text} <- validate_string(params, :text) do
      case Client.insert_live_chat_message(live_chat_id, text, request_opts(params)) do
        {:ok, %{"id" => message_id}} ->
          {:ok, %{sent: true, message_id: message_id, live_chat_id: live_chat_id, text: text}}

        {:ok, _response} ->
          {:ok, %{sent: true, live_chat_id: live_chat_id, text: text}}

        {:error, error} ->
          {:error, "Failed to send YouTube live chat message: #{inspect(error)}"}
      end
    end
  end

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp request_opts(%{token: token}) when is_binary(token) and token != "", do: %{token: token}
  defp request_opts(_params), do: %{}
end
