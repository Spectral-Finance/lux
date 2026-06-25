defmodule Lux.Prisms.Discord.Analytics.GetAuditLog do
  @moduledoc """
  A prism for fetching Discord guild audit logs.

  Retrieves audit log entries for a guild, with optional filtering
  by user, action type, and pagination.

  ## Examples

      iex> GetAuditLog.handler(%{guild_id: "123456789"}, %{name: "Agent"})
      {:ok, %{entries: [...], users: [...], integrations: [...]}}

  """

  use Lux.Prism,
    name: "Get Discord Audit Log",
    description: "Fetches audit log entries for a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The guild ID", pattern: "^[0-9]{17,20}$"},
        user_id: %{type: :string, description: "Filter by user ID"},
        action_type: %{type: :integer, description: "Filter by action type"},
        before: %{type: :string, description: "Entry ID to fetch before"},
        limit: %{type: :integer, description: "Max entries (1-100)", minimum: 1, maximum: 100}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        entries: %{type: :array, description: "Audit log entries"},
        users: %{type: :array, description: "Users referenced in entries"},
        integrations: %{type: :array, description: "Integrations referenced"}
      },
      required: ["entries"]
    }

  alias Lux.Integrations.Discord.Analytics
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching audit log for guild #{guild_id}")

      opts = Map.drop(params, [:guild_id])

      case Analytics.get_audit_log(guild_id, opts) do
        {:ok, result} ->
          entries = Map.get(result, "audit_log_entries", [])
          users = Map.get(result, "users", [])
          integrations = Map.get(result, "integrations", [])
          Logger.info("Fetched #{length(entries)} audit log entries for guild #{guild_id}")
          {:ok, %{entries: entries, users: users, integrations: integrations}}

        {:error, error} ->
          Logger.error("Failed to fetch audit log for guild #{guild_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
