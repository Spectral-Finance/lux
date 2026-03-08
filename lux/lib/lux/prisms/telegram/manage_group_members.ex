defmodule Lux.Prisms.Telegram.ManageGroupMembers do
  @moduledoc """
  A prism for managing Telegram group members: ban, unban, restrict, promote, kick.
  """

  use Lux.Prism,
    name: "Telegram Group Member Management",
    description: "Manage members in Telegram groups: ban, unban, restrict, promote, kick",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["ban", "unban", "restrict", "promote", "kick", "get_member"]},
        chat_id: %{type: [:string, :integer]},
        user_id: %{type: :integer},
        until_date: %{type: :integer, description: "Unix timestamp for ban/restrict expiry"},
        permissions: %{type: :object, description: "ChatPermissions for restrict action"},
        admin_rights: %{type: :object, description: "Admin rights for promote action"},
        revoke_messages: %{type: :boolean, description: "Delete all messages from banned user"}
      },
      required: ["action", "chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{result: %{type: [:boolean, :object]}, action: %{type: :string}}
    }

  alias Lux.Integrations.Telegram.Client

  @impl true
  def handler(params, _agent) do
    action = params["action"] || params[:action]
    token = params["token"] || params[:token] || ""
    chat_id = params["chat_id"] || params[:chat_id]
    user_id = params["user_id"] || params[:user_id]
    plug = params["plug"] || params[:plug]

    case action do
      "ban" -> ban_member(chat_id, user_id, params, token, plug)
      "unban" -> unban_member(chat_id, user_id, params, token, plug)
      "restrict" -> restrict_member(chat_id, user_id, params, token, plug)
      "promote" -> promote_member(chat_id, user_id, params, token, plug)
      "kick" -> kick_member(chat_id, user_id, token, plug)
      "get_member" -> get_member(chat_id, user_id, token, plug)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp ban_member(chat_id, user_id, params, token, plug) do
    json = %{chat_id: chat_id, user_id: user_id}
    json = if params["until_date"] || params[:until_date], do: Map.put(json, :until_date, params["until_date"] || params[:until_date]), else: json
    json = if params["revoke_messages"] || params[:revoke_messages], do: Map.put(json, :revoke_messages, true), else: json

    case Client.request(:post, "/banChatMember", %{token: token, json: json, plug: plug}) do
      {:ok, _} -> {:ok, %{result: true, action: "ban"}}
      error -> error
    end
  end

  defp unban_member(chat_id, user_id, params, token, plug) do
    json = %{chat_id: chat_id, user_id: user_id, only_if_banned: params["only_if_banned"] || true}

    case Client.request(:post, "/unbanChatMember", %{token: token, json: json, plug: plug}) do
      {:ok, _} -> {:ok, %{result: true, action: "unban"}}
      error -> error
    end
  end

  defp restrict_member(chat_id, user_id, params, token, plug) do
    permissions = params["permissions"] || params[:permissions] || default_restricted_permissions()
    json = %{chat_id: chat_id, user_id: user_id, permissions: permissions}
    json = if params["until_date"] || params[:until_date], do: Map.put(json, :until_date, params["until_date"] || params[:until_date]), else: json

    case Client.request(:post, "/restrictChatMember", %{token: token, json: json, plug: plug}) do
      {:ok, _} -> {:ok, %{result: true, action: "restrict"}}
      error -> error
    end
  end

  defp promote_member(chat_id, user_id, params, token, plug) do
    rights = params["admin_rights"] || params[:admin_rights] || %{}
    json = Map.merge(%{chat_id: chat_id, user_id: user_id}, rights)

    case Client.request(:post, "/promoteChatMember", %{token: token, json: json, plug: plug}) do
      {:ok, _} -> {:ok, %{result: true, action: "promote"}}
      error -> error
    end
  end

  defp kick_member(chat_id, user_id, token, plug) do
    # Ban then immediately unban = kick
    with {:ok, _} <- Client.request(:post, "/banChatMember", %{token: token, json: %{chat_id: chat_id, user_id: user_id}, plug: plug}),
         {:ok, _} <- Client.request(:post, "/unbanChatMember", %{token: token, json: %{chat_id: chat_id, user_id: user_id, only_if_banned: true}, plug: plug}) do
      {:ok, %{result: true, action: "kick"}}
    end
  end

  defp get_member(chat_id, user_id, token, plug) do
    case Client.request(:post, "/getChatMember", %{token: token, json: %{chat_id: chat_id, user_id: user_id}, plug: plug}) do
      {:ok, %{"result" => member}} -> {:ok, %{result: member, action: "get_member"}}
      {:ok, member} -> {:ok, %{result: member, action: "get_member"}}
      error -> error
    end
  end

  defp default_restricted_permissions do
    %{
      can_send_messages: false,
      can_send_media_messages: false,
      can_send_polls: false,
      can_send_other_messages: false,
      can_add_web_page_previews: false,
      can_change_info: false,
      can_invite_users: false,
      can_pin_messages: false
    }
  end
end
