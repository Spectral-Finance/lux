defmodule Lux.Integrations.Telegram.Analytics.Collector do
  @moduledoc """
  Telemetry collection engine for Telegram interactions.
  Ingests raw message, command, callback query, and API latency events into structured records.
  """

  @type event_type :: :message | :command | :callback | :error | :api_call

  @type event :: %{
          id: String.t(),
          type: event_type(),
          chat_id: integer() | nil,
          user_id: integer() | nil,
          chat_type: String.t() | nil,
          command: String.t() | nil,
          latency_ms: non_neg_integer() | nil,
          status: :success | :error,
          error_code: integer() | nil,
          error_message: String.t() | nil,
          timestamp: DateTime.t(),
          metadata: map()
        }

  @type state :: %{
          events: list(event()),
          max_events: pos_integer()
        }

  @default_max_events 50_000

  @doc """
  Initializes an analytics collector state.
  """
  @spec init(keyword()) :: state()
  def init(opts \\ []) do
    max_events = Keyword.get(opts, :max_events, @default_max_events)
    %{events: [], max_events: max_events}
  end

  @doc """
  Records a telemetry event into the collector buffer.
  """
  @spec record_event(state(), event_type(), map()) :: {:ok, state(), event()}
  def record_event(state, type, params \\ %{}) when is_atom(type) and is_map(params) do
    now = DateTime.utc_now()
    rand_suffix = :rand.uniform(999_999)
    id = "evt_#{DateTime.to_unix(now)}_#{rand_suffix}"

    status =
      case Map.get(params, :status) do
        :error -> :error
        "error" -> :error
        _ -> :success
      end

    event = %{
      id: id,
      type: type,
      chat_id: Map.get(params, :chat_id),
      user_id: Map.get(params, :user_id),
      chat_type: Map.get(params, :chat_type, "private"),
      command: Map.get(params, :command),
      latency_ms: Map.get(params, :latency_ms),
      status: status,
      error_code: Map.get(params, :error_code),
      error_message: Map.get(params, :error_message),
      timestamp: Map.get(params, :timestamp, now),
      metadata: Map.get(params, :metadata, %{})
    }

    updated_events = [event | Enum.take(state.events, state.max_events - 1)]
    {:ok, %{state | events: updated_events}, event}
  end

  @doc """
  Queries buffered events by filters (type, time window, status, user_id, chat_id).
  """
  @spec query_events(state(), map()) :: list(event())
  def query_events(state, filters \\ %{}) do
    type_filter = Map.get(filters, :type)
    status_filter = Map.get(filters, :status)
    chat_filter = Map.get(filters, :chat_id)
    user_filter = Map.get(filters, :user_id)
    since = Map.get(filters, :since)

    state.events
    |> Enum.filter(fn e ->
      (is_nil(type_filter) or e.type == type_filter) and
        (is_nil(status_filter) or e.status == status_filter) and
        (is_nil(chat_filter) or e.chat_id == chat_filter) and
        (is_nil(user_filter) or e.user_id == user_filter) and
        (is_nil(since) or DateTime.compare(e.timestamp, since) in [:gt, :eq])
    end)
  end

  @doc """
  Clears the in-memory event buffer.
  """
  @spec clear(state()) :: state()
  def clear(state) do
    %{state | events: []}
  end
end
