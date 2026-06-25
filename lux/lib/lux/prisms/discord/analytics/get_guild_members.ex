defmodule Lux.Prisms.Discord.Analytics.GetGuildMembers do
  @moduledoc """
  A prism for fetching Discord guild members.

  Retrieves the member list for a guild with pagination support.
  Requires the GUILD_MEMBERS privileged intent.

  ## Examples

      iex> GetGuildMembers.handler(%{guild_id: "123456789", limit: 100}, %{name: "Agent"})
      {:ok, %{members: [...], count: 100}}

  """

  use Lux.Prism,
    name: "Get Discord Guild Members",
    description: "Fetches guild member list with pagination",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The guild ID", pattern: "^[0-9]{17,20}$"},
        limit: %{type: :integer, description: "Max members (1-1000)", minimum: 1, maximum: 1000},
        after: %{type: :string, description: "Member ID for pagination"}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        members: %{type: :array, description: "Guild members"},
        count: %{type: :integer, description: "Number of members returned"}
      },
      required: ["members"]
    }

  alias Lux.Integrations.Discord.Analytics
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching members for guild #{guild_id}")

      opts = Map.drop(params, [:guild_id])

      case Analytics.get_guild_members(guild_id, opts) do
        {:ok, members} ->
          Logger.info("Fetched #{length(members)} members for guild #{guild_id}")
          {:ok, %{members: members, count: length(members)}}

        {:error, error} ->
          Logger.error("Failed to fetch members for guild #{guild_id}: #{inspect(error)}")
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
