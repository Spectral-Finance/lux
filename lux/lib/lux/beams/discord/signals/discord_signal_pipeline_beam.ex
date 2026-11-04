defmodule Lux.Beams.Discord.Signals.DiscordSignalPipelineBeam do
  @moduledoc """
  A Beam pipeline coordinating the lifecycle of Discord events:
  1. Ingests and parses raw gateway events into typed Lux Signals (`ParseSignalPrism`).
  2. Validates signal payloads against schema rules (`ValidateSignalPrism`).
  3. Dispatches signals to registered agent handlers (`RouteSignalPrism`).
  4. Formats outgoing response payloads for Discord API delivery (`EmitSignalPrism`).

  ## Example Usage

  ```elixir
  {:ok, result} = Lux.Beams.Discord.Signals.DiscordSignalPipelineBeam.run(%{
    event_type: "MESSAGE_CREATE",
    payload: %{
      "content" => "Hello Lux Agent!",
      "channel_id" => "123456789012345678",
      "author" => %{"id" => "999", "username" => "alice"}
    }
  })
  ```
  """

  use Lux.Beam,
    name: "Discord Signal Pipeline Beam",
    description: "Orchestrates parsing, validation, routing, and emission of Discord signals",
    input_schema: %{
      type: :object,
      properties: %{
        event_type: %{type: :string, description: "Discord Gateway event type"},
        payload: %{type: :object, description: "Raw event JSON payload"}
      },
      required: ["event_type", "payload"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        signal_id: %{type: :string},
        success: %{type: :boolean}
      },
      required: ["success"]
    }

  alias Lux.Prisms.Discord.Signals.EmitSignalPrism
  alias Lux.Prisms.Discord.Signals.ParseSignalPrism
  alias Lux.Prisms.Discord.Signals.RouteSignalPrism
  alias Lux.Prisms.Discord.Signals.ValidateSignalPrism

  sequence do
    step(:parse_event, ParseSignalPrism, %{
      event_type: [:input, :event_type],
      payload: [:input, :payload]
    })

    step(:validate_signal, ValidateSignalPrism, %{
      schema_type: "message",
      payload: [:steps, :parse_event, :result, :payload]
    })

    step(:route_signal, RouteSignalPrism, %{
      signal_id: [:steps, :parse_event, :result, :signal_id],
      signal_schema: [:steps, :parse_event, :result, :signal_schema]
    })

    step(:emit_response, EmitSignalPrism, %{
      signal_type: "message",
      payload: [:steps, :parse_event, :result, :payload]
    })
  end
end
