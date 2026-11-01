defmodule Lux.Web3.EventMonitor.SubscriptionManager do
  @moduledoc """
  GenServer for managing smart contract event subscriptions (#75).

  Maintains active subscriptions, enables dynamic filtering, and matches incoming
  logs against subscriber rules across multiple blockchain networks.
  """

  use GenServer
  alias Lux.Web3.EventMonitor.Schemas.Subscription
  alias Lux.Web3.EventMonitor.FilterEngine

  @type state :: %{
          subscriptions: %{String.t() => Subscription.t()}
        }

  # --- Client API ---

  @doc """
  Starts the SubscriptionManager GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a new event subscription.
  """
  @spec create_subscription(GenServer.server(), map()) :: {:ok, Subscription.t()} | {:error, term()}
  def create_subscription(server \\ __MODULE__, attrs) do
    GenServer.call(server, {:create_subscription, attrs})
  end

  @doc """
  Retrieves a subscription by its unique ID.
  """
  @spec get_subscription(GenServer.server(), String.t()) :: {:ok, Subscription.t()} | {:error, :not_found}
  def get_subscription(server \\ __MODULE__, id) do
    GenServer.call(server, {:get_subscription, id})
  end

  @doc """
  Lists all subscriptions with optional filtering.
  """
  @spec list_subscriptions(GenServer.server(), map()) :: [Subscription.t()]
  def list_subscriptions(server \\ __MODULE__, filters \\ %{}) do
    GenServer.call(server, {:list_subscriptions, filters})
  end

  @doc """
  Pauses an active subscription without deleting it.
  """
  @spec pause_subscription(GenServer.server(), String.t()) :: {:ok, Subscription.t()} | {:error, term()}
  def pause_subscription(server \\ __MODULE__, id) do
    GenServer.call(server, {:set_status, id, :paused})
  end

  @doc """
  Resumes a paused subscription.
  """
  @spec resume_subscription(GenServer.server(), String.t()) :: {:ok, Subscription.t()} | {:error, term()}
  def resume_subscription(server \\ __MODULE__, id) do
    GenServer.call(server, {:set_status, id, :active})
  end

  @doc """
  Deletes a subscription by ID.
  """
  @spec delete_subscription(GenServer.server(), String.t()) :: :ok | {:error, :not_found}
  def delete_subscription(server \\ __MODULE__, id) do
    GenServer.call(server, {:delete_subscription, id})
  end

  @doc """
  Updates the last processed block number for a subscription.
  """
  @spec update_processed_block(GenServer.server(), String.t(), non_neg_integer()) :: :ok
  def update_processed_block(server \\ __MODULE__, id, block_number) do
    GenServer.cast(server, {:update_processed_block, id, block_number})
  end

  @doc """
  Finds all active subscriptions that match a given monitored event.
  """
  @spec match_event(GenServer.server(), map()) :: [Subscription.t()]
  def match_event(server \\ __MODULE__, event) do
    GenServer.call(server, {:match_event, event})
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %{subscriptions: %{}}}
  end

  @impl true
  def handle_call({:create_subscription, attrs}, _from, state) do
    id = attrs[:id] || attrs["id"] || generate_id()
    now = System.system_time(:second)

    contract =
      case attrs[:contract_address] || attrs["contract_address"] do
        list when is_list(list) -> Enum.map(list, &String.downcase(to_string(&1)))
        addr when is_binary(addr) -> String.downcase(addr)
        _ -> nil
      end

    sub = %Subscription{
      id: id,
      name: attrs[:name] || attrs["name"],
      chain_id: attrs[:chain_id] || attrs["chain_id"] || 1,
      chain: attrs[:chain] || attrs["chain"] || :ethereum,
      contract_address: contract,
      event_name: attrs[:event_name] || attrs["event_name"],
      event_signature: attrs[:event_signature] || attrs["event_signature"],
      topic0: attrs[:topic0] || attrs["topic0"],
      topics: attrs[:topics] || attrs["topics"] || [],
      filter_pattern: attrs[:filter_pattern] || attrs["filter_pattern"] || %{},
      webhook_url: attrs[:webhook_url] || attrs["webhook_url"],
      webhook_secret: attrs[:webhook_secret] || attrs["webhook_secret"],
      status: :active,
      start_block: attrs[:start_block] || attrs["start_block"],
      last_processed_block: attrs[:start_block] || attrs["start_block"],
      created_at: now,
      updated_at: now
    }

    new_subs = Map.put(state.subscriptions, id, sub)
    {:reply, {:ok, sub}, %{state | subscriptions: new_subs}}
  end

  @impl true
  def handle_call({:get_subscription, id}, _from, state) do
    case Map.get(state.subscriptions, id) do
      nil -> {:reply, {:error, :not_found}, state}
      sub -> {:reply, {:ok, sub}, state}
    end
  end

  @impl true
  def handle_call({:list_subscriptions, filters}, _from, state) do
    subs =
      state.subscriptions
      |> Map.values()
      |> Enum.filter(fn sub ->
        chain_match = is_nil(filters[:chain]) or sub.chain == filters[:chain]
        status_match = is_nil(filters[:status]) or sub.status == filters[:status]
        contract_match =
          case filters[:contract_address] do
            nil -> true
            addr -> String.downcase(to_string(addr)) == sub.contract_address
          end

        chain_match and status_match and contract_match
      end)

    {:reply, subs, state}
  end

  @impl true
  def handle_call({:set_status, id, status}, _from, state) do
    case Map.get(state.subscriptions, id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      sub ->
        updated = %{sub | status: status, updated_at: System.system_time(:second)}
        new_subs = Map.put(state.subscriptions, id, updated)
        {:reply, {:ok, updated}, %{state | subscriptions: new_subs}}
    end
  end

  @impl true
  def handle_call({:delete_subscription, id}, _from, state) do
    if Map.has_key?(state.subscriptions, id) do
      new_subs = Map.delete(state.subscriptions, id)
      {:reply, :ok, %{state | subscriptions: new_subs}}
    else
      {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:match_event, event}, _from, state) do
    matched =
      state.subscriptions
      |> Map.values()
      |> Enum.filter(fn sub ->
        sub.status == :active and FilterEngine.matches?(event, sub)
      end)

    {:reply, matched, state}
  end

  @impl true
  def handle_cast({:update_processed_block, id, block_number}, state) do
    case Map.get(state.subscriptions, id) do
      nil ->
        {:noreply, state}

      sub ->
        updated = %{sub | last_processed_block: block_number, updated_at: System.system_time(:second)}
        new_subs = Map.put(state.subscriptions, id, updated)
        {:noreply, %{state | subscriptions: new_subs}}
    end
  end

  defp generate_id do
    "sub_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end
end
