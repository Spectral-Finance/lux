defmodule Lux.Prisms.Telegram.Group.RestrictMember do
  @moduledoc """
  A prism for restricting a Telegram group member.

  Uses the Bot API restrictChatMember endpoint to manage member permissions
  in groups and supergroups. Supports full permission control including
  messaging, media, polls, and more.

  ## Examples

      iex> RestrictMember.handler(%{
      ...>   chat_id: -1001234567890,
      ...>   user_id: 987654321,
      ...>   can_send_messages: false,
      ...>   until_date: 0
      ...> }, %{name: "ModerationAgent"})
      {:ok, %{restricted: true, chat_id: -1001234567890, user_id: 987654321}}
  """

  use Lux.Prism,
    name: "Restrict Telegram Group Member",
    description: "Restricts a Telegram group member's permissions using restrictChatMember",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Group/supergroup chat ID"},
        user_id: %{type: :integer, description: "User ID to restrict"},
        can_send_messages: %{type: :boolean, default: true},
        can_send_media_messages: %{type: :boolean, default: true},
        can_send_polls: %{type: :boolean, default: true},
        can_send_other_messages: %{type: :boolean, default: true},
        can_add_web_page_previews: %{type: :boolean, default: true},
        can_change_info: %{type: :boolean, default: false},
        can_invite_users: %{type: :boolean, default: false},
        can_pin_messages: %{type: :boolean, default: false},
        until_date: %{type: :integer, description: "Unix timestamp when restriction lifts (0 = permanent)", default: 0}
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        restricted: %{type: :boolean},
        chat_id: %{type: [:string, :integer]},
        user_id: %{type: :integer}
      },
      required: ["restricted"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @impl true
  def handler(%{chat_id: chat_id, user_id: user_id} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} restricting user #{user_id} in chat #{chat_id}")

    permissions = %{
      can_send_messages:           Map.get(params, :can_send_messages, true),
      can_send_media_messages:     Map.get(params, :can_send_media_messages, true),
      can_send_polls:              Map.get(params, :can_send_polls, true),
      can_send_other_messages:     Map.get(params, :can_send_other_messages, true),
      can_add_web_page_previews:   Map.get(params, :can_add_web_page_previews, true),
      can_change_info:             Map.get(params, :can_change_info, false),
      can_invite_users:            Map.get(params, :can_invite_users, false),
      can_pin_messages:            Map.get(params, :can_pin_messages, false)
    }

    body = %{chat_id: chat_id, user_id: user_id, permissions: permissions,
             until_date: Map.get(params, :until_date, 0)}

    case Client.request(:post, "/restrictChatMember", %{json: body}) do
      {:ok, %{"result" => true}} ->
        Logger.info("Restricted user #{user_id} in chat #{chat_id}")
        {:ok, %{restricted: true, chat_id: chat_id, user_id: user_id}}

      {:error, {status, %{"description" => desc}}} ->
        Logger.error("Failed to restrict #{user_id}: #{status} #{desc}")
        {:error, "#{desc} (HTTP #{status})"}

      {:error, error} ->
        {:error, error}
    end
  end
end
