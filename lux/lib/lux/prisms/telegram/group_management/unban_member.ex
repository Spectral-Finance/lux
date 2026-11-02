defmodule Lux.Prisms.Telegram.GroupManagement.UnbanMember do
  @moduledoc """
  A prism for unbanning a user in a Telegram group or channel.
  """

  use Lux.Prism,
    name: "Unban Telegram Chat Member",
    description: "Unbans a previously banned user from a Telegram chat or supergroup",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat identifier"},
        user_id: %{type: :integer, description: "Target user identifier"},
        only_if_banned: %{type: :boolean, description: "Do nothing if user was not banned"}
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
    only_if_banned = Map.get(params, :only_if_banned, false)
    plug = Map.get(params, :plug)

    opts = [only_if_banned: only_if_banned]
    opts = if plug, do: [{:plug, plug} | opts], else: opts

    case MemberManager.unban_member(chat_id, user_id, opts) do
      {:ok, _result} ->
        {:ok, %{status: "unbanned", chat_id: chat_id, user_id: user_id}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters"}
end
