defmodule Lux.Prisms.Telegram.Admin.ExportChatInviteLink do
  @moduledoc """
  A prism to generate a new primary invite link for a chat; any previously generated primary link is revoked.
  Uses Telegram Bot API endpoint: POST /exportChatInviteLink
  """

  use Lux.Prism,
    name: "Export Telegram Chat Invite Link",
    description: "Exports a new primary invite link for a Telegram chat",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        }
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        invite_link: %{
          type: :string,
          description: "The exported invite link"
        }
      },
      required: ["invite_link"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} exporting chat invite link for #{chat_id}")

      request_body = %{chat_id: chat_id}

      case Client.request(:post, "/exportChatInviteLink", %{json: request_body}) do
        {:ok, %{"ok" => true, "result" => invite_link}} when is_binary(invite_link) ->
          Logger.info("Successfully exported chat invite link for #{chat_id}")
          {:ok, %{invite_link: invite_link}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to export chat invite link: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to export chat invite link: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to export chat invite link: #{inspect(error)}"}
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
end
