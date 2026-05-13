defmodule Lux.Integrations.Telegram.Analytics do
  @moduledoc """
  Transport-neutral Telegram analytics and monitoring helpers.

  These helpers normalize Bot API updates into metric events, aggregate chat and
  audience activity, evaluate monitoring thresholds, and build report payloads.
  They do not call Telegram directly or persist state.
  """

  @message_types [
    :text,
    :photo,
    :video,
    :audio,
    :voice,
    :document,
    :sticker,
    :animation,
    :poll,
    :contact,
    :location,
    :unknown
  ]

  @doc """
  Normalizes one Telegram update into an analytics event.
  """
  @spec event(map()) :: map()
  def event(update) when is_map(update) do
    source = update_source(update)
    message = message_from_source(source)
    chat = value(message, :chat) || value(source, :chat) || %{}
    user = value(source, :from) || value(message, :from) || %{}
    text = text_from_source(source, message)
    message_type = message_type(message)

    %{
      update_id: value(update, :update_id),
      kind: update_kind(update),
      chat_id: value(chat, :id),
      chat_type: value(chat, :type),
      user_id: value(user, :id),
      username: value(user, :username),
      message_id: value(message, :message_id),
      message_type: message_type,
      text_length: text_length(text),
      command: command(text),
      has_media?: message_type in @message_types -- [:text, :unknown],
      timestamp: timestamp(message, source),
      raw: update
    }
  end

  @doc """
  Aggregates a list of updates or already-normalized events.
  """
  @spec summary([map()]) :: map()
  def summary(items) when is_list(items) do
    events = Enum.map(items, &event_or_existing/1)
    users = events |> Enum.map(& &1.user_id) |> compact() |> MapSet.new()
    chats = events |> Enum.map(& &1.chat_id) |> compact() |> MapSet.new()
    commands = events |> Enum.map(& &1.command) |> compact()

    %{
      total_updates: length(events),
      active_chats: MapSet.size(chats),
      active_users: MapSet.size(users),
      messages: count_kind(events, :message),
      edited_messages: count_kind(events, :edited_message),
      callback_queries: count_kind(events, :callback_query),
      commands: length(commands),
      media_messages: Enum.count(events, & &1.has_media?),
      average_text_length: average(Enum.map(events, & &1.text_length)),
      by_chat: group_count(events, :chat_id),
      by_user: group_count(events, :user_id),
      by_type: group_count(events, :message_type),
      by_command: group_count(events, :command)
    }
  end

  @doc """
  Builds minute-level buckets for rate monitoring.
  """
  @spec buckets([map()], pos_integer()) :: [map()]
  def buckets(items, window_seconds \\ 60) when is_list(items) and window_seconds > 0 do
    items
    |> Enum.map(&event_or_existing/1)
    |> Enum.group_by(fn event -> div(event.timestamp || 0, window_seconds) * window_seconds end)
    |> Enum.map(fn {window_start, events} ->
      events
      |> summary()
      |> Map.merge(%{
        window_start: window_start,
        window_seconds: window_seconds
      })
    end)
    |> Enum.sort_by(& &1.window_start)
  end

  @doc """
  Evaluates monitoring thresholds against a summary or bucket.
  """
  @spec alerts(map(), map()) :: [map()]
  def alerts(metrics, thresholds \\ %{}) when is_map(metrics) do
    [
      threshold_alert(
        metrics.total_updates,
        :max_updates,
        thresholds,
        :update_volume_high,
        :critical,
        :gt
      ),
      threshold_alert(
        metrics.callback_queries,
        :max_callback_queries,
        thresholds,
        :callback_volume_high,
        :warning,
        :gt
      ),
      threshold_alert(
        metrics.active_users,
        :min_active_users,
        thresholds,
        :active_users_low,
        :warning,
        :lt
      ),
      threshold_alert(
        metrics.commands,
        :max_commands,
        thresholds,
        :command_volume_high,
        :warning,
        :gt
      )
    ]
    |> compact()
  end

  @doc """
  Builds a serializable analytics report payload.
  """
  @spec report([map()], map()) :: map()
  def report(items, opts \\ %{}) do
    metrics = summary(items)
    window_seconds = value(opts, :window_seconds) || 60
    thresholds = value(opts, :thresholds) || %{}
    bucket_metrics = buckets(items, window_seconds)

    %{
      generated_at: value(opts, :generated_at),
      chat_id: value(opts, :chat_id),
      summary: metrics,
      buckets: bucket_metrics,
      alerts: alerts(metrics, thresholds),
      top_chats: top(metrics.by_chat, value(opts, :limit) || 5),
      top_users: top(metrics.by_user, value(opts, :limit) || 5),
      top_commands: top(metrics.by_command, value(opts, :limit) || 5)
    }
  end

  @doc """
  Produces retention snapshots from dated active-user sets.
  """
  @spec retention([map()]) :: map()
  def retention(snapshots) when is_list(snapshots) do
    ordered = Enum.sort_by(snapshots, &(value(&1, :period) || ""))

    case ordered do
      [] ->
        %{periods: [], retained_users: 0, retention_rate: 0.0}

      [first | rest] ->
        first_users = user_set(first)
        last_users = ordered |> List.last() |> user_set()
        retained = MapSet.intersection(first_users, last_users)

        %{
          periods: Enum.map(ordered, &value(&1, :period)),
          first_period_users: MapSet.size(first_users),
          latest_period_users: MapSet.size(last_users),
          retained_users: MapSet.size(retained),
          retention_rate: ratio(MapSet.size(retained), max(MapSet.size(first_users), 1)),
          period_count: length([first | rest])
        }
    end
  end

  defp update_source(update) do
    cond do
      is_map(value(update, :message)) -> value(update, :message)
      is_map(value(update, :edited_message)) -> value(update, :edited_message)
      is_map(value(update, :channel_post)) -> value(update, :channel_post)
      is_map(value(update, :callback_query)) -> value(update, :callback_query)
      true -> update
    end
  end

  defp update_kind(update) do
    cond do
      is_map(value(update, :message)) -> :message
      is_map(value(update, :edited_message)) -> :edited_message
      is_map(value(update, :channel_post)) -> :channel_post
      is_map(value(update, :callback_query)) -> :callback_query
      true -> :unknown
    end
  end

  defp message_from_source(%{} = source) do
    value(source, :message) || source
  end

  defp text_from_source(source, message) do
    value(source, :data) || value(message, :text) || value(message, :caption) || ""
  end

  defp message_type(message) do
    Enum.find(@message_types, :unknown, fn type ->
      type != :unknown and present?(value(message, type))
    end)
  end

  defp timestamp(message, source) do
    value(message, :date) || value(source, :date) || 0
  end

  defp text_length(text) when is_binary(text), do: String.length(text)
  defp text_length(_text), do: 0

  defp command("/" <> rest) do
    rest
    |> String.split(~r/\s+/, parts: 2)
    |> List.first()
    |> String.split("@", parts: 2)
    |> List.first()
  end

  defp command(_text), do: nil

  defp event_or_existing(%{kind: _kind} = event), do: event
  defp event_or_existing(update), do: event(update)

  defp count_kind(events, kind), do: Enum.count(events, &(&1.kind == kind))

  defp group_count(events, key) do
    events
    |> Enum.map(&Map.get(&1, key))
    |> compact()
    |> Enum.frequencies()
  end

  defp threshold_alert(value, key, thresholds, reason, severity, comparator) do
    threshold = value(thresholds, key)

    if threshold && threshold_crossed?(value, threshold, comparator) do
      %{reason: reason, severity: severity, value: value, threshold: threshold}
    end
  end

  defp threshold_crossed?(value, threshold, :gt), do: value > threshold
  defp threshold_crossed?(value, threshold, :lt), do: value < threshold

  defp top(frequencies, limit) do
    frequencies
    |> Enum.sort_by(fn {_key, count} -> -count end)
    |> Enum.take(limit)
    |> Enum.map(fn {key, count} -> %{key: key, count: count} end)
  end

  defp user_set(snapshot) do
    snapshot
    |> value(:users)
    |> List.wrap()
    |> compact()
    |> MapSet.new()
  end

  defp average([]), do: 0.0
  defp average(values), do: Enum.sum(values) / length(values)

  defp ratio(_numerator, 0), do: 0.0
  defp ratio(numerator, denominator), do: numerator / denominator

  defp compact(values), do: Enum.reject(values, &is_nil/1)

  defp present?(nil), do: false
  defp present?(_value), do: true

  defp value(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp value(_map, _key), do: nil
end
