defmodule Lux.Prisms.Telegram.GroupManagement.PromoteMember do
  @moduledoc """
  A prism for promoting a member to administrator or modifying administrator privileges.
  """

  use Lux.Prism,
    name: "Promote Telegram Chat Member",
    description: "Promotes or demotes an administrator in a supergroup or channel with granular admin rights",
    input_schema: %{
      type: :object,
      properties: %{
        chat_id: %{type: [:string, :integer], description: "Target chat identifier"},
        user_id: %{type: :integer, description: "Target user identifier"},
        privileges: %{type: :object, description: "Admin privileges map (e.g. can_delete_messages, can_restrict_members)"},
        custom_title: %{type: :string, description: "Optional custom title for the administrator"}
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
    privileges = Map.get(params, :privileges) || Map.get(params, "privileges") || default_admin_privileges()
    custom_title = Map.get(params, :custom_title) || Map.get(params, "custom_title")
    plug = Map.get(params, :plug)

    opts = if plug, do: [plug: plug], else: []

    with {:ok, _} <- MemberManager.promote_member(chat_id, user_id, privileges, opts),
         :ok <- maybe_set_title(chat_id, user_id, custom_title, opts) do
      {:ok, %{status: "promoted", chat_id: chat_id, user_id: user_id}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters"}

  defp maybe_set_title(_chat_id, _user_id, nil, _opts), do: :ok
  defp maybe_set_title(_chat_id, _user_id, "", _opts), do: :ok

  defp maybe_set_title(chat_id, user_id, title, opts) do
    case MemberManager.set_admin_title(chat_id, user_id, title, opts) do
      {:ok, _} -> :ok
      err -> err
    end
  end

  defp default_admin_privileges do
    %{
      can_manage_chat: true,
      can_delete_messages: true,
      can_restrict_members: true,
      can_pin_messages: true
    }
  end
end
