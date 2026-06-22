defmodule Lux.Web3.Events.Monitor do
  @moduledoc """
  Real-time event monitoring supervisor and coordinator.

  Spawns individual monitor processes for each active subscription,
  handling polling, event filtering, decoding, persistence, and
  webhook dispatching in a fault-tolerant OTP tree.
  """

  use Supervisor

  @poll_interval_default 5_000  # ms
  @max_poll_interval 60_000

  # Client API

  @doc """
  Starts the monitor supervisor.
  """
  @spec start_link([{:store, atom()}, {:manager, atom()}]) :: Supervisor.on_start()
  def start_link(opts \ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Starts monitoring a subscription.
  """
  @spec start_monitor(Lux.Web3.Events.Subscription.t()) :: {:ok, pid()} | {:error, term()}
  def start_monitor(sub) do
    Supervisor.start_child(__MODULE__, [sub])
  end

  @doc """
  Stops monitoring a subscription by PID.
  """
  @spec stop_monitor(pid()) :: :ok
  def stop_monitor(pid) do
    Supervisor.stop(pid)
  end

  @doc """
  Lists all active monitor PIDs.
  """
  @spec list_monitors() :: [pid()]
  def list_monitors() do
    __MODULE__
    |> Supervisor.which_children()
    |> Enum.map(fn {_, pid, _, _} -> pid end)
    |> Enum.filter(&is_pid/1)
  end

  @doc """
  Checks if a subscription is being monitored.
  """
  @spec is_monitoring?(String.t()) :: boolean()
  def is_monitoring?(subscription_id) do
    monitors = list_monitors()
    Enum.any?(monitors, fn pid ->
      try do
        GenServer.call(pid, :status) |> Map.get(:subscription_id) == subscription_id
      rescue
        _ -> false
      end
    end)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    store = opts[:store] || Lux.Web3.Events.Store
    manager = opts[:manager] || Lux.Web3.Events.Manager

    children = [
      {store, []},
      {manager, []},
      {self(), []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @impl true
  def init(subscription) do
    store = Lux.Web3.Events.Store
    webhook_url = subscription.webhook_url

    children = [
      # The monitor process itself
      {__MODULE__, [subscription, store, webhook_url]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end

# The actual monitor worker process
defmodule Lux.Web3.Events.Monitor.Worker do
  @moduledoc false
  use GenServer

  @tick :monitor_tick

  def start_link([sub, store, webhook_url]) do
    GenServer.start_link(__MODULE__, [sub, store, webhook_url])
  end

  @impl true
  def init([sub, store, webhook_url]) do
    Process.send_after(self(), @tick, sub.poll_interval_ms)
    {:ok, %{subscription: sub, store: store, webhook_url: webhook_url, polls: 0}}
  end

  @impl true
  def handle_info(@tick, state) do
    # Reset timer
    Process.send_after(self(), @tick, state.subscription.poll_interval_ms)

    # Poll for new events
    case Lux.Web3.Events.Sync.poll_new_events(state.subscription) do
      {:ok, events} when length(events) > 0 ->
        # Save to persistence
        state.store.save_events(events)

        # Dispatch webhooks
        if state.webhook_url do
          Lux.Web3.Events.Webhook.notify(
            state.webhook_url,
            List.first(events),
            state.subscription
          )
        end

        # Update subscription sync point
        max_block = Enum.max_by(events, & &1.block_number).block_number
        Lux.Web3.Events.Manager.update_synced_block(state.subscription.id, max_block)

        {:noreply, %{state | polls: state.polls + 1, new_events: length(events)}}

      {:ok, []} ->
        {:noreply, %{state | polls: state.polls + 1}}

      {:error, reason} ->
        # Log error but keep monitoring alive
        Logger.error("Monitor error for subscription #{state.subscription.id}: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, %{subscription_id: state.subscription.id, polls: state.polls}, state}
  end
end
