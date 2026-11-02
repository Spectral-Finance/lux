defmodule Lux.Prisms.Telegram.GroupManagement.ManageInviteLink do
  @moduledoc """
  A prism for creating, exporting, editing, and revoking chat invite links.
  """

  use Lux.Prism,
    name: "Manage Telegram Invite Link",
    description: "Creates, updates, or revokes Telegram chat invite links with membership limits and expiry dates",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, description: "'create', 'export', 'edit', or 'revoke'"},
        chat_id: %{type: [:string, :integer], description: "Target chat identifier"},
        invite_link: %{type: :string, description: "Invite link string for 'edit' or 'revoke'"},
        name: %{type: :string, description: "Name of the invite link"},
        expire_date: %{type: :integer, description: "Unix expiry timestamp"},
        member_limit: %{type: :integer, description: "Maximum members allowed"},
        creates_join_request: %{type: :boolean, description: "Requires administrator approval"}
      },
      required: ["action", "chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        chat_id: %{type: [:string, :integer]},
        invite_link: %{type: :string}
      },
      required: ["status"]
    }

  alias Lux.Integrations.Telegram.GroupManagement.SettingsManager

  def handler(params, _agent) when is_map(params) do
    action = to_string(Map.get(params, :action) || Map.get(params, "action", "create"))
    chat_id = Map.get(params, :chat_id) || Map.get(params, "chat_id")
    invite_link = Map.get(params, :invite_link) || Map.get(params, "invite_link")
    name = Map.get(params, :name) || Map.get(params, "name")
    expire_date = Map.get(params, :expire_date) || Map.get(params, "expire_date")
    member_limit = Map.get(params, :member_limit) || Map.get(params, "member_limit")
    join_req = Map.get(params, :creates_join_request) || Map.get(params, "creates_join_request")
    plug = Map.get(params, :plug)

    opts = []
    opts = if name, do: [{:name, name} | opts], else: opts
    opts = if expire_date, do: [{:expire_date, expire_date} | opts], else: opts
    opts = if member_limit, do: [{:member_limit, member_limit} | opts], else: opts
    opts = if join_req != nil, do: [{:creates_join_request, join_req} | opts], else: opts
    opts = if plug, do: [{:plug, plug} | opts], else: opts

    case action do
      "export" ->
        with {:ok, res} <- SettingsManager.export_invite_link(chat_id, opts) do
          {:ok, %{status: "exported", chat_id: chat_id, invite_link: res["result"]}}
        end

      "create" ->
        with {:ok, res} <- SettingsManager.create_invite_link(chat_id, opts) do
          link = get_in(res, ["result", "invite_link"])
          {:ok, %{status: "created", chat_id: chat_id, invite_link: link}}
        end

      "edit" when is_binary(invite_link) ->
        with {:ok, res} <- SettingsManager.edit_invite_link(chat_id, invite_link, opts) do
          link = get_in(res, ["result", "invite_link"])
          {:ok, %{status: "edited", chat_id: chat_id, invite_link: link}}
        end

      "revoke" when is_binary(invite_link) ->
        with {:ok, res} <- SettingsManager.revoke_invite_link(chat_id, invite_link, opts) do
          link = get_in(res, ["result", "invite_link"])
          {:ok, %{status: "revoked", chat_id: chat_id, invite_link: link}}
        end

      other ->
        {:error, "Unsupported invite link action: #{other}"}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters"}
end
