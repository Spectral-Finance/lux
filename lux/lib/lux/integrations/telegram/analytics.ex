defmodule Lux.Integrations.Telegram.Analytics do
  @moduledoc """
  Storage-agnostic analytics helpers for Telegram bot workflows.

  The module works with plain event maps so callers can keep events in memory,
  a database, telemetry handlers, or a stream processor. Prisms wrap these
  functions for agent-facing collection, aggregation, and reporting.
  """

  @type event :: %{
          required(:event_type) => String.t(),
          optional(:chat_id) => String.t() | integer(),
          optional(:user_id) => String.t() | integer(),
          optional(:command) => String.t(),
          optional(:duration_ms) => non_neg_integer(),
          optional(:ok) => boolean(),
          optional(:error) => String.t(),
          required(:occurred_at) => DateTime.t(),
          optional(:metadata) => map()
        }

  @spec normalize_event(map()) :: {:ok, event()} | {:error, String.t()}
  def normalize_event(attrs) when is_map(attrs) do
    with {:ok, event_type} <- required_string(attrs, :event_type),
         {:ok, occurred_at} <-
           normalize_datetime(get_value(attrs, :occurred_at, DateTime.utc_now())),
         {:ok, duration_ms} <- normalize_optional_integer(get_value(attrs, :duration_ms)) do
      {:ok,
       %{
         event_type: event_type,
         chat_id: get_value(attrs, :chat_id),
         user_id: get_value(attrs, :user_id),
         command: blank_to_nil(get_value(attrs, :command)),
         duration_ms: duration_ms,
         ok: get_value(attrs, :ok, true),
         error: blank_to_nil(get_value(attrs, :error)),
         occurred_at: occurred_at,
         metadata: get_value(attrs, :metadata, %{})
       }}
    end
  end

  def normalize_event(_), do: {:error, "Analytics event must be a map"}

  @spec record_event([event()], map()) :: {:ok, [event()]} | {:error, String.t()}
  def record_event(events, attrs) when is_list(events) do
    with {:ok, event} <- normalize_event(attrs), do: {:ok, [event | events]}
  end

  def record_event(_, _), do: {:error, "Existing events must be a list"}

  @spec aggregate([event()]) :: map()
  def aggregate(events) when is_list(events) do
    total = length(events)
    errors = Enum.count(events, fn event -> event[:ok] == false or present?(event[:error]) end)
    durations = events |> Enum.map(& &1[:duration_ms]) |> Enum.filter(&is_integer/1)

    %{
      total_events: total,
      message_events: count_by_type(events, "message"),
      command_events: Enum.count(events, &present?(&1[:command])),
      unique_users:
        events |> Enum.map(& &1[:user_id]) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length(),
      unique_chats:
        events |> Enum.map(& &1[:chat_id]) |> Enum.reject(&is_nil/1) |> Enum.uniq() |> length(),
      command_usage: count_by(events, :command),
      event_usage: count_by(events, :event_type),
      errors: errors,
      error_rate: rate(errors, total),
      average_duration_ms: average(durations),
      usage_by_day: count_by_day(events),
      usage_by_hour: count_by_hour(events)
    }
  end

  @spec report([event()], keyword()) :: map()
  def report(events, opts \\ []) when is_list(events) do
    metrics = aggregate(events)
    top_limit = Keyword.get(opts, :top_limit, 5)

    %{
      metrics: metrics,
      top_commands: top(metrics.command_usage, top_limit),
      top_event_types: top(metrics.event_usage, top_limit),
      chart_data: %{
        daily_usage: chart_series(metrics.usage_by_day),
        hourly_usage: chart_series(metrics.usage_by_hour),
        command_usage: chart_series(metrics.command_usage)
      },
      recommendations: recommendations(metrics)
    }
  end

  @spec chart_series(map()) :: [map()]
  def chart_series(counts) when is_map(counts) do
    counts
    |> Enum.sort_by(fn {label, _count} -> to_string(label) end)
    |> Enum.map(fn {label, count} -> %{label: to_string(label), value: count} end)
  end

  defp count_by_type(events, type),
    do: Enum.count(events, fn event -> event[:event_type] == type end)

  defp count_by(events, field) do
    events
    |> Enum.map(&Map.get(&1, field))
    |> Enum.filter(&present?/1)
    |> Enum.frequencies()
  end

  defp count_by_day(events) do
    events
    |> Enum.map(fn event -> event.occurred_at |> DateTime.to_date() |> Date.to_iso8601() end)
    |> Enum.frequencies()
  end

  defp count_by_hour(events) do
    events
    |> Enum.map(fn event ->
      event.occurred_at
      |> DateTime.truncate(:second)
      |> DateTime.to_iso8601()
      |> String.slice(0, 13)
    end)
    |> Enum.frequencies()
  end

  defp top(counts, limit) do
    counts
    |> Enum.sort_by(fn {_key, count} -> -count end)
    |> Enum.take(limit)
    |> Enum.map(fn {label, count} -> %{label: label, count: count} end)
  end

  defp recommendations(%{total_events: 0}),
    do: ["Collect Telegram bot events before generating operational recommendations."]

  defp recommendations(metrics) do
    []
    |> maybe_add(
      metrics.error_rate > 0.05,
      "Investigate Telegram bot errors; error rate is above 5%."
    )
    |> maybe_add(
      metrics.average_duration_ms && metrics.average_duration_ms > 1_000,
      "Review slow Telegram handlers; average duration is above 1000ms."
    )
    |> maybe_add(
      metrics.command_events == 0,
      "Add command metadata to events to unlock command usage analytics."
    )
    |> case do
      [] -> ["Telegram bot analytics are within the configured baseline."]
      items -> Enum.reverse(items)
    end
  end

  defp maybe_add(items, true, item), do: [item | items]
  defp maybe_add(items, false, _item), do: items
  defp maybe_add(items, nil, _item), do: items

  defp average([]), do: nil
  defp average(values), do: Enum.sum(values) / length(values)

  defp rate(_part, 0), do: 0.0
  defp rate(part, total), do: part / total

  defp required_string(attrs, key) do
    case blank_to_nil(get_value(attrs, key)) do
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, "Missing required #{key}"}
    end
  end

  defp normalize_datetime(%DateTime{} = datetime), do: {:ok, datetime}

  defp normalize_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> {:error, "occurred_at must be an ISO-8601 timestamp"}
    end
  end

  defp normalize_datetime(_), do: {:error, "occurred_at must be a DateTime or ISO-8601 timestamp"}

  defp normalize_optional_integer(nil), do: {:ok, nil}
  defp normalize_optional_integer(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp normalize_optional_integer(_), do: {:error, "duration_ms must be a non-negative integer"}

  defp get_value(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, to_string(key), default))

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp present?(value), do: not is_nil(blank_to_nil(value))
end
