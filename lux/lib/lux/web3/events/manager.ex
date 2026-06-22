defmodule Lux.Web3.Events.Manager do
  @moduledoc """
  Manages contract event subscriptions.

  Provides in-memory subscription storage with CRUD operations,
  pattern matching, and lifecycle management for event monitoring.
  """

  use GenServer

  @type subscription_opts ::
          {:chain_id, pos_integer()}
          | {:contract, String.t()}
          | {:events, [String.t()]}
          | {:poll_interval, pos_integer()}
          | {:webhook_url, String.t() | nil}

  # Client API

  @doc """
  Starts the subscription manager.
  """
  @spec start_link([]) :: GenServer.on_start()
  def start_link(opts \ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a new event subscription.
  """
  @spec subscribe(GenServer.server(), subscription_opts()) ::
          {:ok, Lux.Web3.Events.Subscription.t()} | {:error, term()}
  def subscribe(server \ __MODULE__, opts) do
    sub = Lux.Web3.Events.Subscription.new(opts)
    GenServer.call(server, {:subscribe, sub})
  end

  @doc """
  Unregisters a subscription by ID.
  """
  @spec unsubscribe(GenServer.server(), String.t()) :: :ok | {:error, term()}
  def unsubscribe(server \ __MODULE__, subscription_id) do
    GenServer.call(server, {:unsubscribe, subscription_id})
  end

  @doc """
  Returns all active subscriptions.
  """
  @spec list_subscriptions(GenServer.server()) :: [Lux.Web3.Events.Subscription.t()]
  def list_subscriptions(server \ __MODULE__) do
    GenServer.call(server, {:list})
  end

  @doc """
  Returns all enabled subscriptions for a given contract.
  """
  @spec get_subscriptions_for(GenServer.server(), String.t()) ::
          [Lux.Web3.Events.Subscription.t()]
  def get_subscriptions_for(server \ __MODULE__, contract_address) do
    GenServer.call(server, {:for_contract, contract_address})
  end

  @doc """
  Checks if a topic matches any active subscription.
  """
  @spec matches_subscription?(GenServer.server(), String.t(), String.t()) :: boolean()
  def matches_subscription?(server \ __MODULE__, chain_id, topic0) do
    subs = GenServer.call(server, {:list})
    Enum.any?(subs, fn sub ->
      sub.enabled and sub.chain_id == chain_id and
        Lux.Web3.Events.Subscription.topic_matches?(sub, topic0)
    end)
  end

  @doc """
  Updates the last synced block for a subscription.
  """
  @spec update_synced_block(GenServer.server(), String.t(), non_neg_integer()) :: :ok
  def update_synced_block(server \ __MODULE__, subscription_id, block_number) do
    GenServer.call(server, {:update_block, subscription_id, block_number})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    state = %{subscriptions: %{}, opts: opts}
    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, sub}, _from, state) do
    existing = Map.get(state.subscriptions, sub.id)

    if existing and existing.contract_address == sub.contract_address and
         existing.event_signatures == sub.event_signatures do
      {:reply, {:error, :duplicate}, state}
    else
      new_state = Map.put(state.subscriptions, sub.id, sub)
      {:reply, {:ok, sub}, new_state}
    end
  end

  def handle_call({:unsubscribe, id}, _from, state) do
    case Map.pop(state.subscriptions, id) do
      {nil, _} -> {:reply, {:error, :not_found}, state}
      {_sub, new_state} -> {:reply, :ok, new_state}
    end
  end

  def handle_call({:list}, _from, state) do
    {:reply, Map.values(state.subscriptions), state}
  end

  def handle_call({:for_contract, address}, _from, state) do
    result =
      state.subscriptions
      |> Map.values()
      |> Enum.filter(&(&1.contract_address == address))

    {:reply, result, state}
  end

  def handle_call({:update_block, id, block}, _from, state) do
    case Map.get(state.subscriptions, id) do
      nil ->
        {:reply, :ok, state}

      sub ->
        updated = Lux.Web3.Events.Subscription.mark_synced(sub, block)
        new_state = Map.put(state.subscriptions, id, updated)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_info(:sync, state) do
    subs = Map.values(state.subscriptions) |> Enum.filter(& &1.enabled)

    Task.Supervisor.async_many(
      Lux.ScheduledTasksSupervisor,
      subs,
      fn sub ->
        Lux.Web3.Events.Sync.poll_new_events(sub)
      end,
      timeout: 30_000
    )

    {:noreply, state}
  end
end
