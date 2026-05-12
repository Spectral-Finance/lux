defmodule Lux.Lenses.Discord.Guild.AuditLogs do
  @moduledoc """
  A lens for reading Discord guild audit log entries.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Read Discord Guild Audit Logs",
    description: "Reads audit log entries for Discord guild activity monitoring",
    url: "https://discord.com/api/v10/guilds/:guild_id/audit-logs",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{
          type: :string,
          description: "Filter entries by user ID",
          pattern: "^[0-9]{17,20}$"
        },
        action_type: %{type: :integer, description: "Discord audit log event type"},
        before: %{type: :string, description: "Return entries before this audit entry ID"},
        limit: %{type: :integer, description: "Max entries to return", minimum: 1, maximum: 100}
      },
      required: ["guild_id"]
    }

  @impl true
  def after_focus(%{"audit_log_entries" => entries} = response) do
    {:ok,
     %{
       entries: Enum.map(entries, &format_entry/1),
       users: Enum.map(Map.get(response, "users", []), &format_user/1)
     }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  defp format_entry(entry) do
    %{
      id: entry["id"],
      action_type: entry["action_type"],
      user_id: entry["user_id"],
      target_id: entry["target_id"],
      reason: entry["reason"],
      changes: Map.get(entry, "changes", [])
    }
  end

  defp format_user(user) do
    %{
      id: user["id"],
      username: user["username"],
      discriminator: user["discriminator"]
    }
  end
end
