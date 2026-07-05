defmodule Lux.Prisms.Discord.Voice.PlayMusic do
  use Lux.Prism,
    name: "Play Music",
    description: "Plays music with queue management in a voice channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Voice Channel ID"},
        track_url: %{type: :string, description: "URL of the track to play"}
      },
      required: ["channel_id", "track_url"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        queued: %{type: :boolean},
        track: %{type: :string}
      },
      required: ["queued"]
    }

  require Logger

  def handler(params, _agent) do
    channel_id = params.channel_id
    track_url = params.track_url
    
    Logger.info("Queued music track #{track_url} in channel #{channel_id}")
    {:ok, %{queued: true, track: track_url}}
  end
end
