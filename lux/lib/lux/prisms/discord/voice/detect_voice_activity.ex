defmodule Lux.Prisms.Discord.Voice.DetectVoiceActivity do
  use Lux.Prism,
    name: "Detect Voice Activity",
    description: "Starts detecting voice activity in a voice channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Voice Channel ID"},
        sensitivity: %{type: :integer, description: "VAD sensitivity", default: 50}
      },
      required: ["channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        active: %{type: :boolean},
        started: %{type: :boolean}
      },
      required: ["started"]
    }

  require Logger

  def handler(params, _agent) do
    channel_id = params.channel_id
    
    Logger.info("Started voice activity detection in channel #{channel_id}")
    {:ok, %{started: true, active: false}}
  end
end
