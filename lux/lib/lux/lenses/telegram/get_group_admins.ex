defmodule Lux.Lenses.Telegram.GetGroupAdmins do
  @moduledoc """
  Lens for retrieving group/channel administrators from Telegram.
  """

  alias Lux.Integrations.Telegram.Client

  def focus(params, _opts \\ []) do
    token = params[:token] || params["token"] || ""
    chat_id = params[:chat_id] || params["chat_id"]
    plug = params[:plug] || params["plug"]

    case Client.request(:post, "/getChatAdministrators", %{token: token, json: %{chat_id: chat_id}, plug: plug}) do
      {:ok, %{"result" => admins}} ->
        parsed = Enum.map(admins, fn a ->
          %{
            user_id: get_in(a, ["user", "id"]),
            username: get_in(a, ["user", "username"]),
            first_name: get_in(a, ["user", "first_name"]),
            status: a["status"],
            is_anonymous: a["is_anonymous"] || false,
            can_manage_chat: a["can_manage_chat"] || false,
            can_delete_messages: a["can_delete_messages"] || false,
            can_restrict_members: a["can_restrict_members"] || false,
            can_promote_members: a["can_promote_members"] || false,
            can_change_info: a["can_change_info"] || false,
            can_invite_users: a["can_invite_users"] || false,
            can_pin_messages: a["can_pin_messages"] || false
          }
        end)
        {:ok, %{admins: parsed, count: length(parsed)}}

      {:ok, admins} when is_list(admins) ->
        {:ok, %{admins: admins, count: length(admins)}}

      error -> error
    end
  end
end
