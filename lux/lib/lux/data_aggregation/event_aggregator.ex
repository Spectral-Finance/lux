defmodule Lux.DataAggregation.EventAggregator do
  @moduledoc """
  Aggregates and processes smart contract events across multiple chains.

  ## Features
  - Event log fetching with configurable filters
  - Event decoding using ABI definitions
  - Event indexing for efficient querying
  - Real-time event streaming
  - Cross-chain event correlation
  """

  use GenServer

  alias Lux.DataAggregation.{RPCManager, DataStore, Streamer}

  @poll_interval 30_000
  @max_logs_per_request 1000

  defstruct [
    :chain,
    :contracts,
    :last_processed_block,
    :poll_timer
  ]

  def start_link(opts) do
    chains = Keyword.get(opts, :chains, [:ethereum, :polygon, :bsc])
    GenServer.start_link(__MODULE__, chains, name: __MODULE__)
  end

  @impl true
  def init(chains) do
    aggregators =
      chains
      |> Enum.map(&init_chain_aggregator/1)
      |> Map.new()

    schedule_poll()

    {:ok, %{aggregators: aggregators, subscriptions: %{}}}
  end

  defp init_chain_aggregator(chain) do
    {chain, %{
      chain: chain,
      contracts: %{},
      last_processed_block: nil,
      active: true
    }}
  end

  @doc """
  Register a contract for event monitoring.
  """
  def register_contract(chain, contract_address, abi \\ nil, topics \\ []) do
    GenServer.call(__MODULE__, {:register_contract, chain, contract_address, abi, topics})
  end

  @doc """
  Unregister a contract from event monitoring.
  """
  def unregister_contract(chain, contract_address) do
    GenServer.call(__MODULE__, {:unregister_contract, chain, contract_address})
  end

  @doc """
  Fetch historical events for a contract.
  """
  def fetch_events(chain, contract_address, from_block, to_block, topics \\ []) do
    GenServer.call(__MODULE__, {:fetch_events, chain, contract_address, from_block, to_block, topics})
  end

  @doc """
  Query indexed events.
  """
  def query_events(chain, contract_address, opts \\ []) do
    DataStore.query_events(chain, contract_address, opts)
  end

  @impl true
  def handle_call({:register_contract, chain, contract_address, abi, topics}, _from, state) do
    case Map.get(state.aggregators, chain) do
      nil ->
        {:reply, {:error, :unsupported_chain}, state}

      aggregator ->
        contract_key = String.downcase(contract_address)
        new_contracts = Map.put(aggregator.contracts, contract_key, %{
          address: contract_address,
          abi: abi,
          topics: topics,
          registered_at: DateTime.utc_now()
        })

        new_aggregator = %{aggregator | contracts: new_contracts}
        new_state = %{state | aggregators: Map.put(state.aggregators, chain, new_aggregator)}

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:unregister_contract, chain, contract_address}, _from, state) do
    case Map.get(state.aggregators, chain) do
      nil ->
        {:reply, {:error, :unsupported_chain}, state}

      aggregator ->
        contract_key = String.downcase(contract_address)
        new_contracts = Map.delete(aggregator.contracts, contract_key)
        new_aggregator = %{aggregator | contracts: new_contracts}
        new_state = %{state | aggregators: Map.put(state.aggregators, chain, new_aggregator)}

        {:reply, :ok, new_state}
    end
  end

  def handle_call({:fetch_events, chain, contract_address, from_block, to_block, topics}, _from, state) do
    case Map.get(state.aggregators, chain) do
      nil ->
        {:reply, {:error, :unsupported_chain}, state}

      _aggregator ->
        filter = build_event_filter(contract_address, from_block, to_block, topics)

        case RPCManager.get_logs(chain, filter) do
          {:ok, logs} ->
            # Process and store logs
            processed_logs = Enum.map(logs, &process_log(&1, chain, contract_address))
            Enum.each(processed_logs, &DataStore.store_event(&1))

            {:reply, {:ok, processed_logs}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  defp build_event_filter(contract_address, from_block, to_block, topics) do
    from_hex = if is_integer(from_block), do: "0x" <> Integer.to_string(from_block, 16), else: from_block
    to_hex = if is_integer(to_block), do: "0x" <> Integer.to_string(to_block, 16), else: to_block

    filter = %{
      address: contract_address,
      fromBlock: from_hex,
      toBlock: to_hex
    }

    if topics != [] do
      Map.put(filter, :topics, topics)
    else
      filter
    end
  end

  defp process_log(log, chain, contract_address) do
    %{
      chain: chain,
      contract_address: contract_address,
      transaction_hash: log["transactionHash"],
      log_index: log["logIndex"],
      block_number: parse_hex(log["blockNumber"]),
      block_hash: log["blockHash"],
      address: log["address"] || contract_address,
      topics: log["topics"] || [],
      data: log["data"],
      removed: log["removed"] || false,
      processed_at: DateTime.utc_now()
    }
  end

  defp parse_hex(nil), do: 0
  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(hex) when is_integer(hex), do: hex
  defp parse_hex(_), do: 0

  @impl true
  def handle_info(:poll, state) do
    new_aggregators =
      state.aggregators
      |> Map.new(fn {chain, aggregator} ->
        if aggregator.active and map_size(aggregator.contracts) > 0 do
          case poll_events(chain, aggregator) do
            {:ok, new_last_block} ->
              new_aggregator = %{aggregator | last_processed_block: new_last_block}
              {chain, new_aggregator}

            {:error, _} ->
              {chain, aggregator}
          end
        else
          {chain, aggregator}
        end
      end)

    schedule_poll()
    {:noreply, %{state | aggregators: new_aggregators}}
  end

  defp poll_events(chain, aggregator) do
    # Get current block
    case RPCManager.get_block_number(chain) do
      {:ok, hex_block} ->
        current_block = parse_hex(hex_block)
        from_block = aggregator.last_processed_block || current_block - 100

        # Fetch events for all registered contracts
        results =
          aggregator.contracts
          |> Map.values()
          |> Enum.flat_map(fn contract ->
            filter = build_event_filter(
              contract.address,
              from_block,
              current_block,
              contract.topics
            )

            case RPCManager.get_logs(chain, filter) do
              {:ok, logs} ->
                Enum.map(logs, &process_log(&1, chain, contract.address))

              _ ->
                []
            end
          end)

        # Store events
        Enum.each(results, &DataStore.store_event(&1))

        # Broadcast events
        Enum.each(results, fn event ->
          Streamer.broadcast_event(event.chain, event.contract_address, event)
        end)

        {:ok, current_block}

      error ->
        error
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  @doc """
  Returns event aggregation status.
  """
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @impl true
  def handle_call(:status, _from, state) do
    status =
      state.aggregators
      |> Map.new(fn {chain, aggregator} ->
        {chain, %{
          active: aggregator.active,
          registered_contracts: map_size(aggregator.contracts),
          last_processed_block: aggregator.last_processed_block
        }}
      end)

    {:reply, status, state}
  end
end
