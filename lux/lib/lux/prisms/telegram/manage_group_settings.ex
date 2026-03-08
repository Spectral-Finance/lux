defmodule Lux.Prisms.Telegram.ManageGroupSettings do
  @moduledoc """
  A prism for managing Telegram group settings: title, description, photo, permissions, slow mode.
  """

  use Lux.Prism,
    name: "Telegram Group Settings",
    description: "Manage Telegram group settings: title, description, photo, permissions, slow mode",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["set_title", "set_description", "set_permissions", "set_slow_mode", "pin_message", "unpin_message", "unpin_all", "get_chat"]},
        chat_id: %{type: [:string, :integer]},
        title: %{type: :string},
        description: %{type: :string},
        permissions: %{type: :object},
        slow_mode_delay: %{type: :integer, description: "Seconds: 0, 10, 30, 60, 300, 900, 3600"},
        message_id: %{type: :integer}
      },
      required: ["action", "chat_id"]
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
    plug = params["plug"] || params[:plug]

    case action do
      "set_title" ->
        api_call("/setChatTitle", %{chat_id: chat_id, title: params["title"] || params[:title]}, token, plug, "set_title")

      "set_description" ->
        api_call("/setChatDescription", %{chat_id: chat_id, description: params["description"] || params[:description]}, token, plug, "set_description")

      "set_permissions" ->
        perms = params["permissions"] || params[:permissions] || %{}
        api_call("/setChatPermissions", %{chat_id: chat_id, permissions: perms}, token, plug, "set_permissions")

      "set_slow_mode" ->
        delay = params["slow_mode_delay"] || params[:slow_mode_delay] || 0
        api_call("/setChatSlowModeDelay", %{chat_id: chat_id, slow_mode_delay: delay}, token, plug, "set_slow_mode")

      "pin_message" ->
        msg_id = params["message_id"] || params[:message_id]
        api_call("/pinChatMessage", %{chat_id: chat_id, message_id: msg_id}, token, plug, "pin_message")

      "unpin_message" ->
        msg_id = params["message_id"] || params[:message_id]
        api_call("/unpinChatMessage", %{chat_id: chat_id, message_id: msg_id}, token, plug, "unpin_message")

      "unpin_all" ->
        api_call("/unpinAllChatMessages", %{chat_id: chat_id}, token, plug, "unpin_all")

      "get_chat" ->
        case Client.request(:post, "/getChat", %{token: token, json: %{chat_id: chat_id}, plug: plug}) do
          {:ok, %{"result" => chat}} -> {:ok, %{result: chat, action: "get_chat"}}
          {:ok, chat} -> {:ok, %{result: chat, action: "get_chat"}}
          error -> error
        end

      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp api_call(endpoint, json, token, plug, action_name) do
    case Client.request(:post, endpoint, %{token: token, json: json, plug: plug}) do
      {:ok, _} -> {:ok, %{result: true, action: action_name}}
      error -> error
    end
  end
end
