defmodule Lux.Prisms.Telegram.Analytics.AggregateMetrics do
  @moduledoc """
  A prism for aggregating message volume, user engagement, and command statistics across events.
  """

  use Lux.Prism,
    name: "Aggregate Telegram Metrics",
    description: "Computes total volume, active users, and command distributions over telemetry events",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{type: :array, description: "List of collected telemetry events"}
      },
      required: ["events"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        messages: %{type: :object},
        engagement: %{type: :object},
        commands: %{type: :object}
      },
      required: ["messages", "engagement", "commands"]
    }

  alias Lux.Integrations.Telegram.Analytics.MessageTracker
  alias Lux.Integrations.Telegram.Analytics.EngagementTracker
  alias Lux.Integrations.Telegram.Analytics.CommandStats

  def handler(params, _agent) when is_map(params) do
    events = Map.get(params, :events) || Map.get(params, "events", [])

    messages = MessageTracker.analyze(events)
    engagement = EngagementTracker.analyze(events)
    commands = CommandStats.analyze(events)

    {:ok,
     %{
       messages: messages,
       engagement: engagement,
       commands: commands
     }}
  end

  def handler(_, _), do: {:error, "Invalid input: expected events list"}
end
