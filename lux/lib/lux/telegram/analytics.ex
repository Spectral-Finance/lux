defmodule Lux.Telegram.Analytics do
  @moduledoc """
  Pure Telegram analytics helpers used by Telegram monitoring prisms.

  The functions in this module are transport-neutral: callers can pass raw
  Telegram update maps from webhooks, polling, fixture files, or any custom
  collector and receive deterministic metric payloads.
  """

  @typedoc "A normalized metric event derived from one Telegram update."
  @type event :: %{
          update_id: integer() | nil,
          chat_id: integer() | binary() | nil,
          user_id: integer() | binary() | nil,
          message_id: integer() | nil,
          kind: atom(),
          command: binary() | nil,
          text_length: non_neg_integer(),
          latency_ms: number() | nil,
          error: binary() | nil,
          occurred_at: DateTime.t()
        }

  @doc """
  Normalizes one Telegram update into an analytics event.
  """
  @spec collect_update(map(), keyword()) :: event()
  def collect_update(update, opts \\ []) when is_map(update) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    latency_ms = Keyword.get(opts, :latency_ms)
    error = Keyword.get(opts, :error)

    message =
      first_present(update, [
        :message,
        "message",
        :edited_message,
        "edited_message",
        :channel_post,
        "channel_post",
        :edited_channel_post,
        "edited_channel_post"
      ])

    callback_query = value(update, :callback_query)
    inline_query = value(update, :inline_query)

    {kind, payload} =
      cond do
        is_map(message) -> {:message, message}
        is_map(callback_query) -> {:callback_query, callback_query}
        is_map(inline_query) -> {:inline_query, inline_query}
        true -> {:unknown, %{}}
      end

    from = value(payload, :from) || value(callback_query || %{}, :from) || %{}
    chat = value(payload, :chat) || %{}

    text =
      value(payload, :text) || value(payload, :caption) || value(callback_query || %{}, :data) ||
        ""

    %{
      update_id: value(update, :update_id),
      chat_id: value(chat, :id),
      user_id: value(from, :id),
      message_id: value(payload, :message_id),
      kind: kind,
      command: command_from_text(text),
      text_length: String.length(to_string(text)),
      latency_ms: latency_ms,
      error: error,
      occurred_at: now
    }
  end

  @doc """
  Aggregates normalized events into counters, rates, and reporting series.
  """
  @spec aggregate([event()]) :: map()
  def aggregate(events) when is_list(events) do
    events = Enum.map(events, &normalize_event/1)
    total = length(events)
    errors = Enum.count(events, &present?(&1.error))
    latencies = events |> Enum.map(& &1.latency_ms) |> Enum.filter(&is_number/1)

    %{
      total_updates: total,
      messages: count_by_kind(events, :message),
      callback_queries: count_by_kind(events, :callback_query),
      inline_queries: count_by_kind(events, :inline_query),
      unknown_updates: count_by_kind(events, :unknown),
      unique_users: unique_count(events, :user_id),
      unique_chats: unique_count(events, :chat_id),
      commands: command_usage(events),
      errors: errors,
      error_rate: rate(errors, total),
      avg_latency_ms: average(latencies),
      p95_latency_ms: percentile(latencies, 95),
      engagement: engagement(events),
      visualization: visualization(events)
    }
  end

  @doc """
  Builds a compact report for dashboards, alerts, or agent summaries.
  """
  @spec report([event()], keyword()) :: map()
  def report(events, opts \\ []) do
    metrics = aggregate(events)
    threshold = Keyword.get(opts, :error_rate_threshold, 0.05)

    %{
      status: if(metrics.error_rate > threshold, do: :alert, else: :ok),
      summary: %{
        total_updates: metrics.total_updates,
        unique_users: metrics.unique_users,
        unique_chats: metrics.unique_chats,
        error_rate: metrics.error_rate,
        avg_latency_ms: metrics.avg_latency_ms,
        p95_latency_ms: metrics.p95_latency_ms
      },
      top_commands: top_commands(metrics.commands),
      visualization: metrics.visualization
    }
  end

  @doc """
  Returns whether the event stream exceeds an error-rate threshold.
  """
  @spec error_alert?([event()], number()) :: boolean()
  def error_alert?(events, threshold \\ 0.05) do
    aggregate(events).error_rate > threshold
  end

  defp normalize_event(%{kind: _} = event), do: event
  defp normalize_event(event) when is_map(event), do: collect_update(event)

  defp value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  defp first_present(map, keys) do
    Enum.find_value(keys, &Map.get(map, &1))
  end

  defp command_from_text(text) when is_binary(text) do
    case Regex.run(~r/^\/([A-Za-z0-9_]+)(?:@\w+)?(?:\s|$)/, text) do
      [_, command] -> "/" <> command
      _ -> nil
    end
  end

  defp command_from_text(_), do: nil

  defp count_by_kind(events, kind), do: Enum.count(events, &(&1.kind == kind))

  defp unique_count(events, key) do
    events
    |> Enum.map(&Map.get(&1, key))
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
    |> MapSet.size()
  end

  defp command_usage(events) do
    events
    |> Enum.map(& &1.command)
    |> Enum.filter(&present?/1)
    |> Enum.frequencies()
  end

  defp engagement(events) do
    total = length(events)
    commands = events |> Enum.count(&present?(&1.command))

    %{
      command_rate: rate(commands, total),
      average_text_length: average(Enum.map(events, & &1.text_length))
    }
  end

  defp visualization(events) do
    %{
      updates_by_kind:
        events
        |> Enum.map(& &1.kind)
        |> Enum.frequencies(),
      commands: command_usage(events),
      errors_by_message:
        events
        |> Enum.map(& &1.error)
        |> Enum.filter(&present?/1)
        |> Enum.frequencies()
    }
  end

  defp top_commands(commands) do
    commands
    |> Enum.sort_by(fn {_command, count} -> -count end)
    |> Enum.take(10)
    |> Enum.map(fn {command, count} -> %{command: command, count: count} end)
  end

  defp rate(_count, 0), do: 0.0
  defp rate(count, total), do: count / total

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)

  defp percentile([], _percentile), do: 0.0

  defp percentile(values, percentile) do
    sorted = Enum.sort(values)
    index = max(0, ceil(percentile / 100 * length(sorted)) - 1)
    Enum.at(sorted, index)
  end

  defp present?(value), do: value not in [nil, ""]
end
