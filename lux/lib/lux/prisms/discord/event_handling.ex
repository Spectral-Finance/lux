defmodule Lux.Prisms.Discord.EventHandling do
  @moduledoc """
  Event scheduling, reminders, and notification management for Discord.
  """

  use GenServer

  defstruct [:events, :reminders, :notifications]

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def create_event(pid \\ __MODULE__, params) do
    GenServer.call(pid, {:create_event, params})
  end

  def cancel_event(pid \\ __MODULE__, event_id) do
    GenServer.call(pid, {:cancel_event, event_id})
  end

  def list_events(pid \\ __MODULE__, opts \\ %{}) do
    GenServer.call(pid, {:list_events, opts})
  end

  def get_event(pid \\ __MODULE__, event_id) do
    GenServer.call(pid, {:get_event, event_id})
  end

  def add_reminder(pid \\ __MODULE__, event_id, minutes_before) do
    GenServer.call(pid, {:add_reminder, event_id, minutes_before})
  end

  def get_due_reminders(pid \\ __MODULE__) do
    GenServer.call(pid, :get_due_reminders)
  end

  def rsvp(pid \\ __MODULE__, event_id, user_id, status) do
    GenServer.call(pid, {:rsvp, event_id, user_id, status})
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{events: %{}, reminders: [], notifications: []}}
  end

  @impl true
  def handle_call({:create_event, params}, _from, state) do
    id = params[:id] || gen_id()
    event = %{
      id: id,
      name: params[:name],
      description: params[:description] || "",
      channel_id: params[:channel_id],
      guild_id: params[:guild_id],
      start_time: params[:start_time],
      end_time: params[:end_time],
      rsvps: %{},
      status: :scheduled,
      created_at: DateTime.utc_now()
    }
    {:reply, {:ok, event}, %{state | events: Map.put(state.events, id, event)}}
  end

  @impl true
  def handle_call({:cancel_event, event_id}, _from, state) do
    case Map.get(state.events, event_id) do
      nil -> {:reply, {:error, :not_found}, state}
      event ->
        updated = %{event | status: :cancelled}
        {:reply, :ok, %{state | events: Map.put(state.events, event_id, updated)}}
    end
  end

  @impl true
  def handle_call({:list_events, opts}, _from, state) do
    events = Map.values(state.events)
    events = if opts[:status], do: Enum.filter(events, &(&1.status == opts[:status])), else: events
    {:reply, {:ok, Enum.sort_by(events, & &1.start_time, DateTime)}, state}
  end

  @impl true
  def handle_call({:get_event, event_id}, _from, state) do
    case Map.get(state.events, event_id) do
      nil -> {:reply, {:error, :not_found}, state}
      event -> {:reply, {:ok, event}, state}
    end
  end

  @impl true
  def handle_call({:add_reminder, event_id, minutes_before}, _from, state) do
    case Map.get(state.events, event_id) do
      nil -> {:reply, {:error, :not_found}, state}
      event ->
        remind_at = DateTime.add(event.start_time, -minutes_before * 60)
        reminder = %{event_id: event_id, remind_at: remind_at, sent: false}
        {:reply, {:ok, reminder}, %{state | reminders: [reminder | state.reminders]}}
    end
  end

  @impl true
  def handle_call(:get_due_reminders, _from, state) do
    now = DateTime.utc_now()
    {due, remaining} = Enum.split_with(state.reminders, fn r ->
      !r.sent && DateTime.compare(r.remind_at, now) in [:lt, :eq]
    end)
    marked = Enum.map(due, &%{&1 | sent: true})
    {:reply, {:ok, due}, %{state | reminders: marked ++ remaining}}
  end

  @impl true
  def handle_call({:rsvp, event_id, user_id, status}, _from, state) do
    case Map.get(state.events, event_id) do
      nil -> {:reply, {:error, :not_found}, state}
      event ->
        updated = %{event | rsvps: Map.put(event.rsvps, user_id, status)}
        {:reply, {:ok, %{user_id: user_id, status: status}},
         %{state | events: Map.put(state.events, event_id, updated)}}
    end
  end

  defp gen_id, do: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
end
