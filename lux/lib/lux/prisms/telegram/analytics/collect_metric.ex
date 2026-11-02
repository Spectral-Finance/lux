defmodule Lux.Prisms.Telegram.Analytics.CollectMetric do
  @moduledoc """
  A prism for capturing and buffering Telegram interaction events and telemetry metrics.
  """

  use Lux.Prism,
    name: "Collect Telegram Metric",
    description: "Captures interaction telemetry (message, command, callback, API latency, error) into structured event format",
    input_schema: %{
      type: :object,
      properties: %{
        type: %{type: :string, description: "'message', 'command', 'callback', 'error', 'api_call'"},
        chat_id: %{type: [:integer, :string]},
        user_id: %{type: [:integer, :string]},
        command: %{type: :string},
        latency_ms: %{type: :integer},
        status: %{type: :string, description: "'success' or 'error'"},
        error_code: %{type: :integer},
        error_message: %{type: :string}
      },
      required: ["type"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        status: %{type: :string},
        type: %{type: :string}
      },
      required: ["id", "status", "type"]
    }

  alias Lux.Integrations.Telegram.Analytics.Collector

  def handler(params, _agent) when is_map(params) do
    type_atom = String.to_atom(to_string(Map.get(params, :type) || Map.get(params, "type", "message")))
    state = Collector.init()

    with {:ok, _state, event} <- Collector.record_event(state, type_atom, params) do
      {:ok,
       %{
         id: event.id,
         status: to_string(event.status),
         type: to_string(event.type)
       }}
    end
  end

  def handler(_, _), do: {:error, "Invalid parameters: expected event type"}
end
