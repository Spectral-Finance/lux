defmodule Lux.Web3.Multichain.Aggregator do
  @moduledoc """
  Multi-Chain Data Aggregation and Indexing Engine for EVM-compatible networks (#74).

  Features:
  - Multi-chain block and transaction monitoring and ingestion
  - Smart contract event log aggregation and indexing
  - Normalized in-memory storage with configurable retention policies (TTL and max block depth)
  - Rich querying interface (chain, block range, contracts, topics, addresses)
  - Real-time PubSub event streaming to subscriber processes
  - Prometheus/diagnostic metrics per chain
  """

  use GenServer
  require Logger

  alias Lux.Web3.Multichain.EventFilter
  alias Lux.Web3.Multichain.RpcManager
  alias Lux.Web3.Multichain.Schemas
  alias Lux.Web3.Multichain.Schemas.{Block, Event, Transaction}

  @default_retention %{
    max_blocks_per_chain: 1_000,
    retention_ttl_sec: 86_400
  }

  defstruct [
    :retention,
    blocks: %{},
    transactions: %{},
    events: %{},
    subscribers: %{}
  ]

  # Client API

  @doc """
  Starts the Aggregator GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Ingests a raw or normalized block for a given chain.
  """
  @spec ingest_block(GenServer.server(), atom(), map() | Block.t()) ::
          {:ok, Block.t()} | {:error, term()}
  def ingest_block(server \\ __MODULE__, chain, block_data) when is_atom(chain) do
    GenServer.call(server, {:ingest_block, chain, block_data})
  end

  @doc """
  Ingests a raw or normalized smart contract event.
  """
  @spec ingest_event(GenServer.server(), atom(), map() | Event.t()) ::
          {:ok, Event.t()} | {:error, term()}
  def ingest_event(server \\ __MODULE__, chain, event_data) when is_atom(chain) do
    GenServer.call(server, {:ingest_event, chain, event_data})
  end

  @doc """
  Subscribes the calling process to real-time events.
  Topics can be:
  - `:all`
  - `{:blocks, chain}`
  - `{:events, chain}`
  - `{:events, chain, contract_address}`
  """
  @spec subscribe(GenServer.server(), term()) :: :ok
  def subscribe(server \\ __MODULE__, topic) do
    GenServer.call(server, {:subscribe, self(), topic})
  end

  @doc """
  Unsubscribes the calling process from a topic.
  """
  @spec unsubscribe(GenServer.server(), term()) :: :ok
  def unsubscribe(server \\ __MODULE__, topic) do
    GenServer.call(server, {:unsubscribe, self(), topic})
  end

  @doc """
  Queries aggregated blocks with flexible filters:
  - `:chain`: chain atom
  - `:from_block`: minimum block number
  - `:to_block`: maximum block number
  - `:min_timestamp`: minimum timestamp
  - `:limit`: max results (default 50)
  - `:offset`: pagination offset (default 0)
  """
  @spec query_blocks(GenServer.server(), map()) :: [Block.t()]
  def query_blocks(server \\ __MODULE__, filter \\ %{}) do
    GenServer.call(server, {:query_blocks, filter})
  end

  @doc """
  Queries aggregated transactions with filters:
  - `:chain`: chain atom
  - `:hash`: transaction hash
  - `:from`: sender address
  - `:to`: recipient address
  - `:block_number`: block number
  - `:status`: :success | :reverted
  - `:limit`: max results
  """
  @spec query_transactions(GenServer.server(), map()) :: [Transaction.t()]
  def query_transactions(server \\ __MODULE__, filter \\ %{}) do
    GenServer.call(server, {:query_transactions, filter})
  end

  @doc """
  Queries aggregated contract events with filters:
  - `:chain`: chain atom
  - `:contract_address`: emitting contract
  - `:topic0` or `:event_type`: topic signature
  - `:from_address`, `:to_address`
  - `:from_block`, `:to_block`
  - `:limit`: max results
  """
  @spec query_events(GenServer.server(), map()) :: [Event.t()]
  def query_events(server \\ __MODULE__, filter \\ %{}) do
    GenServer.call(server, {:query_events, filter})
  end

  @doc """
  Returns current engine metrics and index counts.
  """
  @spec get_metrics(GenServer.server()) :: map()
  def get_metrics(server \\ __MODULE__) do
    GenServer.call(server, :get_metrics)
  end

  @doc """
  Manually triggers retention pruning.
  """
  @spec prune(GenServer.server()) :: :ok
  def prune(server \\ __MODULE__) do
    GenServer.call(server, :prune)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    retention = Keyword.get(opts, :retention, @default_retention)
    retention_merged = Map.merge(@default_retention, retention)

    {:ok,
     %__MODULE__{
       retention: retention_merged,
       blocks: %{},
       transactions: %{},
       events: %{},
       subscribers: %{}
     }}
  end

  @impl true
  def handle_call({:ingest_block, chain, raw_or_struct}, _from, state) do
    chain_id =
      case RpcManager.get_chain_id(chain) do
        {:ok, id} -> id
        _ -> 0
      end

    normalized_res =
      case raw_or_struct do
        %Block{} = b -> {:ok, b}
        raw when is_map(raw) -> Schemas.normalize_block(raw, chain, chain_id)
      end

    case normalized_res do
      {:ok, %Block{} = block} ->
        chain_blocks = Map.get(state.blocks, chain, %{})
        updated_chain_blocks = Map.put(chain_blocks, block.number, block)
        updated_blocks = Map.put(state.blocks, chain, updated_chain_blocks)

        # Index transactions
        new_txs =
          Enum.reduce(block.transactions, state.transactions, fn
            %Transaction{} = tx, acc -> Map.put(acc, tx.hash, tx)
            _, acc -> acc
          end)

        # Broadcast to subscribers
        broadcast(state.subscribers, {:new_block, chain, block})

        # Apply retention limit
        pruned_blocks = prune_chain_blocks(updated_blocks, chain, state.retention)

        {:reply, {:ok, block}, %{state | blocks: pruned_blocks, transactions: new_txs}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:ingest_event, chain, raw_or_struct}, _from, state) do
    chain_id =
      case RpcManager.get_chain_id(chain) do
        {:ok, id} -> id
        _ -> 0
      end

    normalized_res =
      case raw_or_struct do
        %Event{} = e -> {:ok, e}
        raw when is_map(raw) -> Schemas.normalize_event(raw, chain, chain_id)
      end

    case normalized_res do
      {:ok, %Event{} = event} ->
        chain_events = Map.get(state.events, chain, [])
        updated_events = Map.put(state.events, chain, [event | chain_events])

        # Broadcast to subscribers
        broadcast(state.subscribers, {:new_event, chain, event})

        {:reply, {:ok, event}, %{state | events: updated_events}}

      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:subscribe, pid, topic}, _from, state) do
    Process.monitor(pid)
    subs = Map.update(state.subscribers, topic, [pid], fn pids -> Enum.uniq([pid | pids]) end)
    {:reply, :ok, %{state | subscribers: subs}}
  end

  @impl true
  def handle_call({:unsubscribe, pid, topic}, _from, state) do
    subs = Map.update(state.subscribers, topic, [], fn pids -> List.delete(pids, pid) end)
    {:reply, :ok, %{state | subscribers: subs}}
  end

  @impl true
  def handle_call({:query_blocks, filter}, _from, state) do
    limit = Map.get(filter, :limit, 50)
    offset = Map.get(filter, :offset, 0)
    target_chain = Map.get(filter, :chain)

    all_blocks =
      if target_chain do
        Map.values(Map.get(state.blocks, target_chain, %{}))
      else
        state.blocks
        |> Map.values()
        |> Enum.flat_map(&Map.values/1)
      end

    filtered =
      all_blocks
      |> Enum.filter(fn b ->
        matches_block_filter?(b, filter)
      end)
      |> Enum.sort_by(& &1.number, :desc)
      |> Enum.slice(offset, limit)

    {:reply, filtered, state}
  end

  @impl true
  def handle_call({:query_transactions, filter}, _from, state) do
    limit = Map.get(filter, :limit, 50)
    offset = Map.get(filter, :offset, 0)

    filtered =
      state.transactions
      |> Map.values()
      |> Enum.filter(fn tx ->
        matches_tx_filter?(tx, filter)
      end)
      |> Enum.sort_by(& &1.block_number, :desc)
      |> Enum.slice(offset, limit)

    {:reply, filtered, state}
  end

  @impl true
  def handle_call({:query_events, filter}, _from, state) do
    limit = Map.get(filter, :limit, 50)
    offset = Map.get(filter, :offset, 0)
    target_chain = Map.get(filter, :chain)

    all_events =
      if target_chain do
        Map.get(state.events, target_chain, [])
      else
        state.events
        |> Map.values()
        |> List.flatten()
      end

    filtered =
      all_events
      |> Enum.filter(fn ev ->
        EventFilter.matches?(ev, filter) and matches_event_block_range?(ev, filter)
      end)
      |> Enum.sort_by(& &1.block_number, :desc)
      |> Enum.slice(offset, limit)

    {:reply, filtered, state}
  end

  @impl true
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      total_chains: map_size(state.blocks),
      total_blocks: Enum.sum(Enum.map(state.blocks, fn {_, b} -> map_size(b) end)),
      total_transactions: map_size(state.transactions),
      total_events: Enum.sum(Enum.map(state.events, fn {_, evs} -> length(evs) end)),
      subscribers_count: Enum.sum(Enum.map(state.subscribers, fn {_, pids} -> length(pids) end))
    }

    {:reply, metrics, state}
  end

  @impl true
  def handle_call(:prune, _from, state) do
    pruned_blocks =
      Enum.reduce(Map.keys(state.blocks), state.blocks, fn chain, acc ->
        prune_chain_blocks(acc, chain, state.retention)
      end)

    {:reply, :ok, %{state | blocks: pruned_blocks}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove dead subscriber from all topics
    updated_subs =
      Enum.into(state.subscribers, %{}, fn {topic, pids} ->
        {topic, List.delete(pids, pid)}
      end)

    {:noreply, %{state | subscribers: updated_subs}}
  end

  # Helpers

  defp matches_block_filter?(block, filter) do
    cond do
      Map.has_key?(filter, :from_block) and block.number < filter.from_block -> false
      Map.has_key?(filter, :to_block) and block.number > filter.to_block -> false
      Map.has_key?(filter, :min_timestamp) and block.timestamp < filter.min_timestamp -> false
      true -> true
    end
  end

  defp matches_tx_filter?(tx, filter) do
    cond do
      Map.has_key?(filter, :chain) and tx.chain != filter.chain -> false
      Map.has_key?(filter, :hash) and tx.hash != String.downcase(filter.hash) -> false
      Map.has_key?(filter, :from) and tx.from != String.downcase(filter.from) -> false
      Map.has_key?(filter, :to) and tx.to != String.downcase(filter.to) -> false
      Map.has_key?(filter, :block_number) and tx.block_number != filter.block_number -> false
      Map.has_key?(filter, :status) and tx.status != filter.status -> false
      true -> true
    end
  end

  defp matches_event_block_range?(event, filter) do
    cond do
      Map.has_key?(filter, :from_block) and event.block_number < filter.from_block -> false
      Map.has_key?(filter, :to_block) and event.block_number > filter.to_block -> false
      true -> true
    end
  end

  defp prune_chain_blocks(blocks, chain, retention) do
    chain_map = Map.get(blocks, chain, %{})
    max_b = retention.max_blocks_per_chain

    if map_size(chain_map) > max_b do
      sorted_keys = Enum.sort(Map.keys(chain_map), :desc)
      kept_keys = Enum.take(sorted_keys, max_b)
      pruned = Map.take(chain_map, kept_keys)
      Map.put(blocks, chain, pruned)
    else
      blocks
    end
  end

  defp broadcast(subscribers, {:new_block, chain, block} = msg) do
    dispatch_to(subscribers, :all, msg)
    dispatch_to(subscribers, {:blocks, chain}, msg)
  end

  defp broadcast(subscribers, {:new_event, chain, event} = msg) do
    dispatch_to(subscribers, :all, msg)
    dispatch_to(subscribers, {:events, chain}, msg)
    dispatch_to(subscribers, {:events, chain, event.contract_address}, msg)
  end

  defp dispatch_to(subscribers, topic, msg) do
    case Map.get(subscribers, topic) do
      nil -> :ok
      pids -> Enum.each(pids, fn pid -> send(pid, msg) end)
    end
  end
end
