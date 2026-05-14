defmodule Lux.Integrations.Telegram.Analytics do
  @moduledoc """
  Transport-neutral analytics helpers for Telegram Bot API updates.

  The module accepts raw Telegram update maps or already-normalized event maps and
  returns deterministic usage, engagement, performance, error, and visualization
  payloads that higher-level prisms can expose to agents.
  """

  @event_types [
    :message,
    :command,
    :callback_query,
    :inline_query,
    :edited_message,
    :chat_member,
    :error,
    :unknown
  ]

  @default_thresholds %{
    error_rate_warning: 0.05,
    error_rate_danger: 0.15,
    p95_latency_warning_ms: 1_000,
    p95_latency_danger_ms: 3_000
  }

  @type update :: map()
  @type normalized_event :: map()
  @type report :: map()

  @doc """
  Converts raw Telegram updates or custom event maps into normalized analytics events.
  """
  @spec normalize_events([update()] | update() | nil) :: [normalized_event()]
  def normalize_events(nil), do: []
  def normalize_events(events) when is_list(events), do: Enum.map(events, &normalize_event/1)
  def normalize_events(event) when is_map(event), do: [normalize_event(event)]

  @doc """
  Converts a raw Telegram update or custom event map into one analytics event.
  """
  @spec normalize_event(update()) :: normalized_event()
  def normalize_event(update) when is_map(update) do
    cond do
      normalized_type?(fetch_value(update, :type)) ->
        normalize_custom_event(update)

      truthy_false?(fetch_value(update, :ok)) or present?(fetch_value(update, :error)) ->
        normalize_error_event(update)

      message = fetch_value(update, :message) ->
        normalize_message_event(message, update, :message)

      message = fetch_value(update, :edited_message) ->
        normalize_message_event(message, update, :edited_message)

      callback = fetch_value(update, :callback_query) ->
        normalize_callback_event(callback, update)

      inline_query = fetch_value(update, :inline_query) ->
        normalize_inline_query_event(inline_query, update)

      chat_member = fetch_value(update, :chat_member) || fetch_value(update, :my_chat_member) ->
        normalize_chat_member_event(chat_member, update)

      true ->
        base_event(update, :unknown)
    end
  end

  @doc """
  Builds a complete analytics report from raw Telegram updates or normalized events.
  """
  @spec report([update()] | update() | nil, keyword() | map()) :: report()
  def report(updates, opts \\ []) do
    opts = Map.new(opts)
    events = normalize_events(updates)
    previous_user_ids = opts |> Map.get(:previous_user_ids, []) |> ids_to_set()
    generated_at = Map.get(opts, :generated_at) || utc_now()
    custom_metric_definitions = Map.get(opts, :custom_metrics, [])

    totals = totals(events)
    error_summary = errors(events, totals.total_updates)
    performance_summary = performance(events)

    %{
      generated_at: generated_at,
      totals: totals,
      engagement: engagement(events),
      commands: command_usage(events),
      chats: top_dimension(events, :chat_id),
      users: top_dimension(events, :user_id),
      errors: error_summary,
      performance: performance_summary,
      patterns: usage_patterns(events),
      retention: retention(events, previous_user_ids),
      custom_metrics: custom_metrics(events, custom_metric_definitions),
      visualizations: visualizations(events, error_summary, performance_summary)
    }
  end

  @doc """
  Evaluates alert thresholds against a report.
  """
  @spec alerts(report(), keyword() | map()) :: map()
  def alerts(report, thresholds \\ %{}) when is_map(report) do
    thresholds = Map.merge(@default_thresholds, normalize_thresholds(thresholds))
    error_rate = get_in(report, [:errors, :error_rate]) || 0.0
    p95_latency = get_in(report, [:performance, :p95_latency_ms]) || 0

    alert_items =
      []
      |> maybe_add_error_rate_alert(error_rate, thresholds)
      |> maybe_add_latency_alert(p95_latency, thresholds)

    %{
      severity: highest_severity(alert_items),
      alerts: Enum.reverse(alert_items),
      thresholds: thresholds
    }
  end

  @doc """
  Builds a compact report payload for agent responses and dashboards.
  """
  @spec report_payload(report(), keyword() | map()) :: map()
  def report_payload(report, opts \\ %{}) do
    opts = Map.new(opts)
    title = Map.get(opts, :title, "Telegram analytics report")

    %{
      title: title,
      generated_at: report.generated_at,
      summary: %{
        total_updates: report.totals.total_updates,
        active_chats: report.engagement.active_chats,
        active_users: report.engagement.active_users,
        error_rate: report.errors.error_rate,
        p95_latency_ms: report.performance.p95_latency_ms
      },
      sections: [
        %{name: "Usage", data: report.totals.by_type},
        %{name: "Commands", data: report.commands},
        %{name: "Errors", data: report.errors},
        %{name: "Performance", data: report.performance},
        %{name: "Retention", data: report.retention},
        %{name: "Custom Metrics", data: Map.get(report, :custom_metrics, [])}
      ],
      visualizations: report.visualizations
    }
  end

  defp normalize_custom_event(event) do
    type = fetch_value(event, :type) |> normalize_type()

    event
    |> base_event(type)
    |> Map.merge(%{
      chat_id: fetch_value(event, :chat_id),
      user_id: fetch_value(event, :user_id),
      command: normalize_command(fetch_value(event, :command)),
      text: fetch_value(event, :text),
      latency_ms: normalize_integer(fetch_value(event, :latency_ms)),
      error: fetch_value(event, :error) || fetch_value(event, :reason)
    })
    |> drop_nil_values()
  end

  defp normalize_error_event(update) do
    update
    |> base_event(:error)
    |> Map.merge(%{
      chat_id: fetch_value(update, :chat_id),
      user_id: fetch_value(update, :user_id),
      latency_ms: normalize_integer(fetch_value(update, :latency_ms)),
      error:
        fetch_value(update, :error) || fetch_value(update, :reason) ||
          fetch_value(update, :description)
    })
    |> drop_nil_values()
  end

  defp normalize_message_event(message, update, source_type) when is_map(message) do
    text = fetch_value(message, :text) || fetch_value(message, :caption)
    command = command_from_text(text)
    event_type = if command, do: :command, else: source_type

    update
    |> base_event(event_type)
    |> Map.merge(%{
      chat_id: nested_value(message, [:chat, :id]),
      chat_type: nested_value(message, [:chat, :type]),
      user_id: nested_value(message, [:from, :id]),
      username: nested_value(message, [:from, :username]),
      message_id: fetch_value(message, :message_id),
      text: text,
      command: command,
      timestamp: timestamp_from_message(message, update),
      latency_ms:
        normalize_integer(fetch_value(update, :latency_ms) || fetch_value(message, :latency_ms))
    })
    |> drop_nil_values()
  end

  defp normalize_callback_event(callback, update) when is_map(callback) do
    update
    |> base_event(:callback_query)
    |> Map.merge(%{
      chat_id: nested_value(callback, [:message, :chat, :id]),
      user_id: nested_value(callback, [:from, :id]),
      username: nested_value(callback, [:from, :username]),
      callback_data: fetch_value(callback, :data),
      message_id: nested_value(callback, [:message, :message_id]),
      timestamp: fetch_value(update, :timestamp),
      latency_ms:
        normalize_integer(fetch_value(update, :latency_ms) || fetch_value(callback, :latency_ms))
    })
    |> drop_nil_values()
  end

  defp normalize_inline_query_event(inline_query, update) when is_map(inline_query) do
    update
    |> base_event(:inline_query)
    |> Map.merge(%{
      user_id: nested_value(inline_query, [:from, :id]),
      username: nested_value(inline_query, [:from, :username]),
      query: fetch_value(inline_query, :query),
      timestamp: fetch_value(update, :timestamp),
      latency_ms:
        normalize_integer(
          fetch_value(update, :latency_ms) || fetch_value(inline_query, :latency_ms)
        )
    })
    |> drop_nil_values()
  end

  defp normalize_chat_member_event(chat_member, update) when is_map(chat_member) do
    update
    |> base_event(:chat_member)
    |> Map.merge(%{
      chat_id: nested_value(chat_member, [:chat, :id]),
      user_id:
        nested_value(chat_member, [:from, :id]) ||
          nested_value(chat_member, [:new_chat_member, :user, :id]),
      old_status: nested_value(chat_member, [:old_chat_member, :status]),
      new_status: nested_value(chat_member, [:new_chat_member, :status]),
      timestamp: timestamp_from_message(chat_member, update),
      latency_ms:
        normalize_integer(
          fetch_value(update, :latency_ms) || fetch_value(chat_member, :latency_ms)
        )
    })
    |> drop_nil_values()
  end

  defp base_event(update, type) do
    %{
      update_id: fetch_value(update, :update_id),
      type: normalize_type(type),
      timestamp: fetch_value(update, :timestamp)
    }
    |> drop_nil_values()
  end

  defp totals(events) do
    by_type =
      @event_types
      |> Map.new(&{&1, 0})
      |> Map.merge(Enum.frequencies_by(events, & &1.type))

    %{
      total_updates: length(events),
      by_type: by_type,
      messages: Map.get(by_type, :message, 0) + Map.get(by_type, :command, 0),
      commands: Map.get(by_type, :command, 0),
      callback_queries: Map.get(by_type, :callback_query, 0),
      inline_queries: Map.get(by_type, :inline_query, 0),
      chat_member_events: Map.get(by_type, :chat_member, 0),
      errors: Map.get(by_type, :error, 0)
    }
  end

  defp engagement(events) do
    chat_ids = events |> Enum.map(&Map.get(&1, :chat_id)) |> reject_blank()
    user_ids = events |> Enum.map(&Map.get(&1, :user_id)) |> reject_blank()

    %{
      active_chats: chat_ids |> MapSet.new() |> MapSet.size(),
      active_users: user_ids |> MapSet.new() |> MapSet.size(),
      messages_per_chat:
        safe_ratio(
          count_type(events, [:message, :command]),
          chat_ids |> MapSet.new() |> MapSet.size()
        ),
      updates_per_user: safe_ratio(length(events), user_ids |> MapSet.new() |> MapSet.size())
    }
  end

  defp command_usage(events) do
    command_counts =
      events
      |> Enum.map(&Map.get(&1, :command))
      |> reject_blank()
      |> Enum.frequencies()

    %{
      total_commands: Enum.sum(Map.values(command_counts)),
      unique_commands: map_size(command_counts),
      top_commands: top_entries(command_counts)
    }
  end

  defp errors(events, total_updates) do
    error_events = Enum.filter(events, &(&1.type == :error or present?(Map.get(&1, :error))))
    errors_by_reason = error_events |> Enum.map(&error_reason/1) |> Enum.frequencies()

    %{
      count: length(error_events),
      error_rate: safe_ratio(length(error_events), total_updates),
      by_reason: errors_by_reason,
      recent: Enum.take(error_events, -5)
    }
  end

  defp performance(events) do
    latencies =
      events
      |> Enum.map(&Map.get(&1, :latency_ms))
      |> Enum.filter(&is_integer/1)
      |> Enum.sort()

    %{
      samples: length(latencies),
      min_latency_ms: percentile(latencies, 0.0),
      avg_latency_ms: average(latencies),
      p50_latency_ms: percentile(latencies, 0.50),
      p95_latency_ms: percentile(latencies, 0.95),
      max_latency_ms: percentile(latencies, 1.0)
    }
  end

  defp usage_patterns(events) do
    %{
      by_hour: bucket_by(events, :hour),
      by_day: bucket_by(events, :day),
      by_type: events |> Enum.frequencies_by(& &1.type) |> sort_frequency_map()
    }
  end

  defp retention(events, previous_user_ids) do
    current_user_ids =
      events
      |> Enum.map(&Map.get(&1, :user_id))
      |> reject_blank()
      |> ids_to_set()

    retained = MapSet.intersection(current_user_ids, previous_user_ids)
    new_users = MapSet.difference(current_user_ids, previous_user_ids)

    %{
      current_users: MapSet.size(current_user_ids),
      previous_users: MapSet.size(previous_user_ids),
      retained_users: MapSet.size(retained),
      new_users: MapSet.size(new_users),
      retention_rate: safe_ratio(MapSet.size(retained), MapSet.size(previous_user_ids))
    }
  end

  defp custom_metrics(_events, definitions) when definitions in [nil, []], do: []

  defp custom_metrics(events, definitions) when is_list(definitions) do
    Enum.map(definitions, fn definition ->
      name = fetch_value(definition, :name) || "custom_metric"
      field = fetch_value(definition, :field)
      expected_value = fetch_value(definition, :value)

      count =
        Enum.count(events, fn event ->
          field && fetch_dynamic(event, field) == expected_value
        end)

      %{
        name: name,
        field: field,
        value: expected_value,
        count: count
      }
    end)
  end

  defp custom_metrics(_events, _definitions), do: []

  defp visualizations(events, error_summary, performance_summary) do
    %{
      event_type_bar: events |> Enum.frequencies_by(& &1.type) |> chart_points("type", "count"),
      hourly_volume_series: events |> bucket_by(:hour) |> chart_points("bucket", "updates"),
      command_bar: command_usage(events).top_commands,
      error_rate_gauge: %{
        value: error_summary.error_rate,
        min: 0.0,
        max: 1.0,
        warning: @default_thresholds.error_rate_warning,
        danger: @default_thresholds.error_rate_danger
      },
      latency_gauge: %{
        value: performance_summary.p95_latency_ms,
        unit: "ms",
        warning: @default_thresholds.p95_latency_warning_ms,
        danger: @default_thresholds.p95_latency_danger_ms
      }
    }
  end

  defp top_dimension(events, key) do
    events
    |> Enum.map(&Map.get(&1, key))
    |> reject_blank()
    |> Enum.frequencies()
    |> top_entries()
  end

  defp top_entries(counts, limit \\ 10) do
    counts
    |> Enum.sort_by(fn {value, count} -> {-count, to_string(value)} end)
    |> Enum.take(limit)
    |> Enum.map(fn {value, count} -> %{value: value, count: count} end)
  end

  defp chart_points(values, label_key, value_key) do
    values
    |> sort_frequency_map()
    |> Enum.map(fn {label, value} -> %{label_key => label, value_key => value} end)
  end

  defp sort_frequency_map(values) when is_map(values) do
    Enum.sort_by(values, fn {key, count} -> {to_string(key), count} end)
  end

  defp count_type(events, types), do: Enum.count(events, &(&1.type in types))

  defp bucket_by(events, precision) do
    events
    |> Enum.map(&timestamp_bucket(Map.get(&1, :timestamp), precision))
    |> reject_blank()
    |> Enum.frequencies()
  end

  defp timestamp_bucket(nil, _precision), do: nil

  defp timestamp_bucket(timestamp, precision) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, datetime, _offset} -> timestamp_bucket(datetime, precision)
      _ -> nil
    end
  end

  defp timestamp_bucket(%DateTime{} = timestamp, :day),
    do: Date.to_iso8601(DateTime.to_date(timestamp))

  defp timestamp_bucket(%DateTime{} = timestamp, :hour) do
    timestamp
    |> DateTime.truncate(:second)
    |> Map.put(:minute, 0)
    |> Map.put(:second, 0)
    |> DateTime.to_iso8601()
  end

  defp timestamp_bucket(_, _precision), do: nil

  defp timestamp_from_message(message, update) do
    fetch_value(update, :timestamp) || unix_to_iso8601(fetch_value(message, :date))
  end

  defp unix_to_iso8601(value) when is_integer(value) do
    case DateTime.from_unix(value) do
      {:ok, datetime} -> DateTime.to_iso8601(datetime)
      _ -> nil
    end
  end

  defp unix_to_iso8601(_value), do: nil

  defp command_from_text("/" <> command_text) do
    command_text
    |> String.split(~r/\s+/, parts: 2)
    |> hd()
    |> String.split("@", parts: 2)
    |> hd()
    |> normalize_command()
  end

  defp command_from_text(_text), do: nil

  defp normalize_command(command) when is_atom(command),
    do: command |> Atom.to_string() |> normalize_command()

  defp normalize_command(command) when is_binary(command) do
    command
    |> String.trim()
    |> String.trim_leading("/")
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp normalize_command(_command), do: nil

  defp normalized_type?(type), do: normalize_type(type) in @event_types

  defp normalize_type(type) when is_atom(type), do: type

  defp normalize_type(type) when is_binary(type) do
    case type |> String.downcase() |> String.replace("-", "_") do
      "message" -> :message
      "command" -> :command
      "callback_query" -> :callback_query
      "inline_query" -> :inline_query
      "edited_message" -> :edited_message
      "chat_member" -> :chat_member
      "error" -> :error
      "unknown" -> :unknown
      _ -> :unknown
    end
  end

  defp normalize_type(_type), do: :unknown

  defp truthy_false?(false), do: true
  defp truthy_false?("false"), do: true
  defp truthy_false?(_value), do: false

  defp present?(value), do: value not in [nil, ""]

  defp error_reason(event) do
    event
    |> Map.get(:error)
    |> case do
      nil -> "unknown"
      "" -> "unknown"
      reason -> to_string(reason)
    end
  end

  defp percentile([], _percentile), do: nil

  defp percentile(values, percentile) do
    index =
      ((length(values) - 1) * percentile)
      |> Float.ceil()
      |> trunc()

    Enum.at(values, index)
  end

  defp average([]), do: nil
  defp average(values), do: Float.round(Enum.sum(values) / length(values), 2)

  defp safe_ratio(_numerator, 0), do: 0.0
  defp safe_ratio(numerator, denominator), do: Float.round(numerator / denominator, 4)

  defp ids_to_set(values) when is_list(values), do: values |> reject_blank() |> MapSet.new()
  defp ids_to_set(%MapSet{} = values), do: values
  defp ids_to_set(_values), do: MapSet.new()

  defp reject_blank(values), do: Enum.reject(values, &(&1 in [nil, ""]))

  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp fetch_value(map, key) when is_map(map) and is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> nil
    end
  end

  defp fetch_dynamic(map, key) when is_atom(key), do: fetch_value(map, key)
  defp fetch_dynamic(map, "type"), do: fetch_value(map, :type)
  defp fetch_dynamic(map, "chat_id"), do: fetch_value(map, :chat_id)
  defp fetch_dynamic(map, "user_id"), do: fetch_value(map, :user_id)
  defp fetch_dynamic(map, "command"), do: fetch_value(map, :command)
  defp fetch_dynamic(map, "chat_type"), do: fetch_value(map, :chat_type)
  defp fetch_dynamic(map, "error"), do: fetch_value(map, :error)
  defp fetch_dynamic(map, "callback_data"), do: fetch_value(map, :callback_data)
  defp fetch_dynamic(_map, _key), do: nil

  defp nested_value(map, keys) do
    Enum.reduce_while(keys, map, fn key, acc ->
      case fetch_value(acc, key) do
        nil -> {:halt, nil}
        value -> {:cont, value}
      end
    end)
  end

  defp drop_nil_values(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) end)
  end

  defp normalize_thresholds(nil), do: %{}

  defp normalize_thresholds(thresholds) do
    thresholds
    |> Map.new()
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      case threshold_key(key) do
        nil -> acc
        threshold_key -> Map.put(acc, threshold_key, value)
      end
    end)
  end

  defp threshold_key(key) when is_atom(key), do: key

  defp threshold_key(key) when is_binary(key) do
    case key do
      "error_rate_warning" -> :error_rate_warning
      "error_rate_danger" -> :error_rate_danger
      "p95_latency_warning_ms" -> :p95_latency_warning_ms
      "p95_latency_danger_ms" -> :p95_latency_danger_ms
      _ -> nil
    end
  end

  defp maybe_add_error_rate_alert(alerts, error_rate, thresholds) do
    cond do
      error_rate >= thresholds.error_rate_danger ->
        [%{severity: :danger, metric: :error_rate, value: error_rate} | alerts]

      error_rate >= thresholds.error_rate_warning ->
        [%{severity: :warning, metric: :error_rate, value: error_rate} | alerts]

      true ->
        alerts
    end
  end

  defp maybe_add_latency_alert(alerts, nil, _thresholds), do: alerts

  defp maybe_add_latency_alert(alerts, latency, thresholds) do
    cond do
      latency >= thresholds.p95_latency_danger_ms ->
        [%{severity: :danger, metric: :p95_latency_ms, value: latency} | alerts]

      latency >= thresholds.p95_latency_warning_ms ->
        [%{severity: :warning, metric: :p95_latency_ms, value: latency} | alerts]

      true ->
        alerts
    end
  end

  defp highest_severity(alerts) do
    cond do
      Enum.any?(alerts, &(&1.severity == :danger)) -> :danger
      Enum.any?(alerts, &(&1.severity == :warning)) -> :warning
      true -> :ok
    end
  end

  defp utc_now do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
