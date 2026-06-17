defmodule Lux.Lenses.Telegram.Messaging.ReadMessage do
  @moduledoc """
  A lens for reading messages from Telegram chats.
  """

  alias Lux.Integrations.Telegram.Client

  use Lux.Lens,
    name: "Read Telegram Message",
    description: "Reads a message from a Telegram chat",
    url: "https://api.telegram.org/bot/:token/getMessage",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: :string,
          description: "The ID of the chat containing the message"
        },
        message_id: %{
          type: :integer,
          description: "The ID of the message to read"
        }
      },
      required: ["chat_id", "message_id"]
    }

  @impl true
  def focus(%{chat_id: chat_id, message_id: message_id}) do
    case Client.request(:get, "/getMessage?chat_id=#{chat_id}&message_id=#{message_id}") do
      {:ok, %{"result" => message}} ->
        {:ok, format_message(message)}

      {:error, {status, description}} ->
        {:error, %{status: status, description: description}}

      {:error, error} ->
        {:error, %{error: inspect(error)}}
    end
  end

  defp format_message(message) do
    %{
      message_id: message["message_id"],
      text: message["text"],
      date: message["date"],
      chat: %{
        id: message["chat"]["id"],
        type: message["chat"]["type"],
        title: message["chat"]["title"]
      },
      from: format_user(message["from"])
    }
  end

  defp format_user(nil), do: nil
  defp format_user(user) do
    %{
      id: user["id"],
      username: user["username"],
      first_name: user["first_name"],
      is_bot: user["is_bot"]
    }
  end
end
