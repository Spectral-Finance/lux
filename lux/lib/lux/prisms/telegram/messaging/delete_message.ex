defmodule Lux.Prisms.Telegram.Messaging.DeleteMessage do
  @moduledoc """
  A prism for deleting messages in Telegram chats.
  """

  use Lux.Prism,
    name: "Delete Telegram Message",
    description: "Deletes a message from a Telegram chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: :string, description: "The ID of the chat"},
        message_id: %{type: :integer, description: "The ID of the message to delete"}
      },
      required: ["chat_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        deleted: %{type: :boolean, description: "Whether the message was deleted"},
        message_id: %{type: :integer, description: "The ID of the deleted message"},
        chat_id: %{type: :string, description: "The ID of the chat"}
      },
      required: ["deleted"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- validate_param(params, :chat_id),
         {:ok, message_id} <- validate_param(params, :message_id) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} deleting message #{message_id} from chat #{chat_id}")

      case Client.request(:post, "/deleteMessage", %{json: %{chat_id: chat_id, message_id: message_id}}) do
        {:ok, _result} ->
          Logger.info("Successfully deleted message #{message_id} from chat #{chat_id}")
          {:ok, %{deleted: true, message_id: message_id, chat_id: chat_id}}

        {:error, {status, description}} ->
          Logger.error("Failed to delete message: {#{status}, #{description}}")
          {:error, {status, description}}

        {:error, error} ->
          Logger.error("Failed to delete message: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      {:ok, value} when is_integer(value) -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
