defmodule Lux.Prisms.Discord.Analytics.AnalyzeActivity do
  @moduledoc """
  A prism for computing Discord server activity analytics.

  Processes a list of events and returns activity metrics including
  peak hours, most active users, and channel distribution.

  ## Examples

      iex> AnalyzeActivity.handler(%{events: [%{type: :message, user_id: "u1", channel_id: "c1", timestamp: ~U[2026-01-01 12:00:00Z], metadata: %{}}]}, %{name: "Agent"})
      {:ok, %{total_events: 1, by_type: %{message: 1}, peak_hour: 12, ...}}

  """

  use Lux.Prism,
    name: "Analyze Discord Activity",
    description: "Computes activity metrics from Discord event data",
    input_schema: %{
      type: :object,
      properties: %{
        events: %{
          type: :array,
          description: "List of event maps with type, user_id, channel_id, timestamp",
          items: %{type: :object}
        }
      },
      required: ["events"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_events: %{type: :integer},
        by_type: %{type: :object},
        by_hour: %{type: :object},
        by_user: %{type: :object},
        by_channel: %{type: :object},
        peak_hour: %{type: [:integer, :null]},
        most_active_user: %{type: [:string, :null]},
        most_active_channel: %{type: [:string, :null]}
      }
    }

  alias Lux.Integrations.Discord.Analytics
  require Logger

  def handler(params, agent) do
    case Map.get(params, :events) do
      nil ->
        {:error, "Missing events parameter"}

      events when is_list(events) ->
        agent_name = agent[:name] || "Unknown Agent"
        Logger.info("Agent #{agent_name} analyzing #{length(events)} Discord events")

        parsed_events = Enum.map(events, &parse_event/1)
        result = Analytics.analyze_activity(parsed_events)
        Logger.info("Activity analysis complete: #{result.total_events} events, peak hour: #{result.peak_hour}")
        {:ok, result}

      _ ->
        {:error, "Events must be a list"}
    end
  end

  defp parse_event(event) when is_map(event) do
    %{
      type: Map.get(event, :type) || Map.get(event, "type", :unknown),
      user_id: Map.get(event, :user_id) || Map.get(event, "user_id", ""),
      channel_id: Map.get(event, :channel_id) || Map.get(event, "channel_id"),
      timestamp: parse_timestamp(Map.get(event, :timestamp) || Map.get(event, "timestamp")),
      metadata: Map.get(event, :metadata) || Map.get(event, "metadata", %{})
    }
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt
  defp parse_timestamp(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")
  defp parse_timestamp(_), do: nil
end
