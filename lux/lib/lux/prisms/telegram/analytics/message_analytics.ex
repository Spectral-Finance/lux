defmodule Lux.Prisms.Telegram.Analytics.MessageAnalytics do
  @moduledoc """
  A prism for aggregating message statistics from Telegram bot analytics.

  Provides insights into message volume, distribution by type, hourly rates,
  and peak activity hours. Supports optional filtering by time range and chat ID.

  ## Examples

      # Get all message stats
      iex> MessageAnalytics.handler(%{}, %{name: "Agent"})
      {:ok, %{total_messages: 150, messages_by_type: %{text: 100, photo: 30, video: 20}, ...}}

      # Filter by time range
      iex> MessageAnalytics.handler(%{
      ...>   time_range: %{start: "2024-01-01T00:00:00Z", end: "2024-01-02T00:00:00Z"}
      ...> }, %{name: "Agent"})
      {:ok, %{total_messages: 42, ...}}
  """

  use Lux.Prism,
    name: "Telegram Message Analytics",
    description: "Aggregates message statistics from Telegram bot analytics data",
    input_schema: %{
      type: :object,
      properties: %{
        time_range: %{
          type: :object,
          description: "Optional time range filter",
          properties: %{
            start: %{type: :string, description: "ISO 8601 start timestamp"},
            end: %{type: :string, description: "ISO 8601 end timestamp"}
          }
        },
        chat_id: %{
          type: :integer,
          description: "Optional chat ID to filter messages"
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        total_messages: %{type: :integer, description: "Total number of messages"},
        messages_by_type: %{type: :object, description: "Message counts grouped by type"},
        messages_per_hour: %{type: :number, description: "Average messages per hour"},
        peak_hours: %{type: :array, description: "Hours with highest message activity"}
      },
      required: ["total_messages", "messages_by_type", "messages_per_hour", "peak_hours"]
    }

  alias Lux.Integrations.Telegram.Analytics.{Aggregator, Collector}
  require Logger

  @doc """
  Computes message analytics from collected data.

  Retrieves raw message data from the Collector, applies optional filters,
  and returns aggregated statistics.
  """
  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} requesting message analytics")

    try do
      stats = Collector.get_stats()
      messages = filter_messages(stats.messages, params)

      result = %{
        total_messages: length(messages),
        messages_by_type: Aggregator.group_by_key(messages, :type),
        messages_per_hour: Aggregator.calculate_rate(messages, :per_hour),
        peak_hours: messages |> Aggregator.peak_hours() |> Enum.take(5) |> format_peak_hours()
      }

      {:ok, result}
    rescue
      e ->
        Logger.error("Message analytics failed: #{inspect(e)}")
        {:error, "Failed to compute message analytics: #{Exception.message(e)}"}
    end
  end

  defp filter_messages(messages, params) do
    messages
    |> maybe_filter_time_range(params[:time_range])
    |> maybe_filter_chat_id(params[:chat_id])
  end

  defp maybe_filter_time_range(messages, nil), do: messages

  defp maybe_filter_time_range(messages, %{start: start_str, end: end_str}) do
    {:ok, start_dt, _} = DateTime.from_iso8601(start_str)
    {:ok, end_dt, _} = DateTime.from_iso8601(end_str)

    Enum.filter(messages, fn msg ->
      DateTime.compare(msg.timestamp, start_dt) in [:gt, :eq] and
        DateTime.compare(msg.timestamp, end_dt) in [:lt, :eq]
    end)
  end

  defp maybe_filter_time_range(messages, _), do: messages

  defp maybe_filter_chat_id(messages, nil), do: messages

  defp maybe_filter_chat_id(messages, chat_id) do
    Enum.filter(messages, fn msg -> msg.chat_id == chat_id end)
  end

  defp format_peak_hours(peak_hours) do
    Enum.map(peak_hours, fn {hour, count} ->
      %{hour: hour, message_count: count}
    end)
  end
end
