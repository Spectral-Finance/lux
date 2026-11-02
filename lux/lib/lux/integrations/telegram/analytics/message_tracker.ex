defmodule Lux.Integrations.Telegram.Analytics.MessageTracker do
  @moduledoc """
  Analyzes message volume, throughput, message type distributions,
  and chat classification metrics from collected telemetry.
  """

  @doc """
  Computes message analytics over a list of events.
  """
  @spec analyze(list(map())) :: map()
  def analyze(events) when is_list(events) do
    msg_events = Enum.filter(events, &(&1.type in [:message, :command, :callback]))
    total_messages = length(msg_events)

    type_distribution =
      msg_events
      |> Enum.frequencies_by(fn e ->
        Map.get(e.metadata, :message_type) || e.type
      end)

    chat_distribution =
      msg_events
      |> Enum.frequencies_by(& &1.chat_type)

    first_ts = Enum.min_by(msg_events, &DateTime.to_unix(&1.timestamp), fn -> nil end)
    last_ts = Enum.max_by(msg_events, &DateTime.to_unix(&1.timestamp), fn -> nil end)

    duration_seconds =
      if first_ts && last_ts do
        max(1, DateTime.diff(last_ts.timestamp, first_ts.timestamp))
      else
        1
      end

    msg_per_hour = Float.round(total_messages / (duration_seconds / 3600.0), 2)
    msg_per_minute = Float.round(total_messages / (duration_seconds / 60.0), 2)

    %{
      total_messages: total_messages,
      duration_seconds: duration_seconds,
      messages_per_hour: msg_per_hour,
      messages_per_minute: msg_per_minute,
      type_distribution: type_distribution,
      chat_distribution: chat_distribution
    }
  end
end
