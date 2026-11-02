defmodule Lux.Prisms.Discord.Server.AddRoleToMember do
  @moduledoc """
  A prism for assigning a role to a member in a Discord guild.
  """

  use Lux.Prism,
    name: "Add Role to Discord Member",
    description: "Assigns a role to a member in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Target guild snowflake ID"},
        user_id: %{type: :string, description: "Target member user snowflake ID"},
        role_id: %{type: :string, description: "Target role snowflake ID"}
      },
      required: ["guild_id", "user_id", "role_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        assigned: %{type: :boolean},
        guild_id: %{type: :string},
        user_id: %{type: :string},
        role_id: %{type: :string}
      },
      required: ["assigned", "guild_id", "user_id", "role_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, user_id} <- validate_param(params, :user_id),
         {:ok, role_id} <- validate_param(params, :role_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} assigning role #{role_id} to user #{user_id} in guild #{guild_id}")

      opts = %{}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:put, "/guilds/#{guild_id}/members/#{user_id}/roles/#{role_id}", opts) do
        {:ok, _} ->
          {:ok, %{
            assigned: true,
            guild_id: guild_id,
            user_id: user_id,
            role_id: role_id
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
