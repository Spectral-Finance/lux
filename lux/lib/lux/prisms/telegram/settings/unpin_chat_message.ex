defmodule Lux.Prisms.Telegram.Settings.UnpinChatMessage do
  @moduledoc """
  A prism to unpin a message (or all messages) in a chat.
  Uses Telegram Bot API endpoints: POST /unpinChatMessage or POST /unpinAllChatMessages
  """

  use Lux.Prism,
    name: "Unpin Telegram Chat Message",
    description: "Unpins a specific message or all pinned messages in a chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of a message to unpin. If omitted, all pinned messages will be unpinned."
        }
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the message(s) were successfully unpinned"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id) do
      
      agent_name = agent[:name] || "Unknown Agent"
      message_id = fetch_optional(params, :message_id)

      {endpoint, request_body} = if is_nil(message_id) do
        Logger.info("Agent #{agent_name} unpinning all messages in chat #{chat_id}")
        {"/unpinAllChatMessages", %{chat_id: chat_id}}
      else
        Logger.info("Agent #{agent_name} unpinning message #{message_id} in chat #{chat_id}")
        {"/unpinChatMessage", %{chat_id: chat_id, message_id: message_id}}
      end

      case Client.request(:post, endpoint, %{json: request_body}) do
        {:ok, %{"ok" => true}} ->
          Logger.info("Successfully completed unpin operation in chat #{chat_id}")
          {:ok, %{success: true}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to unpin message: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to unpin message: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to unpin message: #{inspect(error)}"}
      end
    end
  end

  defp fetch_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} -> {:ok, val}
      :error ->
        case Map.fetch(params, to_string(key)) do
          {:ok, val} -> {:ok, val}
          :error -> {:error, "Missing or invalid #{key}"}
        end
    end
  end

  defp fetch_optional(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} -> val
      :error -> Map.get(params, to_string(key))
    end
  end
end
