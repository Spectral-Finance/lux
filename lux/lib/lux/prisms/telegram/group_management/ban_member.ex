defmodule Lux.Prisms.Telegram.GroupManagement.BanMember do
  @moduledoc """
  A prism for banning a user from a Telegram group or channel.
  """

  use Lux.Prism,
    name: "Ban Telegram Chat Member",
    description: "Bans a member from a Telegram chat or supergroup with optional until_date and message revocation",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat identifier"},
        user_id: %{type: :integer, description: "Target user identifier"},
        until_date: %{type: :integer, description: "Optional unban timestamp (Unix)"},
        revoke_messages: %{type: :boolean, description: "Delete all messages from the user"}
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        chat_id: %{type: [:string, :integer]},
        user_id: %{type: :integer}
      },
      required: ["status", "chat_id", "user_id"]
    }

  alias Lux.Integrations.Telegram.GroupManagement.MemberManager

  def handler(params, _agent) when is_map(params) do
    chat_id = Map.get(params, :chat_id) || Map.get(params, "chat_id")
    user_id = Map.get(params, :user_id) || Map.get(params, "user_id")
    until_date = Map.get(params, :until_date) || Map.get(params, "until_date")
    revoke = Map.get(params, :revoke_messages) || Map.get(params, "revoke_messages", false)
    plug = Map.get(params, :plug)

    opts = [revoke_messages: revoke]
    opts = if until_date, do: [{:until_date, until_date} | opts], else: opts
    opts = if plug, do: [{:plug, plug} | opts], else: opts

    case MemberManager.ban_member(chat_id, user_id, opts) do
      {:ok, _result} ->
        {:ok, %{status: "banned", chat_id: chat_id, user_id: user_id}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters: expected chat_id and user_id"}
end
