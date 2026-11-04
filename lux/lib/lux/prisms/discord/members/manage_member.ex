defmodule Lux.Prisms.Discord.Members.ManageMember do
  @moduledoc """
  A prism for Discord member interaction and server membership operations (`Spectral-Finance/lux#55`).

  Supports:
  - Sending direct messages (`action: "direct_message"`)
  - Updating member nickname or moderation state (`action: "modify_member"`)
  - Leaving a guild (`action: "leave_guild"`)
  """

  use Lux.Prism,
    name: "Manage Discord Member",
    description: "Handles direct messaging, member management, and server membership actions",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["direct_message", "modify_member", "leave_guild"],
          description: "Member or guild interaction to execute"
        },
        guild_id: %{
          type: :string,
          description: "Guild ID (required for modify_member and leave_guild)"
        },
        user_id: %{
          type: :string,
          description: "Target Discord user ID (required for direct_message and modify_member)"
        },
        content: %{
          type: :string,
          description: "Direct message text content"
        },
        nick: %{
          type: :string,
          description: "Updated member nickname"
        }
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{type: :boolean},
        action: %{type: :string},
        user_id: %{type: :string},
        guild_id: %{type: :string},
        dm_channel_id: %{type: :string},
        message_id: %{type: :string}
      },
      required: ["success", "action"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @impl true
  def handler(params, _agent) do
    action = params[:action] || params["action"]

    case action do
      "direct_message" ->
        user_id = params[:user_id] || params["user_id"]
        content = params[:content] || params["content"]

        if is_binary(user_id) and is_binary(content) and content != "" do
          with {:ok, %{"id" => dm_channel_id}} <-
                 Client.request(:post, "/users/@me/channels", %{json: %{recipient_id: user_id}}),
               {:ok, %{"id" => message_id}} <-
                 Client.request(:post, "/channels/#{dm_channel_id}/messages", %{json: %{content: content}}) do
            {:ok,
             %{
               success: true,
               action: "direct_message",
               user_id: user_id,
               dm_channel_id: dm_channel_id,
               message_id: message_id
             }}
          end
        else
          {:error, "Missing user_id or content for direct_message"}
        end

      "modify_member" ->
        guild_id = params[:guild_id] || params["guild_id"]
        user_id = params[:user_id] || params["user_id"]
        nick = params[:nick] || params["nick"]

        if is_binary(guild_id) and is_binary(user_id) do
          case Client.request(:patch, "/guilds/#{guild_id}/members/#{user_id}", %{json: %{nick: nick}}) do
            {:ok, _} ->
              {:ok, %{success: true, action: "modify_member", guild_id: guild_id, user_id: user_id, nick: nick}}

            {:error, err} ->
              {:error, err}
          end
        else
          {:error, "Missing guild_id or user_id for modify_member"}
        end

      "leave_guild" ->
        guild_id = params[:guild_id] || params["guild_id"]

        if is_binary(guild_id) do
          case Client.request(:delete, "/users/@me/guilds/#{guild_id}", %{}) do
            {:ok, _} -> {:ok, %{success: true, action: "leave_guild", guild_id: guild_id}}
            {:error, err} -> {:error, err}
          end
        else
          {:error, "Missing guild_id for leave_guild"}
        end

      other ->
        {:error, "Unsupported member action: #{inspect(other)}"}
    end
  end
end
