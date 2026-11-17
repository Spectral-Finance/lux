defmodule Lux.Lenses.Discord.Moderation.GetAuditLog do
  @moduledoc """
  A lens for fetching the audit log of a Discord guild.

  Supports filtering by action type, user, and pagination.

  ## Examples
      iex> GetAuditLog.focus(%{guild_id: "123456789", action_type: 22})
      {:ok, %{
        entries: [
          %{id: "111", action_type: 22, user_id: "222", target_id: "333", reason: "Spam"}
        ]
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Audit Log",
    description: "Fetches the audit log for a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/audit-logs",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        action_type: %{
          type: :integer,
          description: "Filter by audit log action type"
        },
        user_id: %{
          type: :string,
          description: "Filter by the user who performed the action",
          pattern: "^[0-9]{17,20}$"
        },
        limit: %{
          type: :integer,
          description: "Number of entries to return (1-100)",
          minimum: 1,
          maximum: 100,
          default: 50
        },
        before: %{
          type: :string,
          description: "Get entries before this audit log entry ID",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format.
  """
  @impl true
  def after_focus(%{"audit_log_entries" => entries}) do
    {:ok, %{
      entries: Enum.map(entries, fn entry ->
        %{
          id: entry["id"],
          action_type: entry["action_type"],
          user_id: entry["user_id"],
          target_id: entry["target_id"],
          reason: entry["reason"]
        }
      end)
    }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
