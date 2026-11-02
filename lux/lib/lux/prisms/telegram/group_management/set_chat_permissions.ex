defmodule Lux.Prisms.Telegram.GroupManagement.SetChatPermissions do
  @moduledoc """
  A prism for updating default chat permissions across all members of a supergroup.
  """

  use Lux.Prism,
    name: "Set Telegram Chat Default Permissions",
    description: "Sets default member permissions for a Telegram supergroup or community",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat identifier"},
        preset: %{type: :string, description: "Preset name: 'read_only', 'text_only', 'standard', 'media_restricted'"},
        permissions: %{type: :object, description: "Custom ChatPermissions object"}
      },
      required: ["chat_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        chat_id: %{type: [:string, :integer]},
        permissions: %{type: :object}
      },
      required: ["status", "chat_id", "permissions"]
    }

  alias Lux.Integrations.Telegram.GroupManagement.PermissionManager

  def handler(params, _agent) when is_map(params) do
    chat_id = Map.get(params, :chat_id) || Map.get(params, "chat_id")
    preset_name = Map.get(params, :preset) || Map.get(params, "preset")
    custom_perms = Map.get(params, :permissions) || Map.get(params, "permissions")
    plug = Map.get(params, :plug)

    permissions =
      cond do
        custom_perms && is_map(custom_perms) ->
          custom_perms

        preset_name ->
          case PermissionManager.get_preset(String.to_atom(to_string(preset_name))) do
            {:ok, p} -> p
            _ -> %{can_send_messages: true}
          end

        true ->
          %{can_send_messages: true}
      end

    opts = if plug, do: [plug: plug], else: []

    case PermissionManager.set_chat_permissions(chat_id, permissions, opts) do
      {:ok, _result} ->
        {:ok,
         %{
           status: "updated",
           chat_id: chat_id,
           permissions: permissions
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters"}
end
