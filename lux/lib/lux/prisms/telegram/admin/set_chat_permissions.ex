defmodule Lux.Prisms.Telegram.Admin.SetChatPermissions do
  @moduledoc """
  A prism to set default chat permissions for all members.
  Uses Telegram Bot API endpoint: POST /setChatPermissions
  """

  use Lux.Prism,
    name: "Set Telegram Chat Permissions",
    description: "Sets default chat permissions for all members in a supergroup",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{
          type: [:string, :integer],
          description: "Unique identifier for the target chat or username of the target channel"
        },
        permissions: %{
          type: :object,
          description: "A JSON object for the new default chat permissions",
          properties: %{
            can_send_messages: %{type: :boolean},
            can_send_audios: %{type: :boolean},
            can_send_documents: %{type: :boolean},
            can_send_photos: %{type: :boolean},
            can_send_videos: %{type: :boolean},
            can_send_video_notes: %{type: :boolean},
            can_send_voice_notes: %{type: :boolean},
            can_send_polls: %{type: :boolean},
            can_send_other_messages: %{type: :boolean},
            can_add_web_page_previews: %{type: :boolean},
            can_change_info: %{type: :boolean},
            can_invite_users: %{type: :boolean},
            can_pin_messages: %{type: :boolean},
            can_manage_topics: %{type: :boolean}
          }
        },
        use_independent_chat_permissions: %{
          type: :boolean,
          description: "Pass True if chat permissions are set independently"
        }
      },
      required: ["chat_id", "permissions"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether the permissions were successfully set"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  def handler(params, agent) do
    with {:ok, chat_id} <- fetch_param(params, :chat_id),
         {:ok, permissions} <- fetch_param(params, :permissions) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} setting default permissions in chat #{chat_id}")

      request_body = %{
        chat_id: chat_id,
        permissions: permissions,
        use_independent_chat_permissions: fetch_optional(params, :use_independent_chat_permissions)
      }

      request_body = Enum.filter(request_body, fn {_, v} -> not is_nil(v) end) |> Map.new()

      case Client.request(:post, "/setChatPermissions", %{json: request_body}) do
        {:ok, %{"ok" => true}} ->
          Logger.info("Successfully set chat permissions in #{chat_id}")
          {:ok, %{success: true}}

        {:error, {status, %{"description" => description}}} ->
          {:error, "Failed to set chat permissions: #{description} (HTTP #{status})"}

        {:error, {status, description}} when is_binary(description) ->
          {:error, "Failed to set chat permissions: #{description} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to set chat permissions: #{inspect(error)}"}
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
