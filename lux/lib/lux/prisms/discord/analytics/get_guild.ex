defmodule Lux.Prisms.Discord.Analytics.GetGuild do
  @moduledoc """
  A prism for fetching Discord guild information.

  Retrieves guild details including member counts and channel information.

  ## Examples

      iex> GetGuild.handler(%{guild_id: "123456789"}, %{name: "Agent"})
      {:ok, %{guild: %{"id" => "123456789", "name" => "My Server", ...}}}

  """

  use Lux.Prism,
    name: "Get Discord Guild Info",
    description: "Fetches guild information including member counts",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "The guild ID", pattern: "^[0-9]{17,20}$"}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        guild: %{type: :object, description: "Guild information"}
      },
      required: ["guild"]
    }

  alias Lux.Integrations.Discord.Analytics
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} fetching guild info for #{guild_id}")

      case Analytics.get_guild(guild_id) do
        {:ok, guild} ->
          Logger.info("Fetched guild info: #{Map.get(guild, "name", "unknown")}")
          {:ok, %{guild: guild}}

        {:error, error} ->
          Logger.error("Failed to fetch guild #{guild_id}: #{inspect(error)}")
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
