defmodule Lux.Integrations.Telegram.Analytics.Collector do
  @moduledoc """
  Collects and stores Telegram bot analytics data: messages, commands, errors, response times.

  Uses ETS for fast in-memory counters with periodic aggregation.
  """

  use GenServer

  defstruct [:counters, :events, :start_time, :max_events]

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def track_message(pid \\ __MODULE__, message) do
    GenServer.cast(pid, {:track_message, message})
  end

  def track_command(pid \\ __MODULE__, command, user_id, chat_id) do
    GenServer.cast(pid, {:track_command, command, user_id, chat_id})
  end

  def track_error(pid \\ __MODULE__, error_type, details \\ %{}) do
    GenServer.cast(pid, {:track_error, error_type, details})
  end

  def track_response_time(pid \\ __MODULE__, endpoint, duration_ms) do
    GenServer.cast(pid, {:track_response_time, endpoint, duration_ms})
  end

  def get_counters(pid \\ __MODULE__) do
    GenServer.call(pid, :get_counters)
  end

  def get_events(pid \\ __MODULE__, opts \\ %{}) do
    GenServer.call(pid, {:get_events, opts})
  end

  def reset(pid \\ __MODULE__) do
    GenServer.call(pid, :reset)
  end

  # Server

  @impl true
  def init(opts) do
    state = %__MODULE__{
      counters: %{
        messages_total: 0,
        messages_text: 0,
        messages_media: 0,
        commands_total: 0,
        errors_total: 0,
        unique_users: MapSet.new(),
        unique_chats: MapSet.new(),
        commands: %{},
        errors_by_type: %{},
        response_times: [],
        hourly_messages: %{}
      },
      events: [],
      start_time: DateTime.utc_now(),
      max_events: opts[:max_events] || 10_000
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:track_message, message}, state) do
    user_id = message[:from_id] || message[:user_id]
    chat_id = message[:chat_id]
    has_media = message[:has_media] || false
    hour = DateTime.utc_now() |> Map.get(:hour)

    counters = state.counters
    |> Map.update!(:messages_total, &(&1 + 1))
    |> Map.update!(if(has_media, do: :messages_media, else: :messages_text), &(&1 + 1))
    |> then(fn c -> if user_id, do: Map.update!(c, :unique_users, &MapSet.put(&1, user_id)), else: c end)
    |> then(fn c -> if chat_id, do: Map.update!(c, :unique_chats, &MapSet.put(&1, chat_id)), else: c end)
    |> Map.update!(:hourly_messages, fn hm -> Map.update(hm, hour, 1, &(&1 + 1)) end)

    event = %{type: :message, user_id: user_id, chat_id: chat_id, has_media: has_media, at: DateTime.utc_now()}
    {:noreply, %{state | counters: counters, events: trim_events([event | state.events], state.max_events)}}
  end

  @impl true
  def handle_cast({:track_command, command, user_id, chat_id}, state) do
    counters = state.counters
    |> Map.update!(:commands_total, &(&1 + 1))
    |> Map.update!(:commands, fn cmds -> Map.update(cmds, command, 1, &(&1 + 1)) end)
    |> then(fn c -> if user_id, do: Map.update!(c, :unique_users, &MapSet.put(&1, user_id)), else: c end)
    |> then(fn c -> if chat_id, do: Map.update!(c, :unique_chats, &MapSet.put(&1, chat_id)), else: c end)

    event = %{type: :command, command: command, user_id: user_id, chat_id: chat_id, at: DateTime.utc_now()}
    {:noreply, %{state | counters: counters, events: trim_events([event | state.events], state.max_events)}}
  end

  @impl true
  def handle_cast({:track_error, error_type, details}, state) do
    counters = state.counters
    |> Map.update!(:errors_total, &(&1 + 1))
    |> Map.update!(:errors_by_type, fn et -> Map.update(et, error_type, 1, &(&1 + 1)) end)

    event = %{type: :error, error_type: error_type, details: details, at: DateTime.utc_now()}
    {:noreply, %{state | counters: counters, events: trim_events([event | state.events], state.max_events)}}
  end

  @impl true
  def handle_cast({:track_response_time, endpoint, duration_ms}, state) do
    counters = Map.update!(state.counters, :response_times, fn rts ->
      [{endpoint, duration_ms, DateTime.utc_now()} | rts] |> Enum.take(1000)
    end)

    {:noreply, %{state | counters: counters}}
  end

  @impl true
  def handle_call(:get_counters, _from, state) do
    result = %{
      messages_total: state.counters.messages_total,
      messages_text: state.counters.messages_text,
      messages_media: state.counters.messages_media,
      commands_total: state.counters.commands_total,
      errors_total: state.counters.errors_total,
      unique_users: MapSet.size(state.counters.unique_users),
      unique_chats: MapSet.size(state.counters.unique_chats),
      top_commands: state.counters.commands |> Enum.sort_by(fn {_, v} -> -v end) |> Enum.take(10),
      errors_by_type: state.counters.errors_by_type,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.start_time),
      hourly_distribution: state.counters.hourly_messages
    }

    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call({:get_events, opts}, _from, state) do
    events = state.events
    |> maybe_filter_type(opts[:type])
    |> Enum.take(opts[:limit] || 50)
    {:reply, {:ok, events}, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    {:reply, :ok, %{state | counters: %{state.counters |
      messages_total: 0, messages_text: 0, messages_media: 0,
      commands_total: 0, errors_total: 0,
      unique_users: MapSet.new(), unique_chats: MapSet.new(),
      commands: %{}, errors_by_type: %{}, response_times: [],
      hourly_messages: %{}
    }, events: [], start_time: DateTime.utc_now()}}
  end

  defp trim_events(events, max), do: Enum.take(events, max)
  defp maybe_filter_type(events, nil), do: events
  defp maybe_filter_type(events, type), do: Enum.filter(events, &(&1.type == type))
end
