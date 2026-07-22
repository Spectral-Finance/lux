defmodule Lux.Prisms.Telegram.Admin.PinChatMessage do
  @moduledoc """
  A prism to pin a message in a group, supergroup, or channel.
  Uses Telegram Bot API endpoint: POST /pinChatMessage
  """

  use Lux.Prism,
    name: "Pin Telegram Chat Message",
    description: "Pins a message in a Telegram chat or channel",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        message_id: %{
          type: :integer,
          description: "Identifier of a message to pin"
        },
        disable_notification: %{
          type: :boolean,
          description: "Pass True if it is not necessary to send a notification to all chat members"
        }
      },
      required: ["chat_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the message was successfully pinned"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id),
         {:ok, message_id} <- fetch_param(params, :message_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} pinning message #{message_id} in chat #{chat_id}")

      request_body = %{
        chat_id: chat_id,
        message_id: message_id,
        disable_notification: fetch_optional(params, :disable_notification)
      }

      request_body = Enum.filter(request_body, fn {_, v} -> not is_nil(v) end) |> Map.new()

      case Client.request(:post, "/pinChatMessage", %{json: request_body}) do
        {:ok, %{"ok" => true}} ->
          Logger.info("Successfully pinned message #{message_id} in chat #{chat_id}")
          {:ok, %{success: true}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to pin chat message: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to pin chat message: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to pin chat message: #{inspect(error)}"}
      end
    end
  end

  defp fetch_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when not is_nil(val) -> {:ok, val}
      _ ->
        case Map.fetch(params, to_string(key)) do
          {:ok, val} when not is_nil(val) -> {:ok, val}
          _ -> {:error, "Missing or invalid #{key}"}
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
