defmodule Lux.Prisms.Discord.Server.ListMembers do
  @moduledoc """
  A prism for listing members in a Discord guild.
  """

  use Lux.Prism,
    name: "List Discord Guild Members",
    description: "Returns a list of guild member objects with optional pagination",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Target guild snowflake ID"},
        limit: %{type: :integer, description: "Max members to return (1-1000, default 50)"},
        after: %{type: :string, description: "Highest user ID from previous page"}
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string},
        members: %{type: :array, items: %{type: :object}},
        count: %{type: :integer}
      },
      required: ["guild_id", "members", "count"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} listing members for Discord guild #{guild_id}")

      query_params =
        params
        |> Map.take([:limit, :after])
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> URI.encode_query()

      path =
        if query_params != "" do
          "/guilds/#{guild_id}/members?#{query_params}"
        else
          "/guilds/#{guild_id}/members"
        end

      opts = %{}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:get, path, opts) do
        {:ok, members} when is_list(members) ->
          {:ok, %{
            guild_id: guild_id,
            members: members,
            count: length(members)
          }}

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
