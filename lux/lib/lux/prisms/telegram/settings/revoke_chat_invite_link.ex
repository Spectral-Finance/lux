defmodule Lux.Prisms.Telegram.Settings.RevokeChatInviteLink do
  @moduledoc """
  A prism to revoke an invite link created by the bot.
  Uses Telegram Bot API endpoint: POST /revokeChatInviteLink
  """

  use Lux.Prism,
    name: "Revoke Telegram Chat Invite Link",
    description: "Revokes an invite link created by the bot",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        invite_link: %{
          type: :string,
          description: "The invite link to revoke"
        }
      },
      required: ["chat_id", "invite_link"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the invite link was successfully revoked"
        },
        revoked_link: %{
          type: :object,
          description: "The revoked ChatInviteLink object"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id),
         {:ok, invite_link} <- fetch_param(params, :invite_link) do
      
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} revoking invite link in chat #{chat_id}")

      request_body = %{
        chat_id: chat_id,
        invite_link: invite_link
      }

      case Client.request(:post, "/revokeChatInviteLink", %{json: request_body}) do
        {:ok, %{"ok" => true, "result" => result}} ->
          Logger.info("Successfully revoked invite link in chat #{chat_id}")
          {:ok, %{
            success: true,
            revoked_link: result
          }}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to revoke invite link: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to revoke invite link: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to revoke invite link: #{inspect(error)}"}
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
end
