defmodule Lux.Prisms.Telegram.GroupManagement.RestrictMember do
  @moduledoc """
  A prism for restricting a chat member's permissions or muting them in a Telegram supergroup.
  """

  use Lux.Prism,
    name: "Restrict Telegram Chat Member",
    description: "Restricts member permissions (e.g. read_only, media_restricted, or custom permissions) with optional duration",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat identifier"},
        user_id: %{type: :integer, description: "Target user identifier"},
        preset: %{type: :string, description: "Preset name: 'read_only', 'text_only', 'media_restricted'"},
        permissions: %{type: :object, description: "Custom ChatPermissions object"},
        until_date: %{type: :integer, description: "Unix timestamp when restriction expires"}
      },
      required: ["chat_id", "user_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        chat_id: %{type: [:string, :integer]},
        user_id: %{type: :integer},
        permissions: %{type: :object}
      },
      required: ["status", "chat_id", "user_id"]
    }

  alias Lux.Integrations.Telegram.GroupManagement.MemberManager
  alias Lux.Integrations.Telegram.GroupManagement.PermissionManager

  def handler(params, _agent) when is_map(params) do
    chat_id = Map.get(params, :chat_id) || Map.get(params, "chat_id")
    user_id = Map.get(params, :user_id) || Map.get(params, "user_id")
    preset_name = Map.get(params, :preset) || Map.get(params, "preset")
    custom_perms = Map.get(params, :permissions) || Map.get(params, "permissions")
    until_date = Map.get(params, :until_date) || Map.get(params, "until_date")
    plug = Map.get(params, :plug)

    permissions =
      cond do
        custom_perms && is_map(custom_perms) ->
          custom_perms

        preset_name ->
          case PermissionManager.get_preset(String.to_atom(to_string(preset_name))) do
            {:ok, p} -> p
            _ -> %{can_send_messages: false}
          end

        true ->
          %{can_send_messages: false}
      end

    opts = []
    opts = if until_date, do: [{:until_date, until_date} | opts], else: opts
    opts = if plug, do: [{:plug, plug} | opts], else: opts

    case MemberManager.restrict_member(chat_id, user_id, permissions, opts) do
      {:ok, _result} ->
        {:ok,
         %{
           status: "restricted",
           chat_id: chat_id,
           user_id: user_id,
           permissions: permissions
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters"}
end
