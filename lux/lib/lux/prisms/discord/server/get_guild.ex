defmodule Lux.Prisms.Discord.Server.GetGuild do
  @moduledoc """
  A prism for fetching details of a Discord guild (server).
  """

  use Lux.Prism,
    name: "Get Discord Guild",
    description: "Fetches information and settings for a specific Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Target guild snowflake ID"},
        with_counts: %{type: :boolean, description: "Include approximate member and presence counts"}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string},
        name: %{type: :string},
        owner_id: %{type: :string},
        description: %{type: :string},
        approximate_member_count: %{type: :integer},
        approximate_presence_count: %{type: :integer}
      },
      required: ["guild_id", "name"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} fetching Discord guild #{guild_id}")

      with_counts = Map.get(params, :with_counts, true)
      path = "/guilds/#{guild_id}?with_counts=#{with_counts}"
      opts = %{}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:get, path, opts) do
        {:ok, guild} when is_map(guild) ->
          {:ok, %{
            guild_id: guild["id"] || guild_id,
            name: guild["name"] || "",
            owner_id: guild["owner_id"] || "",
            description: guild["description"],
            approximate_member_count: guild["approximate_member_count"],
            approximate_presence_count: guild["approximate_presence_count"]
          } |> Enum.reject(fn {_, v} -> is_nil(v) end) |> Map.new()}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
