defmodule Lux.Prisms.Discord.Channels.CreateChannel do
  @moduledoc """
  A prism for creating a channel in a Discord guild.
  """

  use Lux.Prism,
    name: "Create Discord Channel",
    description: "Creates a new channel in a Discord guild",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Target guild snowflake ID"},
        name: %{type: :string, description: "Channel name"},
        type: %{type: :integer, description: "Channel type (0: text, 2: voice, 4: category, etc.)"},
        topic: %{type: :string, description: "Channel topic"},
        parent_id: %{type: :string, description: "Parent category ID"}
      },
      required: ["guild_id", "name"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        created: %{type: :boolean},
        channel_id: %{type: :string},
        name: %{type: :string},
        type: %{type: :integer},
        guild_id: %{type: :string}
      },
      required: ["created", "channel_id", "name", "guild_id"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, name} <- validate_param(params, :name) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} creating Discord channel '#{name}' in guild #{guild_id}")

      type = Map.get(params, :type, 0)
      body =
        params
        |> Map.take([:name, :type, :topic, :parent_id])
        |> Map.put(:type, type)
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()

      opts = %{json: body}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:post, "/guilds/#{guild_id}/channels", opts) do
        {:ok, %{"id" => channel_id} = response} ->
          {:ok, %{
            created: true,
            channel_id: channel_id,
            name: response["name"] || name,
            type: response["type"] || type,
            guild_id: response["guild_id"] || guild_id
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
