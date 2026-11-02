defmodule Lux.Lenses.Discord.Channels.ModifyChannel do
  @moduledoc """
  A lens for modifying an existing Discord channel's configuration.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Modify Discord Channel",
    description: "Modifies the settings and properties of a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id",
    method: :patch,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Target Discord channel Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        name: %{
          type: :string,
          description: "Channel name (1-100 characters)"
        },
        topic: %{
          type: :string,
          description: "Channel topic (0-1024 characters)"
        },
        rate_limit_per_user: %{
          type: :integer,
          description: "Slowmode delay in seconds (0-21600)"
        },
        archived: %{
          type: :boolean,
          description: "Whether a thread is archived"
        }
      },
      required: ["channel_id"]
    }

  @impl true
  def before_focus(params) do
    payload = %{}

    payload =
      if Map.get(params, :name), do: Map.put(payload, "name", params.name), else: payload

    payload =
      if Map.get(params, :topic), do: Map.put(payload, "topic", params.topic), else: payload

    payload =
      if Map.get(params, :rate_limit_per_user),
        do: Map.put(payload, "rate_limit_per_user", params.rate_limit_per_user),
        else: payload

    payload =
      if Map.get(params, :archived) != nil,
        do: Map.put(payload, "archived", params.archived),
        else: payload

    {:ok, payload}
  end

  @impl true
  def after_focus(response) when is_map(response) do
    {:ok,
     %{
       id: response["id"],
       name: response["name"],
       topic: response["topic"],
       rate_limit_per_user: response["rate_limit_per_user"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
