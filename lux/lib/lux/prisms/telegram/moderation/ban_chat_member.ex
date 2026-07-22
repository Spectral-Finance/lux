defmodule Lux.Prisms.Telegram.Moderation.BanChatMember do
  @moduledoc """
  A prism to ban a user from a Telegram group, supergroup, or channel.
  Uses Telegram Bot API endpoint: POST /banChatMember
  """

  use Lux.Prism,
    name: "Ban Telegram Chat Member",
    description: "Bans a user from a Telegram group, supergroup, or channel",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        user_id: %{
          type: :integer,
          description: "Unique identifier of the target user"
        },
        until_date: %{
          type: :integer,
          description: "Date when the user will be unbanned; Unix time. If banned for > 366 days or < 30s, banned forever."
        },
        revoke_messages: %{
          type: :boolean,
          description: "Pass True to delete all messages of the user being removed"
        }
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the user was successfully banned"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id),
         {:ok, user_id} <- fetch_param(params, :user_id) do
      
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} banning user #{user_id} in chat #{chat_id}")

      request_body = %{
        chat_id: chat_id,
        user_id: user_id,
        until_date: fetch_optional(params, :until_date),
        revoke_messages: fetch_optional(params, :revoke_messages)
      }
      # Remove nil values
      request_body = Enum.filter(request_body, fn {_, v} -> not is_nil(v) end) |> Map.new()

      case Client.request(:post, "/banChatMember", %{json: request_body}) do
        {:ok, %{"ok" => true}} ->
          Logger.info("Successfully banned user #{user_id} in chat #{chat_id}")
          {:ok, %{success: true}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to ban member: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to ban member: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to ban member: #{inspect(error)}"}
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
