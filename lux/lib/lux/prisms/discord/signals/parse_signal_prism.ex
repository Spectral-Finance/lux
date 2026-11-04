defmodule Lux.Prisms.Discord.Signals.ParseSignalPrism do
  @moduledoc """
  A prism that parses raw Discord Gateway dispatch payloads into strongly-typed Lux Signals.
  """

  use Lux.Prism,
    name: "Discord Parse Signal Prism",
    description: "Ingests raw Discord event data and parses it into a typed Lux Signal",
    input_schema: %{
      type: :object,
      properties: %{
        event_type: %{
          type: :string,
          enum: ["MESSAGE_CREATE", "INTERACTION_CREATE", "PRESENCE_UPDATE", "VOICE_STATE_UPDATE"]
        },
        payload: %{type: :object}
      },
      required: ["event_type", "payload"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        signal_id: %{type: :string},
        signal_schema: %{type: :string},
        payload: %{type: :object},
        success: %{type: :boolean}
      },
      required: ["signal_id", "signal_schema", "success"]
    }

  alias Lux.Signals.Discord.Pipeline

  @impl true
  def handler(inputs, _context) do
    ev_type = Map.get(inputs, "event_type") || Map.get(inputs, :event_type)
    raw_payload = Map.get(inputs, "payload") || Map.get(inputs, :payload, %{})

    case Pipeline.process_event(ev_type, raw_payload) do
      {:ok, signal} ->
        {:ok,
         %{
           signal_id: signal.id,
           signal_schema: inspect(signal.schema_id),
           payload: signal.payload,
           success: true
         }}

      {:error, reason} ->
        {:error, "Failed to parse signal: #{inspect(reason)}"}
    end
  end
end
