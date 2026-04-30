defmodule Lux.DataAggregation.DataStore do
  @moduledoc """
  Efficient data storage and retrieval for aggregated blockchain data.

  ## Features
  - In-memory ETS tables for fast access
  - Configurable data retention policies
  - Indexed queries for blocks, transactions, and events
  - Automatic cleanup of expired data
  """

  use GenServer

  @blocks_table :da_blocks
  @transactions_table :da_transactions
  @events_table :da_events
  @stats_table :da_stats
  @default_retention_hours 24
  @cleanup_interval :timer.hours(1)

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Create ETS tables
    @blocks_table = :ets.new(@blocks_table, [:set, :public, :named_table, write_concurrency: true])
    @transactions_table = :ets.new(@transactions_table, [:set, :public, :named_table, write_concurrency: true])
    @events_table = :ets.new(@events_table, [:set, :public, :named_table, write_concurrency: true])
    @stats_table = :ets.new(@stats_table, [:set, :public, :named_table, write_concurrency: true])

    # Create indexes
    :ets.new(:da_blocks_by_chain, [:bag, :public, :named_table])
    :ets.new(:da_transactions_by_block, [:bag, :public, :named_table])
    :ets.new(:da_transactions_by_hash, [:bag, :public, :named_table])
    :ets.new(:da_events_by_contract, [:bag, :public, :named_table])
    :ets.new(:da_events_by_block, [:bag, :public, :named_table])

    schedule_cleanup()

    {:ok, %{
      retention_hours: @default_retention_hours,
      cleanup_timer: nil,
      stats: %{
        blocks_stored: 0,
        transactions_stored: 0,
        events_stored: 0
      }
    }}
  end

  @doc """
  Store a block.
  """
  def store_block(chain, block, block_number) do
    block_key = {chain, block_number}
    block_data = %{
      chain: chain,
      number: block_number,
      hash: block["hash"],
      parent_hash: block["parentHash"],
      timestamp: parse_hex(block["timestamp"]),
      gas_used: parse_hex(block["gasUsed"]),
      gas_limit: parse_hex(block["gasLimit"]),
      base_fee_per_gas: block["baseFeePerGas"] && parse_hex(block["baseFeePerGas"]),
      transaction_count: length(block["transactions"] || []),
      miner: block["miner"],
      size: parse_hex(block["size"]),
      stored_at: DateTime.utc_now() |> DateTime.to_unix()
    }

    :ets.insert(@blocks_table, {block_key, block_data})
    :ets.insert(:da_blocks_by_chain, {chain, block_number})

    # Update stats
    update_stats(:blocks_stored, 1)

    :ok
  end

  @doc """
  Store a transaction.
  """
  def store_transaction(chain, tx, block_number) do
    tx_hash = tx["hash"]

    tx_data = %{
      chain: chain,
      hash: tx_hash,
      block_number: block_number,
      block_hash: tx["blockHash"],
      from: tx["from"],
      to: tx["to"],
      value: parse_hex(tx["value"]),
      gas: parse_hex(tx["gas"]),
      gas_price: parse_hex(tx["gasPrice"]),
      max_fee_per_gas: tx["maxFeePerGas"] && parse_hex(tx["maxFeePerGas"]),
      max_priority_fee_per_gas: tx["maxPriorityFeePerGas"] && parse_hex(tx["maxPriorityFeePerGas"]),
      input: tx["input"],
      nonce: parse_hex(tx["nonce"]),
      transaction_index: parse_hex(tx["transactionIndex"]),
      stored_at: DateTime.utc_now() |> DateTime.to_unix()
    }

    :ets.insert(@transactions_table, {{chain, tx_hash}, tx_data})
    :ets.insert(:da_transactions_by_block, {{chain, block_number}, tx_hash})
    :ets.insert(:da_transactions_by_hash, {tx_hash, {chain, block_number}})

    update_stats(:transactions_stored, 1)

    :ok
  end

  @doc """
  Store an event.
  """
  def store_event(event) do
    event_key = {event.chain, event.contract_address, event.transaction_hash, event.log_index}

    event_data = %{
      chain: event.chain,
      contract_address: event.contract_address,
      transaction_hash: event.transaction_hash,
      log_index: event.log_index,
      block_number: event.block_number,
      block_hash: event.block_hash,
      address: event.address,
      topics: event.topics,
      data: event.data,
      removed: event.removed,
      stored_at: DateTime.utc_now() |> DateTime.to_unix()
    }

    :ets.insert(@events_table, {event_key, event_data})
    :ets.insert(:da_events_by_contract, {{event.chain, event.contract_address}, event_key})
    :ets.insert(:da_events_by_block, {{event.chain, event.block_number}, event_key})

    update_stats(:events_stored, 1)

    :ok
  end

  @doc """
  Query blocks for a chain.
  """
  def query_blocks(chain, opts \\ []) do
    from = Keyword.get(opts, :from, 0)
    to = Keyword.get(opts, :to, :infinity)
    limit = Keyword.get(opts, :limit, 100)

    chain_blocks = :ets.match_object(:da_blocks_by_chain, {chain, :_})

    chain_blocks
    |> Enum.map(fn {_, block_num} -> block_num end)
    |> Enum.filter(fn num -> num >= from and (to == :infinity or num <= to) end)
    |> Enum.sort(:desc)
    |> Enum.take(limit)
    |> Enum.map(fn num ->
      case :ets.lookup(@blocks_table, {chain, num}) do
        [{_, data}] -> data
        [] -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  @doc """
  Query transactions for a chain.
  """
  def query_transactions(chain, opts \\ []) do
    block_number = Keyword.get(opts, :block_number)
    from_address = Keyword.get(opts, :from)
    limit = Keyword.get(opts, :limit, 100)

    results =
      cond do
        block_number ->
          :ets.match_object(:da_transactions_by_block, {{chain, block_number}, :_})
          |> Enum.map(fn {_, tx_hash} -> lookup_transaction(chain, tx_hash) end)

        from_address ->
          # Full scan with filter (for large datasets, consider adding an index)
          :ets.match_object(@transactions_table, :_)
          |> Enum.filter(fn {{^chain, _}, tx} -> tx.from == from_address end)
          |> Enum.map(fn {_, tx} -> tx end)

        true ->
          :ets.match_object(@transactions_table, :_)
          |> Enum.filter(fn {{^chain, _}, _} -> true end)
          |> Enum.map(fn {_, tx} -> tx end)
      end

    results
    |> Enum.filter(& &1)
    |> Enum.take(limit)
  end

  @doc """
  Query events for a contract.
  """
  def query_events(chain, contract_address, opts \\ []) do
    from_block = Keyword.get(opts, :from_block, 0)
    to_block = Keyword.get(opts, :to_block, :infinity)
    topic_filter = Keyword.get(opts, :topics)
    limit = Keyword.get(opts, :limit, 100)

    contract_events = :ets.match_object(:da_events_by_contract, {{chain, contract_address}, :_})

    contract_events
    |> Enum.map(fn {_, event_key} ->
      case :ets.lookup(@events_table, event_key) do
        [{_, data}] -> data
        [] -> nil
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.filter(fn event ->
      event.block_number >= from_block and
        (to_block == :infinity or event.block_number <= to_block) and
        (topic_filter == nil or topics_match?(event.topics, topic_filter))
    end)
    |> Enum.sort_by(& &1.block_number, :desc)
    |> Enum.take(limit)
  end

  defp topics_match?(_stored_topics, nil), do: true
  defp topics_match?(stored_topics, topic_filter) do
    Enum.zip([stored_topics, topic_filter])
    |> Enum.all?(fn
      {_, nil} -> true
      {stored, filter} -> stored == filter
    end)
  end

  @doc """
  Get chain statistics.
  """
  def chain_stats(chain) do
    block_count = :ets.match_object(:da_blocks_by_chain, {chain, :_}) |> length()
    tx_count = :ets.match_object(@transactions_table, :_) |> Enum.count(fn {{^chain, _}, _} -> true end)
    event_count = :ets.match_object(@events_table, :_) |> Enum.count(fn {{^chain, _, _, _}, _} -> true end)

    latest_block =
      :ets.match_object(:da_blocks_by_chain, {chain, :_})
      |> Enum.map(fn {_, num} -> num end)
      |> Enum.max(fn -> nil end)

    %{
      chain: chain,
      blocks_stored: block_count,
      transactions_stored: tx_count,
      events_stored: event_count,
      latest_block: latest_block
    }
  end

  defp lookup_transaction(chain, tx_hash) do
    case :ets.lookup(@transactions_table, {chain, tx_hash}) do
      [{_, data}] -> data
      [] -> nil
    end
  end

  defp update_stats(key, increment) do
    :ets.update_counter(@stats_table, key, increment, {key, 0})
  end

  defp parse_hex(nil), do: 0
  defp parse_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp parse_hex(val) when is_integer(val), do: val
  defp parse_hex(_), do: 0

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end

  @impl true
  def handle_info(:cleanup, state) do
    cutoff = DateTime.utc_now() |> DateTime.to_unix() - (state.retention_hours * 3600)

    # Clean old blocks
    :ets.match_object(@blocks_table, :_)
    |> Enum.each(fn {{chain, _num}, data} ->
      if data.stored_at < cutoff do
        :ets.delete(@blocks_table, {chain, data.number})
        :ets.delete_object(:da_blocks_by_chain, {chain, data.number})
      end
    end)

    # Clean old transactions
    :ets.match_object(@transactions_table, :_)
    |> Enum.each(fn {{chain, _hash}, data} ->
      if data.stored_at < cutoff do
        :ets.delete(@transactions_table, {chain, data.hash})
        :ets.delete_object(:da_transactions_by_block, {{chain, data.block_number}, data.hash})
        :ets.delete_object(:da_transactions_by_hash, {data.hash, {chain, data.block_number}})
      end
    end)

    # Clean old events
    :ets.match_object(@events_table, :_)
    |> Enum.each(fn {{chain, _, _, _}, data} ->
      if data.stored_at < cutoff do
        :ets.delete(@events_table, {chain, data.contract_address, data.transaction_hash, data.log_index})
        :ets.delete_object(:da_events_by_contract, {{chain, data.contract_address}, {chain, data.contract_address, data.transaction_hash, data.log_index}})
        :ets.delete_object(:da_events_by_block, {{chain, data.block_number}, {chain, data.contract_address, data.transaction_hash, data.log_index}})
      end
    end)

    schedule_cleanup()
    {:noreply, state}
  end

  @doc """
  Get storage statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @impl true
  def handle_call(:stats, _from, state) do
    blocks = :ets.info(@blocks_table, :size)
    transactions = :ets.info(@transactions_table, :size)
    events = :ets.info(@events_table, :size)

    {:reply, %{
      blocks: blocks,
      transactions: transactions,
      events: events,
      retention_hours: state.retention_hours
    }, state}
  end
end
