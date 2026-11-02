defmodule Lux.Lenses.Discord.Channels.CreateChannel do
  @moduledoc """
  A lens for creating a new channel in a Discord guild.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Create Discord Channel",
    description: "Creates a new channel in a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id/channels",
    method: :post,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "Target Discord guild Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "Channel name (1-100 characters)",
          minLength: 1,
          maxLength: 100
        },
        type: %{
          type: :integer,
          description: "Channel type (0: text, 2: voice, 4: category, 5: announcement, 15: forum)"
        },
        topic: %{
          type: :string,
          description: "Channel topic (0-1024 characters)"
        },
        rate_limit_per_user: %{
          type: :integer,
          description: "Amount of seconds a user has to wait before sending another message (0-21600)"
        }
      },
      required: ["guild_id", "name"]
    }

  @impl true
  def before_focus(params) do
    payload = %{"name" => params.name}

    payload =
      if Map.get(params, :type) do
        Map.put(payload, "type", params.type)
      else
        payload
      end

    payload =
      if Map.get(params, :topic) do
        Map.put(payload, "topic", params.topic)
      else
        payload
      end

    payload =
      if Map.get(params, :rate_limit_per_user) do
        Map.put(payload, "rate_limit_per_user", params.rate_limit_per_user)
      else
        payload
      end

    {:ok, payload}
  end

  @impl true
  def after_focus(response) when is_map(response) do
    {:ok,
     %{
       id: response["id"],
       guild_id: response["guild_id"],
       name: response["name"],
       type: response["type"],
       topic: response["topic"],
       rate_limit_per_user: response["rate_limit_per_user"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
