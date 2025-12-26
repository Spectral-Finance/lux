defmodule Lux.TwitterAutomation.Scheduler do
  @moduledoc """
  Schedules tweets and actions for future execution.

  Features:
  - Schedule tweets at specific times
  - Persistent storage via ETS
  - Automatic rescheduling on restart
  - Cancel/reschedule support
  """

  use GenServer
  require Logger

  alias Lux.TwitterAutomation.{Storage, QueueManager}

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Schedule a tweet"
  def schedule_tweet(content, scheduled_time, opts \\ %{}) do
    GenServer.call(__MODULE__, {:schedule_tweet, content, scheduled_time, opts})
  end

  @doc "Schedule any action"
  def schedule_action(action_type, payload, scheduled_time, opts \\ %{}) do
    GenServer.call(__MODULE__, {:schedule_action, action_type, payload, scheduled_time, opts})
  end

  @doc "Cancel scheduled item"
  def cancel_scheduled(id) do
    GenServer.call(__MODULE__, {:cancel_scheduled, id})
  end

  @doc "List scheduled items"
  def list_scheduled(opts \\ %{}) do
    GenServer.call(__MODULE__, {:list_scheduled, opts})
  end

  @doc "Reschedule an item"
  def reschedule(id, new_time) do
    GenServer.call(__MODULE__, {:reschedule, id, new_time})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Restore scheduled items from ETS and set timers
    {:ok, pending_items} = Storage.get_scheduled_by_status(:pending)

    timers =
      Enum.reduce(pending_items, %{}, fn item, acc ->
        case schedule_timer(item) do
          {:ok, timer_ref} -> Map.put(acc, item.id, timer_ref)
          _ -> acc
        end
      end)

    Logger.info("Scheduler initialized with #{map_size(timers)} pending items")

    {:ok, %{timers: timers}}
  end

  @impl true
  def handle_call({:schedule_tweet, content, scheduled_time, opts}, _from, state) do
    item = %{
      id: generate_id(),
      action_type: :create_tweet,
      payload: Map.merge(%{text: content}, opts),
      scheduled_time: scheduled_time,
      status: :pending,
      created_at: DateTime.utc_now(),
      metadata: opts[:metadata] || %{}
    }

    Storage.store_scheduled_item(item)

    case schedule_timer(item) do
      {:ok, timer_ref} ->
        new_timers = Map.put(state.timers, item.id, timer_ref)
        Logger.info("Scheduled tweet #{item.id} for #{scheduled_time}")
        {:reply, {:ok, item.id}, %{state | timers: new_timers}}

      {:error, reason} ->
        Storage.delete_scheduled_item(item.id)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:schedule_action, action_type, payload, scheduled_time, opts}, _from, state) do
    item = %{
      id: generate_id(),
      action_type: action_type,
      payload: payload,
      scheduled_time: scheduled_time,
      status: :pending,
      created_at: DateTime.utc_now(),
      metadata: opts[:metadata] || %{}
    }

    Storage.store_scheduled_item(item)

    case schedule_timer(item) do
      {:ok, timer_ref} ->
        new_timers = Map.put(state.timers, item.id, timer_ref)
        Logger.info("Scheduled #{action_type} #{item.id} for #{scheduled_time}")
        {:reply, {:ok, item.id}, %{state | timers: new_timers}}

      {:error, reason} ->
        Storage.delete_scheduled_item(item.id)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:cancel_scheduled, id}, _from, state) do
    case Map.get(state.timers, id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      timer_ref ->
        Process.cancel_timer(timer_ref)
        Storage.update_item_status(id, :cancelled)
        new_timers = Map.delete(state.timers, id)
        Logger.info("Cancelled scheduled item #{id}")
        {:reply, :ok, %{state | timers: new_timers}}
    end
  end

  @impl true
  def handle_call({:list_scheduled, opts}, _from, state) do
    result =
      case opts[:status] do
        nil -> Storage.get_scheduled_by_status(:pending)
        status -> Storage.get_scheduled_by_status(status)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:reschedule, id, new_time}, _from, state) do
    with {:ok, item} <- Storage.get_scheduled_item(id),
         :ok <- cancel_timer(state.timers[id]),
         updated_item <- %{item | scheduled_time: new_time, status: :pending},
         :ok <- Storage.store_scheduled_item(updated_item),
         {:ok, new_timer_ref} <- schedule_timer(updated_item) do
      new_timers = Map.put(state.timers, id, new_timer_ref)
      Logger.info("Rescheduled item #{id} to #{new_time}")
      {:reply, :ok, %{state | timers: new_timers}}
    else
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_info({:execute, item_id}, state) do
    case Storage.get_scheduled_item(item_id) do
      {:ok, item} ->
        execute_scheduled_item(item)
        new_timers = Map.delete(state.timers, item_id)
        {:noreply, %{state | timers: new_timers}}

      _ ->
        {:noreply, state}
    end
  end

  ## Private Functions

  defp schedule_timer(item) do
    now = DateTime.utc_now()
    delay_ms = DateTime.diff(item.scheduled_time, now, :millisecond)

    cond do
      delay_ms < 0 ->
        # Already past, execute immediately
        execute_scheduled_item(item)
        {:ok, nil}

      delay_ms > :timer.hours(24 * 365) ->
        # More than 1 year in future - Erlang timer limit
        {:error, :too_far_in_future}

      true ->
        timer_ref = Process.send_after(self(), {:execute, item.id}, delay_ms)
        {:ok, timer_ref}
    end
  end

  defp cancel_timer(nil), do: :ok
  defp cancel_timer(timer_ref) do
    Process.cancel_timer(timer_ref)
    :ok
  end

  defp execute_scheduled_item(item) do
    Logger.info("Executing scheduled item #{item.id}")

    # Enqueue to QueueManager for rate-limited execution
    case QueueManager.enqueue(item.action_type, item.payload, :high) do
      {:ok, _queue_id} ->
        Storage.update_item_status(item.id, :queued)

      {:error, error} ->
        Logger.error("Failed to enqueue scheduled item: #{inspect(error)}")
        Storage.update_item_status(item.id, :failed)
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
