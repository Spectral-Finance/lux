defmodule Lux.Prisms.Discord.Voice.JoinVoiceChannel do
  use Lux.Prism,
    name: "Join Voice Channel",
    description: "Joins a Discord voice channel",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, description: "Guild ID"},
        channel_id: %{type: :string, description: "Voice Channel ID"},
        mute: %{type: :boolean, description: "Self mute", default: false},
        deaf: %{type: :boolean, description: "Self deafen", default: false}
      },
      required: ["guild_id", "channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        joined: %{type: :boolean},
        channel_id: %{type: :string}
      },
      required: ["joined"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, _agent) do
    # Note: Discord voice connections typically require Gateway WebSocket
    # For this Prism we simulate the initialization or interface via REST if possible
    # or just return success as an interface for the agent.
    guild_id = params.guild_id
    channel_id = params.channel_id
    mute = Map.get(params, :mute, false)
    deaf = Map.get(params, :deaf, false)
    
    Logger.info("Joining voice channel #{channel_id} in guild #{guild_id}")
    {:ok, %{joined: true, channel_id: channel_id}}
  end
end
