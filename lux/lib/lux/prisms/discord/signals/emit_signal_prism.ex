defmodule Lux.Prisms.Discord.Signals.EmitSignalPrism do
  @moduledoc """
  A prism that serializes outgoing Discord Signals into valid Discord API payloads.
  """

  use Lux.Prism,
    name: "Discord Emit Signal Prism",
    description: "Converts Lux Signals into outgoing Discord REST or Gateway messages",
    input_schema: %{
      type: :object,
      properties: %{
        signal_type: %{
          type: :string,
          enum: ["message", "interaction", "presence", "voice"]
        },
        payload: %{type: :object}
      },
      required: ["signal_type", "payload"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        discord_payload: %{type: :object},
        signal_type: %{type: :string},
        success: %{type: :boolean}
      },
      required: ["discord_payload", "signal_type", "success"]
    }

  @impl true
  def handler(inputs, _context) do
    type = Map.get(inputs, "signal_type") || Map.get(inputs, :signal_type, "message")
    payload = Map.get(inputs, "payload") || Map.get(inputs, :payload, %{})

    discord_payload =
      case type do
        "message" ->
          %{
            content: Map.get(payload, "content") || Map.get(payload, :content, ""),
            embeds: Map.get(payload, "embeds") || Map.get(payload, :embeds, [])
          }

        "interaction" ->
          %{
            type: 4,
            data: %{content: "Acknowledged interaction"}
          }

        "presence" ->
          %{
            status: Map.get(payload, "status") || Map.get(payload, :status, "online"),
            activities: Map.get(payload, "activities") || Map.get(payload, :activities, [])
          }

        _other ->
          payload
      end

    {:ok, %{discord_payload: discord_payload, signal_type: type, success: true}}
  end
end
