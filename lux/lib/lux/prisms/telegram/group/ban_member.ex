defmodule Lux.Prisms.Telegram.Group.BanMember do
  @moduledoc """
  A prism for banning a member from a Telegram group.

  Uses the banChatMember Bot API endpoint to permanently or temporarily
  ban users, with optional message deletion.

  ## Examples

      iex> BanMember.handler(%{
      ...>   chat_id: -1001234567890,
      ...>   user_id: 987654321,
      ...>   revoke_messages: true
      ...> }, %{name: "ModerationAgent"})
      {:ok, %{banned: true, chat_id: -1001234567890, user_id: 987654321}}
  """

  use Lux.Prism,
    name: "Ban Telegram Group Member",
    description: "Bans a member from a Telegram group or supergroup",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Group chat ID or @username"},
        user_id: %{type: :integer, description: "User ID to ban"},
        until_date: %{type: :integer, description: "Unix timestamp when ban lifts (0 = permanent)", default: 0},
        revoke_messages: %{type: :boolean, description: "Delete all messages from this user", default: false}
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        banned: %{type: :boolean},
        chat_id: %{type: [:string, :integer]},
        user_id: %{type: :integer}
      },
      required: ["banned"]
    }

  alias Lux.Integrations.Telegram.Client
  require Logger

  @impl true
  def handler(%{chat_id: chat_id, user_id: user_id} = params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} banning user #{user_id} from chat #{chat_id}")

    body = %{
      chat_id: chat_id,
      user_id: user_id,
      until_date: Map.get(params, :until_date, 0),
      revoke_messages: Map.get(params, :revoke_messages, false)
    }

    case Client.request(:post, "/banChatMember", %{json: body}) do
      {:ok, %{"result" => true}} ->
        Logger.info("Banned user #{user_id} from chat #{chat_id}")
        {:ok, %{banned: true, chat_id: chat_id, user_id: user_id}}

      {:error, {status, %{"description" => desc}}} ->
        Logger.error("Failed to ban #{user_id}: #{status} #{desc}")
        {:error, "#{desc} (HTTP #{status})"}

      {:error, error} ->
        {:error, error}
    end
  end
end
